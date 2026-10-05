# Implementation plan

## Outcome

A narrow Ruby CLI scaffolder and versioned development tooling, initially one gem
and repository. Fix shared behavior once; consumers adopt it through reviewed
dependency updates. Preserve project-owned code and intentional differences.

## P0 — Durable preparation

- Record constraints, original investigation, decisions, open questions and evidence.
- Keep existing repos read-only while Rich-RI evolves in another session.
- Define independently observable acceptance gates; distinguish local from hosted.

## P1 — Shared toolkit

- Validated project configuration, namespaced errors and argv command execution.
- Release metadata and changelog validation; pure plan before writes.
- Recoverable release workflow extracted from Rich-RI and improved with Slipway
  contracts; exact merge SHA, immutable tags, partial-publication diagnosis.
- Artifact build, checksum/metadata verification and isolated installed-gem smoke.
- GitHub policy check/plan/apply, reading all relevant settings before mutations.
- Thin CLI/Rake adapters and a shared RuboCop preset. Minimal runtime dependencies.
- Unit and integration tests for real operational risks; clean archive packaging.

## P2 — Generator and third CLI

- One ERB template for Ruby CLIs; validate names and destination, no overwrite.
- Generate runtime, executable, version, gemspec allowlist, tests, Gemfile,
  configuration, Rake adapters, docs, contribution/security, CI and release.
- Generated tooling is a development dependency, never consumer runtime code.
- CLI must run help/version, successful behavior, invalid input and piped output.
- Build/install BOTH toolkit and canary from artifacts, not only path dependencies.
- Test a toolkit version update with no copied implementation or application edits.
- Exercise failed release preparation/resume and reject bad metadata/artifacts.

## P3 — Hosted canary acceptance

- Set final names before creating public repositories or publishing immutable gems.
- Review workflow, rulesets, environment and publisher configuration concretely.
- Establish GitHub CI on supported Ruby/OS cells and lint/security/generated checks.
- Rehearse release without publication; record exact commits and CI run URLs.
- Prove actual OIDC publication using the canary, installed artifact behavior and
  digest identity; then prove a subsequent toolkit update/release and recovery.
- Never describe a dry-run as proof of RubyGems authentication.

## P4 — Existing projects, only after canary gates

- Refresh Rich-RI and Slipway baselines (HEAD, CI, gemspec, artifacts, help/version,
  tests, release behavior, repository protections); incorporate concurrent fixes.
- Work in isolated branches/worktrees, one consumer at a time.
- Replace implementation copies with dependency and thin adapters. Preserve names,
  runtime dependencies, contents/behavior, version and intentional policy differences.
- Compare package manifests and normalized payloads before/after; test installed
  behavior, smallest supported Ruby and platform/dependency matrices.
- Preserve trusted publisher workflow identity unless explicitly migrating it.
- Produce rollbackable migration PRs with evidence and reversal steps.
- Publish existing products only as required by their release policy and a concrete
  validated version; never burn an existing version merely to test infrastructure.

## P5 — Completion

- Both consumers use shared maintenance without application/runtime coupling.
- Generator produces the accepted canary configuration.
- Release/update and recovery runbooks, compatibility policy and maintenance docs.
- Evidence captures what passed, skipped, remains conditional and cannot be claimed.

## Acceptance evidence format

For each gate record: timestamp; toolkit version/commit; consumer commit; command
or hosted run URL; platform/Ruby; result/skips; artifact hashes; unresolved limits.
Keep raw ephemeral logs under ignored `tmp/`; keep concise durable evidence in docs.
