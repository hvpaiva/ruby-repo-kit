# frozen_string_literal: true

require_relative "test_helper"
require "ruby_repo_kit/scaffold"
require "open3"
require "rbconfig"
require "rubygems/package"

module ScaffoldFixtures
  def with_destination
    Dir.mktmpdir("scaffold parent ") do |directory|
      yield File.join(File.realpath(directory), "a project with spaces")
    end
  end

  def scaffold(destination, **settings)
    RubyRepoKit::Scaffold.new(
      name: "sample-echo", destination: destination, repository: "example/sample-echo",
      author: "Example Maintainer", email: "maintainer@example.test", **settings
    )
  end
end

class ScaffoldTest < Minitest::Test
  include ScaffoldFixtures

  def test_generation_sets_identity_and_development_integration_without_side_effects
    with_destination do |destination|
      assert_equal destination, scaffold(destination).generate
      project = RubyRepoKit::Project.load(root: destination)

      assert_equal "sample-echo", project.name
      assert_equal "lib/sample_echo/version.rb", project.version_file
      assert_equal RubyRepoKit::Project::DEFAULT_CHECKS, project.required_checks
      assert_empty project.generated_paths
      assert_path_exists File.join(destination, ".github/workflows/release.yml")
      assert File.executable?(File.join(destination, "exe/sample-echo"))
      assert File.executable?(File.join(destination, "bin/release"))
      refute_path_exists File.join(destination, ".git")
      refute_path_exists File.join(destination, "Gemfile.lock")
      refute_path_exists File.join(destination, ".bundle")
    end
  end

  def test_existing_directory_and_files_are_never_overwritten
    with_destination do |destination|
      FileUtils.mkdir_p(destination)
      sentinel = File.join(destination, "README.md")
      File.write(sentinel, "Existing project")

      assert_raises(RubyRepoKit::Error) { scaffold(destination).generate }
      assert_equal "Existing project", File.read(sentinel)
    end
  end

  def test_existing_regular_file_is_never_overwritten
    with_destination do |destination|
      File.write(destination, "Existing file")

      assert_raises(RubyRepoKit::Error) { scaffold(destination).generate }
      assert_equal "Existing file", File.read(destination)
    end
  end

  def test_destination_symlinks_and_broken_symlinks_are_rejected
    with_destination do |destination|
      target = File.join(File.dirname(destination), "target")
      FileUtils.mkdir_p(target)
      File.symlink(target, destination)

      assert_raises(RubyRepoKit::Error) { scaffold(destination).generate }
      assert_empty Dir.children(target)

      File.unlink(destination)
      FileUtils.rmdir(target)
      File.symlink(target, destination)

      assert_raises(RubyRepoKit::Error) { scaffold(destination).generate }
      refute_path_exists target
    end
  end

  def test_existing_symlink_parent_is_canonicalized_without_overwriting_the_destination
    with_destination do |destination|
      parent = File.dirname(destination)
      alias_path = File.join(parent, "alias")
      File.symlink(parent, alias_path)

      generated = scaffold(File.join(alias_path, "new-project")).generate

      assert_equal File.join(parent, "new-project"), generated
      assert_path_exists File.join(generated, "sample-echo.gemspec")
      assert_raises(RubyRepoKit::Error) { scaffold(File.join(alias_path, "new-project")).generate }
    end
  end

  def test_invalid_names_repositories_and_versions_are_rejected_before_writing
    with_destination do |destination|
      [
        { name: "../escape" }, { name: "BadName" }, { name: "x;system" }, { name: "object" },
        { name: "ruby-repo-kit" }, { repository: "example/../other" }, { repository: "a/b\ninjected: true" },
        { toolkit_version: "0.1.0\";raise" }, { author: "Name\nOther" }, { email: "missing-address" }
      ].each do |invalid|
        assert_raises(RubyRepoKit::Error) { scaffold(destination, **invalid).generate }
      end
      refute_path_exists destination
    end
  end

  def test_author_is_a_ruby_literal_not_executable_code
    with_destination do |destination|
      author = "A \"\#{raise(\"interpolation executed\")}\" O'Brien"
      scaffold(destination, author: author).generate
      specification = Gem::Specification.load(File.join(destination, "sample-echo.gemspec"))

      assert_equal [author], specification.authors
      assert_equal ["optparse"], specification.runtime_dependencies.map(&:name)
      refute_includes specification.files, "Gemfile"
      refute_includes specification.files, ".ruby-repo.yml"
      assert(specification.files.all? { |path| File.file?(File.join(destination, path)) })
    end
  end

  def test_option_parser_namespace_is_rejected_before_creating_a_broken_cli
    with_destination do |destination|
      %w[option-parser option_parser].each do |name|
        error = assert_raises(RubyRepoKit::Error) { scaffold(destination, name: name).generate }

        assert_includes error.message, "Reserved Ruby namespace: OptionParser"
        refute_path_exists destination
      end
    end
  end

  def test_alternate_name_and_namespace_are_rendered_without_template_tokens_or_source_project_names
    with_destination do |destination|
      scaffold(destination, name: "harbor_notes2", repository: "another/harbor-notes").generate
      version = File.read(File.join(destination, "lib/harbor_notes2/version.rb"))
      files = Dir.glob("**/*", File::FNM_DOTMATCH, base: destination).select do |path|
        File.file?(File.join(destination, path))
      end
      content = files.map { |path| File.read(File.join(destination, path)) }.join

      assert_includes version, "module HarborNotes2"
      assert(files.none? { |path| path.end_with?(".erb") || path.include?("__") })
      refute_match(/<%|__require_path__|__name__|rich-ri|rich_ri|RichRI|slipway|Slipway/, content)
    end
  end

  def test_workflows_match_required_checks_and_publish_only_the_verified_artifact
    with_destination do |destination|
      scaffold(destination).generate
      ci = Psych.safe_load_file(File.join(destination, ".github/workflows/ci.yml"))
      release = Psych.safe_load_file(File.join(destination, ".github/workflows/release.yml"))
      matrix = ci.fetch("jobs").fetch("test").fetch("strategy").fetch("matrix")

      assert_equal %w[3.4 4.0], matrix.fetch("ruby")
      assert_equal [{ "os" => "macos-latest", "ruby" => "4.0" }], matrix.fetch("include")
      assert_equal %w[audit commits fresh-dependencies quality test], ci.fetch("jobs").keys.sort
      assert_equal "release", release.fetch("jobs").fetch("publish").fetch("environment")
      assert_equal "needs.verify.outputs.publish == 'true'", release.fetch("jobs").fetch("publish").fetch("if")
      verify_runs = release.fetch("jobs").fetch("verify").fetch("steps").filter_map { |step| step["run"] }.join
      publish_runs = release.fetch("jobs").fetch("publish").fetch("steps").filter_map { |step| step["run"] }.join

      assert_includes verify_runs, "package:check[pkg/sample-echo-"
      assert_includes publish_runs, "release:verify_artifact"
      refute_includes publish_runs, "rake build"
    end
  end

  def test_required_status_names_match_the_generated_ci_jobs
    with_destination do |destination|
      scaffold(destination).generate
      jobs = Psych.safe_load_file(File.join(destination, ".github/workflows/ci.yml")).fetch("jobs")
      matrix = jobs.fetch("test").fetch("strategy").fetch("matrix")
      cells = matrix.fetch("os").product(matrix.fetch("ruby"))
      cells += matrix.fetch("include").map { |cell| [cell.fetch("os"), cell.fetch("ruby")] }
      names = %w[quality commits audit fresh-dependencies] + cells.map { |os, ruby| "test (#{os}, #{ruby})" }

      assert_equal RubyRepoKit::Project::DEFAULT_CHECKS.sort, names.sort
    end
  end

  def test_external_workflow_actions_are_pinned_to_commit_hashes
    with_destination do |destination|
      scaffold(destination).generate
      paths = Dir.glob(File.join(destination, ".github/workflows/*.yml"))
      references = paths.flat_map { |path| File.read(path).scan(/^\s*(?:-\s+)?uses:\s*(\S+)/).flatten }
      external_references = references.reject { |reference| reference.start_with?("./") }

      refute_empty external_references
      assert(external_references.all? { |reference| reference.match?(/\A[^@\s]+@[0-9a-f]{40}\z/) })
    end
  end
