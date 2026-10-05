#!/usr/bin/env ruby
# frozen_string_literal: true

# Local recovery evidence only: Git transports are restricted to file://, and gh
# responses are strict simulations. The original consumer is never modified.
require "date"
require "digest"
require "fileutils"
require "json"
require "open3"
require "optparse"
require "shellwords"
require "time"
require "tmpdir"
require_relative "../lib/ruby_repo_kit/release"
require_relative "support/canary_rehearsal_transport"

class CanaryRecoveryRehearsal
  ROOT = File.expand_path("..", __dir__)
  EXCLUDED = %w[.git .bundle coverage pkg tmp vendor].freeze
  Clock = Struct.new(:now) do
    def sleep(*) = raise("Unexpected wait in local rehearsal")
  end

  class Configuration
    attr_reader :checks

    def initialize = @checks = 0
    def verify! = @checks += 1
  end

  def initialize(source:, gem_home:, output:)
    @source = File.realpath(source)
    @gem_home = File.realpath(gem_home)
    @output = File.expand_path(output)
    @report = { started_at: Time.now.utc.iso8601, source: @source, ruby: RUBY_DESCRIPTION,
                github: "SIMULATED: configuration verification and PR list/create only",
                publication: "NOT EXERCISED: no tag, GitHub write, OIDC or RubyGems push" }
    @environment = ENV.keys.grep(/\ABUNDL/).to_h { |key| [key, nil] }.merge(
      "RUBYOPT" => nil, "RUBYLIB" => nil, "GEM_HOME" => @gem_home,
      "GEM_PATH" => [@gem_home, Gem.default_dir].join(File::PATH_SEPARATOR),
      "GIT_ALLOW_PROTOCOL" => "file", "GIT_TERMINAL_PROMPT" => "0"
    )
  end

  def run
    FileUtils.mkdir_p(File.dirname(@output))
    File.open("#{@output}.log", "w") do |log|
      @log = log
      before = source_inventory
      @report[:source_sha256] = Digest::SHA256.hexdigest(JSON.generate(before))
      head, status = Open3.capture2e(@environment, "git", "rev-parse", "HEAD", chdir: @source)
      @report[:source_commit] = status.success? ? head.strip : "No commit at capture time"
      Dir.mktmpdir("ruby-repo-recovery-") { |base| rehearse(base, before.keys) }
      ensure_condition(source_inventory == before, "Original canary changed during the rehearsal")
      @report[:source_unchanged] = true
      @report[:result] = "PASS"
    rescue StandardError => e
      @report[:result] = "FAIL"
      @report[:error] = "#{e.class}: #{e.message}"
      raise
    ensure
      @report[:completed_at] = Time.now.utc.iso8601
      File.write("#{@output}.json", "#{JSON.pretty_generate(@report)}\n")
    end
    puts "PASS: local recovery; evidence #{@output}.{json,log}"
    @report
  end

  private

  def source_inventory
    Dir.glob("**/*", File::FNM_DOTMATCH, base: @source).sort.filter_map do |relative|
      next if EXCLUDED.include?(relative.split("/").first)

      path = File.join(@source, relative)
      next unless File.file?(path)

      [relative, Digest::SHA256.file(path).hexdigest]
    end.to_h
  end

  def rehearse(base, files)
    @checkout = File.join(base, "checkout")
    FileUtils.mkdir_p(@checkout)
    files.each do |relative|
      target = File.join(@checkout, relative)
      FileUtils.mkdir_p(File.dirname(target))
      FileUtils.cp(File.join(@source, relative), target, preserve: true)
    end
    @bare = File.join(base, "origin.git")
    project = configure_project(base)
    @transport = CanaryRehearsalTransport.new(environment: @environment, checkout: @checkout, bare: @bare,
                                              repository: @repository, branch: @branch, log: @log)
    @github_calls = @transport.github_calls
    installed_toolkit
    initialize_git(project)
    initial = capture(%w[git rev-parse HEAD]).strip
    started = Time.now.utc
    date = started.to_date.iso8601
    first_attempt(project, Clock.new(started), initial)
    changes = [project.version_file, project.changelog].to_h { |path| [path, File.read(project.path(path))] }
    configuration = Configuration.new
    workflow(project, clock: Clock.new(started + 86_400), configuration: configuration).run
    confirm_recovery(project, initial, date, changes)
    @report[:second_policy_checks] = configuration.checks
  end

  def configure_project(base)
    settings = Psych.safe_load_file(File.join(@checkout, RubyRepoKit::Project::CONFIG_FILE))
    project = RubyRepoKit::Project.new(root: @checkout, settings: settings)
    version = RubyRepoKit::Release::Metadata.new(project: project).version
    parts = version.split(".").map(&:to_i)
    parts[-1] += 1
    @target = parts.join(".")
    @repository = project.repository
    @origin = "https://github.com/#{@repository}.git"
    @branch = "release/v#{@target}"
    notes = File.read(project.path(project.changelog))
    ensure_condition(notes.include?("## [Unreleased]\n"), "Canary is missing its Unreleased section")
    addition = "## [Unreleased]\n\n- Exercise temporary local release recovery.\n"
    File.write(project.path(project.changelog), notes.sub("## [Unreleased]\n", addition))
    wrapper = File.join(base, "check_once.rb")
    sentinel = File.join(base, "check_passed_once")
    File.write(wrapper, <<~RUBY)
      require "rbconfig"
      abort "Real canary checks failed" unless system(RbConfig.ruby, "-S", "bundle", "exec", "rake", "check")
      unless File.exist?(ARGV.fetch(0))
        File.write(ARGV.fetch(0), "The real checks passed before the injected failure.\\n")
        warn "INJECTED_REHEARSAL_FAILURE_AFTER_REAL_CHECKS"
        exit 73
      end
    RUBY
    @report[:target_version] = @target
    @report[:branch] = @branch
    settings = settings.merge("check_command" => [RbConfig.ruby, wrapper, sentinel])
    RubyRepoKit::Project.new(root: @checkout, settings: settings)
  end

  def installed_toolkit
    code = 'require "ruby_repo_kit"; s = Gem.loaded_specs.fetch("ruby-repo-kit"); ' \
           'puts [RubyRepoKit::VERSION, s.full_gem_path, s.cache_file].join("\n")'
    version, path, cache = capture([RbConfig.ruby, "-e", code]).lines.map(&:strip)
    @report[:installed_toolkit] = { version: version, path: path, artifact_sha256: Digest::SHA256.file(cache).hexdigest }
    sources = Dir["#{ROOT}/lib/ruby_repo_kit/release*.rb", "#{ROOT}/lib/ruby_repo_kit/release/*.rb"].sort
    @report[:orchestrator_source_sha256] = Digest::SHA256.hexdigest(sources.map { |file| File.read(file) }.join)
    @report[:orchestrator] = "Current toolkit source; real consumer checks use the installed gem above"
  end

  def initialize_git(project)
    capture(["git", "init", "--bare", "--initial-branch=main", @bare])
    capture(%w[git init --initial-branch=main])
    capture(["git", "remote", "add", "origin", @origin])
    capture(%w[git add .])
    capture(["git", "commit", "-S", "-m", "chore: prepare local recovery rehearsal"])
    @report[:initial_signature] = capture(%w[git verify-commit HEAD]).strip
    capture(%w[git push -u origin main])
    ensure_condition(capture(%w[git remote get-url origin]).strip == @origin, "Unexpected origin identity")
    @report[:transport] = "Real Git fetch/push/ls-remote redirected per command to a temporary local bare repository"
    @report[:original_version] = RubyRepoKit::Release::Metadata.new(project: project).version
  end

  def first_attempt(project, clock, initial)
    begin
      workflow(project, clock: clock, configuration: Configuration.new).run
      raise "The first release preparation unexpectedly succeeded"
    rescue RubyRepoKit::Error => e
      ensure_condition(e.message.include?("INJECTED_REHEARSAL_FAILURE_AFTER_REAL_CHECKS"), e.message)
      @report[:injected_failure_observed] = true
    end
    ensure_condition(capture(%w[git rev-parse HEAD]).strip == initial, "Failure created a commit")
    ensure_condition(capture(%w[git branch --show-current]).strip == @branch, "Failure lost the release branch")
    ensure_condition(@github_calls.none? { |argv| argv[2] == "create" }, "Failure opened a simulated PR")
    remote = capture(["git", "ls-remote", "--heads", "origin", "refs/heads/#{@branch}"])
    ensure_condition(remote.empty?, "Failure pushed the release branch")
    @report[:after_failure_status] = capture(%w[git status --short]).lines.map(&:chomp)
  end

  def workflow(project, clock:, configuration:)
    commands = RubyRepoKit::Commands.new(project: project, runner: @transport.method(:call), out: @log)
    RubyRepoKit::Release::Workflow.new(@target, project: project, commands: commands,
                                                configuration: configuration, clock: clock, out: @log)
  end

  def confirm_recovery(project, initial, date, changes)
    changes.each do |path, original|
      ensure_condition(File.read(project.path(path)) == original, "Retry changed already prepared #{path}")
    end
    text = File.read(project.path(project.changelog))
    ensure_condition(text.include?("## [#{@target}] - #{date}"), "Retry failed to preserve the original UTC date")
    ensure_condition(capture(%w[git status --porcelain]).empty?, "Retry left uncommitted files")
    count = capture(["git", "rev-list", "--count", "#{initial}..HEAD"]).strip
    ensure_condition(count == "1", "Retry duplicated commits")
    @report[:release_signature] = capture(%w[git verify-commit HEAD]).strip
    head = capture(%w[git rev-parse HEAD]).strip
    remote = capture(["git", "ls-remote", "--heads", "origin", "refs/heads/#{@branch}"])
    ensure_condition(remote.split.first == head, "Local bare remote differs from the signed release commit")
    ensure_condition(@github_calls.one? { |argv| argv[2] == "create" }, "Retry duplicated simulated PRs")
    ensure_condition(capture(%w[git tag --list]).empty?, "Rehearsal unexpectedly created a tag")
    @report.merge!(release_commit: head, initial_commit: initial, prepared_date: date,
                   retry_clock_date: (Date.iso8601(date) + 1).iso8601, preserved_date: true,
                   release_commit_count: 1, simulated_pr_count: 1, tags_created: 0, clean_after_retry: true,
                   github_calls: @github_calls)
  end

  def capture(argv)
    output, status = @transport.call(argv)
    raise "#{argv.shelljoin} failed: #{output}" unless status.success?

    output
  end

  def ensure_condition(condition, message)
    raise message unless condition
  end
end

if $PROGRAM_NAME == __FILE__
  root = CanaryRecoveryRehearsal::ROOT
  options = { source: File.expand_path("../ruby-repo-canary", root),
              gem_home: File.join(root, "tmp/installed-toolkit/gems"),
              output: File.join(root, "tmp/recovery-#{Time.now.utc.strftime('%Y%m%dT%H%M%SZ')}") }
  OptionParser.new do |parser|
    parser.on("--source PATH") { |value| options[:source] = value }
    parser.on("--gem-home PATH") { |value| options[:gem_home] = value }
    parser.on("--output PREFIX") { |value| options[:output] = value }
  end.parse!
  CanaryRecoveryRehearsal.new(**options).run
end
