# frozen_string_literal: true

require "digest"
require "rubygems/package"

module RubyRepoKit
  module Release
    # Records and checks existing bytes; publication never builds another gem.
    class Artifact
      def initialize(project:)
        @project = project
        @metadata = Metadata.new(project: project)
      end

      def path = @project.path("pkg/#{@project.name}-#{@metadata.version}.gem")

      def record
        artifact = path
        digest = Digest::SHA256.file(artifact).hexdigest
        text = File.read(@project.path(@project.changelog))
        section = text.include?("## [#{@metadata.version}]") ? @metadata.version : "Unreleased"
        File.write(@project.path("pkg/SHA256SUMS"), "#{digest}  #{File.basename(artifact)}\n")
        File.write(@project.path("pkg/release-notes.md"), "#{@metadata.notes(text, section).strip}\n")
        artifact
      end

      def verify(expected: ENV.fetch("RELEASE_SHA256", nil))
        artifact = path
        digest = Digest::SHA256.file(artifact).hexdigest
        manifest = File.read(@project.path("pkg/SHA256SUMS"))
        unless manifest == "#{digest}  #{File.basename(artifact)}\n" && (expected.nil? || expected == digest)
          raise Error, "Release artifact checksum mismatch"
        end

        package = Gem::Package.new(artifact)
        package.verify
        unless package.spec.name == @project.name && package.spec.version.to_s == @metadata.version
          raise Error, "Release artifact name/version does not match the checkout"
        end

        artifact
      rescue Gem::Package::Error, SystemCallError => e
        raise Error, "Cannot verify release artifact: #{e.message}"
      end
    end
  end
end
