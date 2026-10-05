# frozen_string_literal: true

require "English"
require "json"
require "open3"

module RubyRepoKit
  # All commands run in the consumer checkout and are passed as argv, never shell text.
  class Commands
    def initialize(project:, runner: nil, out: $stdout)
      @project = project
      @runner = runner || method(:execute)
      @out = out
    end

    def call(argv, stream: false)
      command = argv.dup
      command += ["--repo", @project.repository] if command.first == "gh" && %w[pr run release].include?(command[1])
      @out.puts "==> #{command.join(' ')}"
      output, status = @runner.call(command, stream: stream)
      raise Error, "#{command.join(' ')} failed.\n#{output}" unless status.success?

      output
    end

    def json(argv)
      JSON.parse(call(argv))
    rescue JSON::ParserError => e
      raise Error, "Command returned invalid JSON: #{e.message}"
    end

    private

    def execute(argv, stream: false)
      return Open3.capture2e(*argv, chdir: @project.root) unless stream

      system(*argv, chdir: @project.root)
      ["", $CHILD_STATUS]
    rescue Errno::ENOENT => e
      raise Error, "Required command is unavailable: #{e.message}"
    end
  end
end
