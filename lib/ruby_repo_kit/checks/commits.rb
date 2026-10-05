# frozen_string_literal: true

module RubyRepoKit
  # A read-only Conventional Commits policy for commits and pull request metadata.
  class Commits
    TYPES = %w[feat fix docs test refactor chore ci].freeze
    SUBJECT = /\A(?:#{TYPES.join('|')})(?:\([a-z0-9]+(?:-[a-z0-9]+)*\))?!?: (?:\[security\] )?[a-z][^\r\n]*\z/
    UNFINISHED = /\A(?:fixup!|squash!|amend!|wip\b)|\A\w+(?:\([^)]*\))?!?:\s*wip\b/i
    REVERT = /\A(?:Revert|Reapply) "(?<subject>.+)"\z/
    BOT_ADDRESS = /\A(?:noreply@anthropic\.com|cursoragent@cursor\.com|(?:aider|noreply)@aider\.chat|
                   \d+\+(?:Copilot|[\w-]+\[bot\])@users\.noreply\.github\.com)\z/ix
    TOOL_TRAILER = /^(?:Generated-(?:by|with)|Assisted-by|Claude-Session):.*\b
                    (?:claude|anthropic|copilot|cursor|codex|chatgpt|gpt-|gemini|assistant)\b/ix

    def initialize(project:, commands: nil)
      @commands = commands || Commands.new(project: project)
    end

    def check(range: nil, title: ENV.fetch("PR_TITLE", nil), body: ENV.fetch("PR_BODY", nil))
      range ||= default_range
      validate_range(range)
      output = @commands.call(["git", "log", "--no-show-signature", "--reverse", "-z",
                               "--format=%h%x1f%p%x1f%B", range, "--"])
      problems = commit_problems(output)
      problems << "Pull request title is not a Conventional Commit" if title && !valid_subject?(title.strip)
      problems << "Pull request body contains a tool attribution trailer" if body && attribution?(body)
      raise Error, "Commit policy failed:\n#{problems.join("\n")}" unless problems.empty?

      true
    end

    private

    def default_range
      refs = @commands.call(["git", "for-each-ref", "--format=%(refname)", "refs/remotes/origin/main"])
      refs.lines.map(&:strip).include?("refs/remotes/origin/main") ? "origin/main..HEAD" : "HEAD"
    end

    def validate_range(range)
      references = range.is_a?(String) ? range.split(/\.\.\.?/, -1) : []
      valid = references.length.between?(1, 2) && references.all? do |reference|
        reference.match?(%r{\A[A-Za-z0-9][A-Za-z0-9._/-]*\z}) &&
          !reference.include?("..") && !reference.include?("//") && !reference.end_with?("/") &&
          reference.split("/").none? { |part| part.start_with?(".") || part.end_with?(".", ".lock") }
      end
      raise Error, "Expected a commit reference or REF..REF range" unless valid
    end

    def commit_problems(output)
      output.dup.force_encoding(Encoding::UTF_8).scrub.split("\0").flat_map do |record|
        sha, parents, message = record.split("\x1f", 3)
        raise Error, "Git returned an unreadable commit record" unless sha && parents && message

        problems = []
        if parents.split.length < 2 && !valid_subject?(message.lines.first.to_s.chomp)
          problems << "#{sha}: subject is not a Conventional Commit"
        end
        problems << "#{sha}: message contains a tool attribution trailer" if attribution?(message)
        problems
      end
    end

    def valid_subject?(subject)
      return false if UNFINISHED.match?(subject)

      # git can nest Revert/Reapply subjects; iteration avoids recursive stack growth.
      while (reverted = REVERT.match(subject))
        subject = reverted[:subject]
      end
      !UNFINISHED.match?(subject) && SUBJECT.match?(subject)
    end

    def attribution?(text)
      text.each_line.any? do |line|
        address = line.match(/^Co-Authored-By:[^<\n]*<(?<address>[^>\n]+)>/i)
        if address
          BOT_ADDRESS.match?(address[:address].strip)
        else
          TOOL_TRAILER.match?(line) || line.match?(/^\W*Generated with \[?Claude/i)
        end
      end
    end
  end
end
