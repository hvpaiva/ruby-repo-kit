# Local acceptance evidence

Date: 2026-10-04 America/Sao_Paulo. Linux x86_64, Ruby 4.0.7, Bundler 4.0.22.
Toolkit initial signed commit: `cfcc767de4ff6beacd1cb4eb9fa01952b6f10654`.
Canary signed commit: `c295b44743a8e71fb6f18e0b4983318d38d8aa85`.
Both signatures were verified locally; GitHub also reported the toolkit initial
commit signature as verified.

## Toolkit

`bundle exec rake check release:verify` passed:

- 103 tests, 558 assertions, no failures/errors/skips.
- Coverage: 1,015 / 1,070 lines (94.85%), 314 / 376 branches (83.51%).
  Enforced thresholds: 90% lines, 80% branches.
- RuboCop: 41 files, no offenses.
- Local repository and release-metadata validation passed.
- Built gem installed in an isolated GEM_HOME/GEM_PATH and its executable passed
  help/version smoke checks outside the checkout and bundle.

The recorded package was separately consumed by
`bundle exec rake 'package:check[pkg/ruby-repo-kit-0.1.0.gem]'`:

    21aa06837167a5af747fc55e620c03525753270f3d5da70ad656be39caa94f32

The source was also exported with `git archive HEAD` to a temporary directory,
built and installed there without `.git`. All 58 packaged file paths matched,
including 31 templates. This checks the archive-packaging failure seen in the
original Slipway audit. No claim of reproducible archive/gem bytes is made.

## Actual generated canary

The installed toolkit executable generated the canary in its final local path,
using the accepted name/repository/author. Its Gemfile refers to RubyGems normally
and has no path or Git override. The local bootstrap used the installed toolkit
artifact plus existing development-gem caches; no toolkit dependency is in the
canary runtime gemspec.

`bundle exec rake check release:artifact release:verify_artifact audit` and the
separate metadata check passed:

- Seven tests, 29 assertions, no failures/errors/skips.
- 33 / 33 lines and 6 / 6 branches covered (100%).
- RuboCop: 11 files, no offenses.
- The canary gem installed and ran outside its checkout/bundle with no runtime
  toolkit dependency.
- Release artifact checksum verification passed.

The recorded canary package was separately consumed by
`bundle exec rake 'package:check[pkg/ruby-repo-canary-0.1.0.gem]'`:

    2786325b7a461dd588a63138ced3b3239db8deceb1220b886b42790eea634ef7

The preliminary installed toolkit used for generation can differ in documentation
bytes from the later recorded toolkit artifact; neither was publicly released.
Hosted published artifacts must receive their own exact digest evidence.

## Shared observations and limits

Both dependency audits passed against ruby-advisory-db
`97659622944c19d42961c03813666f4196457229` (1,252 advisories).
Zizmor 1.30.1 offline reported no findings for each pair of workflows, with one
intentional local-workflow ignore and eleven default suppressions.

GitHub policies were planned, applied and verified on the two NEW repositories.
Existing consumer repositories were not changed. Slipway remained at `c8e9bde`;
independently evolving Rich-RI was observed clean at `9328c1a`.

Hosted CI exposed empty checksums in the offline bootstrap lockfile, despite
these local checks passing. Toolkit PR #1 filled checksums without changing gem
versions or disabling frozen installation, and corrected a macOS path assertion.
All seven required checks passed in run 37250241313; merge commit is
`8b4ea8eb32ad3aeff97e81a05a868bb62913672d`. Canary resolution against RubyGems
must follow the toolkit's first publication. Local success is not G3/G4 success.
