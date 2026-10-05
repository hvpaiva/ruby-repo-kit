# frozen_string_literal: true

require "json"
require "open3"
require "psych"
require "rbconfig"
require_relative "specification"
require_relative "checks/lockfile"

module RubyRepoKit
  # Local structural checks. Evaluating a gemspec/Gemfile is trusted project code;
  # a child interpreter avoids loading consumer constants into the toolkit process.
  class Checks
    TOOLKIT_NAME = "ruby-repo-kit"
    PRESET = "config/rubocop.yml"
    GEMFILE_SCRIPT = <<~RUBY
      require "json"
      require "bundler"
      definition = Bundler::Dsl.evaluate("Gemfile", nil, {})
      puts JSON.generate(definition.dependencies.map(&:name))
    RUBY

    def initialize(project:)
      @project = project
    end

    def run
      [@project.gemspec, @project.version_file, @project.changelog, "Gemfile", "Rakefile"].each do |file|
        require_file(file)
      end
      Lockfile.new(path: @project.path("Gemfile.lock")).check
      specification = Specification.load(project: @project)
      metadata(specification)
      manifest(specification)
      development_dependency(specification)
      rubocop_preset unless @project.name == TOOLKIT_NAME
      true
    rescue Errno::ENOENT, Errno::EACCES, Psych::Exception => e
      raise Error, "Project checks failed: #{e.message}"
    end

    private

    def require_file(file)
      path = @project.path(file)
      raise Error, "Required project file is missing: #{file}" unless File.file?(path)

      path
    end

    def metadata(specification)
      unless specification.name == @project.name
        raise Error, "Gemspec name differs from project configuration (expected #{@project.name})"
      end

      text = File.read(@project.path(@project.version_file))
      versions = text.scan(/^\s*VERSION\s*=\s*(["'])([^"'\n]+)\1(?:\.freeze)?\s*(?:#.*)?$/).map(&:last)
      unless versions.length == 1 && Gem::Version.correct?(versions.first)
        raise Error, "#{@project.version_file} must contain one literal VERSION assignment"
      end
      return if Gem::Version.new(versions.first) == specification.version

      raise Error, "Gemspec version differs from #{@project.version_file}"
    end

    def manifest(specification)
      files = specification.files
      raise Error, "Gemspec files must be a list of relative paths" unless files.is_a?(Array) && files.all?(String)

      files.each { |file| require_file(file) }
      unless files.include?(@project.version_file) && files.any? { |file| file.start_with?("lib/") }
        raise Error, "Gem manifest must include its lib files and #{@project.version_file}"
      end

      specification.executables.each do |executable|
        relative = File.join(specification.bindir, executable)
        require_file(relative)
        raise Error, "Gem manifest does not include executable #{relative}" unless files.include?(relative)
      end
    end

    def development_dependency(specification)
      return if @project.name == TOOLKIT_NAME
      if specification.runtime_dependencies.any? { |dependency| dependency.name == TOOLKIT_NAME }
        raise Error, "#{TOOLKIT_NAME} belongs in the consumer Gemfile, never its runtime dependencies"
      end
      return if gemfile_dependencies.include?(TOOLKIT_NAME)

      raise Error, "Declare #{TOOLKIT_NAME} in the consumer Gemfile"
    end

    def gemfile_dependencies
      environment = ENV.keys.grep(/\ABUNDL/).to_h { |key| [key, nil] }
      environment["RUBYOPT"] = nil
      environment["RUBYLIB"] = nil
      output, error, status = Open3.capture3(environment, RbConfig.ruby, "-e", GEMFILE_SCRIPT, chdir: @project.root)
      raise Error, "Cannot inspect project Gemfile: #{error.strip}" unless status.success?

      JSON.parse(output)
    rescue JSON::ParserError
      raise Error, "The Gemfile inspector returned invalid JSON (check output from the Gemfile)"
    end

    def rubocop_preset
      path = @project.path(".rubocop.yml")
      return unless File.exist?(path)

      configuration = Psych.safe_load_file(path, permitted_classes: [], aliases: true)
      inherited = configuration.is_a?(Hash) && configuration["inherit_gem"]
      presets = inherited.is_a?(Hash) && inherited[TOOLKIT_NAME]
      return if Array(presets).include?(PRESET)

      raise Error, ".rubocop.yml must inherit #{TOOLKIT_NAME}/#{PRESET}; local overrides remain allowed"
    end
  end
end
