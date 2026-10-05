# frozen_string_literal: true

require "json"
require "open3"
require_relative "../ruby_repo_kit"

module RubyRepoKit
  # Evaluate trusted gemspec code in a fresh process. A version bump must not reuse
  # constants/require caches from an earlier inspection or another consumer.
  module Specification
    READER = <<~'RUBY'
      require "json"
      spec = Gem::Specification.load(ARGV.fetch(0))
      abort "Cannot load gemspec" unless spec
      puts JSON.generate(
        name: spec.name, version: spec.version.to_s, files: spec.files,
        executables: spec.executables, bindir: spec.bindir,
        require_paths: spec.require_paths, required_ruby_version: spec.required_ruby_version.to_s,
        runtime_dependencies: spec.runtime_dependencies.map do |dependency|
          [dependency.name, dependency.requirement.requirements.map { |operator, version| "#{operator} #{version}" }]
        end
      )
    RUBY

    def self.load(project:)
      environment = ENV.keys.grep(/\ABUNDL/).to_h { |key| [key, nil] }
      environment["RUBYOPT"] = nil
      environment["RUBYLIB"] = nil
      out, err, status = Open3.capture3(environment, RbConfig.ruby, "-rrubygems", "-e", READER,
                                        project.path(project.gemspec), chdir: project.root)
      raise Error, "Cannot load #{project.gemspec}: #{err.strip}" unless status.success?

      data = JSON.parse(out)
      Gem::Specification.new do |spec|
        %w[name version files executables bindir require_paths required_ruby_version].each do |field|
          spec.public_send("#{field}=", data.fetch(field))
        end
        data.fetch("runtime_dependencies").each { |name, requirements| spec.add_dependency(name, *requirements) }
      end
    rescue JSON::ParserError, KeyError => e
      raise Error, "Unreadable gemspec metadata: #{e.message}"
    end
  end
end
