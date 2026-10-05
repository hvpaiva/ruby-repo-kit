# Publication setup and continuation

The source repositories exist and their GitHub policies have been applied and
verified:

- https://github.com/hvpaiva/ruby-repo-kit
- https://github.com/hvpaiva/ruby-repo-canary

The user confirmed both RubyGems pending-publisher registrations. Toolkit 0.1.0
has now been published through its trusted publisher, with matching Actions,
GitHub Release and RubyGems artifact digests. See
[publication evidence](evidence/PUBLICATION.md). The canary must exercise its own
publisher. GitHub authentication works locally; no static RubyGems credential
needs to be installed here.

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

The toolkit's pending registration was exercised by the successful first
publication. The canary registration is confirmed by the user but still needs its
own successful first publication. No password, API token or recovery code needs
to be copied into chat.

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
