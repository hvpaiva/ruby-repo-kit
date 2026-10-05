# frozen_string_literal: true

require "rake/testtask"
require "rubocop/rake_task"
require_relative "lib/ruby_repo_kit/rake_tasks"

RubyRepoKit::RakeTasks.install(project: RubyRepoKit::Project.load(root: __dir__))
RuboCop::RakeTask.new(:rubocop)

Rake::TestTask.new(:test) do |task|
  task.libs << "lib" << "test"
  task.pattern = "test/**/*_test.rb"
  task.warning = true
end

namespace :test do
  desc "Run toolkit tests with line and branch coverage"
  task :cov do
    sh({ "COVERAGE" => "1" }, "bundle", "exec", "rake", "test")
  end
end

desc "No repository artifacts need generation; templates are tested by the suite"
task :generate

desc "Run local lint, tests, repository and installed-package checks"
task check: %w[rubocop test:cov repo:check package:check]

desc "Run toolkit tests and Ruby lint"
task default: %w[test rubocop]
