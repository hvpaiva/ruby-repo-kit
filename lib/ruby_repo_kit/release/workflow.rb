# frozen_string_literal: true

require "tempfile"

module RubyRepoKit
  module Release
    class Workflow
      def initialize(version, project:, commands: nil, configuration: nil, clock: SystemClock,
                     out: $stdout, push: false, dry_run: false, branch: "main")
        raise Error, "--push and --dry-run cannot be combined" if push && dry_run

        @version = version
        @project = project
        @push = push
        @dry_run = dry_run
        @out = out
        @clock = clock
        @commands = commands || Commands.new(project: project, out: out)
        @metadata = Metadata.new(project: project, commands: @commands, clock: clock)
        @base = @metadata.validate_branch(branch, version)
        @preparation = Preparation.new(project: project, commands: @commands, metadata: @metadata, clock: clock)
        @configuration = configuration
        @publication = Publication.new(version, project: project, commands: @commands, out: out, clock: clock,
                                                branch: @base)
      end

      def run
        validate
        request = find_pull_request
        if request&.fetch("state") == "MERGED"
          require_clean
          @publication.run(request.dig("mergeCommit", "oid"), push: @push, dry_run: @dry_run)
        elsif @publication.remote_tag.any?
          raise Error, "#{tag} already exists without a matching merged release PR; inspect it before continuing"
        elsif request
          resume_pull_request(request)
        else
          prepare_pull_request
        end
      rescue Error => e
        raise Error, "#{e.message}\nAfter resolving the problem, rerun #{resume_command}#{' --push' if @push}. " \
                     "Existing pull requests and tags are inspected before any new action."
      end

      private

      def tag = "v#{@version}"
      def branch = "release/#{tag}"

      def resume_command
        "bundle exec ruby-repo-kit release #{@version}#{" --branch #{@base}" unless @base == 'main'}"
      end

      def command(...) = @commands.call(...)

      def configuration
        return @configuration if @configuration

        require_relative "../github"
        @configuration = GitHub::Configuration.new(project: @project)
      end

      def validate
        origin = command(%w[git remote get-url origin]).strip
        repository = Regexp.escape(@project.repository)
        unless origin.match?(%r{\A(?:https://github\.com/|git@github\.com:|ssh://git@github\.com/)#{repository}(?:\.git)?\z})
          raise Error, "The origin repository must be #{@project.repository}"
        end

        configuration.verify!
        command(%w[git fetch origin --tags])
        @current_branch = command(%w[git branch --show-current]).strip
        raise Error, "Run from #{@base} or #{branch}" unless [@base, branch].include?(@current_branch)
      end

      def find_pull_request
        requests = @commands.json(["gh", "pr", "list", "--state", "all", "--base", @base, "--head", branch,
                                   "--json", "url,state,headRefOid,mergeCommit,isCrossRepository"])
        if requests.any? { |request| request["isCrossRepository"] != false }
          raise Error, "Release pull requests must originate in #{@project.repository}, not a fork"
        end
        raise Error, "Several pull requests use #{branch}; reconcile them before releasing" if requests.length > 1

        requests.first
      end

      def require_clean
        raise Error, "Commit or stash unrelated work before continuing" unless command(%w[git status --porcelain
                                                                                          -z]).empty?
      end

      def resume_pull_request(request)
        require_clean
        unless request["state"] == "OPEN"
          raise Error,
                "The release PR was closed without merging; reopen it before retrying"
        end

        @commit = request.fetch("headRefOid")
        raise Error, "GitHub did not return a valid release PR head" unless @commit&.match?(/\A[0-9a-f]{40}\z/)
        if @current_branch == branch && command(%w[git rev-parse HEAD]).strip != @commit
          raise Error, "Local #{branch} differs from the PR head. Push its reviewed changes before retrying"
        end

        if @dry_run
          verify_pull_request
          return @out.puts "Existing release PR: #{request.fetch('url')} (dry run)."
        end

        finish_pull_request(request.fetch("url"))
      end

      def prepare_pull_request
        if @current_branch == @base
          require_clean
          unless command(%w[git rev-parse HEAD]) == command(["git", "rev-parse", "origin/#{@base}"])
            raise Error, "Local #{@base} must match origin/#{@base}; pull first"
          end

          changes = @metadata.changes(@version)
          if @dry_run
            return @out.puts changes.fetch(@project.changelog),
                             "Dry run: no working files or GitHub state changed."
          end

          command(["git", "switch", "-c", branch])
        else
          changes = @preparation.resume(@version, dry_run: @dry_run)
          if @dry_run
            return @out.puts "Would resume preparation on #{branch}; no working files or GitHub state changed."
          end
        end
        @preparation.run(changes, version: @version) if changes
        @commit = command(%w[git rev-parse HEAD]).strip
        command(%w[git verify-commit HEAD])
        command(["git", "push", "-u", "origin", branch], stream: true)
        finish_pull_request(open_pull_request)
      end

      def open_pull_request
        Tempfile.create(["#{@project.name}-release", ".md"]) do |body|
          body.write("Release #{@project.name} #{@version}. The signed tag will target the merge commit.\n\n" \
                     "Validation: `#{@project.check_command.join(' ')}`. Release notes are in #{@project.changelog}.\n")
          body.flush
          command(["gh", "pr", "create", "--base", @base, "--head", branch, "--title", "chore: release #{tag}",
                   "--body-file", body.path]).strip
        end
      end

      def finish_pull_request(url)
        verify_pull_request
        return @out.puts "Release PR: #{url}. Run #{resume_command} --push to merge, sign and publish." unless @push

        wait_for_checks(url)
        command(["gh", "pr", "checks", url, "--watch", "--fail-fast", "--interval", "10"], stream: true)
        command(["gh", "pr", "merge", url, "--merge", "--delete-branch", "--match-head-commit", @commit])
        sha = command(["gh", "pr", "view", url, "--json", "mergeCommit", "--jq", ".mergeCommit.oid"]).strip
        raise Error, "GitHub did not return a valid release merge commit" unless sha.match?(/\A[0-9a-f]{40}\z/)

        command(%w[git fetch origin --tags])
        command(["git", "merge-base", "--is-ancestor", @commit, sha])
        @publication.run(sha, push: true)
      end

      def verify_pull_request
        @publication.verify_metadata(@commit)
        command(["git", "verify-commit", @commit])
      end

      def wait_for_checks(url)
        60.times do
          count = command(["gh", "pr", "view", url, "--json", "statusCheckRollup", "--jq",
                           ".statusCheckRollup | length"])
          return if count.to_i.positive?

          @clock.sleep(5)
        end
        raise Error, "Timed out waiting for checks on #{url}; the existing PR will be reused on retry"
      end
    end
  end
end
