# frozen_string_literal: true

require "test_helper"
require "ruby_repo_kit/package"
require_relative "package_support"

class PackageIsolationTest < Minitest::Test
  include PackageFixtures

  def test_bundler_setup_cannot_reintroduce_an_external_gem_home
    in_project do |project|
      write_gem(project)
      Dir.mktmpdir("package-external-") do |directory|
        hook, marker = external_gem_hook(directory)
        empty_home = File.join(directory, "empty")
        environment = { "GEM_HOME" => empty_home, "GEM_PATH" => empty_home, "RUBYOPT" => nil, "RUBYLIB" => nil,
                        "BUNDLER_SETUP" => nil, "RUBYGEMS_GEMDEPS" => nil }
        _output, error, status = Open3.capture3(environment, RbConfig.ruby, "-r", hook, "-e", "nil")

        assert_predicate status, :success?, error
        assert_path_exists marker # Control: the hook really can load the external gem.
        FileUtils.rm_f(marker)

        package = RubyRepoKit::Package.new(project: project, out: StringIO.new)
        package.check(environment: { "BUNDLER_SETUP" => hook }) do |env, home, working_directory|
          assert_nil env.fetch("BUNDLER_SETUP")
          probe = 'puts Gem.path; abort "External gem leaked" if Gem::Specification.find_all_by_name("external_fixture").any?'
          output, error, status = Open3.capture3(env, RbConfig.ruby, "-e", probe, chdir: working_directory)

          assert_predicate status, :success?, error
          assert_equal([File.realpath(home)], output.lines.map { |line| File.realpath(line.strip) })
        end
        refute_path_exists marker
      end
    end
  end

  def test_rubygems_gemdeps_cannot_replace_the_artifact_with_the_source_checkout
    in_project do |project|
      write_gem(project)
      package = RubyRepoKit::Package.new(project: project, out: StringIO.new)
      artifact = package.build
      executable = project.path("exe/sample-cli")
      File.write(executable, "abort 'Source checkout was executed instead of the artifact'\n")
      gemfile = project.path("external.gemfile")
      marker = project.path("gemdeps-loaded")
      File.write(gemfile, <<~RUBY)
        File.write(#{marker.dump}, "executed")
        source "https://rubygems.org"
        gem "sample-cli", path: #{project.root.dump}
      RUBY
      package.check(artifact: artifact,
                    environment: { "RUBYGEMS_GEMDEPS" => gemfile }) do |environment, home, directory|
        assert_nil environment.fetch("RUBYGEMS_GEMDEPS")
        probe = 'Gem.use_gemdeps; require "sample_cli"; puts Gem.loaded_specs.fetch("sample-cli").full_gem_path'
        output, error, status = Open3.capture3(environment, RbConfig.ruby, "-e", probe, chdir: directory)

        assert_predicate status, :success?, error
        assert_match(%r{\A#{Regexp.escape(File.realpath(home))}/}, File.realpath(output.strip))
      end
      refute_path_exists marker
      refute_path_exists "#{gemfile}.lock"
    end
  end

  def test_inherited_rubygems_gemdeps_is_removed_from_package_subprocesses
    in_project do |project|
      write_gem(project)
      marker = project.path("inherited-gemdeps-loaded")
      gemfile = project.path("inherited.gemfile")
      File.write(gemfile, <<~RUBY)
        File.write(#{marker.dump}, "executed")
        source "https://rubygems.org"
        gem "sample-cli", path: #{project.root.dump}
      RUBY
      program = <<~RUBY
        require "ruby_repo_kit/package"
        project = RubyRepoKit::Project.load(root: ARGV.fetch(0))
        RubyRepoKit::Package.new(project: project).check do |environment, _home, _directory|
          abort "Inherited Gemfile leaked" unless environment.fetch("RUBYGEMS_GEMDEPS").nil?
        end
      RUBY
      environment = ENV.keys.grep(/\ABUNDL/).to_h { |key| [key, nil] }.merge(
        "RUBYOPT" => nil, "RUBYLIB" => nil, "RUBYGEMS_GEMDEPS" => gemfile
      )
      root = File.expand_path("..", __dir__)
      output, error, status = Open3.capture3(environment, RbConfig.ruby, "-I#{root}/lib", "-e", program, project.root,
                                             chdir: root)

      assert_predicate status, :success?, "#{error}\n#{output}"
      assert_includes output, "Installed sample-cli 0.1.0"
      refute_path_exists marker
      refute_path_exists "#{gemfile}.lock"
    end
  end

  private

  def external_gem_hook(directory)
    home = File.join(directory, "gems")
    library = File.join(home, "gems/external_fixture-0.1.0/lib")
    FileUtils.mkdir_p([library, File.join(home, "specifications")])
    File.write(File.join(library, "external_fixture.rb"), "EXTERNAL_FIXTURE = true\n")
    File.write(File.join(home, "specifications/external_fixture-0.1.0.gemspec"), <<~RUBY)
      Gem::Specification.new do |spec|
        spec.name = "external_fixture"
        spec.version = "0.1.0"
        spec.summary = "External isolation fixture"
        spec.authors = ["Test"]
      end
    RUBY
    hook = File.join(directory, "setup.rb")
    marker = File.join(directory, "hook-loaded")
    File.write(hook, <<~RUBY)
      Gem.paths = { "GEM_HOME" => ENV.fetch("GEM_HOME"),
                    "GEM_PATH" => [ENV.fetch("GEM_HOME"), #{home.dump}].join(File::PATH_SEPARATOR) }
      require "external_fixture"
      File.write(#{marker.dump}, "executed")
    RUBY
    [hook, marker]
  end
end
