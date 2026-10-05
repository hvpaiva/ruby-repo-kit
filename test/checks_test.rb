# frozen_string_literal: true

require "test_helper"
require "ruby_repo_kit/checks"

class ChecksTest < Minitest::Test
  def write_project(project, version: "0.1.0", gem_version: version, files: nil, runtime: false, dependency: true)
    files ||= [project.version_file, "lib/sample_cli.rb", "exe/sample-cli", "CHANGELOG.md"]
    FileUtils.mkdir_p([File.dirname(project.path(project.version_file)), project.path("exe")])
    File.write(project.path(project.version_file), "module SampleCLI\n  VERSION = '#{version}'\nend\n")
    File.write(project.path("lib/sample_cli.rb"), "# consumer code\n")
    File.write(project.path("exe/sample-cli"), "#!/usr/bin/env ruby\nputs 'sample'\n")
    File.write(project.path("CHANGELOG.md"), "# Changelog\n")
    File.write(project.path("Rakefile"), "require 'ruby_repo_kit/tasks'\n")
    File.write(project.path("Gemfile"),
               "source 'https://rubygems.org'\ngemspec\n#{"gem 'ruby-repo-kit', require: false\n" if dependency}")
    File.write(project.path(project.gemspec), <<~RUBY)
      Gem::Specification.new do |spec|
        spec.name = #{project.name.inspect}
        spec.version = #{gem_version.inspect}
        spec.summary = "Fixture gem"
        spec.authors = ["Fixture"]
        spec.files = #{files.inspect}
        spec.bindir = "exe"
        spec.executables = ["sample-cli"]
        # Tests deliberately do not install or resolve dependencies.
        #{"spec.add_dependency 'ruby-repo-kit'" if runtime}
      end
    RUBY
  end

  def check(project) = RubyRepoKit::Checks.new(project: project).run

  def test_checks_accept_default_gemfile_group_and_rubocop_overrides
    in_project do |project|
      write_project(project)
      File.write(project.path(".rubocop.yml"), <<~YAML)
        inherit_gem:
          ruby-repo-kit: config/rubocop.yml
        Metrics/MethodLength:
          Max: 20
      YAML

      assert check(project)
      refute Object.const_defined?(:SampleCLI)
    end
  end

  def test_doctor_requires_version_to_agree_with_gemspec
    in_project do |project|
      write_project(project, gem_version: "0.2.0")
      error = assert_raises(RubyRepoKit::Error) { check(project) }

      assert_match(/version differs/, error.message)
    end
  end

  def test_doctor_rejects_incomplete_lockfile_checksums_before_loading_project_code
    in_project do |project|
      write_project(project)
      File.write(project.path("Gemfile.lock"), <<~LOCK)
        GEM
          remote: https://rubygems.org/
          specs:
            rake (13.4.2)

        CHECKSUMS
          rake (13.4.2)
      LOCK
      File.write(project.path(project.gemspec), "raise 'gemspec must not run before lockfile preflight'\n")
      error = assert_raises(RubyRepoKit::Error) { check(project) }

      assert_match(/empty or missing CHECKSUMS.*rake-13.4.2/, error.message)
    end
  end

  def test_consumer_toolkit_dependency_must_not_be_runtime
    in_project do |project|
      write_project(project, runtime: true)
      error = assert_raises(RubyRepoKit::Error) { check(project) }

      assert_match(/runtime dependencies/, error.message)
    end
  end

  def test_requires_explicit_development_dependency_without_resolving_it
    in_project do |project|
      write_project(project, dependency: false)
      error = assert_raises(RubyRepoKit::Error) { check(project) }

      assert_match(/consumer Gemfile/, error.message)
    end
  end

  def test_manifest_must_include_version_and_existing_lib_files
    in_project do |project|
      write_project(project, files: ["exe/sample-cli"])
      error = assert_raises(RubyRepoKit::Error) { check(project) }

      assert_match(/manifest must include/, error.message)
      write_project(project, files: [project.version_file, "lib/missing.rb"])
      assert_raises(RubyRepoKit::Error) { check(project) }
    end
  end

  def test_manifest_cannot_escape_root_by_path_or_symlink
    in_project do |project|
      write_project(project, files: [project.version_file, "../outside.rb"])
      assert_raises(RubyRepoKit::Error) { check(project) }
      Dir.mktmpdir do |outside|
        File.write(File.join(outside, "private.rb"), "# private\n")
        File.symlink(File.join(outside, "private.rb"), project.path("lib/escape.rb"))
        write_project(project, files: [project.version_file, "lib/escape.rb"])

        assert_raises(RubyRepoKit::Error) { check(project) }
      end
    end
  end

  def test_rakefile_and_rubocop_inheritance_are_checked_without_exact_text_matching
    in_project do |project|
      write_project(project)
      File.write(project.path(".rubocop.yml"), "AllCops:\n  NewCops: enable\n")
      assert_raises(RubyRepoKit::Error) { check(project) }
      File.delete(project.path(".rubocop.yml"))
      File.delete(project.path("Rakefile"))

      assert_raises(RubyRepoKit::Error) { check(project) }
    end
  end

  def test_rechecking_after_version_changes_does_not_reuse_loaded_consumer_constant
    in_project do |project|
      write_project(project)

      assert check(project)
      write_project(project, version: "0.2.0")

      assert check(project)
      refute Object.const_defined?(:SampleCLI)
    end
  end

  def test_toolkit_itself_does_not_require_self_dependency_or_inheritance
    in_project("name" => "ruby-repo-kit") do |project|
      write_project(project, dependency: false)
      File.write(project.path(".rubocop.yml"), "inherit_from: config/rubocop.yml\n")

      assert check(project)
    end
  end
end
