# Toolkit 0.1.0 publication evidence

Verified on 2026-10-04 America/Sao_Paulo (2026-10-05 UTC), after the user confirmed
creation of the RubyGems pending trusted publishers. This is actual toolkit
publication evidence, separate from the earlier unpublished rehearsal.

## Source and hosted execution

[Release PR #3](https://github.com/hvpaiva/ruby-repo-kit/pull/3) passed all seven
required CI checks and merged as `b524e95b1f3fd041d5123768dd2a655c3805cb10` at
2026-10-05 01:39:12 UTC. The signed annotated tag `v0.1.0`, object
`1bffc28bcbebb01afacab65e70e518ce906f54de`, points to that exact merge commit.
GitHub's tag verification reports `verified: true`, reason `valid`.

[Tagged release run 37252275299](https://github.com/hvpaiva/ruby-repo-kit/actions/runs/37252275299)
completed successfully at 2026-10-05 01:41:33 UTC. The event was a tag push. Its
quality, audit, fresh-dependencies and Linux Ruby 3.4/4.0 plus macOS Ruby 4.0 jobs
passed. The commits job was skipped for this push; it passed in the release PR.

`verify` passed release metadata, tag ancestry, artifact build and isolated
installation. `attest`, `publish` and `github-release` all ran and passed; these
were not skipped. Publication used the `release` environment and the pinned
`rubygems/configure-rubygems-credentials` action with `id-token: write`. The
credentials action succeeded, then `gem push` reported successful registration of
`ruby-repo-kit (0.1.0)`. No static RubyGems credential was supplied by the workflow.
The actual successful trusted-publisher path is distinct from the separate
Sigstore attestation path.

## Independent registry and artifact checks

The [RubyGems version API](https://rubygems.org/api/v2/rubygems/ruby-repo-kit/versions/0.1.0.json)
returned version `0.1.0`, platform `ruby`, created at
`2026-10-05T01:41:19.011Z`. The
[GitHub Release](https://github.com/hvpaiva/ruby-repo-kit/releases/tag/v0.1.0)
exists, was published at `2026-10-05T01:41:30Z`, and is neither a draft nor a
prerelease. It contains the gem and `SHA256SUMS`.

```text
ruby-repo-kit-0.1.0.gem
SHA256 a740c0bc435d455a2b03a36dc84b441dabe8c39a3f14bb66b0251f8e6986755f
```

That exact digest was independently confirmed for all of the following:

- The `release-gem` artifact downloaded from the tagged GitHub Actions run.
- The gem asset downloaded from the published GitHub Release.
- The gem downloaded directly from RubyGems.
- Both downloaded `SHA256SUMS` manifests and the RubyGems version API's `sha`.
- The `RELEASE_SHA256` output passed from `verify` to the hosted attest/publish jobs.

The artifact was not rebuilt for these comparisons. This digest differs from the
earlier branch rehearsal, as expected for a different source commit.

`gh attestation verify ... --repo hvpaiva/ruby-repo-kit --format json` completed
with exit status 0. The verified subject has the digest above and identifies
`.github/workflows/release.yml@refs/tags/v0.1.0`, source commit
`b524e95b1f3fd041d5123768dd2a655c3805cb10`, and invocation
`37252275299/attempts/1`. Its
[GitHub attestation](https://github.com/hvpaiva/ruby-repo-kit/attestations/52679695)
was created by the actual tagged release.

## Installed published artifact

On Linux/Ruby 4.0.7, `RubyRepoKit::Package#check` installed the gem downloaded from
RubyGems into a temporary isolated `GEM_HOME`/`GEM_PATH`, outside the checkout.
Installed `ruby-repo-kit --help` and `--version` passed. The installed generator
also created a CLI using its packaged templates in a path containing a space;
that CLI's `--version` and echo behavior passed outside the source checkout.
Only cached runtime dependencies and Ruby's default gems were available to the
isolated install; the published toolkit bytes themselves came from RubyGems.

Raw API responses, tag verification, run/job logs, attestation verification,
downloaded artifacts and the smoke-check log are retained locally under ignored
`tmp/publication-toolkit-0.1.0-37252275299/`.

## Gate boundary

The toolkit has a real first publication with verified byte identity and installed
behavior. This result does not itself satisfy canary G3 or G4. Subsequent,
independent [canary evidence](CANARY.md) closes G3 and verifies its first actual
publication. G4 remains partial until the actual update/release/recovery cycle
required by the plan is complete. Existing product repositories remain read-only
until their prerequisite gates are met.
