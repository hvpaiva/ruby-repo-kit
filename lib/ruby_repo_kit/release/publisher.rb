# frozen_string_literal: true

module RubyRepoKit
  module Release
    class Publisher
      def initialize(project:, commands: nil)
        @project = project
        @commands = commands || Commands.new(project: project)
      end

      def publish(expected: ENV.fetch("RELEASE_SHA256", nil), environment: ENV)
        metadata = Metadata.new(project: @project)
        version = metadata.version
        unless environment["GITHUB_ACTIONS"] == "true" && environment["GITHUB_REPOSITORY"] == @project.repository &&
               environment["GITHUB_REF"] == "refs/tags/v#{version}"
          raise Error, "Publication runs only in this project's tagged GitHub Actions release workflow"
        end
        raise Error, "Publication requires the verified RELEASE_SHA256" unless expected&.match?(/\A[0-9a-f]{64}\z/)

        metadata.verify(tag: "v#{version}")
        artifact = Artifact.new(project: @project).verify(expected: expected)
        @commands.call(["gem", "push", "--host", "https://rubygems.org", artifact], stream: true)
        artifact
      end
    end
  end
end
