# Architectural decisions

## Accepted

1. One gem/repository first, internal namespaces for release, checks, GitHub and
   generation. CLI/Rake are adapters. Separate packages only for proven divergence.
2. Third CLI is a mandatory pre-migration gate (user instruction 2026-10-04).
3. Templates ERB owned here, following Bundler conventions without wrapping and
   replacing most of bundle gem's output. One CLI profile first.
4. Consumers own generated application/docs/tests. Operational code stays here.
5. Share RuboCop via inherit_gem; use explicit migrations for local integration.
   Do not build a generic template merge engine. Consider Copier only if needed.
6. Gemfile + lockfile pin tooling; consumer gemspec must not depend on toolkit.
7. Keep release data/configuration separate from the engine. Use argv commands,
   injected runners/clocks, exact commit identity and conservative retry behavior.
8. Keep conventional rake entry points. No implicit competing Bundler release tasks.
9. Distinguish policy from mechanism: coverage thresholds, signing, merge methods,
   latest-only support, optional man/completion remain explicit choices.
10. Require artifact identity from build/test through publish. Hosted OIDC is a
    separate proof from local/fake-runner tests. No production canary on old gems.
11. User accepted `ruby-repo-kit` and `ruby-repo-canary` and the dedicated minimal
    canary scope in normal chat on 2026-10-04. Names are no longer provisional.

## Pending

- GitHub repo + RubyGems gem API endpoints returned 404 for both accepted names.
  Names are not reserved; recheck immediately before publication.
- Hosted setup/publication details, after concrete local artifacts are reviewable.

## Investigation references

- Original repos: hvpaiva/slipway at c8e9bde; hvpaiva/rich-ri at 379ea1d.
- https://guides.rubygems.org/command-reference/bundle-gem/
- https://guides.rubygems.org/gemfile-and-gemspec/
- https://guides.rubygems.org/trusted-publishing/
- https://docs.rubocop.org/rubocop/latest/configuration/inheritance.html
- https://docs.github.com/en/actions/concepts/workflows-and-actions/reusing-workflow-configurations
- https://copier.readthedocs.io/en/stable/updating/

Rich-RI's recovery/artifact pipeline is the starting implementation. Slipway's
whole-history changelog and documented quality contracts complement it. Neither
repository is copied wholesale or treated as a universal Ruby standard.
