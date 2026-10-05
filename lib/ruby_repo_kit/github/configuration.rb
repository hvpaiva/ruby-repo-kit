# frozen_string_literal: true

module RubyRepoKit
  module GitHub
    class Configuration
      def initialize(project:, client: nil, out: $stdout)
        @project = project
        @client = client || Client.new(project: project)
        @policy = Policy.new(project: project)
        @out = out
      end

      # A fresh GET-only plan on every invocation; no cached remote state is applied.
      def plan
        @changes = []
        repository_settings
        rulesets
        environment
        security_features
        label
        @changes.freeze
      rescue KeyError, TypeError, NoMethodError => e
        raise Error, "GitHub returned an incomplete configuration (#{e.class})"
      end

      def verify!
        pending = plan
        unless pending.empty?
          descriptions = pending.map { |change| "- #{change.description}" }.join("\n")
          raise Error, "Repository configuration needs attention:\n#{descriptions}\nRun github:plan, then github:apply."
        end

        @out.puts "GitHub repository policy verified for #{@project.repository}."
        true
      end

      def apply!
        pending = plan # Every read must succeed before the first write.
        pending.each do |change|
          @client.request(change.path, method: change.verb, body: change.body)
          @out.puts "Configured #{change.description}."
        end
        verify!
      end
      alias setup apply!

      private

      def change(description, verb, path, body = nil)
        @changes << Change.new(description, verb, path, body)
      end

      def get(path, **)
        @client.request(path, **)
      end

      def object(value)
        raise Error, "GitHub returned an object of an unexpected type" unless value.is_a?(Hash)

        value
      end

      def list(value)
        raise Error, "GitHub returned a list of an unexpected type" unless value.is_a?(Array) && value.all?(Hash)

        value
      end

      # Order and extra server metadata are irrelevant; duplicates still count.
      def matches?(actual, expected)
        case expected
        when Hash then actual.is_a?(Hash) && expected.all? { |key, value| matches?(actual[key], value) }
        when Array
          return false unless actual.is_a?(Array) && actual.length == expected.length

          remaining = actual.dup
          expected.all? do |value|
            index = remaining.index { |item| matches?(item, value) }
            index && remaining.delete_at(index)
          end
        else actual == expected
        end
      end

      def repository_settings
        current = object(get("").body)
        raise Error, "Repository administrator access is required" unless current.dig("permissions", "admin") == true

        change("merge settings", "PATCH", "", Policy::MERGE_SETTINGS) unless matches?(current, Policy::MERGE_SETTINGS)
        scanning = %w[secret_scanning secret_scanning_push_protection].to_h { |key| [key, { "status" => "enabled" }] }
        return if matches?(current["security_and_analysis"], scanning)

        change("secret scanning and push protection", "PATCH", "", { "security_and_analysis" => scanning })
      end

      def rulesets
        existing = list(get("/rulesets?includes_parents=false").body)
        [@policy.main_ruleset, @policy.tags_ruleset].each do |desired|
          found = existing.select { |ruleset| ruleset["name"] == desired["name"] }
          raise Error, "Duplicate #{desired['name']} rulesets; reconcile them in GitHub first" if found.length > 1

          if found.empty?
            change("#{desired['name']} ruleset", "POST", "/rulesets", desired)
            next
          end
          path = "/rulesets/#{identifier(found.first.fetch('id'))}"
          current = object(get(path).body)
          # Rules outside this policy remain project-owned when a managed rule changes.
          managed = desired.fetch("rules").map { |rule| rule.fetch("type") }
          extra = list(current.fetch("rules")).reject { |rule| managed.include?(rule.fetch("type")) }
          replacement = desired.merge("rules" => desired.fetch("rules") + extra)
          change("#{desired['name']} ruleset", "PUT", path, replacement) unless matches?(current, replacement)
        end
      end

      def environment
        path = "/environments/#{@project.environment}"
        current = get(path, missing: true)
        settings = object(current.body)
        unless matches?(settings["deployment_branch_policy"], Policy::ENVIRONMENT)
          body = preserved_protection(settings).merge("deployment_branch_policy" => Policy::ENVIRONMENT)
          change("#{@project.environment} environment", "PUT", path, body)
        end
        policies = current.status == 404 ? [] : deployment_policies(path)
        matching, extra = policies.partition { |policy| matches?(policy, Policy::TAG) }
        # A duplicated matching policy is unnecessary and otherwise conceals drift.
        (extra + matching.drop(1)).each do |policy|
          change("remove extra #{@project.environment} deployment policy #{policy.fetch('name')}", "DELETE",
                 "#{path}/deployment-branch-policies/#{identifier(policy.fetch('id'))}")
        end
        return unless matching.empty?

        change("#{@project.environment} deployments restricted to v* tags", "POST",
               "#{path}/deployment-branch-policies", Policy::TAG)
      end

      def deployment_policies(path)
        list(object(get("#{path}/deployment-branch-policies").body).fetch("branch_policies"))
      end

      def preserved_protection(settings)
        list(settings.fetch("protection_rules", [])).each_with_object({}) do |rule, body|
          case rule.fetch("type")
          when "wait_timer" then body["wait_timer"] = rule.fetch("wait_timer")
          when "required_reviewers"
            body["prevent_self_review"] = rule.fetch("prevent_self_review")
            body["reviewers"] = list(rule.fetch("reviewers")).map do |reviewer|
              { "type" => reviewer.fetch("type"), "id" => object(reviewer.fetch("reviewer")).fetch("id") }
            end
          when "branch_policy" then next
          else raise Error,
                     "Unknown environment protection #{rule['type'].inspect}; update its deployment policy manually"
          end
        end
      end

      def security_features
        alerts = get("/vulnerability-alerts", missing: true)
        change("vulnerability alerts", "PUT", "/vulnerability-alerts") if alerts.status == 404
        %w[automated-security-fixes private-vulnerability-reporting immutable-releases].each do |feature|
          enabled = object(get("/#{feature}").body).fetch("enabled")
          raise Error, "GitHub returned an unknown #{feature} state" unless [true, false].include?(enabled)

          change(feature.tr("-", " "), "PUT", "/#{feature}") unless enabled
        end
      end

      def label
        response = get("/labels/skip-changelog", missing: true)
        change("skip-changelog label", "POST", "/labels", Policy::LABEL) if response.status == 404
      end

      def identifier(value)
        raise Error, "GitHub returned an invalid resource identifier" unless value.is_a?(Integer) && value.positive?

        value
      end
    end
  end
end
