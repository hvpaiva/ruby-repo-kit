# frozen_string_literal: true

require "date"
require "rubygems/version"

module RubyRepoKit
  module Release
    # Parses repository-owned metadata without loading the consumer's Ruby code.
    class Metadata
      VERSION_PATTERN = /\A(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)\z/
      VERSION_LINE = /^([ \t]*VERSION[ \t]*=[ \t]*)(["'])([^"'\r\n]+)\2((?:\.freeze)?[ \t]*(?:#.*)?)\r?$/
      HEADING = /\A## \[([^\]]+)\] - (\d{4}-\d{2}-\d{2})( \[YANKED\])?\z/
      Heading = Data.define(:version, :date, :yanked)

      def initialize(project:, clock: SystemClock, commands: nil)
        @project = project
        @clock = clock
        @commands = commands || Commands.new(project: project)
      end

      def version = version_from(File.read(@project.path(@project.version_file)))

      def version_from(source)
        version_match(source)[3].tap { |value| validate_version(value) }
      end

      def validate_version(target)
        raise Error, "Use a stable X.Y.Z version" unless target.is_a?(String) && VERSION_PATTERN.match?(target)

        target
      end

      def validate_branch(branch, target)
        validate_version(target)
        hotfix = "hotfix/#{target.split('.').first(2).join('.')}"
        raise Error, "Release branch must be main or #{hotfix}" unless ["main", hotfix].include?(branch)

        branch
      end

      def verify(tag:, version: self.version, changelog: nil)
        validate_version(version)
        text = changelog || File.read(@project.path(@project.changelog))
        history = validate_history(text)
        # A branch rehearsal checks the release we would prepare, without writing it.
        if tag.nil? && history.none? { |heading| heading.version == version }
          changes(version,
                  source: { @project.version_file => "VERSION = \"#{version}\"\n", @project.changelog => text })
          return version
        end
        raise Error, "Release tag must be v#{version}" unless tag.nil? || tag == "v#{version}"
        raise Error, "The newest changelog release must be #{version}" unless history.first&.version == version
        raise Error, "Cannot publish a yanked release" if history.first.yanked
        raise Error, "Release notes for #{version} are empty" unless notes(text, version).match?(/^[-*] \S/)

        check_reference(text, "Unreleased", "#{@project.url}/compare/v#{version}...HEAD")
        version
      end

      def verify_ref(sha: ENV.fetch("GITHUB_SHA"), version: self.version)
        validate_version(version)
        raise Error, "Invalid release commit" unless sha.is_a?(String) && sha.match?(/\A[0-9a-f]{40}\z/)

        refs = @commands.call(["git", "for-each-ref", "--contains", sha, "--format=%(refname:short)",
                               "refs/remotes/origin"])
        allowed = ["origin/main", "origin/hotfix/#{version.split('.').first(2).join('.')}"]
        return true if refs.lines.map(&:strip).intersect?(allowed)

        raise Error, "Release commit must belong to main or its matching hotfix branch"
      end

      def notes(changelog, target)
        heading = /^## \[#{Regexp.escape(target)}\][^\n]*\n/
        return "" unless changelog.match?(heading)

        changelog.split(heading, 2).last.to_s.split(/^## |^\[[^\]]+\]:/, 2).first.to_s
      end

      def changes(target, source: nil, date: nil)
        validate_version(target)
        source ||= [@project.version_file, @project.changelog].to_h { |path| [path, File.read(@project.path(path))] }
        original = source.fetch(@project.version_file)
        current = version_from(original)
        raise Error, "Version cannot go backwards" if Gem::Version.new(target) < Gem::Version.new(current)

        text = source.fetch(@project.changelog)
        history = validate_history(text)
        raise Error, "Version already appears in the changelog" if history.any? { |heading| heading.version == target }
        raise Error, "Add release notes under Unreleased first" unless notes(text, "Unreleased").match?(/^[-*] \S/)

        release_date = date || @clock.now.utc.to_date
        updated = text.sub("## [Unreleased]\n", "## [Unreleased]\n\n## [#{target}] - #{release_date.iso8601}\n")
        link = "[Unreleased]: #{@project.url}/compare/v#{target}...HEAD"
        updated = updated.sub(/^\[Unreleased\]:[^\n]*$/, link)
        updated = "#{updated.rstrip}\n[#{target}]: #{@project.url}/releases/tag/v#{target}\n"
        verify(tag: "v#{target}", version: target, changelog: updated)
        match = version_match(original)
        replacement = "#{match[1]}#{match[2]}#{target}#{match[2]}#{match[4]}"
        { @project.version_file => original.sub(VERSION_LINE) { replacement }, @project.changelog => updated }
      end

      private

      def version_match(source)
        assignments = source.scan(/^[ \t]*VERSION[ \t]*=/)
        matches = source.to_enum(:scan, VERSION_LINE).map { Regexp.last_match }
        unless assignments.length == 1 && matches.length == 1
          raise Error, "#{@project.version_file} must contain exactly one static VERSION string assignment"
        end

        matches.first
      end

      def validate_history(text)
        sections = text.lines.map(&:chomp).grep(/^## /)
        unless sections.first == "## [Unreleased]" && sections.count("## [Unreleased]") == 1
          raise Error, "Expected one Unreleased section before the release history"
        end

        history = sections.drop(1).map { |line| parse_heading(line) }
        versions = history.map(&:version)
        raise Error, "Duplicate changelog release" unless versions.uniq == versions

        history.each_cons(2) do |newer, older|
          unless Gem::Version.new(newer.version) > Gem::Version.new(older.version) && newer.date >= older.date
            raise Error, "Changelog releases must be newest first by version and date"
          end
        end
        history.each do |heading|
          check_reference(text, heading.version, "#{@project.url}/releases/tag/v#{heading.version}")
        end
        references = text.lines.grep(/^\[Unreleased\]:/)
        raise Error, "Expected one Unreleased link reference" unless references.length == 1

        history
      end

      def parse_heading(line)
        match = HEADING.match(line)
        raise Error, "Invalid changelog release heading: #{line}" unless match

        validate_version(match[1])
        date = Date.iso8601(match[2])
        raise Error, "Release date cannot be in the future" if date > @clock.now.utc.to_date

        Heading.new(match[1], date, !match[3].nil?)
      rescue Date::Error
        raise Error, "Invalid changelog release date"
      end

      def check_reference(text, name, url)
        lines = text.lines.map(&:chomp).grep(/^\[#{Regexp.escape(name)}\]:/)
        raise Error, "Missing or incorrect release link for #{name}" unless lines == ["[#{name}]: #{url}"]
      end
    end
  end
end
