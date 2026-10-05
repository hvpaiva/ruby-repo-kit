# frozen_string_literal: true

require "test_helper"
require "ruby_repo_kit/rake_tasks"

class RakeTasksTest < Minitest::Test
  def setup
    @previous_application = Rake.application
    Rake.application = Rake::Application.new
  end

  def teardown
    Rake.application = @previous_application
  end

  def test_install_registers_explicit_interfaces_without_running_effects
    in_project do |project|
      RubyRepoKit::RakeTasks.install(project: project)
      tasks = %w[repo:check build package:check lint:commits audit release release:verify
                 release:verify_ref release:artifact release:verify_artifact github:plan github:verify github:apply]

      tasks.each do |task|
        assert Rake::Task.task_defined?(task), "Missing #{task}"
      end
      refute_path_exists project.path("pkg")
    end
  end

  def test_refuses_to_combine_competing_release_tasks
    in_project do |project|
      Rake::Task.define_task(:release) { flunk "Existing release must not run" }
      error = assert_raises(RubyRepoKit::Error) { RubyRepoKit::RakeTasks.install(project: project) }
      assert_includes error.message, "competing release tooling"
      refute Rake::Task.task_defined?("release:artifact")
    end
  end

  def test_release_tasks_compose_with_local_tasks_and_verify_real_metadata
    previous = %w[GITHUB_REF_TYPE GITHUB_REF_NAME TAG].to_h { |key| [key, ENV.fetch(key, nil)] }
    previous.each_key { |key| ENV.delete(key) }
    in_project do |project|
      FileUtils.mkdir_p(File.dirname(project.path(project.version_file)))
      File.write(project.path(project.version_file), "module SampleCLI\n  VERSION = '0.1.0'\nend\n")
      File.write(project.path(project.changelog), <<~TEXT)
        ## [Unreleased]
        ## [0.1.0] - 2026-10-01
        - Add the example CLI.
        [Unreleased]: https://github.com/example/sample-cli/compare/v0.1.0...HEAD
        [0.1.0]: https://github.com/example/sample-cli/releases/tag/v0.1.0
      TEXT
      RubyRepoKit::RakeTasks.install_release(project: project)

      %w[build repo:check lint:commits package:check audit github:plan github:verify github:apply].each do |task|
        refute Rake::Task.task_defined?(task), "Unexpected shared task: #{task}"
      end
      output, error = capture_io { Rake::Task["release:verify"].invoke }

      assert_equal "Verified sample-cli 0.1.0\n", output
      assert_empty error
      assert_equal ["build"], Rake::Task["release:artifact"].prerequisites
      assert_empty Rake::Task["release"].prerequisites
    end
  ensure
    previous.each { |key, value| ENV[key] = value }
  end

  def test_composed_release_tasks_refuse_to_change_an_existing_publisher
    in_project do |project|
      existing = Rake::Task.define_task("release" => ["existing:guard"]) { flunk "Existing release must not run" }
      actions = existing.actions.dup
      prerequisites = existing.prerequisites.dup

      assert_raises(RubyRepoKit::Error) { RubyRepoKit::RakeTasks.install_release(project: project) }
      assert_equal actions, existing.actions
      assert_equal prerequisites, existing.prerequisites
      refute Rake::Task.task_defined?("release:artifact")
      refute Rake::Task.task_defined?("release:verify")
    end
  end

  def test_artifact_verification_never_implicitly_builds
    in_project do |project|
      RubyRepoKit::RakeTasks.install(project: project)

      assert_empty Rake::Task["release:verify_artifact"].prerequisites
      assert_equal ["build"], Rake::Task["release:artifact"].prerequisites
      assert_empty Rake::Task["release"].prerequisites
    end
  end
end
