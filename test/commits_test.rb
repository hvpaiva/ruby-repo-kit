# frozen_string_literal: true

require "test_helper"
require "ruby_repo_kit/checks/commits"

class CommitsTest < Minitest::Test
  class Commands
    attr_reader :calls
    attr_accessor :messages, :base

    def initialize(messages = [])
      @calls = []
      @messages = messages
      @base = true
    end

    def call(argv)
      @calls << argv
      return base ? "refs/remotes/origin/main\n" : "" if argv[1] == "for-each-ref"

      messages.join("\0")
    end
  end

  def commit(message, parents: "def5678") = "abc1234\x1f#{parents}\x1f#{message}\n"

  def checker(project, commands)
    RubyRepoKit::Commits.new(project: project, commands: commands)
  end

  def test_checks_default_range_and_pr_metadata_without_network
    in_project do |project|
      commands = Commands.new([commit("feat(cli): add help"), commit('Revert "fix: repair output"')])

      assert checker(project, commands).check(title: "chore(deps): [security] bump dependency", body: "Tested locally.")
      assert_includes commands.calls.last, "origin/main..HEAD"
      assert(commands.calls.all? { |argv| argv.first == "git" })
    end
  end

  def test_without_origin_main_it_checks_head
    in_project do |project|
      commands = Commands.new([commit("chore: initial repository", parents: "")])
      commands.base = false

      assert checker(project, commands).check(title: nil, body: nil)
      assert_includes commands.calls.last, "HEAD"
    end
  end

  def test_rejects_malformed_subjects_scopes_and_unfinished_commits
    in_project do |project|
      ["fix: Capitalized", "feat(bad scope): add help", "feat(-bad): add help", "fixup! fix: output",
       "fix: wip output"].each do |subject|
        commands = Commands.new([commit(subject)])

        assert_raises(RubyRepoKit::Error) { checker(project, commands).check(range: "HEAD", title: nil, body: nil) }
      end
    end
  end

  def test_merge_subject_is_generated_but_attribution_is_still_checked
    in_project do |project|
      commands = Commands.new([commit("Merge branch 'main'", parents: "a b")])

      assert checker(project, commands).check(range: "HEAD", title: nil, body: nil)
      commands.messages = [commit("Merge branch 'main'\n\nGenerated-by: Codex", parents: "a b")]
      assert_raises(RubyRepoKit::Error) { checker(project, commands).check(range: "HEAD", title: nil, body: nil) }
    end
  end

  def test_human_coauthor_is_accepted_and_bot_attribution_in_pr_is_rejected
    in_project do |project|
      commands = Commands.new([commit("fix: output\n\nCo-Authored-By: Claude Monet <claude@example.com>")])

      assert checker(project, commands).check(range: "HEAD", title: nil, body: nil)
      body = "Co-Authored-By: Assistant <noreply@anthropic.com>"
      assert_raises(RubyRepoKit::Error) { checker(project, commands).check(range: "HEAD", title: "fix: output", body: body) }
    end
  end

  def test_unsafe_ranges_are_rejected_before_any_command
    in_project do |project|
      commands = Commands.new

      ["--all", "HEAD;touch file", "HEAD\n--all", "HEAD..", "A..B..C", "../HEAD", "HEAD@{1}",
       "main:secret"].each do |range|
        assert_raises(RubyRepoKit::Error) { checker(project, commands).check(range: range, title: nil, body: nil) }
      end

      assert_empty commands.calls
    end
  end

  def test_bad_title_is_rejected_even_if_the_commit_range_is_empty
    in_project do |project|
      assert_raises(RubyRepoKit::Error) do
        checker(project, Commands.new).check(range: "origin/main...HEAD", title: "Oops", body: nil)
      end
    end
  end

  def test_reads_real_git_records_in_a_repository_with_a_space_in_its_path
    in_project do |project|
      environment = { "GIT_CONFIG_GLOBAL" => File::NULL, "GIT_CONFIG_NOSYSTEM" => "1",
                      "GIT_DIR" => nil, "GIT_WORK_TREE" => nil }
      flags = %w[-c user.name=Fixture -c user.email=fixture@example.com
                 -c commit.gpgsign=false -c core.hooksPath=/dev/null]
      [%w[init --initial-branch=main], ["commit", "--allow-empty", "-m", "chore: initial fixture"]].each do |arguments|
        _output, error, status = Open3.capture3(environment, "git", *flags, *arguments, chdir: project.root)
        raise error unless status.success?
      end
      commands = RubyRepoKit::Commands.new(project: project, out: StringIO.new)

      assert checker(project, commands).check(title: nil, body: nil)
    end
  end
end
