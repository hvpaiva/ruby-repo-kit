# frozen_string_literal: true

require "rake"
require_relative "../ruby_repo_kit"
require_relative "package"

module RubyRepoKit
  # Explicit installation avoids task registration merely by requiring the gem.
  class RakeTasks
    extend Rake::DSL

    def self.install(project:)
      if Rake::Task.task_defined?("release")
        raise Error,
              "A release task already exists; remove competing release tooling before installing RubyRepoKit tasks"
      end

      desc "Validate local repository maintenance contracts"
      task "repo:check" do
        require_relative "checks"
        Checks.new(project: project).run
      end

      desc "Build the distributable gem"
      task :build do
        puts Package.new(project: project).build
      end

      desc "Install and smoke-test the built gem outside the checkout and bundle"
      task "package:check", [:artifact] do |_task, args|
        Package.new(project: project).check(artifact: args[:artifact])
      end

      desc "Check commit and pull-request message conventions"
      task "lint:commits", [:range] do |_task, args|
        require_relative "checks/commits"
        Commits.new(project: project).check(range: args[:range] || ENV.fetch("COMMIT_RANGE", nil),
                                            title: ENV.fetch("PR_TITLE", nil), body: ENV.fetch("PR_BODY", nil))
      end

      desc "Audit locked dependencies against the latest advisory database"
      task :audit do
        sh "bundle", "exec", "bundler-audit", "check", "--update"
      end

      install_release(project: project)
      install_github(project)
    end

    def self.install_release(project:)
      require_relative "release"

      desc "Verify the release tag, version and changelog"
      task "release:verify" do
        metadata = Release::Metadata.new(project: project)
        tag = ENV["GITHUB_REF_TYPE"] == "tag" ? ENV.fetch("GITHUB_REF_NAME", nil) : ENV.fetch("TAG", nil)
        puts "Verified #{project.name} #{metadata.verify(tag: tag)}"
      end

      desc "Verify release commit ancestry"
      task "release:verify_ref" do
        Release::Metadata.new(project: project).verify_ref(sha: ENV.fetch("GITHUB_SHA"))
      end

      desc "Build and record the release artifact checksum and notes"
      task "release:artifact" => :build do
        puts Release::Artifact.new(project: project).record
      end

      desc "Verify existing release bytes without rebuilding"
      task "release:verify_artifact" do
        puts Release::Artifact.new(project: project).verify
      end

      desc "Publish verified artifact in the configured GitHub release workflow only"
      task :release do
        Release::Publisher.new(project: project).publish
      end
    end

    def self.install_github(project)
      %w[plan verify apply].each do |operation|
        desc "#{operation.capitalize} GitHub repository policy"
        task "github:#{operation}" do
          require_relative "github"
          configuration = GitHub::Configuration.new(project: project)
          case operation
          when "plan" then configuration.plan.each do |change|
            puts "#{change.verb} #{change.path}: #{change.description}"
          end
          when "verify" then configuration.verify!
          when "apply" then configuration.apply!
          end
        end
      end
    end
  end
end
