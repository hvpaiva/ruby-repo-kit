# frozen_string_literal: true

require_relative "lib/ruby_repo_kit/version"

Gem::Specification.new do |spec|
  spec.name = "ruby-repo-kit"
  spec.version = RubyRepoKit::VERSION
  spec.authors = ["Highlander Paiva"]
  spec.email = ["contact@hvpaiva.dev"]
  spec.summary = "Versioned maintenance tools and scaffolding for Ruby CLI repositories"
  spec.description = "Shared release, repository checks and focused Ruby CLI generation, " \
                     "installed as a development dependency."
  spec.homepage = "https://github.com/hvpaiva/ruby-repo-kit"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.4"
  spec.metadata = {
    "source_code_uri" => spec.homepage,
    "changelog_uri" => "#{spec.homepage}/blob/main/CHANGELOG.md",
    "rubygems_mfa_required" => "true",
    "allowed_push_host" => "https://rubygems.org"
  }
  spec.files = Dir.chdir(__dir__) do
    Dir.glob("lib/**/*.rb") + Dir.glob("templates/**/*", File::FNM_DOTMATCH).select { |file| File.file?(file) } +
      Dir.glob("config/**/*").select { |file| File.file?(file) } +
      %w[exe/ruby-repo-kit README.md CHANGELOG.md LICENSE.txt]
  end
  spec.bindir = "exe"
  spec.executables = ["ruby-repo-kit"]
  spec.require_paths = ["lib"]
  spec.add_dependency "bundler", ">= 2.6", "< 5"
  spec.add_dependency "date", ">= 3.4", "< 4"
  spec.add_dependency "erb", ">= 4.0", "< 7"
  spec.add_dependency "json", ">= 2.9", "< 4"
  spec.add_dependency "open3", "~> 0.2"
  spec.add_dependency "optparse", ">= 0.6", "< 1"
  spec.add_dependency "psych", ">= 5.2", "< 6"
  spec.add_dependency "rake", "~> 13.4"
end
