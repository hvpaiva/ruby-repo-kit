# Published 0.1.1 upgrade and recovery cycle

## Toolkit 0.1.1 publication

Verified 2026-10-04 America/Sao_Paulo (2026-10-05 UTC). This is the actual second
toolkit publication, with the first-release generator correction, checksum
preflight and consumer composition adapters included.

[Release PR #8](https://github.com/hvpaiva/ruby-repo-kit/pull/8), head
`d8508af380683c1f538618684c4c2f02104696d3`, passed all seven checks and merged at
2026-10-05 02:10:25 UTC as `b02066722fe49b68024c45a4491d4a3cf0e3b6e6`.
Annotated tag `v0.1.1`, object `91cc3ceda136357c60a15b028d1d497b3f67f9e3`, points
to that exact merge commit. GitHub reports its signature as verified, reason valid.

[Tag run 37254345206](https://github.com/hvpaiva/ruby-repo-kit/actions/runs/37254345206)
completed successfully at 2026-10-05 02:12:44 UTC. Quality, audit, fresh dependency
resolution, Linux Ruby 3.4/4.0 and macOS Ruby 4.0 passed. Verify, tag ancestry,
attest, the trusted publisher and GitHub Release creation all ran successfully.
Commit checks were skipped on the tag push and had passed in the release PR.

The [RubyGems version API](https://rubygems.org/api/v2/rubygems/ruby-repo-kit/versions/0.1.1.json)
reports creation at `2026-10-05T02:12:30.860Z`. The
[GitHub Release](https://github.com/hvpaiva/ruby-repo-kit/releases/tag/v0.1.1)
was published at `2026-10-05T02:12:41Z`, with the gem and checksum manifest; it is
neither a draft nor a prerelease.

```text
ruby-repo-kit-0.1.1.gem
SHA256 3a4c3676690f8cd82779d8f7ae8e6dc25d17d25afbe7866ca3503a8cef0673dd
```

Independent downloads from the tagged Actions artifact, GitHub Release and
RubyGems all have that digest. Both downloaded checksum manifests, the RubyGems
API and the verify job output passed into attest/publish match it. No artifact
was rebuilt for comparison.

[Attestation 52683983](https://github.com/hvpaiva/ruby-repo-kit/attestations/52683983)
verified with exit 0 for the RubyGems-downloaded gem, enforcing all these values:

```text
repository: hvpaiva/ruby-repo-kit
signer workflow: hvpaiva/ruby-repo-kit/.github/workflows/release.yml
source ref: refs/tags/v0.1.1
source digest: b02066722fe49b68024c45a4491d4a3cf0e3b6e6
```

The gem downloaded from RubyGems installed in an isolated temporary gem home on
Linux/Ruby 4.0.7. Its installed executable passed help and version checks. That
installed toolkit generated a new CLI in a path containing a space. Its generated
Gemfile requests `ruby-repo-kit ~> 0.1.1`, its changelog does not already claim a
released 0.1.0, and the installed toolkit's `Metadata#changes("0.1.0")` prepared
valid first-release metadata in memory without altering the generated files.
This directly verifies the corrected packaged template and first-release path.

Raw run/tag/API responses, three downloaded gems, attestation verification,
checksum comparisons and installed smoke output are retained under ignored
`tmp/publication-toolkit-0.1.1-37254345206/`. The smoke helper is
`tmp/check-toolkit-011-artifact.rb`.

## Canary adopts the published development dependency

[Canary PR #5](https://github.com/hvpaiva/ruby-repo-canary/pull/5), head
`7ee792741b4f3dfd1ef3de53bda989415b0a8cee`, changed only the lockfile's toolkit
version/checksum and Unreleased notes. Its toolkit entry moved from 0.1.0 to
published 0.1.1 with SHA256
`3a4c3676690f8cd82779d8f7ae8e6dc25d17d25afbe7866ca3503a8cef0673dd`. No application,
runtime-dependency or copied tooling implementation changed.

All seven checks passed in [CI run 37254667473](https://github.com/hvpaiva/ruby-repo-canary/actions/runs/37254667473)
before merge `385eac705c200445a49ab7a453ad95ef752f1583` at
2026-10-05 02:18:10 UTC. The fresh-dependencies job explicitly fetched and
installed toolkit 0.1.1; it did not silently downgrade to make checks pass.

On attempt 1, Ubuntu Ruby 4.0 and commits stopped in Bundler installation, reporting
that locked toolkit 0.1.1 could not be found. Other jobs installed that published
version successfully. A failed-check retry on the same head and lockfile passed.
This was a dependency index/cache availability issue consistent with the recent
publication; it did not reach tests and is separate from the deliberate
publication-recovery fixture below.

A separate [published-package upgrade and preparation-recovery exercise](PUBLISHED_UPGRADE_RECOVERY.md)
verified the development-only update without copied code: exactly two lockfile
lines changed and all 31 other files stayed identical. Both published toolkit
versions passed the unchanged consumer checks; 0.1.1 detected a deliberately
missing dependency checksum that 0.1.0 missed. Its preparation retry used real
signed local Git commits and a simulated GitHub adapter, so that result remains
distinct from the hosted publication recovery below.

## Actual canary publication and partial-failure recovery

[Release PR #6](https://github.com/hvpaiva/ruby-repo-canary/pull/6), head
`1cb089db706c8de551850cedae22b61866634a6d`, passed all seven checks in
[run 37254883959](https://github.com/hvpaiva/ruby-repo-canary/actions/runs/37254883959)
and merged as `ca474f4f53719b5a823766e5a43cf7c879fd19a8`. Signed annotated tag
`v0.1.1`, object `12e0e669f5d8ac34916d96358bae715917b08ac4`, points to that merge
commit. GitHub reports its signature as verified, reason valid.

[Canary PR #4](https://github.com/hvpaiva/ruby-repo-canary/pull/4) introduced one
explicit test fixture, only for tag `v0.1.1` on attempt 1: the terminal
`github-release` job exits 73 after its successful `publish` dependency, before
creating a GitHub Release. The canary documents this fixture in
[RECOVERY_EXERCISE.md](https://github.com/hvpaiva/ruby-repo-canary/blob/v0.1.1/docs/RECOVERY_EXERCISE.md).
It is not in the generator and does not fail future versions.

[Tag run 37254971421, attempt 1](https://github.com/hvpaiva/ruby-repo-canary/actions/runs/37254971421/attempts/1)
passed quality, audit, fresh dependencies, Linux Ruby 3.4/4.0, macOS Ruby 4.0,
artifact verification, attestation and actual trusted RubyGems publication. The
commit job was skipped on the tag push and had passed in the PR. The expected
terminal fixture failed with exit 73. The shared engine returned exit 1 and the
specific diagnostic that RubyGems had succeeded, with this recovery command:

```sh
gh run rerun 37254971421 --job 111590365433 --repo hvpaiva/ruby-repo-canary
```

Before executing that command, independent verification saved the attempt-1 jobs,
run, signed tag object, RubyGems API and public gem. The GitHub Release endpoint
returned 404. RubyGems already recorded version 0.1.1 at
`2026-10-05T02:21:46.749Z`, with the same gem digest as the verified Actions artifact.
The engine's failure therefore represented a real partial publication, not a
local simulation or uncertainty about whether RubyGems had accepted the package.

Only the indicated GitHub Release job was retried. [Attempt 2](https://github.com/hvpaiva/ruby-repo-canary/actions/runs/37254971421/attempts/2)
completed successfully. The endpoints for each attempt report:

| Job | Attempt 1 | Attempt 2 |
| --- | --- | --- |
| publish | ID 111590234203, success, 02:21:13–02:21:50 UTC | Carried ID 111591104479, same success and original timestamps |
| github-release | ID 111590365433, failure, 02:21:52–02:21:57 UTC | ID 111591104002, success, 02:25:38–02:25:48 UTC |

GitHub assigns new IDs even to carried successful jobs. We compared the attempt
endpoints and publisher logs rather than treating those IDs as an execution
count. Both views contain the same 316 publisher messages and timestamps at
second precision, including the single original registration at 02:21:48 UTC.
The CLI renders carried step names as `UNKNOWN STEP`, changes BOM placement and
rounds some timestamp fractions; those display differences were normalized for
the comparison. No publisher execution occurred in the retry window.

The [GitHub Release](https://github.com/hvpaiva/ruby-repo-canary/releases/tag/v0.1.1)
was created at `2026-10-05T02:25:45Z`, reports `immutable: true`, and contains the
gem and checksum manifest. After recovery, the RubyGems `created_at` and digest,
tag reference and full signed tag object were unchanged.

```text
ruby-repo-canary-0.1.1.gem
SHA256 4b4bbcee784d759bc36482d697de01923893dbb7f4b044d4250afd0e3b4cbee1
```

Independent downloads from Actions, GitHub Release and RubyGems all have that
digest. Both checksum manifests, the RubyGems version API, GitHub asset digest
and workflow's `RELEASE_SHA256` agree. Recovery reused the original artifact.

[Attestation 52685345](https://github.com/hvpaiva/ruby-repo-canary/attestations/52685345)
verified for the public gem, enforcing repository `hvpaiva/ruby-repo-canary`,
signer workflow `hvpaiva/ruby-repo-canary/.github/workflows/release.yml`, source
ref `refs/tags/v0.1.1` and source digest
`ca474f4f53719b5a823766e5a43cf7c879fd19a8`. Provenance identifies attempt 1,
when the gem was built and attested, not the terminal job retry.

The gem downloaded from RubyGems installed outside the checkout into an isolated
temporary gem home on Linux/Ruby 4.0.7. Help, version, echo, a literal flag after
`--`, an unknown option and missing input all produced the expected streams and
exit statuses. Runtime metadata has no toolkit dependency, and the isolated
process found no installed `ruby-repo-kit` specification.

Raw responses, both attempt logs, three downloaded gems, digest comparisons,
attestation verification and isolated installed smoke results are retained under
ignored `tmp/publication-canary-0.1.1-37254971421/`. The real engine failure and
recovery watch logs are in the canary's ignored `tmp/`.

## Completed replay and gate result

After attempt 2 succeeded, repeating the same real release command for 0.1.1
with `--push` returned exit 0. It reverified policy, metadata, tag signature and
identity, then reported: `Released v0.1.1; the existing successful run is
37254971421.` Its log contains no commit, push, tag-creation or publication
command. This final log is `ruby-repo-canary/tmp/release-0.1.1-resume.log`.

Unlike the earlier 0.1.0 replay, no before/after run-list snapshot was captured
for this replay. Do not infer such a comparison. The replay evidence is its
exit status and recorded read/verify-only command trace; the separate before/
after tag, registry, jobs and artifact evidence above proves the scoped recovery.

G4 is satisfied: the canary adopted a real published toolkit improvement without
copying operational code, published its subsequent version through OIDC,
recovered from a demonstrated partial hosted publication without repeating
RubyGems publication, and preserved immutable artifact identity and installed
behavior. G1–G4 permit the next stage; G5 still requires fresh baselines, isolated
integration PRs and proof that each existing product's contracts are preserved.
Neither Slipway nor Rich-RI was modified by these acceptance experiments.
