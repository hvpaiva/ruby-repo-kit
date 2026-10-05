# frozen_string_literal: true

if ENV["COVERAGE"]
  require "simplecov"
  SimpleCov.start do
    merging false
    enable_coverage :branch
    cover "lib/**/*.rb"
    minimum_coverage line: 90, branch: 80
    # Bundler reads this via the gemspec before the coverage process starts.
    skip "lib/ruby_repo_kit/version.rb"
  end
end

require "minitest/autorun"
require "tmpdir"
require "fileutils"
require "stringio"
require "ruby_repo_kit"

module ProjectFixtures
  def in_project(settings = {})
    Dir.mktmpdir("ruby repo kit ") do |root|
      data = { "schema" => 1, "name" => "sample-cli", "repository" => "example/sample-cli" }.merge(settings)
      File.write(File.join(root, RubyRepoKit::Project::CONFIG_FILE), Psych.dump(data))
      yield RubyRepoKit::Project.load(root: root)
    end
  end
end

module Minitest
  class Test
    include ProjectFixtures
  end
end
