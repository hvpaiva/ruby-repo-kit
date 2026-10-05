# frozen_string_literal: true

require "bundler"

module RubyRepoKit
  class Checks
    # Parse only: never resolve, install, fetch or rewrite the consumer's bundle.
    class Lockfile
      def initialize(path:)
        @path = path
      end

      def check
        return true unless File.exist?(@path)

        parsed = Bundler::LockfileParser.new(File.read(@path))
        # Checksums are opt-in for existing lockfiles, including Bundler 2.6.
        return true unless parsed.checksums

        incomplete = parsed.specs.select do |spec|
          spec.source.is_a?(Bundler::Source::Rubygems) &&
            spec.source.checksum_store.to_lock(spec) == spec.name_tuple.lock_name
        end
        return true if incomplete.empty?

        raise Error, "Gemfile.lock has empty or missing CHECKSUMS for: #{incomplete.map(&:full_name).join(', ')}. " \
                     "Run `bundle lock --add-checksums`, then review and commit Gemfile.lock before frozen CI."
      rescue Bundler::BundlerError, ArgumentError => e
        raise Error, "Cannot inspect Gemfile.lock checksums: #{e.message}"
      end
    end
  end
end
