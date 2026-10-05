# frozen_string_literal: true

module RubyRepoKit
  module GitHub
    # The initial personal-project policy is explicit, separate from reconciliation.
    class Policy
      ACTIONS_APP_ID = 15_368
      MERGE_SETTINGS = {
        "allow_merge_commit" => true, "allow_squash_merge" => false, "allow_rebase_merge" => false,
        "merge_commit_title" => "PR_TITLE", "merge_commit_message" => "BLANK", "delete_branch_on_merge" => true
      }.freeze
      ENVIRONMENT = { "protected_branches" => false, "custom_branch_policies" => true }.freeze
      TAG = { "name" => "v*", "type" => "tag" }.freeze
      LABEL = { "name" => "skip-changelog", "color" => "ededed",
                "description" => "No CHANGELOG.md entry: no user-visible change" }.freeze

      def initialize(project:)
        @project = project
      end

      def main_ruleset
        {
          "name" => "main", "target" => "branch", "enforcement" => "active", "bypass_actors" => [],
          "conditions" => { "ref_name" => { "include" => protected_branches, "exclude" => [] } },
          "rules" => [
            { "type" => "pull_request", "parameters" => {
              "required_approving_review_count" => 0, "dismiss_stale_reviews_on_push" => false,
              "require_code_owner_review" => false, "require_last_push_approval" => false,
              "required_review_thread_resolution" => @project.require_review_thread_resolution,
              "allowed_merge_methods" => ["merge"]
            } },
            { "type" => "required_status_checks", "parameters" => {
              "strict_required_status_checks_policy" => true, "do_not_enforce_on_create" => false,
              "required_status_checks" => @project.required_checks.map do |name|
                { "context" => name, "integration_id" => ACTIONS_APP_ID }
              end
            } },
            { "type" => "required_signatures" }, { "type" => "non_fast_forward" }, { "type" => "deletion" }
          ]
        }
      end

      def tags_ruleset
        {
          "name" => "tags", "target" => "tag", "enforcement" => "active",
          "bypass_actors" => [{ "actor_id" => 5, "actor_type" => "RepositoryRole", "bypass_mode" => "always" }],
          "conditions" => { "ref_name" => { "include" => ["refs/tags/v*"], "exclude" => [] } },
          "rules" => %w[creation update deletion].map { |type| { "type" => type } }
        }
      end

      private

      def protected_branches
        ["refs/heads/main"].tap do |branches|
          branches << "refs/heads/hotfix/*" if @project.protect_hotfix_branches
        end
      end
    end
  end
end
