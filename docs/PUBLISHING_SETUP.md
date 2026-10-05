# Publication setup and continuation

The source repositories exist and their GitHub policies have been applied and
verified:

- https://github.com/hvpaiva/ruby-repo-kit
- https://github.com/hvpaiva/ruby-repo-canary

The user confirmed both RubyGems pending-publisher registrations. Toolkit and
canary 0.1.0 and 0.1.1 have each been published through their own trusted
publishers, with matching Actions, GitHub Release and RubyGems artifact digests. See
[toolkit publication](evidence/PUBLICATION.md) and
[canary first acceptance](evidence/CANARY.md) and the completed
[0.1.1 upgrade/recovery cycle](evidence/CYCLE_0_1_1.md). G4 is closed. No new account
setup is required from the user; no static RubyGems credential needs to be installed here.

## Registered RubyGems publisher identities

The user registered these entries in the intended gem owner's account through
[pending trusted publishers](https://rubygems.org/profile/oidc/pending_trusted_publishers):

| Field | Toolkit | Canary |
| --- | --- | --- |
| Gem name | ruby-repo-kit | ruby-repo-canary |
| Repository owner | hvpaiva | hvpaiva |
| Repository name | ruby-repo-kit | ruby-repo-canary |
| Workflow filename | release.yml | release.yml |
| Environment | release | release |
| Workflow repository owner/name | Leave blank | Leave blank |

The last two optional fields are for cross-repository reusable publication
workflows. Both publishing jobs currently live in their own repository. The
official [RubyGems guide](https://guides.rubygems.org/trusted-publishing/) describes
pending publishers and their conversion after the first successful publication.

Both pending registrations were exercised by their successful first publications.
No password, API token or recovery code needs to be copied into chat.

## Ordered continuation

1. Toolkit protected PR checks and the nonpublishing Release rehearsal passed;
   consult docs/evidence/HOSTED.md for exact identities and limits.
2. Evidence and the recovery script were committed through protected PR #2.
3. Completed: toolkit [release PR #3](https://github.com/hvpaiva/ruby-repo-kit/pull/3)
   merged after all required checks; the shared release command signed the exact
   merge SHA as v0.1.0. Its tagged workflow published the gem and GitHub Release.
4. Completed: independent publication verification confirmed actual trusted
   publishing, attestation, identical downloaded bytes and installed behavior.
   See evidence/PUBLICATION.md. Do not retry or recreate this published version.
5. Completed: canary PR #1 populated checksums against published toolkit 0.1.0;
   all seven hosted checks passed. PR #2 corrected the initial changelog after
   real preparation exposed a generator defect. Toolkit PR #5 fixes that generator
   and adds checksum preflight, both now published in 0.1.1.
6. Completed: canary release PR #3 passed all seven checks and its exact-head
   rehearsal, then published 0.1.0 through its own trusted publisher. Independent
   verification confirmed all artifact digests, attestation and installed behavior.
   That closed G3 and partially satisfied G4. See evidence/CANARY.md.
7. Completed: toolkit 0.1.1 was published and adopted by canary PR #5 after all
   seven checks. Canary release PR #6 passed checks and published 0.1.1. A scoped
   fixture failed GitHub Release creation after successful RubyGems publication;
   only the terminal job was retried. Registry/tag/bytes remained unchanged, and
   the immutable GitHub Release completed. Independent installed behavior,
   attestation and final release-command replay passed. G4 is closed; see
   evidence/CYCLE_0_1_1.md and evidence/PUBLISHED_UPGRADE_RECOVERY.md.
8. Next, G5: review G1–G4 evidence, refresh Slipway/Rich-RI baselines and prepare
   isolated, rollbackable adoption PRs. Respect independent ongoing Rich-RI changes.
   Use [OPERATIONS.md](OPERATIONS.md) for upgrade, release and recovery procedures.

Do not bypass required checks, rewrite version tags, put temporary path/Git
dependencies in the canary to manufacture a green CI, or describe a dry-run as
authentication/publication evidence.
