# frozen_string_literal: true

require "test_helper"
require "ruby_repo_kit/package"

class PackageTest < Minitest::Test
  def write_gem(project)
    FileUtils.mkdir_p(project.path("lib/sample_cli"))
    FileUtils.mkdir_p(project.path("exe"))
    File.write(project.path("lib/sample_cli/version.rb"), "module SampleCLI; VERSION = '0.1.0'; end\n")
    File.write(project.path("lib/sample_cli.rb"), "require_relative 'sample_cli/version'\n")
    File.write(project.path("exe/sample-cli"), <<~RUBY)
      #!#{RbConfig.ruby}
      require 'sample_cli'
      puts(ARGV == ['--version'] ? "sample-cli \#{SampleCLI::VERSION}" : 'Usage: sample-cli [TEXT]')
    RUBY
    File.chmod(0o755, project.path("exe/sample-cli"))
    File.write(project.path("sample-cli.gemspec"), <<~RUBY)
      require_relative 'lib/sample_cli/version'
      Gem::Specification.new do |spec|
        spec.name = 'sample-cli'
        spec.version = SampleCLI::VERSION
        spec.authors = ['Test']
        spec.summary = 'A temporary package fixture'
        spec.license = 'MIT'
        spec.homepage = 'https://example.org/sample-cli'
        spec.files = Dir.chdir(__dir__) { Dir['lib/**/*.rb', 'exe/*'] }
        spec.bindir = 'exe'
        spec.executables = ['sample-cli']
      end
    RUBY
  end

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
end
