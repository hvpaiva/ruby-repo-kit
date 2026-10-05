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

  def test_artifact_verification_never_implicitly_builds
    in_project do |project|
      RubyRepoKit::RakeTasks.install(project: project)

      assert_empty Rake::Task["release:verify_artifact"].prerequisites
      assert_equal ["build"], Rake::Task["release:artifact"].prerequisites
      assert_empty Rake::Task["release"].prerequisites
    end
  end
end
