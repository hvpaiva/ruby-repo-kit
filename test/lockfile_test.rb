# frozen_string_literal: true

require "test_helper"
require "ruby_repo_kit/checks/lockfile"

class LockfileTest < Minitest::Test
  DIGEST = "a" * 64

  def lockfile(checksums: "  remote-gem (1.2.3) sha256=#{DIGEST}\n", sources: nil)
    sources ||= <<~LOCK
      GEM
        remote: https://not-accessed.invalid/
        specs:
          remote-gem (1.2.3)
    LOCK
    "#{sources}\nPLATFORMS\n  ruby\n\nDEPENDENCIES\n  remote-gem\n" \
      "#{"\nCHECKSUMS\n#{checksums}" unless checksums.nil?}\nBUNDLED WITH\n  2.6.0\n"
  end

  def with_lock(contents)
    Dir.mktmpdir("lockfile preflight ") do |root|
      path = File.join(root, "Gemfile.lock")
      File.write(path, contents)
      yield RubyRepoKit::Checks::Lockfile.new(path: path), path
    end
  end

  def test_complete_checksums_pass_without_an_installed_bundle_or_gemfile
    with_lock(lockfile) { |checker, _path| assert checker.check }
  end

  def test_empty_and_missing_rubygems_entries_fail_with_repair_instructions
    ["  remote-gem (1.2.3)\n", ""].each do |checksums|
      with_lock(lockfile(checksums: checksums)) do |checker, _path|
        error = assert_raises(RubyRepoKit::Error) { checker.check }

        assert_match(/remote-gem-1\.2\.3/, error.message)
        assert_match(/bundle lock --add-checksums/, error.message)
      end
    end
  end

  def test_path_and_git_specs_do_not_require_artifact_checksums
    sources = <<~LOCK
      PATH
        remote: .
        specs:
          consumer (0.1.0)

      GIT
        remote: https://not-accessed.invalid/git-library.git
        revision: #{'a' * 40}
        specs:
          git-library (2.0.0)

      GEM
        remote: https://not-accessed.invalid/
        specs:
          remote-gem (1.2.3)
    LOCK
    checksums = "  consumer (0.1.0)\n  git-library (2.0.0)\n  remote-gem (1.2.3) sha256=#{DIGEST}\n"

    with_lock(lockfile(sources: sources, checksums: checksums)) { |checker, _path| assert checker.check }
  end

  def test_checksums_are_checked_for_each_locked_platform
    sources = <<~LOCK
      GEM
        remote: https://not-accessed.invalid/
        specs:
          remote-gem (1.2.3)
          remote-gem (1.2.3-x86_64-linux)
    LOCK
    with_lock(lockfile(sources: sources)) do |checker, path|
      error = assert_raises(RubyRepoKit::Error) { checker.check }

      assert_match(/remote-gem-1\.2\.3-x86_64-linux/, error.message)
      checksums = "  remote-gem (1.2.3) sha256=#{DIGEST}\n  remote-gem (1.2.3-x86_64-linux) sha256=#{DIGEST}\n"
      File.write(path, lockfile(sources: sources, checksums: checksums))

      assert checker.check
    end
  end

  def test_checksum_for_another_version_does_not_satisfy_the_locked_spec
    with_lock(lockfile(checksums: "  remote-gem (1.2.2) sha256=#{DIGEST}\n")) do |checker, _path|
      assert_raises(RubyRepoKit::Error) { checker.check }
    end
  end

  def test_malformed_digest_and_merge_conflicts_are_reported_as_project_errors
    [lockfile(checksums: "  remote-gem (1.2.3) sha256=invalid\n"), "<<<<<<< HEAD\n"].each do |contents|
      with_lock(contents) do |checker, _path|
        error = assert_raises(RubyRepoKit::Error) { checker.check }

        assert_match(/Cannot inspect Gemfile.lock checksums/, error.message)
      end
    end
  end

  def test_legacy_lockfile_without_checksum_section_retains_bundler_opt_in_behavior
    with_lock(lockfile(checksums: nil)) { |checker, _path| assert checker.check }
  end

  def test_absent_lockfile_does_not_prevent_checking_a_new_scaffold
    with_lock(lockfile) do |checker, path|
      File.delete(path)

      assert checker.check
      refute_path_exists path
    end
  end

  def test_preflight_never_rewrites_lockfile_or_creates_bundle_configuration
    [lockfile, lockfile(checksums: "")].each do |contents|
      with_lock(contents) do |checker, path|
        before = File.stat(path)
        begin
          checker.check
        rescue RubyRepoKit::Error
          # Failing preflight must also leave the repository untouched.
        end

        assert_equal contents, File.read(path)
        assert_equal before.mtime, File.stat(path).mtime
        assert_equal ["Gemfile.lock"], Dir.children(File.dirname(path))
      end
    end
  end
end
