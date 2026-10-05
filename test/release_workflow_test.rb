# frozen_string_literal: true

require "test_helper"
require_relative "release_support"

class ReleaseWorkflowTest < Minitest::Test
  include ReleaseSupport

  def test_dry_run_is_read_only_and_wrong_origin_or_policy_stops_before_mutations
    release_project do |project|
      runner = Runner.new(project)
      release_workflow(project, runner: runner, dry_run: true).run
      mutations = %w[switch push commit tag add]

      assert_equal initial_changelog(project), File.read(project.path(project.changelog))
      refute(runner.calls.any? { |argv| mutations.include?(argv[1]) || argv[2] == "create" })
      wrong = Runner.new(project, origin: "git@github.com:someone/else.git")

      assert_raises(RubyRepoKit::Error) { release_workflow(project, runner: wrong).run }
      assert_equal [%w[git remote get-url origin]], wrong.calls
      denied = Runner.new(project)
      configuration = Configuration.new("release environment is missing")

      assert_raises(RubyRepoKit::Error) { release_workflow(project, runner: denied, configuration: configuration).run }
      assert_equal [%w[git remote get-url origin]], denied.calls
    end
  end

  def test_default_prepares_and_opens_one_pr_without_merging_or_tagging
    release_project do |project|
      runner = Runner.new(project)
      release_workflow(project, runner: runner).run
      publication = [%w[gh pr merge], %w[git tag -s]]

      assert_equal "0.2.0", RubyRepoKit::Release::Metadata.new(project: project).version
      assert_includes runner.calls, ["git", "commit", "-S", "-m", "chore: release v0.2.0"]
      assert_includes runner.calls, %w[git push -u origin release/v0.2.0]
      assert_includes runner.state.fetch(:pr_body), "sample-cli 0.2.0"
      refute(runner.calls.any? { |argv| publication.include?(argv.first(3)) })
    end
  end

  def test_failed_local_checks_preserve_edits_but_do_not_commit_or_push
    release_project do |project|
      runner = Runner.new(project, fail_at: project.check_command)
      mutations = %w[commit push]

      assert_raises(RubyRepoKit::Error) { release_workflow(project, runner: runner, push: true).run }
      assert_equal "0.2.0", RubyRepoKit::Release::Metadata.new(project: project).version
      refute(runner.calls.any? { |argv| mutations.include?(argv[1]) })
    end
  end

  def test_push_waits_for_checks_pins_merge_and_signs_only_the_verified_merge
    release_project do |project|
      runner = Runner.new(project)
      release_workflow(project, runner: runner, push: true).run
      checks = runner.calls.index { |argv| argv.first(3) == %w[gh pr checks] }
      merge = runner.calls.index { |argv| argv.first(3) == %w[gh pr merge] }

      assert_operator checks, :<, merge
      assert_includes runner.calls[merge], HEAD_SHA
      assert_includes runner.calls, ["git", "merge-base", "--is-ancestor", HEAD_SHA, MERGE_SHA]
      assert_includes runner.calls, ["git", "tag", "-s", "v0.2.0", "-m", "Release 0.2.0", MERGE_SHA]
      assert_includes runner.calls, %w[git verify-tag v0.2.0]
      assert_includes runner.calls, %w[git push origin v0.2.0]
    end
  end

  def test_failed_remote_checks_or_ancestry_never_create_a_tag
    [%w[gh pr checks], %w[git merge-base --is-ancestor]].each do |failure|
      release_project do |project|
        runner = Runner.new(project, fail_at: failure)

        assert_raises(RubyRepoKit::Error) { release_workflow(project, runner: runner, push: true).run }
        refute(runner.calls.any? { |argv| argv.first(3) == %w[git tag -s] })
        refute(runner.calls.any? { |argv| argv.first(3) == %w[gh pr merge] }) if failure == %w[gh pr checks]
      end
    end
  end

  def test_open_pr_is_reused_and_foreign_multiple_or_wrong_version_pr_is_rejected
    release_project do |project|
      runner = Runner.new(project, pr: release_request(project, "OPEN"))
      release_workflow(project, runner: runner, push: true).run

      refute(runner.calls.any? { |argv| argv.first(3) == %w[gh pr create] || argv.first(2) == %w[git commit] })
      scenarios = [
        { pr: release_request(project, "OPEN").merge("isCrossRepository" => true) },
        { requests: [release_request(project, "OPEN"), release_request(project, "OPEN")] },
        { pr: release_request(project, "OPEN"), release_version: "0.9.0" }
      ]
      scenarios.each do |state|
        rejected = Runner.new(project, **state)

        assert_raises(RubyRepoKit::Error) { release_workflow(project, runner: rejected, push: true).run }
        refute(rejected.calls.any? { |argv| argv.first(3) == %w[gh pr merge] })
      end
    end
  end

  def test_hotfix_keeps_base_and_retry_command
    release_project do |project|
      runner = Runner.new(project, branch: "hotfix/0.2", base: "hotfix/0.2", fail_at: %w[git push])
      error = assert_raises(RubyRepoKit::Error) do
        release_workflow(project, runner: runner, branch: "hotfix/0.2", push: true).run
      end

      assert_includes error.message, "release 0.2.0 --branch hotfix/0.2 --push"
      assert_includes runner.calls, %w[git rev-parse origin/hotfix/0.2]
    end
  end

  def test_no_checks_timeout_never_merges
    release_project do |project|
      clock = Clock.new
      runner = Runner.new(project, pr: release_request(project, "OPEN"), check_count: "0")

      assert_raises(RubyRepoKit::Error) { release_workflow(project, runner: runner, clock: clock, push: true).run }
      assert_equal 60, clock.sleeps.length
      refute(runner.calls.any? { |argv| argv.first(3) == %w[gh pr merge] })
    end
  end

  def test_resuming_a_pr_checks_metadata_and_signature_even_without_push
    [{}, { dry_run: true }].each do |options|
      release_project do |project|
        [{ release_version: "0.9.0" }, { fail_at: ["git", "verify-commit", HEAD_SHA] }].each do |problem|
          runner = Runner.new(project, pr: release_request(project, "OPEN"), **problem)

          assert_raises(RubyRepoKit::Error) { release_workflow(project, runner: runner, **options).run }
          refute(runner.calls.any? { |argv| argv.first(3) == %w[gh pr merge] || argv.first(2) == %w[git push] })
        end
        runner = Runner.new(project, pr: release_request(project, "OPEN"))
        release_workflow(project, runner: runner, **options).run

        assert_includes runner.calls, ["git", "show", "#{HEAD_SHA}:#{project.version_file}"]
        assert_includes runner.calls, ["git", "verify-commit", HEAD_SHA]
      end
    end
  end
end
