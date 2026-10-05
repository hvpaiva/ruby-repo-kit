# frozen_string_literal: true

require "test_helper"
require_relative "release_support"

class ReleaseRecoveryTest < Minitest::Test
  include ReleaseSupport

  def test_partial_preparation_resumes_next_day_preserving_date
    release_project do |project|
      runner = Runner.new(project, branch: "release/v0.2.0",
                                   dirty: " M #{project.version_file}\0 M #{project.changelog}\0")
      changes = RubyRepoKit::Release::Metadata.new(project: project, clock: Clock.new).changes("0.2.0")
      changes.each { |path, content| File.write(project.path(path), content) }
      release_workflow(project, runner: runner, clock: Clock.new(Time.utc(2026, 10, 5))).run

      assert_equal changes.fetch(project.changelog), File.read(project.path(project.changelog))
      assert(runner.calls.any? { |argv| argv.first(3) == %w[gh pr create] })
    end
  end

  def test_partial_preparation_refuses_unrelated_edits_and_similarly_named_directories
    [" M README.md\0", " M man-extra/page.1\0", "R  man/page.1\0README.md\0"].each do |dirty|
      release_project("generated_paths" => ["man"]) do |project|
        runner = Runner.new(project, branch: "release/v0.2.0", dirty: dirty)

        assert_raises(RubyRepoKit::Error) { release_workflow(project, runner: runner).run }
        refute(runner.calls.any? { |argv| argv.first == "bundle" })
      end
    end
    release_project do |project|
      runner = Runner.new(project, branch: "release/v0.2.0", dirty: " M #{project.version_file}\0")
      File.write(project.path(project.version_file), "VERSION = '0.5.0'\n")

      assert_raises(RubyRepoKit::Error) { release_workflow(project, runner: runner).run }
      assert_equal "VERSION = '0.5.0'\n", File.read(project.path(project.version_file))
    end
  end

  def test_merged_pr_with_local_tag_resumes_without_duplicate_commit_pr_or_tag
    release_project do |project|
      runner = Runner.new(project, pr: release_request(project), local_tag: true)
      release_workflow(project, runner: runner, push: true).run
      duplicate = [%w[gh pr create], %w[git tag -s]]

      assert_includes runner.calls, %w[git push origin v0.2.0]
      refute(runner.calls.any? { |argv| duplicate.include?(argv.first(3)) })
      refute(runner.calls.any? { |argv| argv.first(2) == %w[git commit] })
    end
  end

  def test_already_prepared_branch_rechecks_and_opens_pr_without_rewriting_or_committing
    release_project do |project|
      metadata = RubyRepoKit::Release::Metadata.new(project: project, clock: Clock.new)
      metadata.changes("0.2.0").each { |path, content| File.write(project.path(path), content) }
      runner = Runner.new(project, branch: "release/v0.2.0")
      release_workflow(project, runner: runner).run

      assert_includes runner.calls, project.check_command
      assert(runner.calls.any? { |argv| argv.first(3) == %w[gh pr create] })
      refute(runner.calls.any? { |argv| argv.first(2) == %w[git commit] })
    end
  end

  def test_closed_or_locally_diverged_pr_never_merges
    release_project do |project|
      [{ pr: release_request(project, "CLOSED") },
       { pr: release_request(project, "OPEN"), branch: "release/v0.2.0", head: "d" * 40 }].each do |state|
        runner = Runner.new(project, **state)

        assert_raises(RubyRepoKit::Error) { release_workflow(project, runner: runner, push: true).run }
        refute(runner.calls.any? { |argv| argv.first(3) == %w[gh pr merge] })
      end
    end
  end

  def test_merged_pr_without_push_reports_next_step_without_creating_a_tag
    release_project do |project|
      runner = Runner.new(project, pr: release_request(project))
      output = StringIO.new
      release_workflow(project, runner: runner, out: output).run

      assert_includes output.string, "--push to sign and push its tag"
      refute(runner.calls.any? { |argv| argv.first(3) == %w[git tag -s] || argv.first(2) == %w[git push] })
    end
  end

  def test_remote_tag_is_observation_only_and_mismatch_is_never_replaced
    release_project do |project|
      runner = Runner.new(project, pr: release_request(project), local_tag: true, remote_tag: MERGE_SHA)
      release_workflow(project, runner: runner, push: true).run

      refute(runner.calls.any? { |argv| argv.first(2) == %w[git push] || argv.first(3) == %w[git tag -s] })
      wrong = Runner.new(project, pr: release_request(project), remote_tag: "d" * 40)
      error = assert_raises(RubyRepoKit::Error) { release_workflow(project, runner: wrong, push: true).run }

      assert_match(/never be moved/, error.message)
      orphaned = Runner.new(project, remote_tag: MERGE_SHA)

      assert_raises(RubyRepoKit::Error) { release_workflow(project, runner: orphaned, push: true).run }
    end
  end

  def test_local_tag_must_be_signed_annotated_and_target_the_merge
    [{ tag_type: "commit\n" }, { tag_sha: "d" * 40 }, { fail_at: %w[git verify-tag] }].each do |state|
      release_project do |project|
        runner = Runner.new(project, pr: release_request(project), local_tag: true, **state)

        assert_raises(RubyRepoKit::Error) { release_workflow(project, runner: runner, push: true).run }
        refute(runner.calls.any? { |argv| argv.first(2) == %w[git push] })
      end
    end
  end

  def test_dry_run_existing_pr_or_tag_never_merges_pushes_or_watches
    release_project do |project|
      [release_request(project, "OPEN"), release_request(project)].each do |request|
        runner = Runner.new(project, pr: request, local_tag: true, remote_tag: MERGE_SHA)
        # An open PR with an already published tag is an inconsistent state and is refused.
        if request["state"] == "OPEN"
          assert_raises(RubyRepoKit::Error) { release_workflow(project, runner: runner, dry_run: true).run }
        else
          release_workflow(project, runner: runner, dry_run: true).run
        end

        refute(runner.calls.any? { |argv| argv.first(2) == %w[git push] || argv.first(3) == %w[gh run watch] })
      end
    end
  end

  def test_partial_publication_reports_only_safe_recovery_and_never_reruns
    release_project do |project|
      scenarios = [
        [[{ "name" => "publish", "conclusion" => "success" },
          { "name" => "github-release", "conclusion" => "failure", "databaseId" => 41 }], /Retry only GitHub release/],
        [[{ "name" => "publish", "conclusion" => "skipped" }], /Publication did not run/],
        [[{ "name" => "publish", "conclusion" => "failure" }], /Check whether RubyGems accepted/]
      ]
      scenarios.each do |jobs, message|
        runner = Runner.new(project, pr: release_request(project), remote_tag: MERGE_SHA,
                                     run_status: "in_progress", conclusion: "failure", jobs: jobs)
        error = assert_raises(RubyRepoKit::Error) { release_workflow(project, runner: runner, push: true).run }

        assert_match message, error.message
        refute(runner.calls.any? { |argv| argv.first(3) == %w[gh run rerun] || argv.first(2) == %w[git push] })
      end
    end
  end

  def test_missing_workflow_after_tag_push_is_observation_only
    release_project do |project|
      runner = Runner.new(project, pr: release_request(project), remote_tag: MERGE_SHA, missing_run: true)
      clock = Clock.new
      error = assert_raises(RubyRepoKit::Error) { release_workflow(project, runner: runner, clock: clock, push: true).run }

      assert_includes error.message, "No Release run appeared"
      assert_equal 60, clock.sleeps.length
      refute(runner.calls.any? { |argv| argv.first(3) == %w[gh workflow run] || argv.first(2) == %w[git push] })
    end
  end

  def test_successful_manual_publication_recovers_an_earlier_failed_push_run
    release_project do |project|
      runs = [
        { databaseId: 456, headSha: MERGE_SHA, status: "completed", conclusion: "success", event: "workflow_dispatch" },
        { databaseId: 123, headSha: MERGE_SHA, status: "completed", conclusion: "failure", event: "push" }
      ]
      jobs = %w[publish github-release].map { |name| { "name" => name, "conclusion" => "success" } }
      runner = Runner.new(project, pr: release_request(project), remote_tag: MERGE_SHA, runs: runs, manual_jobs: jobs)
      output = StringIO.new
      release_workflow(project, runner: runner, out: output, push: true).run

      assert_includes output.string, "Released v0.2.0; the existing successful run is 456"
      assert(runner.calls.any? { |argv| argv.first(6) == %w[gh run view 456 --json jobs] })
      refute(runner.calls.any? { |argv| argv.first(2) == %w[git push] || argv.first(3) == %w[gh run rerun] })
    end
  end

  def test_successful_manual_dry_run_or_another_commit_never_reports_released
    publication_jobs = %w[publish github-release]
    [MERGE_SHA, HEAD_SHA].each do |sha|
      release_project do |project|
        runs = [
          { databaseId: 456, headSha: sha, status: "completed", conclusion: "success", event: "workflow_dispatch" },
          { databaseId: 123, headSha: MERGE_SHA, status: "completed", conclusion: "failure", event: "push" }
        ]
        conclusion = sha == MERGE_SHA ? "skipped" : "success"
        jobs = publication_jobs.map { |name| { "name" => name, "conclusion" => conclusion } }
        runner = Runner.new(project, pr: release_request(project), remote_tag: MERGE_SHA, runs: runs, manual_jobs: jobs)
        output = StringIO.new

        assert_raises(RubyRepoKit::Error) { release_workflow(project, runner: runner, out: output, push: true).run }
        refute_includes output.string, "Released v0.2.0"
        refute(runner.calls.any? { |argv| argv.first(2) == %w[git push] || argv.first(3) == %w[gh run rerun] })
      end
    end
  end

  def test_manual_dry_run_without_any_push_run_is_not_a_publication
    release_project do |project|
      runs = [{ databaseId: 456, headSha: MERGE_SHA, status: "completed", conclusion: "success",
                event: "workflow_dispatch" }]
      jobs = %w[publish github-release].map { |name| { "name" => name, "conclusion" => "skipped" } }
      runner = Runner.new(project, pr: release_request(project), remote_tag: MERGE_SHA, runs: runs, manual_jobs: jobs)
      output = StringIO.new
      error = assert_raises(RubyRepoKit::Error) do
        release_workflow(project, runner: runner, out: output, push: true).run
      end

      assert_includes error.message, "publication was not confirmed"
      refute_includes error.message, "--failed"
      refute_includes output.string, "Released v0.2.0"
    end
  end
end
