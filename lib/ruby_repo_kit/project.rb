# frozen_string_literal: true

require "pathname"
require "psych"

module RubyRepoKit
  # Explicit consumer configuration; no paths are resolved relative to the gem.
  class Project
    CONFIG_FILE = ".ruby-repo.yml"
    DEFAULT_CHECKS = ["quality", "commits", "audit", "fresh-dependencies", "test (ubuntu-latest, 3.4)",
                      "test (ubuntu-latest, 4.0)", "test (macos-latest, 4.0)"].freeze
    KEYS = %w[schema name repository version_file gemspec changelog generated_paths
              generate_command check_command required_checks workflow environment].freeze
    attr_reader :root, :name, :repository, :version_file, :gemspec, :changelog,
                :generated_paths, :generate_command, :check_command, :required_checks,
                :workflow, :environment

    def self.load(root: Dir.pwd)
      source = File.join(root, CONFIG_FILE)
      new(root: root, settings: Psych.safe_load_file(source, permitted_classes: [], aliases: false))
    rescue Errno::ENOENT => e
      raise Error, "Cannot load project configuration: #{e.message}"
    rescue Psych::Exception => e
      raise Error, "Invalid #{CONFIG_FILE}: #{e.message}"
    end

    def initialize(root:, settings:)
      raise Error, "Project configuration must be a mapping" unless settings.is_a?(Hash)
      raise Error, "Unknown project settings: #{settings.keys - KEYS}" unless (settings.keys - KEYS).empty?
      raise Error, "Unsupported configuration schema (expected 1)" unless settings.fetch("schema", nil) == 1

      @root = File.realpath(root).freeze
      @name = identifier(settings["name"], /\A[a-z][a-z0-9]*(?:[-_][a-z0-9]+)*\z/, "gem name")
      @repository = identifier(settings["repository"], %r{\A[A-Za-z0-9][A-Za-z0-9-]*/[A-Za-z0-9][A-Za-z0-9_.-]*\z},
                               "repository")
      @version_file = relative(settings.fetch("version_file", "lib/#{name.tr('-', '_')}/version.rb"))
      @gemspec = relative(settings.fetch("gemspec", "#{name}.gemspec"))
      @changelog = relative(settings.fetch("changelog", "CHANGELOG.md"))
      @generated_paths = string_array(settings.fetch("generated_paths", [])).map { |entry| relative(entry) }.freeze
      @generate_command = argv(settings.fetch("generate_command", %w[bundle exec rake generate]))
      @check_command = argv(settings.fetch("check_command", %w[bundle exec rake check]))
      @required_checks = string_array(settings.fetch("required_checks", DEFAULT_CHECKS)).freeze
      @workflow = identifier(settings.fetch("workflow", "release.yml"), /\A[a-zA-Z0-9_-]+\.ya?ml\z/,
                             "workflow filename")
      @environment = identifier(settings.fetch("environment", "release"), /\A[a-zA-Z0-9_-]+\z/, "environment")
      freeze
    end

    def url = "https://github.com/#{repository}"

    def release_files = [version_file, changelog, "Gemfile.lock", *generated_paths].uniq

    def path(relative_path)
      value = relative(relative_path)
      absolute = File.join(root, value)
      ancestor = absolute
      ancestor = File.dirname(ancestor) until File.exist?(ancestor) || File.symlink?(ancestor)
      resolved = File.realpath(ancestor)
      unless resolved == root || resolved.start_with?("#{root}/")
        raise Error, "Project path escapes root through a symlink: #{value}"
      end

      absolute
    rescue Errno::ENOENT
      raise Error, "Project path contains a broken symlink: #{value}"
    end

    private

    def identifier(value, pattern, description)
      raise Error, "Invalid #{description}: #{value.inspect}" unless value.is_a?(String) && pattern.match?(value)

      value.dup.freeze
    end

    def relative(value)
      unless value.is_a?(String) && !value.empty? && !value.include?("\0") &&
             !Pathname.new(value).absolute? && !value.split("/").intersect?(["..", ".", ""])
        raise Error, "Expected a relative project path: #{value.inspect}"
      end

      value.dup.freeze
    end

    def string_array(value)
      unless value.is_a?(Array) && value.all? { |entry| entry.is_a?(String) && !entry.empty? && !entry.include?("\0") }
        raise Error, "Expected an array of nonempty strings"
      end

      value.map { |entry| entry.dup.freeze }
    end

    def argv(value)
      result = string_array(value)
      raise Error, "Commands require an executable and argv array" if result.empty?

      result.freeze
    end
  end
end
