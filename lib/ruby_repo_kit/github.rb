# frozen_string_literal: true

module RubyRepoKit
  module GitHub
    class Error < RubyRepoKit::Error; end

    Response = Data.define(:status, :body)
    Change = Data.define(:description, :verb, :path, :body)
  end
end

require_relative "github/client"
require_relative "github/policy"
require_relative "github/configuration"
