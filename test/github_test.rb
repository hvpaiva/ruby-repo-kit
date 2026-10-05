# frozen_string_literal: true

require "test_helper"
require "ruby_repo_kit/github"

class GitHubTest < Minitest::Test
  GitHub = RubyRepoKit::GitHub
  class MemoryClient
    attr_reader :calls, :state
    attr_accessor :fail_path, :fail_method

    def initialize(project)
      @calls = []
      @environment = "/environments/#{project.environment}"
      policy = GitHub::Policy.new(project: project)
      scanning = %w[secret_scanning secret_scanning_push_protection].to_h { |key| [key, { "status" => "enabled" }] }
      @state = {
        "" => GitHub::Policy::MERGE_SETTINGS.merge("permissions" => { "admin" => true },
                                                   "security_and_analysis" => scanning),
        "/rulesets?includes_parents=false" => [{ "id" => 1, "name" => "main" }, { "id" => 2, "name" => "tags" }],
        "/rulesets/1" => policy.main_ruleset, "/rulesets/2" => policy.tags_ruleset,
        @environment => { "deployment_branch_policy" => GitHub::Policy::ENVIRONMENT },
        "#{@environment}/deployment-branch-policies" => { "branch_policies" => [GitHub::Policy::TAG.merge("id" => 1)] },
        "/vulnerability-alerts" => {}, "/automated-security-fixes" => { "enabled" => true },
        "/private-vulnerability-reporting" => { "enabled" => true }, "/immutable-releases" => { "enabled" => true },
        "/labels/skip-changelog" => { "name" => "skip-changelog", "color" => "123456" }
      }
      @state = JSON.parse(JSON.generate(@state))
    end

    def request(path, method: "GET", body: nil, missing: false)
      @calls << [method, path, body]
      raise GitHub::Error, "HTTP 403" if path == fail_path && (fail_method.nil? || method == fail_method)

      if method == "GET"
        return GitHub::Response.new(404, {}) if !state.key?(path) && missing

        return GitHub::Response.new(200, state.fetch(path))
      end

      apply(path, method, body)
      GitHub::Response.new(200, {})
    end

    def writes = calls.reject { |method, *_| method == "GET" }

    def apply(path, _method, body)
      case path
      when "" then state[""] = state[""].merge(body)
      when "/rulesets"
        index = state.fetch("/rulesets?includes_parents=false")
        id = (index.map { |item| item.fetch("id") }.max || 0) + 1
        index << body.slice("name").merge("id" => id)
        state["/rulesets/#{id}"] = body
      when "#{@environment}/deployment-branch-policies"
        state[path] ||= { "branch_policies" => [] }
        state[path]["branch_policies"] << body.merge("id" => 1)
      when %r{/deployment-branch-policies/\d+\z}
        state[path.sub(%r{/\d+\z}, "")]["branch_policies"].reject! { |entry| entry["id"].to_s == path.split("/").last }
      when "/labels" then state["/labels/skip-changelog"] = body
      else state[path] = body || { "enabled" => true }
      end
    end
  end

  def configuration(project, client)
    GitHub::Configuration.new(project: project, client: client, out: StringIO.new)
  end

  def test_plan_is_read_only_and_ignores_order_metadata_and_existing_label_style
    in_project do |project|
      client = MemoryClient.new(project)
      client.state["/rulesets/1"]["rules"].reverse!
      client.state["/rulesets/1"]["created_at"] = "2026-10-04"
      config = configuration(project, client)

      assert_empty config.plan
      assert config.verify!
      assert_empty client.writes
    end
  end

  def test_policy_uses_configured_checks_and_protects_main_hotfixes_and_tags
    in_project("required_checks" => %w[test-custom quality]) do |project|
      policy = GitHub::Policy.new(project: project)
      rules = policy.main_ruleset.fetch("rules")
      checks = rules.find do |rule|
        rule["type"] == "required_status_checks"
      end.dig("parameters", "required_status_checks")

      assert_equal(%w[test-custom quality], checks.map { |check| check["context"] })
      assert_equal [15_368], checks.map { |check| check["integration_id"] }.uniq
      assert_equal %w[refs/heads/main refs/heads/hotfix/*], policy.main_ruleset.dig("conditions", "ref_name", "include")
      assert_includes rules.map { |rule| rule["type"] }, "required_signatures"
      assert_equal(%w[creation update deletion], policy.tags_ruleset["rules"].map { |rule| rule["type"] })
    end
  end

  def test_apply_reconciles_all_reads_before_writes_and_second_apply_does_not_write
    in_project("environment" => "gem-release") do |project|
      client = MemoryClient.new(project)
      client.state[""]["allow_squash_merge"] = true
      client.state["/rulesets?includes_parents=false"] = []
      %w[/environments/gem-release /environments/gem-release/deployment-branch-policies
         /vulnerability-alerts /labels/skip-changelog].each { |path| client.state.delete(path) }
      %w[automated-security-fixes private-vulnerability-reporting immutable-releases].each do |feature|
        client.state["/#{feature}"] = { "enabled" => false }
      end
      config = configuration(project, client)

      assert config.apply!
      first_write = client.calls.index { |method, *_| method != "GET" }

      assert_includes client.calls.take(first_write).map { |_, path, _| path }, "/labels/skip-changelog"
      assert_equal 10, client.writes.length
      client.calls.clear

      assert config.apply!
      assert_empty client.writes
    end
  end

  def test_no_mutation_when_a_late_read_is_forbidden_or_unknown
    in_project do |project|
      client = MemoryClient.new(project)
      client.state[""]["allow_squash_merge"] = true
      client.fail_path = "/immutable-releases"

      assert_raises(GitHub::Error) { configuration(project, client).apply! }
      assert_empty client.writes
      client.fail_path = nil
      client.state["/immutable-releases"] = { "enabled" => "unknown" }

      assert_raises(GitHub::Error) { configuration(project, client).apply! }
      assert_empty client.writes
    end
  end

  def test_partial_apply_is_replanned_and_resumes_without_repeating_completed_writes
    in_project do |project|
      client = MemoryClient.new(project)
      client.state[""]["allow_squash_merge"] = true
      client.state["/immutable-releases"] = { "enabled" => false }
      client.fail_path = "/immutable-releases"
      client.fail_method = "PUT"
      config = configuration(project, client)

      assert_raises(GitHub::Error) { config.apply! }
      refute client.state[""]["allow_squash_merge"]
      client.fail_path = nil
      client.calls.clear

      assert config.apply!
      assert_equal [["PUT", "/immutable-releases", nil]], client.writes
    end
  end

  def test_drift_in_checks_bypasses_or_extra_deployment_policies_is_visible
    in_project do |project|
      client = MemoryClient.new(project)
      ruleset = client.state["/rulesets/1"]
      ruleset["bypass_actors"] = [{ "actor_id" => 5 }]
      checks = ruleset["rules"].find { |rule| rule["type"] == "required_status_checks" }
      checks["parameters"]["required_status_checks"].first["integration_id"] = 42
      client.state["/environments/release/deployment-branch-policies"]["branch_policies"] <<
        { "id" => 2, "type" => "branch", "name" => "*" }
      config = configuration(project, client)

      error = assert_raises(GitHub::Error) { config.verify! }
      assert_match(/main ruleset/, error.message)
      assert_match(/extra release deployment policy/, error.message)
      assert_empty client.writes
      assert config.apply!
    end
  end

  def test_environment_update_preserves_reviewers_and_wait_timer
    in_project do |project|
      client = MemoryClient.new(project)
      client.state["/environments/release"] = {
        "deployment_branch_policy" => nil,
        "protection_rules" => [
          { "type" => "wait_timer", "wait_timer" => 30 },
          { "type" => "required_reviewers", "prevent_self_review" => true,
            "reviewers" => [{ "type" => "User", "reviewer" => { "id" => 42, "login" => "owner" } }] }
        ]
      }
      plan = configuration(project, client).plan
      body = plan.find { |change| change.path == "/environments/release" }.body

      assert_equal 30, body["wait_timer"]
      assert body["prevent_self_review"]
      assert_equal [{ "type" => "User", "id" => 42 }], body["reviewers"]
      assert_empty client.writes
    end
  end

  def test_unknown_environment_protection_is_not_erased_by_an_update
    in_project do |project|
      client = MemoryClient.new(project)
      client.state["/environments/release"] = {
        "deployment_branch_policy" => nil, "protection_rules" => [{ "type" => "future_protection" }]
      }

      assert_raises(GitHub::Error) { configuration(project, client).apply! }
      assert_empty client.writes
    end
  end

  def test_unmanaged_rules_remain_when_managed_rules_are_reconciled
    in_project do |project|
      client = MemoryClient.new(project)
      extra = { "type" => "required_deployments",
                "parameters" => { "required_deployment_environments" => ["preview"] } }
      client.state["/rulesets/1"]["rules"] << extra
      config = configuration(project, client)

      assert_empty config.plan
      client.state["/rulesets/1"]["enforcement"] = "disabled"

      assert config.apply!
      assert_includes client.state["/rulesets/1"]["rules"], extra
    end
  end

  def test_duplicate_ruleset_or_unknown_api_shape_refuses_changes
    in_project do |project|
      client = MemoryClient.new(project)
      client.state["/rulesets?includes_parents=false"] << { "id" => 3, "name" => "main" }

      assert_raises(GitHub::Error) { configuration(project, client).apply! }
      client.state["/rulesets?includes_parents=false"] = { "unknown" => [] }
      assert_raises(GitHub::Error) { configuration(project, client).apply! }
      assert_empty client.writes
    end
  end
end

class GitHubClientTest < Minitest::Test
  GitHub = RubyRepoKit::GitHub
  Status = Data.define(:success) do
    def success? = success
  end

  def client_response(project, code, content = {}, success: code.between?(200, 299))
    GitHub::Client.new(project: project, runner: lambda do |*_args, **_options|
      output = "HTTP/2.0 #{code} Response\r\nContent-Type: application/json\r\n\r\n#{JSON.generate(content)}"
      [output, Status.new(success)]
    end)
  end

  def test_client_distinguishes_404_from_forbidden_and_server_failures
    in_project do |project|
      assert_equal 404, client_response(project, 404).request("/vulnerability-alerts", missing: true).status
      [403, 429, 500].each do |code|
        assert_raises(GitHub::Error) { client_response(project, code).request("/vulnerability-alerts", missing: true) }
      end
      assert_raises(GitHub::Error) { client_response(project, 403, success: true).request("/immutable-releases") }
      assert_raises(GitHub::Error) { client_response(project, 200, success: false).request("") }
    end
  end

  def test_client_sends_configured_repository_and_json_on_stdin
    in_project("repository" => "different/consumer") do |project|
      calls = []
      runner = lambda do |argv, **options|
        calls << [argv, options]
        ["HTTP/2.0 204 No Content\r\n\r\n", Status.new(true)]
      end
      result = GitHub::Client.new(project: project, runner: runner).request("/labels", method: "POST",
                                                                                       body: { "name" => "example" })

      assert_equal 204, result.status
      assert_includes calls.first.first, "repos/different/consumer/labels"
      assert_equal({ "name" => "example" }, JSON.parse(calls.first.last.fetch(:stdin_data)))
      refute_includes calls.first.first, "example"
    end
  end

  def test_client_reads_every_page_and_refuses_cross_repository_pagination
    in_project do |project|
      calls = []
      next_url = "https://api.github.com/repos/#{project.repository}/rulesets?page=2"
      runner = lambda do |argv, **_options|
        calls << argv.last
        link = calls.length == 1 ? "Link: <#{next_url}>; rel=\"next\"\r\n" : ""
        ["HTTP/2.0 200 OK\r\n#{link}\r\n[{\"id\":#{calls.length}}]", Status.new(true)]
      end
      client = GitHub::Client.new(project: project, runner: runner)

      assert_equal [{ "id" => 1 }, { "id" => 2 }], client.request("/rulesets").body
      assert_equal 2, calls.length
      calls.clear
      next_url = "https://api.github.com/repos/other/repo/rulesets?page=2"
      assert_raises(GitHub::Error) { client.request("/rulesets") }
      assert_equal 1, calls.length
    end
  end

  def test_client_rejects_unreadable_output_without_exposing_it
    in_project do |project|
      runner = ->(*, **) { ["unexpected secret sentinel", Status.new(false)] }
      error = assert_raises(GitHub::Error) { GitHub::Client.new(project: project, runner: runner).request("") }

      refute_match(/sentinel/, error.message)
      assert_raises(GitHub::Error) { client_response(project, 200).request("/../outside") }
    end
  end

  def test_client_rejects_cyclic_pagination_and_invalid_json
    in_project do |project|
      runner = lambda do |*, **|
        header = "HTTP/2.0 200 OK\r\nLink: <https://api.github.com/repos/#{project.repository}/rulesets>; rel=\"next\""
        ["#{header}\r\n\r\n[]", Status.new(true)]
      end

      assert_raises(GitHub::Error) { GitHub::Client.new(project: project, runner: runner).request("/rulesets") }
      runner = ->(*, **) { ["HTTP/2.0 200 OK\r\n\r\nnot JSON", Status.new(true)] }

      assert_raises(GitHub::Error) { GitHub::Client.new(project: project, runner: runner).request("") }
    end
  end

  def test_real_client_runner_uses_project_root
    in_project do |project|
      bin = File.join(project.root, "bin")
      FileUtils.mkdir_p(bin)
      File.write(File.join(bin, "gh"),
                 "#!/usr/bin/env ruby\nrequire 'json'\nputs \"HTTP/2.0 200 OK\\n\\n\" + JSON.generate(cwd: Dir.pwd)\n")
      File.chmod(0o755, File.join(bin, "gh"))
      previous = ENV.fetch("PATH")
      begin
        ENV["PATH"] = "#{bin}:#{previous}"
        result = GitHub::Client.new(project: project).request("")

        assert_equal project.root, result.body.fetch("cwd")
      ensure
        ENV["PATH"] = previous
      end
    end
  end
end
