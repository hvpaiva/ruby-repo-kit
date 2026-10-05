# frozen_string_literal: true

require "test_helper"
require "ruby_repo_kit/package"
require_relative "package_support"

class PackageTest < Minitest::Test
  include PackageFixtures

  def test_builds_without_git_and_runs_installed_gem_outside_bundle
    in_project do |project|
      write_gem(project)
      output = StringIO.new
      package = RubyRepoKit::Package.new(project: project, out: output)
      artifact = package.build

      assert_path_exists artifact
      assert_equal [], package.verify(artifact).runtime_dependencies
      result = package.check(artifact: artifact) do |environment, home, directory|
        refute_equal project.root, directory
        assert_equal home, environment.fetch("GEM_PATH")
        assert_path_exists File.join(home, "bin/sample-cli")
      end

      assert result
      assert_includes output.string, "isolated gem home"
    end
  end

  def test_rejects_corrupted_existing_artifact_without_rebuilding_it
    in_project do |project|
      write_gem(project)
      package = RubyRepoKit::Package.new(project: project, out: StringIO.new)
      artifact = package.build
      File.write(artifact, "not a gem")
      assert_raises(RubyRepoKit::Error) { package.check(artifact: artifact) }
      assert_equal "not a gem", File.read(artifact)
    end
  end

  def test_isolated_install_resolves_uncached_default_gems_without_other_gem_homes
    in_project do |project|
      write_gem(project)
      specification = project.path(project.gemspec)
      File.write(specification, File.read(specification).sub("spec.bindir =", <<~RUBY.strip))
        spec.add_dependency 'optparse', '>= 0.6', '< 1'
        spec.bindir =
      RUBY
      executable = project.path("exe/sample-cli")
      File.write(executable,
                 File.read(executable).sub("require 'sample_cli'", "require 'optparse'\nrequire 'sample_cli'"))
      # Exercise the interpreter's default gem, even on machines with its .gem cached.
      package_class = Class.new(RubyRepoKit::Package) do
        def cache_dependencies(*) = nil
      end
      package = package_class.new(project: project, out: StringIO.new)
      package.check do |environment, home, directory|
        probe = <<~RUBY
          require "optparse"
          puts Gem.path
          puts Gem.loaded_specs.fetch("optparse").default_gem?
          puts Gem::Specification.reject(&:default_gem?).map(&:name)
        RUBY
        output, error, status = Open3.capture3(environment, RbConfig.ruby, "-e", probe, chdir: directory)

        assert_predicate status, :success?, error
        assert_equal [File.realpath(home), "true", "sample-cli"], output.lines.map(&:strip)
        refute(Dir.children(directory).any? { |name| name.start_with?("optparse-") })
      end
    end
  end

  def test_isolated_install_still_rejects_unavailable_runtime_dependencies
    in_project do |project|
      write_gem(project)
      specification = project.path(project.gemspec)
      text = File.read(specification).sub("spec.bindir =", <<~RUBY.strip)
        spec.add_dependency 'ruby-repo-missing-package-fixture', '= 99.99.99'
        spec.bindir =
      RUBY
      File.write(specification, text)

      error = assert_raises(RubyRepoKit::Error) { RubyRepoKit::Package.new(project: project).check }
      assert_includes error.message, "ruby-repo-missing-package-fixture"
    end
  end

  def test_installed_version_must_not_only_contain_expected_version_as_a_prefix
    in_project do |project|
      write_gem(project)
      path = project.path("exe/sample-cli")
      File.write(path, File.read(path).sub("SampleCLI::VERSION}", "SampleCLI::VERSION}.1"))

      error = assert_raises(RubyRepoKit::Error) { RubyRepoKit::Package.new(project: project).check }
      assert_includes error.message, "reports a different version"
    end
  end

  def test_version_inspection_does_not_cache_the_consumers_version_constant
    in_project do |project|
      write_gem(project)

      assert_equal "0.1.0", RubyRepoKit::Specification.load(project: project).version.to_s
      path = project.path(project.version_file)
      File.write(path, File.read(path).sub("0.1.0", "0.2.0"))

      assert_equal "0.2.0", RubyRepoKit::Specification.load(project: project).version.to_s
      refute Object.const_defined?(:SampleCLI)
    end
  end

  def test_missing_manifest_file_fails_before_build
    in_project do |project|
      write_gem(project)
      path = project.path(project.gemspec)
      source = File.read(path).sub("spec.bindir =", "spec.files += ['missing.rb']; spec.bindir =")
      File.write(path, source)
      error = assert_raises(RubyRepoKit::Error) { RubyRepoKit::Package.new(project: project).build }
      assert_includes error.message, "missing.rb"
      refute_path_exists project.path("pkg")
    end
  end

  def test_application_environment_is_applied_before_default_smoke_and_forwarded_to_callback
    previous = ENV.fetch("KIT_PACKAGE_CONFIG", nil)
    ENV["KIT_PACKAGE_CONFIG"] = "invalid"
    in_project do |project|
      write_gem(project)
      executable = project.path("exe/sample-cli")
      guard = "abort 'Invalid application configuration' unless ENV['KIT_PACKAGE_CONFIG'] == 'valid'\n"
      File.write(executable, File.read(executable).sub("require 'sample_cli'", "#{guard}require 'sample_cli'"))
      package = RubyRepoKit::Package.new(project: project, out: StringIO.new)
      artifact = package.build
      error = assert_raises(RubyRepoKit::Error) { package.check(artifact: artifact) }
      assert_includes error.message, "Invalid application configuration"

      overrides = { "KIT_PACKAGE_CONFIG" => "valid", "KIT_PACKAGE_UNUSED" => nil, "PAGER" => "cat" }.freeze
      package.check(artifact: artifact, environment: overrides) do |environment, _home, _directory|
        assert_equal "valid", environment.fetch("KIT_PACKAGE_CONFIG")
        assert_nil environment.fetch("KIT_PACKAGE_UNUSED")
        assert_equal "cat", environment.fetch("PAGER")
      end
      assert_equal "invalid", ENV.fetch("KIT_PACKAGE_CONFIG")
      assert_equal({ "KIT_PACKAGE_CONFIG" => "valid", "KIT_PACKAGE_UNUSED" => nil, "PAGER" => "cat" }, overrides)
    end
  ensure
    ENV["KIT_PACKAGE_CONFIG"] = previous
  end

  def test_application_overrides_cannot_replace_package_isolation
    in_project do |project|
      write_gem(project)
      overrides = %w[GEM_HOME GEM_PATH RUBYOPT RUBYLIB XDG_CONFIG_HOME NO_COLOR].to_h { |key| [key, "untrusted"] }
      original = overrides.dup
      package = RubyRepoKit::Package.new(project: project, out: StringIO.new)
      package.check(environment: overrides) do |environment, home, directory|
        assert_equal home, environment.fetch("GEM_HOME")
        assert_equal home, environment.fetch("GEM_PATH")
        assert_nil environment.fetch("RUBYOPT")
        assert_nil environment.fetch("RUBYLIB")
        assert_equal File.join(directory, "config"), environment.fetch("XDG_CONFIG_HOME")
        assert_equal "1", environment.fetch("NO_COLOR")
      end
      assert_equal original, overrides
    end
  end

  def test_invalid_package_environment_is_rejected_before_building
    invalid = [nil, [], { "" => "x" }, { "BAD=NAME" => "x" }, { "BAD\0NAME" => "x" },
               { name: "x" }, { "NAME" => false }, { "NAME" => 1 }, { "NAME" => "a\0b" }]
    in_project do |project|
      package = RubyRepoKit::Package.new(project: project, out: StringIO.new)
      invalid.each do |environment|
        error = assert_raises(RubyRepoKit::Error) { package.check(environment: environment) }
        assert_includes error.message, "Package environment must map"
      end
      refute_path_exists project.path("pkg")
    end
  end
end
