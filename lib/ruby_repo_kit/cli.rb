# frozen_string_literal: true

require "optparse"
require_relative "../ruby_repo_kit"

module RubyRepoKit
  class CLI
    HELP = <<~TEXT
      Usage: ruby-repo-kit COMMAND [OPTIONS]

      new NAME       Generate a Ruby CLI in a new directory
      doctor         Check this project's local maintenance contract
      release X.Y.Z  Prepare or resume a release (--dry-run, --push, --branch)
      github plan    Show repository-policy changes without applying them
      github verify  Verify repository policy without writes
      github apply   Explicitly apply the repository's policy

      --help         Show this help
      --version      Show the toolkit version

      Project commands read .ruby-repo.yml in the current directory.
    TEXT

    def self.run(argv, root: Dir.pwd, out: $stdout, err: $stderr)
      new(root: root, out: out, err: err).run(argv.dup)
    end

    def initialize(root:, out:, err:)
      @root = root
      @out = out
      @err = err
    end

    def run(argv)
      command = argv.shift
      case command
      when nil, "--help", "-h" then @out.puts HELP
      when "--version" then @out.puts "ruby-repo-kit #{VERSION}"
      when "new" then generate(argv)
      when "doctor" then doctor(argv)
      when "release" then release(argv)
      when "github" then github(argv)
      else raise OptionParser::InvalidArgument, "unknown command #{command.inspect}"
      end
      0
    rescue OptionParser::ParseError => e
      @err.puts "ruby-repo-kit: #{e.message}"
      2
    rescue Error => e
      @err.puts "ruby-repo-kit: #{e.message}"
      1
    rescue Errno::EPIPE
      0
    end

    private

    def project
      @project ||= Project.load(root: @root)
    end

    def generate(argv)
      require_relative "scaffold"
      settings = {}
      parser = OptionParser.new do |options|
        options.on("--repository OWNER/NAME") { |value| settings[:repository] = value }
        options.on("--directory PATH") { |value| settings[:destination] = File.expand_path(value, @root) }
        options.on("--author NAME") { |value| settings[:author] = value }
        options.on("--email ADDRESS") { |value| settings[:email] = value }
      end
      name = one_argument(parser.parse(argv), "new requires one gem name")
      %i[repository author email].each do |key|
        raise OptionParser::MissingArgument, "--#{key}" unless settings.key?(key)
      end
      settings[:destination] ||= File.join(@root, name)
      destination = Scaffold.new(name: name, **settings).generate
      @out.puts "Created #{destination}. Run bin/setup there to install development dependencies."
    end

    def doctor(argv)
      require_relative "checks"
      raise OptionParser::InvalidArgument, "doctor takes no arguments" unless argv.empty?

      Checks.new(project: project).run
      @out.puts "Local maintenance contract verified for #{project.name}."
    end

    def release(argv)
      require_relative "release"
      settings = { dry_run: false, push: false, branch: "main" }
      parser = OptionParser.new do |options|
        options.on("--dry-run") { settings[:dry_run] = true }
        options.on("--push") { settings[:push] = true }
        options.on("--branch NAME") { |value| settings[:branch] = value }
      end
      version = one_argument(parser.parse(argv), "release requires one X.Y.Z version")
      if settings[:dry_run] && settings[:push]
        raise OptionParser::InvalidArgument, "--dry-run and --push are mutually exclusive"
      end

      Release::Workflow.new(version, project: project, out: @out, **settings).run
    end

    def github(argv)
      require_relative "github"
      action = one_argument(argv, "github requires plan, verify or apply")
      unless %w[plan verify apply].include?(action)
        raise OptionParser::InvalidArgument, "unknown github action #{action.inspect}"
      end

      configuration = GitHub::Configuration.new(project: project, out: @out)
      case action
      when "plan"
        pending = configuration.plan
        pending.each { |change| @out.puts "#{change.verb} #{change.path}: #{change.description}" }
        @out.puts "No repository-policy changes required." if pending.empty?
      when "verify" then configuration.verify!
      when "apply" then configuration.apply!
      end
    end

    def one_argument(argv, message)
      raise OptionParser::InvalidArgument, message unless argv.length == 1

      argv.first
    end
  end
end
