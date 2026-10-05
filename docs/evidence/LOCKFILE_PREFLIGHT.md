# Lockfile checksum preflight

Observed 2026-10-05 UTC, Linux/Ruby 4.0.7. Implementation starts from published
0.1.0 merge `b524e95b1f3fd041d5123768dd2a655c3805cb10`. This evidence concerns the
Unreleased fix; no new toolkit version has been published by this change.

## Defect and boundary

The initial hosted toolkit and canary installations rejected empty CHECKSUMS
entries under frozen Bundler. Local checks had passed with installed dependencies.
The recorded failure and workflow identities are in [HOSTED.md](HOSTED.md).

Doctor and `repo:check` now read Gemfile.lock before loading project metadata.
When CHECKSUMS is enabled, each locked RubyGems specification must have a digest,
including platform variants. PATH/Git sources have no required artifact digest.
The check preserves Bundler's opt-in behavior for existing lockfiles without a
CHECKSUMS section and allows a newly generated project without a lockfile.
It neither resolves nor fetches dependencies and cannot verify an artifact's
bytes: Bundler retains that responsibility when installing the gem.

## Validation

- `bundle exec rake check release:verify`: 113 tests, 593 assertions, no failures,
  errors or skips; 45 Ruby files linted clean; 94.94% lines and 83.76% branches;
  isolated built-gem installation and release metadata verification passed.
- `test/lockfile_test.rb`: 9 tests, 32 assertions, no failures/errors/skips with
  Bundler 4.0.22 and separately with Bundler 2.6.0, the supported minimum.
- Cases cover complete/empty/missing entries, PATH/Git exemptions, platform and
  version identity, malformed SHA-256, merge conflicts, opt-in compatibility,
  absent lockfiles, unchanged file contents/mtime and no generated bundle files.
- The doctor integration test rejects an incomplete lockfile before evaluating
  a deliberately failing consumer gemspec.

Bundler 2.6.0 was downloaded from RubyGems and extracted under ignored
`tmp/bundler-compatibility/`, not installed into the user's gem home. The standalone
test command selected its `lib` via Ruby's load path, with no bundle setup:

```sh
env -u RUBYOPT -u RUBYLIB ruby \
  -Itmp/bundler-compatibility/bundler-2.6.0/lib -Ilib:test \
  -e 'require "bundler"; puts Bundler::VERSION; require_relative "test/lockfile_test"'
```

Bundler 2.6.0 emits existing RubyGems platform constant redefinition warnings on
Ruby 4.0.7; the tests and preflight complete successfully. This is minimum-version
parser compatibility evidence, not a claim that every Bundler 2.6 operation was
tested on Ruby 4.

## Enforced read-only, offline execution

Two standalone fixtures contained an uninstalled RubyGems dependency at
`https://not-accessed.invalid/`, plus PATH and Git dependencies. One fixture had a
complete RubyGems checksum; the other had an empty entry. Both were inspected in
a Linux bubblewrap sandbox for each Bundler version:

```sh
bwrap --unshare-net --ro-bind / / --dev /dev --proc /proc RUBY \
  -Ilib tmp/bundler-compatibility/readonly.rb \
  tmp/bundler-compatibility/complete.lock \
  tmp/bundler-compatibility/incomplete.lock
```

The 2.6.0 run also selected its extracted `lib` via `-I`. Before inspection, the
harness required an attempted filesystem write to fail with `Errno::EROFS` and a
TCP connection to fail with `Errno::ENETUNREACH`. Under those enforced limits,
both versions accepted the complete fixture and rejected the incomplete one with
the expected actionable error. Both file SHA-256 values remained unchanged.
Only stdout/stderr were written; the harness, fixtures and captured logs remain
under ignored `tmp/bundler-compatibility/`. Downloading the compatibility archive
occurred separately, outside this offline proof.

## Dependency on Bundler internals

The small `Checks::Lockfile` adapter uses `Bundler::LockfileParser`, specification
source identity, `checksum_store.to_lock` and `name_tuple.lock_name`. These are
Bundler implementation APIs, not an independently stable toolkit-owned format.
They exist in the inspected/tested 2.6.0 and 4.0.22 implementations. The newer
`checksum_store.missing?`/`empty?` methods were deliberately avoided because they
are unavailable in 2.6.0. Compatibility tests must be rerun when changing the
supported Bundler range; a future internal change may require adapting this file.

This local evidence does not replace the pending consumer adoption, protected CI
and actual subsequent release evidence required by G4.
