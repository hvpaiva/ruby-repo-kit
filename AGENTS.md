# Ruby repository toolkit implementation

Read `docs/STATUS.md`, `docs/PLAN.md`, and `docs/DECISIONS.md` before continuing.
These files are the durable handoff across sessions and context compaction.

## User constraints

- Build the toolkit and generator, then validate a THIRD Ruby CLI before changing
  Slipway or Rich-RI infrastructure. Their published behavior must be preserved.
- Slipway and Rich-RI are READ-ONLY until the canary acceptance gate is satisfied.
- Another agent is fixing Rich-RI and CI concurrently. Re-read its current HEAD,
  worktree, and relevant files before adoption; never overwrite concurrent work.
- User accepted names `ruby-repo-kit` and `ruby-repo-canary`, and a dedicated
  minimal canary. Verify availability before publishing; local gates come first.
- User is connected through SSH on a phone and cannot open queued question UI.
  Keep pending choices visible in normal text; do not use queued question tools.
- Maintain accurate evidence. Unit tests, a local installation, GitHub CI and a
  real RubyGems OIDC publication are different gates, not interchangeable proof.
- Keep project-owned code out of automatic template updates. No generic framework.

## Implementation

- One normal Ruby gem, namespace `RubyRepoKit`, executable `ruby-repo-kit`.
- Shared release/check logic with thin CLI and Rake adapters. Consumer development
  dependency only; never add this toolkit as a consumer runtime dependency.
- Ruby >= 3.4. Keep external commands as argv arrays. Validate paths/identifiers.
- No credentials in files/logs. Release actions must distinguish planning,
  preparation, PR creation, tagging and publishing, and handle partial failures.
- Add meaningful tests for the operational behavior and generated consumer.
- Keep docs/STATUS.md current at milestones, with next commands and unresolved gates.
- Record changes as local commits where practical. Do not bypass signing policy.

## Source repositories

- `/home/hvpaiva/dev/personal/slipway` (audit baseline c8e9bde).
- `/home/hvpaiva/dev/personal/rich-ri` (audit baseline 379ea1d; now evolving).
- `/home/hvpaiva/dev/personal/ruby-repo-canary` (planned disposable consumer).

Do not infer gate completion from an old chat summary; consult the evidence files.
