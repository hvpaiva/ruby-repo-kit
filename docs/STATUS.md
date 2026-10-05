# Status and session handoff

Updated: 2026-10-04 (America/Sao_Paulo).

## Current phase

P4: G1–G4 passed; recapture existing product baselines and prepare isolated adoption PRs.
The existing product repositories have NOT been migrated.

## Immediate continuation

The user confirmed both RubyGems pending publishers. Toolkit release PR #3 merged
after all seven checks passed. Signed tag `v0.1.0` points to merge commit
`b524e95b1f3fd041d5123768dd2a655c3805cb10`; tagged release run
https://github.com/hvpaiva/ruby-repo-kit/actions/runs/37252275299 completed actual
trusted publication and GitHub Release creation. Independent downloads from
RubyGems, the GitHub Release and Actions have identical SHA256; the published gem
passed isolated installation and installed-generator smoke checks. See
[publication evidence](evidence/PUBLICATION.md).

The canary's corrected release candidate passed all seven PR checks and rehearsal
37252940888 at exact head `8001c2ce30930f19fbd7d49d598f04ea1abd2081`, closing G3.
Its signed v0.1.0 tag points to merge
`2604a94dd4d28da7383d0a781997ac7c64524c17`; actual release run 37253081855 passed.
RubyGems, GitHub Release and Actions bytes match; the downloaded published gem
passed six isolated CLI behavior checks with no toolkit runtime dependency.
Repeating the real release command recognized the same completed hosted run with
no new tag/publication or worktree changes. This proves completed-release
idempotence, not recovery from an injected hosted publication failure. See
[canary evidence](evidence/CANARY.md).

Toolkit 0.1.1 was published from signed tag `v0.1.1`, pointing to merge commit
`b02066722fe49b68024c45a4491d4a3cf0e3b6e6`, in run 37254345206. Canary PR #5 adopted that published development dependency
without application changes; all seven checks passed. Its release PR #6 passed
all seven checks and merged as `ca474f4f53719b5a823766e5a43cf7c879fd19a8`.

Canary v0.1.1 run 37254971421 deliberately failed its terminal GitHub Release job
after actual RubyGems publication succeeded. The engine diagnosed partial
publication and prescribed a retry of that job alone. Attempt 2 completed the
immutable GitHub Release; publisher timestamps/logs, registry creation timestamp,
gem bytes and signed tag prove that publication was not repeated. Independent
three-source digest, exact-tag attestation and isolated installed CLI checks
passed. See [the actual cycle](evidence/CYCLE_0_1_1.md) and the separate
[published-package local upgrade/recovery](evidence/PUBLISHED_UPGRADE_RECOVERY.md).

The final release-command replay returned exit 0 and recognized the same successful
run without mutation commands. G4 is closed. Review G1–G4 and recapture each
product's current baseline before isolated migration PRs.
No new account setup is required from the user. Do not recreate published versions.

## User authorization and constraints

User authorized the full implementation following the investigation, but changed
the sequence: validate a third CLI FIRST; migrate Slipway/Rich-RI only afterward.
User has independently asked another agent to fix Rich-RI and adjust CI.
User accepted names `ruby-repo-kit` and `ruby-repo-canary`, and a dedicated minimal
canary, in normal chat. Both GitHub repo endpoints under hvpaiva and RubyGems gem
API endpoints initially returned HTTP 404 on 2026-10-04. Both GitHub repositories
now exist, and both 0.1.0 and 0.1.1 gems are published; the initial availability
checks are historical evidence rather than a current registry state.
User cannot access queued questions over phone SSH. Choices have been restated
in normal text; avoid asynchronous question widgets going forward.

## Evidence baseline

- Slipway: c8e9bde21af9c687247aef06d18aa0f6ef559b95; clean at kickoff.
- Rich-RI: ba6f1db83b302df8c0f1d0489911fcb999ed2aee; clean at kickoff,
  but work is concurrent. Changes after original audit so far were documentation.
- Original audit: Slipway 1534 tests/5750 assertions/8 shell skips, no failures;
  105 tooling tests/337 assertions, no failures/skips. Rich-RI 173 tests/2653
  assertions/6 skips and RuboCop passed; isolated install and additional linters
  passed. These are historical observations, NOT new toolkit acceptance results.
- Ruby locally: 4.0.7; Bundler: 4.0.22; Ruby 3.4 and macOS not yet exercised locally.

## Gates

- [x] G1: toolkit tests and independent gem packaging pass (Linux/Ruby 4.0.7).
- [x] G2: generated canary local installation/behavior/upgrade/recovery pass.
- [x] G3: canary GitHub CI and protected release rehearsal pass on the corrected candidate.
- [x] G4: actual canary 0.1.0/0.1.1 publication, published-toolkit adoption,
  artifact identity, installed behavior and scoped hosted partial-publication
  recovery passed. Completed-release replay also passed; see evidence/CYCLE_0_1_1.md.
- [ ] G5: existing repository baseline recaptured; canary gate evidence reviewed;
  isolated migration PRs preserve application/package/CI/release contracts.

## Resume

