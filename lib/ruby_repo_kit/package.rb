# frozen_string_literal: true

require "bundler"
require "fileutils"
require "open3"
require "rubygems/package"
require "tmpdir"
require_relative "../ruby_repo_kit"
require_relative "specification"

module RubyRepoKit
  # Builds the consumer and tests the installed artifact outside its bundle/checkout.
  class Package
    def initialize(project:, out: $stdout)
      @project = project
      @out = out
    end

    def build(output: nil)
      spec = specification
      target = output || @project.path("pkg/#{spec.name}-#{spec.version}.gem")
      FileUtils.mkdir_p(File.dirname(target))
      execute({}, [*gem_command, "build", @project.gemspec, "--output", target], chdir: @project.root)
      verify(target)
      target
    end

    def check(artifact: nil, environment: {})
      environment = validated_environment(environment)
      Dir.mktmpdir("ruby-repo-package-") do |dir|
        package = artifact ? File.expand_path(artifact, @project.root) : build(output: File.join(dir, "package.gem"))
        spec = verify(package)
        home = File.join(dir, "gems")
        cache_dependencies(dir)
        Bundler.with_unbundled_env do
          env = environment.merge("GEM_HOME" => home, "GEM_PATH" => home, "RUBYOPT" => nil, "RUBYLIB" => nil,
                                  "XDG_CONFIG_HOME" => File.join(dir, "config"), "NO_COLOR" => "1")
          # GEM_HOME selects the destination. --install-dir would make RubyGems
          # ignore installed specifications, including Ruby's uncached default gems.
          execute(env, [*gem_command, "install", "--local", "--no-document", "--norc",
                        "--bindir", File.join(home, "bin"), package], chdir: dir)
          spec.executables.each do |name|
            executable = File.join(home, "bin", name)
            version = execute(env, [executable, "--version"], chdir: dir)
            unless version.match?(/(?<![\w.])#{Regexp.escape(spec.version.to_s)}(?![\w.])/)
              raise Error, "Installed #{name} reports a different version"
            end

            help = execute(env, [executable, "--help"], chdir: dir)
            raise Error, "Installed #{name} has empty help" if help.strip.empty?
          end
          yield env, home, dir if block_given?
        end
        @out.puts "Installed #{spec.name} #{spec.version} from the built gem in an isolated gem home."
        spec
      end
    end

    def verify(path)
      package = Gem::Package.new(path)
      package.verify
      expected = specification
      unless package.spec.name == expected.name && package.spec.version == expected.version
        raise Error, "Package identity differs from #{@project.name} #{expected.version}"
      end

      package.spec
    rescue Gem::Package::Error, Errno::ENOENT => e
      raise Error, "Invalid gem artifact: #{e.message}"
    end

    private

    def validated_environment(environment)
      valid = environment.is_a?(Hash) && environment.all? do |key, value|
        key.is_a?(String) && key.match?(/\A[A-Za-z_][A-Za-z0-9_]*\z/) &&
          (value.nil? || (value.is_a?(String) && !value.include?("\0")))
      end
      raise Error, "Package environment must map variable names to strings or nil" unless valid

      environment.to_h { |key, value| [key.dup, value&.dup] }
    end

    def specification
      spec = Specification.load(project: @project)
      raise Error, "Gemspec name differs from project name" unless spec.name == @project.name

      spec.files.each do |file|
        raise Error, "Gemspec includes a missing file: #{file}" unless File.file?(@project.path(file))
      end
      spec
    end

    def gem_command
      [RbConfig.ruby, "-rrubygems/gem_runner", "-e", "Gem::GemRunner.new.run(ARGV)", "--"]
    end

    def cache_dependencies(directory)
      Bundler.load.specs.each do |spec|
        FileUtils.cp(spec.cache_file, directory) if File.file?(spec.cache_file)
      end
    end

    def execute(env, argv, chdir:)
      output, status = Open3.capture2e(env, *argv, chdir: chdir)
      raise Error, "#{argv.join(' ')} failed:\n#{output}" unless status.success?

      output
    end
  end
end
