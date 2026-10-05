# Hosted CI and release rehearsal

Observed 2026-10-04 America/Sao_Paulo (2026-10-05 UTC). This evidence covers the
toolkit's first hosted CI and unpublished rehearsal artifact. The subsequent
actual toolkit 0.1.0 publication is recorded separately in
[PUBLICATION.md](PUBLICATION.md). Subsequent canary evidence is in
[CANARY.md](CANARY.md): G3 and first publication passed. The subsequent actual
0.1.1 update and hosted recovery are recorded in [CYCLE_0_1_1.md](CYCLE_0_1_1.md).
Neither toolkit result alone authorizes migrating Slipway or Rich-RI.

## Toolkit CI

The [successful PR CI run](https://github.com/hvpaiva/ruby-repo-kit/actions/runs/37250241313)
tested PR head `cc09b251da4bf13bc1e81c0f3abb378553cde5ab`. All seven checks passed:

- `quality`
- `test (ubuntu-latest, 3.4)`
- `test (ubuntu-latest, 4.0)`
- `test (macos-latest, 4.0)`
- `audit`
- `fresh-dependencies`
- `commits`

Ruby versions provisioned were 3.4.11 and 4.0.7; the macOS job used Ruby 4.0.7.
[PR #1](https://github.com/hvpaiva/ruby-repo-kit/pull/1) merged as
`8b4ea8eb32ad3aeff97e81a05a868bb62913672d` at 2026-10-05 01:10:25 UTC.

The initial hosted failures were real defects, subsequently corrected by that PR:
offline lockfile generation had left empty gem checksums, which frozen Bundler
installation correctly rejected. Checksums were populated without changing the
locked versions. Once installation worked, macOS exposed a test expectation that
compared `/var/...` to RubyGems' canonical `/private/var/...`; the expectation now
compares canonical paths. The final successful run exercised all matrix tests.

## Toolkit release rehearsal

[Release run 37250441649](https://github.com/hvpaiva/ruby-repo-kit/actions/runs/37250441649)
completed successfully at 2026-10-05 01:12:45 UTC. It was dispatched on `main` at
commit `8b4ea8eb32ad3aeff97e81a05a868bb62913672d`, version `0.1.0`, without publishing.

The called CI passed quality, both Linux Ruby versions, macOS, audit and fresh
dependencies. Its quality job reported 103 tests, 558 assertions, zero failures,
errors or skips, and 41 Ruby files with no RuboCop offenses. The commits job was
skipped because the event was `workflow_dispatch`, not a pull request; commit
validation had passed in the PR run above.

The `verify` job passed frozen dependency installation, release metadata
verification, one artifact build and isolated installation of that artifact.
`Verify the tag ancestry` was skipped because this was a branch run, not a tag.
The `attest` job passed checksum verification against the digest passed by the
`verify` job, then created a build provenance attestation. Both `publish` and
`github-release` have the actual job conclusion `skipped`.

Downloaded artifact:

```text
release-gem / ruby-repo-kit-0.1.0.gem
sha256:21aa06837167a5af747fc55e620c03525753270f3d5da70ad656be39caa94f32
```

The local download is under ignored `tmp/hosted-rehearsal-37250441649/`.
`sha256sum --check SHA256SUMS` passed. Its computed digest matches both the
downloaded manifest and the `RELEASE_SHA256` value received from `verify` in the
attest job log. That is the gem digest, distinct from GitHub's artifact ZIP digest.
`RubyRepoKit::Package#check(artifact: ...)` also installed this downloaded gem in
an isolated gem home and passed its installed executable's help/version checks
on Linux/Ruby 4.0.7, without rebuilding the artifact.

The following command completed with exit status 0:

```sh
gh attestation verify \
  tmp/hosted-rehearsal-37250441649/ruby-repo-kit-0.1.0.gem \
  --repo hvpaiva/ruby-repo-kit --format json
```

The verified subject has the digest above. Its provenance identifies the same
source commit and `.github/workflows/release.yml@refs/heads/main`, with invocation
`37250441649/attempts/1`. The
[GitHub attestation](https://github.com/hvpaiva/ruby-repo-kit/attestations/52675246)
and [Sigstore transparency record](https://search.sigstore.dev?logIndex=3079766394)
were created by the real hosted workflow. The local run JSON, attest log,
verification JSON and installed-package log are retained beside the download.

This proves hosted build provenance and the checked artifact's identity. It does
not prove RubyGems trusted-publisher authentication, a version-tag ancestry check,
release-environment admission, gem publication, or GitHub Release creation: those
paths did not run in this rehearsal. The downloaded branch artifact remains
rehearsal evidence; the later tagged release produced and verified its own
distinct artifact, as recorded in PUBLICATION.md.

## Initial canary failure and remaining acceptance

The [initial canary CI run](https://github.com/hvpaiva/ruby-repo-canary/actions/runs/37249904838)
at `c295b44743a8e71fb6f18e0b4983318d38d8aa85` failed before executing application
tests. There are two distinct observed causes:

- `quality`, `audit` and the three matrix jobs failed during frozen Bundler
  installation: `Your lockfile has an empty CHECKSUMS entry for "rake"` (exit 16).
- `fresh-dependencies` reached RubyGems and failed to resolve the unpublished
  `ruby-repo-kit (~> 0.1.0)` (exit 7). Its tests were therefore skipped.

`commits` was skipped as expected for the initial push. No canary dependency
source was changed to make these checks appear successful. After toolkit 0.1.0
publication, canary PR #1 completed the checksums and passed hosted CI. The
corrected release candidate subsequently passed G3 and its own first actual
publication; see CANARY.md for those distinct source identities. At that point G4
still required a subsequent actual update/release/recovery cycle. That cycle is
now recorded separately in [CYCLE_0_1_1.md](CYCLE_0_1_1.md); this historical toolkit
rehearsal and local rehearsals remain distinct evidence.
