# frozen_string_literal: true

require "test_helper"

class CommandsTest < Minitest::Test
  def test_executes_arguments_literally_in_project_directory
    in_project do |project|
      commands = RubyRepoKit::Commands.new(project: project, out: StringIO.new)
      result = commands.call([RbConfig.ruby, "-e", "puts Dir.pwd; puts ARGV", "$(touch unexpected)"])

      assert_equal [project.root, "$(touch unexpected)"], result.lines.map(&:chomp)
      refute_path_exists File.join(project.root, "unexpected")
    end
  end

  def test_repository_is_explicit_without_modifying_caller_arguments
    in_project do |project|
      observed = []
      runner = lambda do |argv, stream:|
        observed << [argv, stream]
        ["{}", Struct.new(:success?).new(true)]
      end
      commands = RubyRepoKit::Commands.new(project: project, runner: runner, out: StringIO.new)
      original = %w[gh pr list].freeze
      commands.call(original)
      commands.call(%w[gh api repos/example/sample-cli])

      assert_equal ["gh", "pr", "list", "--repo", "example/sample-cli"], observed.first.first
      assert_equal %w[gh api repos/example/sample-cli], observed.last.first
      assert_equal %w[gh pr list], original
    end
  end

  def test_propagates_process_failure
    in_project do |project|
      commands = RubyRepoKit::Commands.new(project: project, out: StringIO.new)
      error = assert_raises(RubyRepoKit::Error) { commands.call([RbConfig.ruby, "-e", "warn 'failure'; exit 3"]) }
      assert_includes error.message, "failure"
    end
  end
end
