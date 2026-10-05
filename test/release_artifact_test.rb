# frozen_string_literal: true

require "test_helper"
require_relative "release_support"
require "rubygems/package"
require "digest"

class ReleaseArtifactTest < Minitest::Test
  include ReleaseSupport

  def build_artifact(project, name: project.name, version: "0.1.0")
    spec = Gem::Specification.new do |gem|
      gem.name = name
      gem.version = version
      gem.authors = ["Test"]
      gem.summary = "Fixture"
      gem.license = "MIT"
      gem.homepage = "https://example.org"
    end
    path = project.path("pkg/#{project.name}-0.1.0.gem")
    FileUtils.mkdir_p(File.dirname(path))
    capture_io { Gem::Package.build(spec, false, false, path) }
    path
  end

  def test_record_and_verify_use_exact_bytes_without_rebuilding
    release_project do |project|
      path = build_artifact(project)
      artifact = RubyRepoKit::Release::Artifact.new(project: project)

      assert_equal path, artifact.record
      digest = Digest::SHA256.file(path).hexdigest

      assert_equal path, artifact.verify(expected: digest)
      assert_equal "### Added\n\n- Initial behavior.\n", File.read(project.path("pkg/release-notes.md"))
      assert_raises(RubyRepoKit::Error) { artifact.verify(expected: "0" * 64) }
      File.binwrite(path, "tampered")

      assert_raises(RubyRepoKit::Error) { artifact.verify(expected: digest) }
    end
  end

  def test_manifest_cannot_authorize_another_package_name_or_version
    [{ name: "another-gem" }, { version: "0.2.0" }].each do |identity|
      release_project do |project|
        build_artifact(project, **identity)
        artifact = RubyRepoKit::Release::Artifact.new(project: project)
        artifact.record

        assert_raises(RubyRepoKit::Error) { artifact.verify }
      end
    end
  end

  def test_publish_rejects_local_wrong_repository_tag_or_missing_digest_before_commands
    release_project do |project|
      runner = ->(*) { flunk "Must not execute a publication command" }
      commands = RubyRepoKit::Commands.new(project: project, runner: runner, out: StringIO.new)
      publisher = RubyRepoKit::Release::Publisher.new(project: project, commands: commands)
      valid = { "GITHUB_ACTIONS" => "true", "GITHUB_REPOSITORY" => project.repository,
                "GITHUB_REF" => "refs/tags/v0.1.0" }

      [{}, valid.merge("GITHUB_REPOSITORY" => "someone/else"),
       valid.merge("GITHUB_REF" => "refs/heads/main")].each do |env|
        assert_raises(RubyRepoKit::Error) { publisher.publish(environment: env, expected: "0" * 64) }
      end

      assert_raises(RubyRepoKit::Error) { publisher.publish(environment: valid, expected: nil) }
    end
  end

  def test_publish_verifies_metadata_and_checksum_before_the_single_push
    release_project do |project|
      path = build_artifact(project)
      File.write(project.path(project.changelog), released_changelog(project, "0.1.0"))
      RubyRepoKit::Release::Artifact.new(project: project).record
      digest = Digest::SHA256.file(path).hexdigest
      env = { "GITHUB_ACTIONS" => "true", "GITHUB_REPOSITORY" => project.repository,
              "GITHUB_REF" => "refs/tags/v0.1.0" }
      calls = []
      runner = lambda do |argv, **options|
        assert_equal ["gem", "push", "--host", "https://rubygems.org", path], argv
        assert options[:stream]
        calls << argv
        ["", Status.new(true)]
      end
      commands = RubyRepoKit::Commands.new(project: project, runner: runner, out: StringIO.new)
      publisher = RubyRepoKit::Release::Publisher.new(project: project, commands: commands)

      assert_raises(RubyRepoKit::Error) { publisher.publish(environment: env, expected: "0" * 64) }
      assert_empty calls
      assert_equal path, publisher.publish(environment: env, expected: digest)
      assert_equal 1, calls.length
    end
  end
end
