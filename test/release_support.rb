# frozen_string_literal: true

require "ruby_repo_kit/release"
require "json"

module ReleaseSupport
  HEAD_SHA = "a" * 40
  MERGE_SHA = "b" * 40
  Status = Struct.new(:success?)

  class Clock
    attr_reader :sleeps, :now

    def initialize(now = Time.utc(2026, 10, 4))
      @now = now
      @sleeps = []
    end

    def sleep(seconds) = @sleeps << seconds
  end

  class Configuration
    attr_reader :calls

    def initialize(error = nil)
      @error = error
      @calls = 0
    end

    def verify!
      @calls += 1
      raise RubyRepoKit::Error, @error if @error
    end
  end

  def release_project(settings = {})
    in_project(settings) do |project|
      FileUtils.mkdir_p(File.dirname(project.path(project.version_file)))
      File.write(project.path(project.version_file), "module Example\n  VERSION = \"0.1.0\"\nend\n")
      File.write(project.path(project.changelog), initial_changelog(project))
      yield project
    end
  end

  def initial_changelog(project)
    "# Changelog\n\n## [Unreleased]\n\n### Added\n\n- Initial behavior.\n\n" \
      "[Unreleased]: #{project.url}/commits/main\n"
  end

  def released_changelog(project, version = "0.2.0", date = "2026-10-04")
    "# Changelog\n\n## [Unreleased]\n\n## [#{version}] - #{date}\n\n- Initial behavior.\n\n" \
      "[Unreleased]: #{project.url}/compare/v#{version}...HEAD\n" \
      "[#{version}]: #{project.url}/releases/tag/v#{version}\n"
  end

  def release_request(project, state = "MERGED")
    { "state" => state, "url" => "#{project.url}/pull/1", "isCrossRepository" => false,
      "headRefOid" => HEAD_SHA, "mergeCommit" => { "oid" => MERGE_SHA } }
  end

  def release_workflow(project, runner:, **options)
    commands = RubyRepoKit::Commands.new(project: project, runner: runner.method(:call), out: StringIO.new)
    defaults = { configuration: Configuration.new, clock: Clock.new, out: StringIO.new }
    RubyRepoKit::Release::Workflow.new("0.2.0", project: project, commands: commands, **defaults.merge(options))
  end

  # Unexpected commands raise instead of silently succeeding. Never executes a process.
  class Runner
    include ReleaseSupport

    attr_reader :calls, :state, :streams

    def initialize(project, **state)
      @project = project
      @calls = []
      @streams = []
      @state = state
      @source = [project.version_file, project.changelog].to_h { |path| [path, File.read(project.path(path))] }
    end

    def call(command, stream: false)
      @calls << command
      @streams << stream
      if command.first == "gh"
        unless command.last(2) == ["--repo", @project.repository]
          raise Minitest::Assertion, "Missing explicit repository: #{command.inspect}"
        end

        command = command[0...-2]
      end
      output = answer(command)
      failed = @state[:fail_at] && command.first(@state[:fail_at].length) == @state[:fail_at]
      [output, Status.new(!failed)]
    end

    private

    def answer(command)
      return git_answer(command) if command.first == "git"
      return github_answer(command) if command.first == "gh"
      return "" if [@project.generate_command, @project.check_command, %w[bundle lock --local]].include?(command)

      raise Minitest::Assertion, "Unexpected command: #{command.inspect}"
    end

    def git_answer(command)
      return "" if git_noops.include?(command)

      case command
      when %w[git remote get-url origin] then @state.fetch(:origin, "git@github.com:#{@project.repository}.git\n")
      when %w[git branch --show-current] then "#{@state.fetch(:branch, 'main')}\n"
      when %w[git status --porcelain -z] then @state.fetch(:dirty, "")
      when %w[git rev-parse HEAD], %w[git rev-parse origin/main], %w[git rev-parse origin/hotfix/0.2]
        "#{@state.fetch(:head, HEAD_SHA)}\n"
      when %w[git tag --list v0.2.0] then @state[:local_tag] ? "v0.2.0\n" : ""
      when ["git", "tag", "-s", "v0.2.0", "-m", "Release 0.2.0", MERGE_SHA]
        @state[:local_tag] = true
        ""
      when %w[git cat-file -t refs/tags/v0.2.0] then @state.fetch(:tag_type, "tag\n")
      when ["git", "rev-parse", "v0.2.0^{commit}"] then "#{@state.fetch(:tag_sha, MERGE_SHA)}\n"
      when ["git", "ls-remote", "--tags", "origin", "refs/tags/v0.2.0", "refs/tags/v0.2.0^{}"]
        @state[:remote_tag] ? "#{'c' * 40}\trefs/tags/v0.2.0\n#{@state[:remote_tag]}\trefs/tags/v0.2.0^{}\n" : ""
      else git_source(command)
      end
    end

    def git_noops
      [%w[git fetch origin --tags], %w[git log -1 --format=full], %w[git switch -c release/v0.2.0],
       ["git", "add", "--", *@project.release_files], ["git", "commit", "-S", "-m", "chore: release v0.2.0"],
       %w[git verify-commit HEAD], ["git", "verify-commit", HEAD_SHA], %w[git push -u origin release/v0.2.0],
       %w[git push origin v0.2.0], %w[git verify-tag v0.2.0],
       ["git", "merge-base", "--is-ancestor", HEAD_SHA, MERGE_SHA],
       ["git", "merge-base", "--is-ancestor", MERGE_SHA, "origin/main"],
       ["git", "merge-base", "--is-ancestor", MERGE_SHA, "origin/hotfix/0.2"]]
    end

    def git_source(command)
      allowed = ["HEAD", HEAD_SHA, MERGE_SHA].product([@project.version_file, @project.changelog])
      unless command.first(2) == %w[git show] && allowed.any? do |ref, path|
        command == ["git", "show", "#{ref}:#{path}"]
      end
        raise Minitest::Assertion, "Unexpected git command: #{command.inspect}"
      end

      ref, path = command[2].split(":", 2)
      return @source.fetch(path) if ref == "HEAD"
      return "VERSION = \"#{@state.fetch(:release_version, '0.2.0')}\"\n" if path == @project.version_file

      released_changelog(@project)
    end

    def github_answer(command)
      url = "#{@project.url}/pull/1"
      case command
      when ["gh", "pr", "list", "--state", "all", "--base", @state.fetch(:base, "main"), "--head", "release/v0.2.0",
            "--json", "url,state,headRefOid,mergeCommit,isCrossRepository"]
        JSON.generate(@state.fetch(:requests, @state[:pr] ? [@state[:pr]] : []))
      when ["gh", "pr", "view", url, "--json", "statusCheckRollup", "--jq", ".statusCheckRollup | length"]
        @state.fetch(:check_count, "1\n")
      when ["gh", "pr", "view", url, "--json", "mergeCommit", "--jq", ".mergeCommit.oid"] then "#{MERGE_SHA}\n"
      when ["gh", "pr", "checks", url, "--watch", "--fail-fast", "--interval", "10"],
           ["gh", "pr", "merge", url, "--merge", "--delete-branch", "--match-head-commit", HEAD_SHA],
           %w[gh run watch 123] then ""
      when ["gh", "run", "list", "--workflow", @project.workflow, "--branch", "v0.2.0",
            "--limit", "20", "--json", "databaseId,headSha,status,conclusion,event"]
        run = { databaseId: 123, headSha: MERGE_SHA, status: @state.fetch(:run_status, "completed"),
                conclusion: @state.fetch(:conclusion, "success"), event: "push" }
        JSON.generate(@state.fetch(:runs, @state[:missing_run] ? [] : [run]))
      when %w[gh run view 123 --json status,conclusion]
        JSON.generate({ status: "completed", conclusion: @state.fetch(:conclusion, "success") })
      when %w[gh run view 123 --json jobs] then JSON.generate({ jobs: @state.fetch(:jobs, []) })
      when %w[gh run view 456 --json jobs] then JSON.generate({ jobs: @state.fetch(:manual_jobs, []) })
      else create_request(command, url)
      end
    end

    def create_request(command, url)
      expected = ["gh", "pr", "create", "--base", @state.fetch(:base, "main"), "--head", "release/v0.2.0",
                  "--title", "chore: release v0.2.0", "--body-file"]
      unless command.length == expected.length + 1 && command[0...-1] == expected && File.file?(command.last)
        raise Minitest::Assertion, "Unexpected gh command: #{command.inspect}"
      end

      @state[:pr_body] = File.read(command.last)
      url
    end
  end
end
