# frozen_string_literal: true

require "test_helper"
require_relative "release_support"

class ReleaseMetadataTest < Minitest::Test
  include ReleaseSupport

  def test_changes_preserve_quotes_and_freezing_outside_the_project_directory
    ["'", '"'].product(["", ".freeze"]).each do |quote, suffix|
      release_project do |project|
        original = "module Example\n  VERSION = #{quote}0.1.0#{quote}#{suffix} # public version\nend\n"
        File.write(project.path(project.version_file), original)
        metadata = RubyRepoKit::Release::Metadata.new(project: project, clock: Clock.new)
        changes = metadata.changes("0.2.0")

        assert_equal "0.1.0", metadata.version
        assert_equal original, File.read(project.path(project.version_file))
        assert_equal original.sub("0.1.0", "0.2.0"), changes.fetch(project.version_file)
        assert_includes changes.fetch(project.changelog), "## [0.2.0] - 2026-10-04"
        assert_equal "0.2.0",
                     metadata.verify(tag: "v0.2.0", version: "0.2.0", changelog: changes.fetch(project.changelog))
      end
    end
  end

  def test_version_parser_refuses_ambiguous_or_executable_sources
    release_project do |project|
      metadata = RubyRepoKit::Release::Metadata.new(project: project)

      ["VERSION = `echo 0.1.0`", "VERSION = '0.1.0'\nVERSION = \"0.2.0\"\n",
       "OTHER = '0.1.0'", "VERSION = read_version()", "VERSION = '0.1.0'; exit"].each do |source|
        assert_raises(RubyRepoKit::Error) { metadata.version_from(source) }
      end
      %w[01.2.3 1.2 1.2.3.pre -1.2.3].each do |version|
        assert_raises(RubyRepoKit::Error) { metadata.validate_version(version) }
      end
    end
  end

  def test_two_projects_do_not_share_paths_or_repository_links
    release_project do |first|
      release_project("name" => "other", "repository" => "someone/other",
                      "version_file" => "src/version.rb") do |second|
        [first, second].each do |project|
          metadata = RubyRepoKit::Release::Metadata.new(project: project, clock: Clock.new)
          changes = metadata.changes("0.2.0")

          assert_equal [project.version_file, project.changelog], changes.keys
          assert_includes changes.fetch(project.changelog), "#{project.url}/releases/tag/v0.2.0"
        end
      end
    end
  end

  def test_branch_rehearsal_validates_metadata_without_writing
    release_project do |project|
      metadata = RubyRepoKit::Release::Metadata.new(project: project, clock: Clock.new)

      assert_equal "0.1.0", metadata.verify(tag: nil)
      assert_equal initial_changelog(project), File.read(project.path(project.changelog))
      assert_raises(RubyRepoKit::Error) { metadata.verify(tag: "v0.1.0") }
    end
  end

  def test_history_rejects_bad_order_dates_duplicate_headings_links_and_empty_target
    release_project do |project|
      metadata = RubyRepoKit::Release::Metadata.new(project: project, clock: Clock.new)
      good = released_changelog(project)
      bad = [good.sub("2026-10-04", "2026-99-99"), good.sub("2026-10-04", "2026-10-05"),
             good.sub("- Initial behavior.", ""), good.sub("releases/tag/v0.2.0", "releases/tag/v9.9.9"),
             "#{good}[0.2.0]: #{project.url}/releases/tag/v0.2.0\n", "#{good}\n## [0.2.0] - 2026-10-04\n",
             good.sub("## [Unreleased]", "## [Other]"),
             good.sub("## [0.2.0] - 2026-10-04", "## [0.2.0] - 2026-10-04 [YANKED]")]

      bad.each { |text| assert_raises(RubyRepoKit::Error) { metadata.verify(tag: "v0.2.0", version: "0.2.0", changelog: text) } }
      history = good.sub("[Unreleased]:", "## [0.3.0] - 2026-10-03\n\n- Other.\n\n[Unreleased]:") +
                "[0.3.0]: #{project.url}/releases/tag/v0.3.0\n"

      assert_raises(RubyRepoKit::Error) { metadata.verify(tag: "v0.2.0", version: "0.2.0", changelog: history) }
    end
  end

  def test_version_cannot_go_backwards_or_repeat_history_and_hotfix_must_match
    release_project do |project|
      metadata = RubyRepoKit::Release::Metadata.new(project: project, clock: Clock.new)

      assert_raises(RubyRepoKit::Error) { metadata.changes("0.0.9") }
      File.write(project.path(project.changelog), released_changelog(project, "0.1.0"))

      assert_raises(RubyRepoKit::Error) { metadata.changes("0.1.0") }
      assert_equal "hotfix/0.2", metadata.validate_branch("hotfix/0.2", "0.2.1")
      assert_raises(RubyRepoKit::Error) { metadata.validate_branch("hotfix/0.1", "0.2.1") }
    end
  end

  def test_ref_verification_uses_real_git_in_the_project_not_process_cwd
    release_project do |project|
      commands = [%w[init -q -b main], %w[add .], ["commit", "-qm", "chore: fixture"],
                  %w[update-ref refs/remotes/origin/hotfix/0.2 HEAD]]
      commands.each do |args|
        _out, error, status = Open3.capture3("git", "-c", "user.name=Test", "-c", "user.email=test@example.org",
                                             "-c", "commit.gpgsign=false", "-c", "core.hooksPath=/dev/null",
                                             "-c", "maintenance.auto=false", *args, chdir: project.root)

        assert_predicate status, :success?, error
      end
      sha, = Open3.capture2("git", "rev-parse", "HEAD", chdir: project.root)
      metadata = RubyRepoKit::Release::Metadata.new(project: project,
                                                    commands: RubyRepoKit::Commands.new(project: project,
                                                                                        out: StringIO.new))

      assert metadata.verify_ref(sha: sha.strip, version: "0.2.1")
      assert_raises(RubyRepoKit::Error) { metadata.verify_ref(sha: sha.strip, version: "0.3.0") }
    end
  end
end
