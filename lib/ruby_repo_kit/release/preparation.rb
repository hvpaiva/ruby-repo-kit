# frozen_string_literal: true

module RubyRepoKit
  module Release
    # Owns local edits and recovery; the workflow owns remote PR and tag transitions.
    class Preparation
      def initialize(project:, commands:, metadata:, clock: SystemClock)
        @project = project
        @commands = commands
        @metadata = metadata
        @clock = clock
      end

      def resume(version, dry_run: false)
        dirty = owned_changes(version)
        source = [@project.version_file, @project.changelog].to_h do |path|
          [path, @commands.call(["git", "show", "HEAD:#{path}"])]
        end
        if source.fetch(@project.changelog).include?("## [#{version}]")
          raise Error, "Commit or stash unrelated work before continuing" unless dirty.empty?

          @metadata.verify(tag: "v#{version}", version: @metadata.version_from(source.fetch(@project.version_file)),
                           changelog: source.fetch(@project.changelog))
          @commands.call(@project.check_command, stream: true) unless dry_run
          return
        end

        pending_changes(version, source)
      end

      def run(changes, version:)
        targets = changes.to_h { |path, content| [@project.path(path), content] }
        targets.each { |path, content| File.write(path, content) }
        @commands.call(%w[bundle lock --local])
        @commands.call(@project.generate_command, stream: true)
        @commands.call(@project.check_command, stream: true)
        owned_changes(version)
        @commands.call(["git", "add", "--", *@project.release_files])
        @commands.call(["git", "commit", "-S", "-m", "chore: release v#{version}"])
        @commands.call(%w[git log -1 --format=full])
      end

      private

      def pending_changes(version, source)
        text = File.read(@project.path(@project.changelog))
        dated = text[/^## \[#{Regexp.escape(version)}\] - (\d{4}-\d{2}-\d{2})$/, 1]
        date = dated ? Date.iso8601(dated) : @clock.now.utc.to_date
        changes = @metadata.changes(version, source: source, date: date)
        changes.each do |path, content|
          actual = File.read(@project.path(path))
          next if [source.fetch(path), content].include?(actual)

          raise Error, "#{path} has edits beyond release preparation; review them before retrying"
        end
        changes
      rescue Date::Error
        raise Error, "Invalid date in partially prepared release"
      end

      def owned_changes(version)
        entries = @commands.call(%w[git status --porcelain -z]).split("\0")
        paths = []
        until entries.empty?
          entry = entries.shift
          paths << entry[3..]
          paths << entries.shift if entry[0, 2].match?(/[RC]/)
        end
        unless paths.all? { |path| owned_path?(path) }
          raise Error, "Unrelated changes on release/v#{version}; commit or stash them first"
        end

        paths.each { |path| @project.path(path) }
      end

      def owned_path?(path)
        path && @project.release_files.any? { |owned| path == owned || path.start_with?("#{owned}/") }
      end
    end
  end
end
