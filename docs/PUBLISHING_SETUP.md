# First-publication handoff

The source repositories exist and their GitHub policies have been applied and
verified:

- https://github.com/hvpaiva/ruby-repo-kit
- https://github.com/hvpaiva/ruby-repo-canary

No gem or version tag has been published. GitHub authentication works in this
workspace. No RubyGems credential file, RubyGems API environment variable or
connected browser is available. The missing account step is RubyGems Trusted
Publishing registration, not another GitHub secret.

## RubyGems account step

In the intended gem owner's account, open
[pending trusted publishers](https://rubygems.org/profile/oidc/pending_trusted_publishers)
and create these two entries:

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

No password, API token or recovery code needs to be copied into chat. Confirming
that both entries exist is enough to resume the publication gate.

## Ordered continuation

1. Toolkit protected PR checks and the nonpublishing Release rehearsal passed;
   consult docs/evidence/HOSTED.md for exact identities and limits.
2. Evidence and the recovery script were committed through protected PR #2.
3. Toolkit 0.1.0 is prepared in [release PR #3](https://github.com/hvpaiva/ruby-repo-kit/pull/3)
   using the shared command. Require all checks on its latest head and the pending
   publisher registration above, then resume
   `bundle exec ruby-repo-kit release 0.1.0 --push`. The command merges and signs
   the exact release merge SHA; no tag has been created yet.
4. Verify actual toolkit OIDC publication, GitHub release and the downloaded gem's
   identity/digest. A green branch rehearsal cannot substitute for this step.
5. In the canary, resolve against the published toolkit and run
   `bundle lock --add-checksums`. Its bootstrap lockfile was generated offline
   against a local artifact; it is not yet a hosted-installation acceptance result.
   Commit the checksum update through a PR and require all seven CI checks.
6. Rehearse then publish canary 0.1.0 through the same reviewed release flow.
   Record run URLs, commit/tag identity, artifact digest and installed behavior.
7. Exercise a subsequent actual toolkit/canary update and release. Local
   version-only upgrade evidence is useful but does not replace this hosted gate.
8. Only after G1-G4: refresh Slipway/Rich-RI baselines and prepare isolated,
   rollbackable adoption PRs. Respect the independent ongoing Rich-RI changes.

Do not bypass required checks, rewrite version tags, put temporary path/Git
dependencies in the canary to manufacture a green CI, or describe a dry-run as
authentication/publication evidence.