end

class ScaffoldRuntimeTest < Minitest::Test
  include ScaffoldFixtures

  def test_generated_cli_tests_pass_and_the_packaged_executable_runs_without_the_toolkit
    with_destination do |destination|
      scaffold(destination).generate
      output, errors, status = Open3.capture3(
        clean_environment.merge("COVERAGE" => "1"), RbConfig.ruby, "-Ilib", "-Itest",
        "test/cli_test.rb", chdir: destination
      )

      assert_predicate status, :success?, "#{output}\n#{errors}"

      package = build_package(destination)
      package_spec = Gem::Package.new(package).spec

      assert_equal ["optparse"], package_spec.runtime_dependencies.map(&:name)
      assert_equal ["sample-echo"], package_spec.executables

      install_and_exercise(package, File.dirname(destination))
    end
  end

  private

  def clean_environment
    ENV.keys.grep(/\ABUNDL/).to_h { |key| [key, nil] }.merge("RUBYOPT" => nil, "RUBYLIB" => nil)
  end

  def build_package(destination)
    output, errors, status = Open3.capture3(
      clean_environment, RbConfig.ruby, "-S", "gem", "build", "sample-echo.gemspec", chdir: destination
    )
    raise "#{output}\n#{errors}" unless status.success?

    File.join(destination, "sample-echo-0.1.0.gem")
  end

  def install_and_exercise(package, parent)
    home = File.join(parent, "installed gems")
    environment = clean_environment.merge("GEM_HOME" => home, "GEM_PATH" => home)
    output, errors, status = Open3.capture3(
      environment, RbConfig.ruby, "-S", "gem", "install", "--local",
      "--no-document", "--norc", package
    )
    raise "#{output}\n#{errors}" unless status.success?

    command = [RbConfig.ruby, File.join(home, "bin/sample-echo")]
    output, errors, status = Open3.capture3(environment, *command, "installed", "correctly", chdir: parent)

    assert_predicate status, :success?, errors
    assert_equal "installed correctly\n", output
    assert_empty errors

    output, errors, status = Open3.capture3(environment, *command, "--version", chdir: parent)

    assert_predicate status, :success?, errors
    assert_equal "0.1.0\n", output

    output, errors, status = Open3.capture3(environment, *command, "--invalid", chdir: parent)

    assert_equal 2, status.exitstatus
    assert_empty output
    assert_includes errors, "invalid option"
  end
end
