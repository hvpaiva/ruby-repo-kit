# Canary hosted acceptance evidence

Recorded 2026-10-04 America/Sao_Paulo (2026-10-05 UTC). G3 passed for the corrected
candidate and the first real canary publication is verified below. G4 was partial
at this milestone; the subsequent actual update and hosted recovery are recorded
in [CYCLE_0_1_1.md](CYCLE_0_1_1.md).

## Initial successful CI and branch rehearsal

[Canary PR #1](https://github.com/hvpaiva/ruby-repo-canary/pull/1) passed all seven
required checks at head `f7cead9be4c6c3acb2735d86aa0f71cc8c6a10c2`, then merged as
`2461a0a142fa85038ccef30ace07798f71e3b523` at 2026-10-05 01:46:31 UTC. It completed
the frozen lockfile checksums against the now-published toolkit 0.1.0.

[Rehearsal run 37252756196](https://github.com/hvpaiva/ruby-repo-canary/actions/runs/37252756196)
was dispatched on that `main` commit and completed successfully at
2026-10-05 01:48:08 UTC. Quality, audit, fresh dependencies, Linux Ruby 3.4/4.0,
macOS Ruby 4.0, verify and attest passed. Commits was skipped for the dispatch;
publication and GitHub Release creation were also skipped. Tag ancestry was not
exercised on this branch run.

```text
ruby-repo-canary-0.1.0.gem
SHA256 2786325b7a461dd588a63138ced3b3239db8deceb1220b886b42790eea634ef7
```

The downloaded `release-gem` artifact's actual SHA256, its `SHA256SUMS` manifest
and the verify job's output received by attest match. `gh attestation verify`
returned exit 0; the provenance ties those bytes to commit
`2461a0a142fa85038ccef30ace07798f71e3b523`, release.yml on main and invocation
`37252756196/attempts/1`. See
[attestation 52680734](https://github.com/hvpaiva/ruby-repo-canary/attestations/52680734).

The downloaded artifact installed in an isolated gem home on Linux/Ruby 4.0.7.
Six installed behavior cases passed: help, version, echo, literal flag following
`--`, unknown-option error and missing-input error. Success used stdout with
empty stderr; both errors used stderr with empty stdout and status 2. The
toolkit was absent from both the canary's runtime dependencies and its isolated
runtime gem specifications.

Raw logs, run JSON, attestation verification and downloaded artifact are retained
under ignored `tmp/canary-rehearsal-37252756196/`. The local smoke script is
`tmp/check-canary-artifact.rb`.

## Why this rehearsal does not close the corrected-candidate gate

Subsequent real release preparation exposed an initial-template defect: the
generated changelog already contained a released `0.1.0` section, so the release
engine correctly refused a duplicate version without mutating the project.
Canary PR #2 corrects the initial changelog to Unreleased; the generator receives
its own regression correction in the next toolkit release. The corrected,
prepared release candidate must rerun the hosted rehearsal. This earlier green
run must not be presented as proof of that later source state or actual canary
trusted publication. The corrected candidate is verified separately below.

## Corrected, prepared release candidate: G3 passed

The corrected changelog allowed the shared command to prepare the initial release
normally. [Canary release PR #3](https://github.com/hvpaiva/ruby-repo-canary/pull/3)
head `8001c2ce30930f19fbd7d49d598f04ea1abd2081` passed all seven checks in
[CI run 37252930225](https://github.com/hvpaiva/ruby-repo-canary/actions/runs/37252930225).
Those include commit checks as well as quality, audit, fresh dependencies and
the Linux/macOS Ruby matrix.

[Corrected rehearsal 37252940888](https://github.com/hvpaiva/ruby-repo-canary/actions/runs/37252940888)
ran on that exact `release/v0.1.0` head and completed successfully at
2026-10-05 01:50:53 UTC. CI, verify and attest passed; commits, publication and
GitHub Release jobs were skipped as expected for a nonpublishing branch dispatch.

```text
ruby-repo-canary-0.1.0.gem
SHA256 99cfd962d923911c8f91dcec75e557e77b6828ae9cb66a0c66adea17375729a3
```

The downloaded artifact, manifest and verify job output have that same digest.
`gh attestation verify` returned exit 0 and linked the digest to the exact PR head,
release.yml on `refs/heads/release/v0.1.0`, and invocation
`37252940888/attempts/1`; see
[attestation 52681154](https://github.com/hvpaiva/ruby-repo-canary/attestations/52681154).
The downloaded candidate passed the same six installed CLI cases and absence of
the toolkit from runtime dependencies/specifications in an isolated gem home.

This supplies G3's consumer CI and release rehearsal evidence for the corrected
candidate. The branch rehearsal does not claim RubyGems authentication, tag
ancestry or publication. G4 still requires the actual canary publication and the
subsequent update/release/recovery evidence. Raw records are retained under
ignored `tmp/canary-rehearsal-37252940888/`.

## Actual canary 0.1.0 trusted publication

Release PR #3 merged at 2026-10-05 01:51:32 UTC as
`2604a94dd4d28da7383d0a781997ac7c64524c17`. The annotated `v0.1.0` tag, object
`b7c7133bb326abca60912958655e05f4a7257189`, points to that exact merge commit.
GitHub reports the tag signature as verified with reason `valid`.

[Tag run 37253081855](https://github.com/hvpaiva/ruby-repo-canary/actions/runs/37253081855)
completed successfully at 2026-10-05 01:53:33 UTC. Its CI matrix, verify (including
tag ancestry), attest, publish and GitHub Release jobs passed. The `release`
environment's publish job successfully configured RubyGems credentials through
the pinned trusted-publishing action, then reported successful registration of
`ruby-repo-canary (0.1.0)`. The commit job was skipped for the tag push; all seven
checks had passed on the release PR. The workflow supplies no static RubyGems key.

The [RubyGems version API](https://rubygems.org/api/v2/rubygems/ruby-repo-canary/versions/0.1.0.json)
independently reports creation at `2026-10-05T01:53:22.746Z`.
The [GitHub Release](https://github.com/hvpaiva/ruby-repo-canary/releases/tag/v0.1.0)
was published at `2026-10-05T01:53:31Z`, is neither a draft nor a prerelease, and
contains the gem and checksum manifest.

The tagged Actions artifact, GitHub Release gem and gem downloaded directly from
RubyGems all have SHA256
`99cfd962d923911c8f91dcec75e557e77b6828ae9cb66a0c66adea17375729a3`. Both manifests,
the RubyGems API and the verify output passed to attest/publish report that same
digest. The published bytes also match the prepared-candidate rehearsal; the
merge did not alter its packaged payload. No comparison rebuilt the gem.

The [tag attestation](https://github.com/hvpaiva/ruby-repo-canary/attestations/52681438)
was verified with exit status 0 using explicit source/ref/workflow constraints:

```sh
gh attestation verify ruby-repo-canary-0.1.0.gem \
  --repo hvpaiva/ruby-repo-canary \
  --signer-workflow hvpaiva/ruby-repo-canary/.github/workflows/release.yml \
  --source-ref refs/tags/v0.1.0 \
  --source-digest 2604a94dd4d28da7383d0a781997ac7c64524c17
```

Those constraints select the actual tagged provenance, even though identical
bytes also have a valid attestation from the branch rehearsal. The provenance
identifies invocation `37253081855/attempts/1`.

The gem downloaded from RubyGems was installed in a temporary isolated gem home
on Linux/Ruby 4.0.7. All six behavior cases described above passed, including
stdout/stderr and exit statuses. The installed application's runtime gem
specifications and declared dependencies contain no `ruby-repo-kit`.

Raw responses, logs, gems, tag verification, both attestation verification outputs
and installed smoke evidence are under ignored
`tmp/publication-canary-0.1.0-37253081855/`.

## Completed-release replay

After publication, the real `ruby-repo-kit release 0.1.0 --push` command was run
again in the canary and returned exit 0. It rechecked repository policy, fetched
refs, found the merged release PR, checked main ancestry and release metadata,
verified the existing signed tag, and selected the existing successful run
`37253081855`. The command log contains no commit, tag-creation, push, publication
or workflow-dispatch command for this replay.

Before/after results from `gh run list --workflow release.yml --branch v0.1.0`
were byte-identical and contained only the same successful run and merge SHA.
The worktree remained clean. Local evidence is retained in the canary's ignored
`tmp/release-0.1.0-before-resume.json`, `tmp/release-0.1.0-after-resume.json`, and
`tmp/release-0.1.0-resume.log`.

This is real idempotent recognition of a completed hosted release. No failure
was injected into GitHub publication, and this replay did not exercise recovery
from a partially failed hosted publish. The earlier failure-injection evidence
in RECOVERY.md concerns local preparation with a temporary remote and remains
separate.

## G4 continuation after this milestone

First toolkit and canary publications are now verified through their respective
trusted publishers with exact artifact identity and installed behavior. G3 is
closed. G4 remained open for the subsequent real toolkit 0.1.1/consumer adoption
and release/recovery cycle, now recorded in [CYCLE_0_1_1.md](CYCLE_0_1_1.md). The local version-only update and simulated remote
recovery remain useful prior evidence, but do not replace that hosted cycle.
No new account setup is required from the user. Slipway and Rich-RI remain
read-only until the remaining gates have passed and their current baselines are
recaptured.
