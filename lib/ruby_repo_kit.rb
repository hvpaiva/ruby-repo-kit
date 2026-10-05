# frozen_string_literal: true

require_relative "ruby_repo_kit/version"

module RubyRepoKit
  class Error < StandardError; end
end

require_relative "ruby_repo_kit/project"
require_relative "ruby_repo_kit/commands"
