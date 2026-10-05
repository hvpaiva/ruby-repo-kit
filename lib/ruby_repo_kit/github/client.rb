# frozen_string_literal: true

require "json"
require "open3"

module RubyRepoKit
  module GitHub
    # HTTP status, including an allowed 404, is independent of gh's exit status.
    # Pagination stays within this repository; credentials never enter argv or logs.
    class Client
      def initialize(project:, runner: nil)
        @project = project
        @runner = runner || method(:execute)
      end

      def request(path, method: "GET", body: nil, missing: false)
        validate_request(path, method, missing)
        result, following = fetch(path, method, body, missing)
        seen = [path]
        while following
          raise Error, "GitHub returned pagination for a non-GET request" unless method == "GET"
          raise Error, "GitHub pagination repeated a page" if seen.include?(following)

          seen << following
          page, following = fetch(following, "GET", nil, false)
          result = Response.new(result.status, combine_pages(result.body, page.body))
        end
        result
      end

      private

      def validate_request(path, method, missing)
        unless path.is_a?(String) && (path.empty? || path.start_with?("/")) &&
               !path.match?(/[\x00-\x20\\#]/) && !path.split(%r{[/?]}).include?("..")
          raise Error, "Expected a repository-relative GitHub API path"
        end
        raise Error, "Unsupported GitHub method" unless %w[GET POST PUT PATCH DELETE].include?(method)
        raise Error, "Only GET requests may allow missing resources" if missing && method != "GET"
      end

      def fetch(path, method, body, missing)
        argv = ["gh", "api", "--hostname", "github.com", "--include", "--method", method,
                "-H", "Accept: application/vnd.github+json", "repos/#{@project.repository}#{path}"]
        argv += ["--input", "-"] unless body.nil?
        output, status = @runner.call(argv, stdin_data: body.nil? ? nil : JSON.generate(body))
        header, content = output.to_s.split(/\r?\n\r?\n/, 2)
        code = header[%r{\AHTTP/\S+ (\d{3})\b}, 1].to_i
        raise Error, "GitHub #{method} #{path}: unreadable HTTP response" if code.zero?
        unless (status.success? && (200..299).cover?(code)) || (missing && code == 404)
          raise Error, "GitHub #{method} #{path}: HTTP #{code}"
        end

        parsed = content.to_s.strip.empty? ? {} : JSON.parse(content)
        [Response.new(code, parsed), next_path(header)]
      rescue JSON::ParserError
        raise Error, "GitHub #{method} #{path}: invalid JSON response"
      end

      def next_path(header)
        link = header.lines.find { |line| line.match?(/\Alink:/i) }
        url = link&.match(/<([^>]+)>;\s*rel="next"/)&.[](1)
        return unless url

        prefix = "https://api.github.com/repos/#{@project.repository}"
        raise Error, "GitHub pagination points outside the configured repository" unless url.start_with?("#{prefix}/")

        path = url.delete_prefix(prefix)
        validate_request(path, "GET", false)
        path
      end

      def combine_pages(first, following)
        return first + following if first.is_a?(Array) && following.is_a?(Array)
        if first.is_a?(Hash) && following.is_a?(Hash) &&
           first["branch_policies"].is_a?(Array) && following["branch_policies"].is_a?(Array)
          return first.merge("branch_policies" => first["branch_policies"] + following["branch_policies"])
        end

        raise Error, "GitHub returned an unsupported paginated response"
      end

      def execute(argv, stdin_data: nil)
        output, _error, status = Open3.capture3(*argv, stdin_data: stdin_data, chdir: @project.root)
        [output, status]
      rescue Errno::ENOENT
        raise Error, "GitHub CLI (gh) is not installed or the project directory is unavailable"
      end
    end
  end
end
