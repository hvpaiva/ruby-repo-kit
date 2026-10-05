# frozen_string_literal: true

# Adapted from Slipway and Rich-RI (MIT, Copyright 2026 Highlander Paiva).
require_relative "../ruby_repo_kit"

module RubyRepoKit
  module Release
    module SystemClock
      def self.now = Time.now
      def self.sleep(seconds) = Kernel.sleep(seconds)
    end
  end
end

require_relative "release/metadata"
require_relative "release/artifact"
require_relative "release/publication"
require_relative "release/preparation"
require_relative "release/workflow"
require_relative "release/publisher"
