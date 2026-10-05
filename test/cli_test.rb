# frozen_string_literal: true

require "test_helper"
require "ruby_repo_kit/cli"

class CLITest < Minitest::Test
  def invoke(*argv, root: Dir.pwd)
    out = StringIO.new
    err = StringIO.new
    status = RubyRepoKit::CLI.run(argv, root: root, out: out, err: err)
    [status, out.string, err.string]
  end

  def test_help_and_version_work_without_a_project
    assert_equal [0, "ruby-repo-kit #{RubyRepoKit::VERSION}\n", ""], invoke("--version", root: "/")
    status, output, error = invoke("--help", root: "/")

    assert_equal 0, status
    assert_includes output, "github plan"
    assert_empty error
  end

  def test_unknown_command_reports_usage_failure
    status, output, error = invoke("nope")

    assert_equal 2, status
    assert_empty output
    assert_includes error, "unknown command"
  end

  def test_generation_and_doctor_work_from_a_directory_with_spaces
    Dir.mktmpdir do |root|
      directory = File.join(root, "my canary")
      status, output, error = invoke("new", "my-canary", "--directory", directory,
                                     "--repository", "example/my-canary", "--author", "Example",
                                     "--email", "example@example.org", root: root)

      assert_equal 0, status, error
      assert_includes output, "Created #{File.realpath(directory)}"
      status, output, error = invoke("doctor", root: directory)

      assert_equal 0, status, error
      assert_includes output, "verified for my-canary"
    end
  end

  def test_invalid_options_fail_before_release_or_github_activity
    [
      ["release", "0.1.0", "--push", "--dry-run"],
      ["release"],
      ["github", "delete"],
      ["github", "plan", "extra"],
      ["doctor", "extra"],
      ["new", "my-canary", "--repository", "example/my-canary"]
    ].each do |argv|
      status, output, error = invoke(*argv, root: "/")

      assert_equal 2, status, "#{argv.inspect}: #{error}"
      assert_empty output
    end
  end

  def test_missing_project_is_a_concise_operational_error
    status, output, error = invoke("doctor", root: "/")

    assert_equal 1, status
    assert_empty output
    assert_includes error, ".ruby-repo.yml"
  end
end
