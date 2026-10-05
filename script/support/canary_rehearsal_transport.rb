# frozen_string_literal: true

require "open3"
require "shellwords"

# All GitHub calls are strict fakes; Git uses real local storage and signatures.
class CanaryRehearsalTransport
  attr_reader :github_calls

  def initialize(environment:, checkout:, bare:, repository:, branch:, log:)
    @environment = environment
    @checkout = checkout
    @bare = bare
    @repository = repository
    @branch = branch
    @log = log
    @origin = "https://github.com/#{@repository}.git"
    @github_calls = []
  end

  def call(argv, stream: false)
    return simulated_github(argv) if argv.first == "gh"

    actual = argv
    if argv.first == "git" && %w[fetch push ls-remote].include?(argv[1])
      actual = ["git", "-c", "url.file://#{@bare}.insteadOf=#{@origin}", *argv.drop(1)]
    end
    @log.puts "REAL#{' STREAM-CAPTURED' if stream}: #{actual.shelljoin}"
    output, status = Open3.capture2e(@environment, *actual, chdir: @checkout)
    @log.puts output.gsub("\0", "\\0"), "EXIT: #{status.exitstatus}"
    @log.flush
    [output, status]
  end

  private

  def simulated_github(argv)
    @github_calls << argv
    @log.puts "SIMULATED GITHUB: #{argv.shelljoin}"
    suffix = ["--repo", @repository]
    list = ["gh", "pr", "list", "--state", "all", "--base", "main", "--head", @branch,
            "--json", "url,state,headRefOid,mergeCommit,isCrossRepository", *suffix]
    create = ["gh", "pr", "create", "--base", "main", "--head", @branch,
              "--title", "chore: release #{@branch.delete_prefix('release/')}", "--body-file"]
    output = if argv == list
               "[]"
             elsif argv.first(create.length) == create && argv.last(2) == suffix &&
                   argv.length == create.length + 3 && File.file?(argv[create.length])
               "https://example.invalid/local-rehearsal/pull/1\n"
             else
               raise "Unexpected GitHub command (never executed): #{argv.inspect}"
             end
    [output, Struct.new(:success?).new(true)]
  end
end
