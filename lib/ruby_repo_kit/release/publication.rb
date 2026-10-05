# frozen_string_literal: true

module RubyRepoKit
  module Release
    # Remote tags are observation-only on retries; an accepted gem cannot be republished.
    class Publication
      def initialize(version, project:, commands:, clock: SystemClock, out: $stdout, branch: "main")
        @version = version
        @project = project
        @commands = commands
        @clock = clock
        @out = out
        @metadata = Metadata.new(project: project, commands: commands, clock: clock)
        @base = @metadata.validate_branch(branch, version)
      end

      def tag = "v#{@version}"

      def remote_tag
        @commands.call(["git", "ls-remote", "--tags", "origin", "refs/tags/#{tag}",
                        "refs/tags/#{tag}^{}"]).lines.to_h do |line|
          sha, ref = line.split
          [ref, sha]
        end
      end

      def run(sha, push:, dry_run: false)
        verify_commit(sha)
        remote = remote_tag
        if remote.any? && remote["refs/tags/#{tag}^{}"] != sha
          raise Error, "Remote #{tag} targets another commit; it will never be moved"
        end

        exists = !@commands.call(["git", "tag", "--list", tag]).strip.empty?
        verify_tag(sha) if exists
        if dry_run || (!push && remote.empty?)
          next_step = exists ? "push the signed tag" : "sign and push its tag"
          @out.puts "Release merge #{sha} is ready. Run #{resume_command} --push to #{next_step}."
          return
        end
        if remote.empty?
          @commands.call(["git", "tag", "-s", tag, "-m", "Release #{@version}", sha]) unless exists
          verify_tag(sha)
          @commands.call(["git", "push", "origin", tag], stream: true)
        end
        watch_release(sha)
      end

      def verify_commit(sha)
        raise Error, "GitHub did not return a valid release merge commit" unless sha&.match?(/\A[0-9a-f]{40}\z/)

        @commands.call(["git", "merge-base", "--is-ancestor", sha, "origin/#{@base}"])
        verify_metadata(sha)
      end

      def verify_metadata(sha)
        source = @commands.call(["git", "show", "#{sha}:#{@project.version_file}"])
        version = @metadata.version_from(source)
        changelog = @commands.call(["git", "show", "#{sha}:#{@project.changelog}"])
        @metadata.verify(tag: tag, version: version, changelog: changelog)
      end

      private

      def resume_command
        "bundle exec ruby-repo-kit release #{@version}#{" --branch #{@base}" unless @base == 'main'}"
      end

      def verify_tag(sha)
        unless @commands.call(["git", "cat-file", "-t", "refs/tags/#{tag}"]).strip == "tag" &&
               @commands.call(["git", "rev-parse", "#{tag}^{commit}"]).strip == sha
          raise Error, "Local #{tag} is not an annotated tag of the release merge; it will never be replaced"
        end

        @commands.call(["git", "verify-tag", tag])
      end

      def watch_release(sha)
        run = find_run(sha)
        unless run
          raise Error, "#{tag} is already on GitHub. No Release run appeared; inspect Actions before dispatching it. " \
                       "The tag was not changed."
        end

        id = run.fetch("databaseId").to_s
        manual = run["event"] == "workflow_dispatch"
        unless run["status"] == "completed"
          @commands.call(["gh", "run", "watch", id], stream: true)
          run = @commands.json(["gh", "run", "view", id, "--json", "status,conclusion"])
        end
        raise Error, failed_run_message(id) unless run["conclusion"] == "success"

        if manual && !published_run?(id)
          raise Error, "Manual run #{id} was successful, but publication was not confirmed. " \
                       "A dry run is not a release. Inspect gh run view #{id} --repo #{@project.repository}; " \
                       "no publication was retried."
        end

        @out.puts "Released #{tag}; the existing successful run is #{id}."
      end

      def find_run(sha)
        60.times do
          runs = @commands.json(["gh", "run", "list", "--workflow", @project.workflow,
                                 "--branch", tag, "--limit", "20", "--json",
                                 "databaseId,headSha,status,conclusion,event"])
          matching = runs.select { |candidate| candidate["headSha"] == sha }
          manual = matching.select { |candidate| candidate["event"] == "workflow_dispatch" }
          recovered = manual.find do |candidate|
            candidate["conclusion"] == "success" && published_run?(candidate.fetch("databaseId").to_s)
          end
          run = recovered || matching.find { |candidate| candidate["event"] == "push" } || manual.first
          return run if run

          @clock.sleep(5)
        end
        nil
      end

      def published_run?(id)
        jobs = @commands.json(["gh", "run", "view", id, "--json", "jobs"]).fetch("jobs")
        %w[publish github-release].all? do |name|
          jobs.any? { |job| job["name"] == name && job["conclusion"] == "success" }
        end
      end

      def failed_run_message(id)
        jobs = @commands.json(["gh", "run", "view", id, "--json", "jobs"]).fetch("jobs")
        publication = jobs.find { |job| job["name"] == "publish" }
        github_release = jobs.find { |job| job["name"] == "github-release" }
        prefix = "#{tag} is already on GitHub. Release run #{id} did not complete publication; " \
                 "no publication was retried."
        if publication && publication["conclusion"] == "success" && github_release
          "#{prefix}\nRubyGems publication succeeded. Retry only GitHub release creation:\n" \
            "gh run rerun #{id} --job #{github_release.fetch('databaseId')} --repo #{@project.repository}"
        elsif publication.nil? || publication["conclusion"] == "skipped"
          "#{prefix}\nPublication did not run. Fix the failed checks, then: " \
            "gh run rerun #{id} --failed --repo #{@project.repository}"
        else
          "#{prefix}\nInspect gh run view #{id} --log-failed --repo #{@project.repository}. " \
            "Check whether RubyGems accepted #{@version} before retrying any publish job."
        end
      end
    end
  end
end