1. Read PLAN.md and DECISIONS.md; inspect git status in this toolkit.
2. Read INVESTIGATION.md for original audit rationale.
3. Consult PUBLISHING_SETUP.md, OPERATIONS.md and docs/evidence/ for publication identities and procedures.
4. Review the completed G4 evidence, then recapture each existing product baseline for G5.
5. Do NOT modify Slipway/Rich-RI before G1-G4; never silently weaken a gate.

## Implementation history

The observations below describe earlier milestones; current state is above.

Created gem skeleton, Project configuration, Commands runner, Package support,
CLI and Rake adapters. `bundle install --local` passed with cached gems. Initial
Project/Commands/CLI tests: 10 tests, 42 assertions, no failures/errors/skips.
Package tests: 4 tests, 17 assertions, no failures/errors/skips; actual isolated
gem install and corrupted-artifact rejection passed. Gemspec inspection now runs
in a child process to avoid stale VERSION constants after a version bump.
Release, GitHub/checks, commits, shared lint and generator are now implemented.
Integrated run: 103 tests / 558 assertions, zero failures/errors/skips; RuboCop
43 files clean after adding the rehearsal scripts; repo:check and release:verify
passed. Coverage 94.85% lines / 83.51%
branches; enforcing 90%/80%. Full `bundle exec rake check release:verify` passed.
Independent toolkit package installation passed after explicit optparse dependency
and default-gem isolation correction. `--install-dir` made RubyGems ignore default
gems; GEM_HOME/GEM_PATH already supply isolation, so the redundant flag was removed.
Dependency checking remains enabled, with missing-dependency regression coverage.
Review fixes completed: OptionParser namespace collision, VERSION .freeze,
manual-release recovery recognition, existing-PR dry-run validation and exact
installed-version matching. Fresh-dependencies is now a required CI check.
Dependency audit passed against advisory database 97659622944c19d42961c03813666f4196457229.
Tooling and canary workflows passed zizmor 1.30.1 offline: no reported findings,
one intentional local-workflow ignore and eleven default suppressions each.

The real canary was generated by the installed 0.1.0 toolkit gem. Initial signed
commit: c295b44743a8e71fb6f18e0b4983318d38d8aa85. It passed `rake check`, release
metadata/artifact verification and audit: 7 tests / 29 assertions, no failures or
skips, 100% lines/branches, 11 linted files clean, independent installed package.
Local upgrade and failed-preparation recovery rehearsals passed in temporary
copies; see docs/evidence/UPGRADE.md and RECOVERY.md for identity and limitations.
Upgrade changed only the copied lockfile; recovery preserved date across a retry
and produced one genuinely signed commit, using only a temporary local Git remote.
Existing repos remain read-only. Slipway HEAD remains c8e9bde; independently
evolving Rich-RI was observed at 9328c1a53c3560c02d480ece13d4ba34c90120d6 (clean).

Hosted prerequisites: GitHub CLI is authenticated as hvpaiva. The user completed
both RubyGems pending-publisher registrations for workflow release.yml and
environment release. Both projects' actual OIDC publications succeeded through
their own publisher registrations. No static RubyGems credential was added locally.
INVESTIGATION.md preserves original comparison and architecture tradeoffs.
Public GitHub repositories now exist for both names, with initial signed commits
and GitHub policy applied/verified. Both v0.1.0 gems are published with verified
signed tags; see evidence/PUBLICATION.md and evidence/CANARY.md for identities.
Toolkit initial commit cfcc767de4ff6beacd1cb4eb9fa01952b6f10654.
Initial toolkit hosted CI 37249760068 exposed empty checksums from the offline
lockfile. PR https://github.com/hvpaiva/ruby-repo-kit/pull/1 populates checksums
without version changes and fixes a macOS-only path assertion (/var vs /private/var).
Final PR run https://github.com/hvpaiva/ruby-repo-kit/actions/runs/37250241313
passed all seven checks, including Linux/Ruby 3.4/4.0 and macOS/Ruby 4.0. PR #1
merged without bypass into 8b4ea8eb32ad3aeff97e81a05a868bb62913672d, whose signature
GitHub verified. Nonpublishing hosted toolkit release rehearsal passed at
https://github.com/hvpaiva/ruby-repo-kit/actions/runs/37250441649. The downloaded
gem matched the recorded SHA256, installed independently, and passed GitHub
attestation verification against the workflow/commit. Both publishing jobs were
skipped. See docs/evidence/HOSTED.md; this is TOOLKIT evidence, not canary G3/G4.
Initial canary CI 37249904838 failed on empty frozen-lock checksums; its
fresh-dependencies job separately could not resolve the then-unpublished toolkit.
Canary PR #1 completed checksums against the published toolkit and passed all
seven checks. A subsequent real preparation attempt safely exposed a generator
defect: the initial changelog already claimed a released 0.1.0. Canary PR #2 moved
those notes under Unreleased; release PR #3 then prepared normally and passed the
exact-head checks/rehearsal above. Toolkit PR #5 adds regression coverage and fixes
the generator in published 0.1.1. The subsequent real upgrade and hosted recovery
are recorded in evidence/CYCLE_0_1_1.md; see PUBLISHING_SETUP.md for continuation.
