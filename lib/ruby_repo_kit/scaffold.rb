# frozen_string_literal: true

require "erb"
require "fileutils"
require "psych"

module RubyRepoKit
  # Creates a project once. Generated application files belong to the consumer.
  class Scaffold
    TEMPLATE_ROOT = File.expand_path("../../templates/cli", __dir__)
    NAME_PATTERN = /\A[a-z][a-z0-9]*(?:[-_][a-z0-9]+)*\z/
    REPOSITORY_PATTERN = %r{\A[A-Za-z0-9][A-Za-z0-9-]*/[A-Za-z0-9][A-Za-z0-9_.-]*\z}
    RESERVED_NAMESPACES = %w[
      Array BasicObject Binding Class Comparable Complex Data Dir Enumerable
      Enumerator ENV Encoding Exception FalseClass Fiber File Float GC Hash IO
      Integer Kernel Marshal MatchData Math Method Module NilClass Numeric Object OptionParser
      ObjectSpace Proc Process Ractor Random Range Rational Regexp RubyRepoKit
      RubyVM Signal StandardError String Struct Symbol Thread Time TracePoint
      TrueClass UnboundMethod
    ].freeze
    EXECUTABLE_PREFIXES = %w[exe/ bin/].freeze

    def initialize(name:, destination:, repository:, author:, email:, toolkit_version: RubyRepoKit::VERSION)
      @name = validate_identifier(name, NAME_PATTERN, "gem name")
      @repository = validate_identifier(repository, REPOSITORY_PATTERN, "repository (owner/name)")
      @author = validate_text(author, "author")
      @email = validate_identifier(email, /\A[^\s@]+@[^\s@]+\.[^\s@]+\z/, "email")
      @toolkit_version = validate_identifier(toolkit_version, /\A\d+\.\d+\.\d+(?:[.-][a-zA-Z0-9]+)*\z/,
                                             "toolkit version")
      @destination = File.expand_path(validate_text(destination, "destination"))
      @require_path = @name.tr("-", "_")
      @namespace = @name.split(/[-_]/).map(&:capitalize).join
      raise Error, "Reserved Ruby namespace: #{@namespace}" if RESERVED_NAMESPACES.include?(@namespace)
    end

    # Returns a canonical path, including when the existing parent is a symlink.
    # No Git, dependency installation or network calls are performed.
    def generate
      validate_destination
      files = rendered_files
      raise Error, "CLI templates are missing from the installed toolkit" if files.empty?

      Dir.mkdir(@destination)
      files.each do |relative, content|
        target = File.join(@destination, relative)
        FileUtils.mkdir_p(File.dirname(target))
        mode = EXECUTABLE_PREFIXES.any? { |prefix| relative.start_with?(prefix) } ? 0o755 : 0o644
        File.open(target, File::WRONLY | File::CREAT | File::EXCL, mode) { |file| file.write(content) }
      end
      @destination
    rescue SystemCallError => e
      raise Error, "Cannot generate project without overwriting files: #{e.message}"
    end

    private

    def validate_identifier(value, pattern, description)
      text = validate_text(value, description)
      raise Error, "Invalid #{description}: #{value.inspect}" unless pattern.match?(text)

      text
    end

    def validate_text(value, description)
      unless value.is_a?(String) && value.valid_encoding? && !value.strip.empty? && !value.match?(/[[:cntrl:]]/)
        raise Error, "Expected a nonempty #{description} without control characters"
      end

      value.dup.freeze
    end

    def validate_destination
      if File.exist?(@destination) || File.symlink?(@destination)
        raise Error, "Destination already exists: #{@destination}"
      end

      parent = File.dirname(@destination)
      raise Error, "Destination parent must be an existing directory: #{parent}" unless File.directory?(parent)

      # /tmp and /var are legitimate symlinks on some supported operating systems.
      # Resolve the parent once; the new destination itself is always created
      # exclusively and an existing or dangling destination symlink is rejected.
      @destination = File.join(File.realpath(parent), File.basename(@destination))
    end

    def rendered_files
      paths = Dir.glob("**/*", File::FNM_DOTMATCH, base: TEMPLATE_ROOT).sort
      paths.filter_map do |relative|
        source = File.join(TEMPLATE_ROOT, relative)
        raise Error, "Templates cannot contain symlinks: #{relative}" if File.symlink?(source)
        next unless File.file?(source)

        target = relative.delete_suffix(".erb").gsub("__name__", @name).gsub("__require_path__", @require_path)
        [target, ERB.new(File.read(source), trim_mode: "-").result(binding)]
      end
    end

    def ruby_literal(value) = value.dump

    def project_configuration
      Psych.dump(
        "schema" => 1,
        "name" => @name,
        "repository" => @repository,
        "version_file" => "lib/#{@require_path}/version.rb",
        "gemspec" => "#{@name}.gemspec",
        "changelog" => "CHANGELOG.md",
        "generated_paths" => [],
        "generate_command" => %w[bundle exec rake generate],
        "check_command" => %w[bundle exec rake check],
        "required_checks" => Project::DEFAULT_CHECKS
      )
    end
  end
end
