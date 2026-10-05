# frozen_string_literal: true

require "rake/testtask"
require "rubocop/rake_task"
require "fileutils"
require "ruby_repo_kit"
require "ruby_repo_kit/rake_tasks"

RubyRepoKit::RakeTasks.install(project: RubyRepoKit::Project.load(root: __dir__))

Rake::TestTask.new(:test) do |task|
  task.libs << "lib" << "test"
  task.pattern = "test/**/*_test.rb"
  task.warning = true
end

RuboCop::RakeTask.new(:rubocop)

namespace :test do
  desc "Run tests with line and branch coverage"
  task :cov do
    FileUtils.rm_f("coverage/.resultset.json")
    sh({ "COVERAGE" => "1" }, "bundle", "exec", "rake", "test")
  end
end

desc "Regenerate project-owned artifacts (none are configured yet)"
task :generate

namespace :generate do
  desc "Check generated artifacts (none are configured yet)"
  task :check
end

desc "Run local lint, tests, repository and installed-package checks"
task check: %w[rubocop test:cov repo:check generate:check package:check]

task default: :check
