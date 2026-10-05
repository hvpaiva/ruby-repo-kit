# Local packaged-toolkit upgrade evidence

This is the earlier local rehearsal. Later verification uses actual published
packages in [PUBLISHED_UPGRADE_RECOVERY.md](PUBLISHED_UPGRADE_RECOVERY.md) and
real hosted publication recovery in [CYCLE_0_1_1.md](CYCLE_0_1_1.md).

Observed on 2026-10-04 at 22:02:25–22:02:31 America/Sao_Paulo
(2026-10-05 01:02 UTC), using Ruby 4.0.7 on x86_64 Linux and Bundler 4.0.22.

**Passed:** a copy of the real `ruby-repo-canary` adopted an installed
`ruby-repo-kit` gem from 0.1.0 to 0.1.1 through
`bundle update --local ruby-repo-kit`. Only the copy's `Gemfile.lock` changed.
The original canary and original toolkit `VERSION` remained unchanged.

This was a **local, version-only rehearsal**. The candidate changed only
`lib/ruby_repo_kit/version.rb` in a temporary toolkit copy. It proves dependency
selection, installed-gem integration and compatibility with the canary checks;
it does not prove propagation of a substantive behavior change, RubyGems
publication, OIDC, hosted CI, signatures, or release recovery. It does not satisfy
the hosted publication gate required before migrating Slipway or Rich-RI.

## Method

1. Copy the current toolkit and real canary sources to temporary directories.
   Exclude `.git`, `.bundle`, `tmp`, `pkg`, `coverage`, and `vendor`.
   The canary had no Git repository/commit at capture time; content hashes identify
   the snapshot instead.
2. Make a second toolkit copy with only `VERSION = "0.1.1"` changed.
   Build both `.gem` artifacts from these copies, including the current library,
   templates, gemspec and configuration.
3. Install the 0.1.0 artifact with dependency resolution enabled, `--local`,
   `--no-document` and `--norc`. Both `GEM_HOME` and `GEM_PATH` point only to a
   temporary gem home. Existing `.gem` dependency caches and the interpreter's
   default gems supply dependencies; there is no download.
4. For the canary's development bundle only, extend `GEM_PATH` with the existing
   standard gem locations. Use the absolute Ruby executable and its executable
   directory before mise shims. Run `bundle install --local`, inspect the loaded
   toolkit version/location/source, and run `bundle exec rake check`.
5. Install the 0.1.1 artifact into the same temporary gem home. Run
   `bundle update --local ruby-repo-kit`, inspect adoption again, and rerun
   `bundle exec rake check`.
6. Compare SHA-256 manifests before/after and check that both originals were
   preserved. Temporary source copies, gem homes and artifacts are then removed.

The canary's Gemfile retained `source "https://rubygems.org"` and
`gem "ruby-repo-kit", "~> 0.1.0", require: false`. No toolkit `path:` or `git:`
dependency was introduced. Bundler reported `Bundler::Source::Rubygems` for the
toolkit before and after; the artifacts themselves were supplied locally, not
fetched from RubyGems. The lockfile's existing `PATH remote: .` describes the
canary's own gemspec, not the toolkit.

## Results

| Check | Toolkit 0.1.0 | Toolkit 0.1.1 |
| --- | --- | --- |
| Build and isolated gem install | Passed | Passed |
| Loaded toolkit constant/spec | 0.1.0, temporary installed gem | 0.1.1, temporary installed gem |
| `bundle exec rake check` | Passed | Passed |
| RuboCop | 11 files, no offenses | 11 files, no offenses |
| Canary tests | 7 tests, 29 assertions; no failures/errors/skips | Same |
| Canary coverage | 33/33 lines, 6/6 branches | Same |
| Repository/generated checks | Passed | Passed |
| Installed canary package smoke | Passed, canary 0.1.0 | Passed, canary 0.1.0 |

`Package.check` created a further isolated gem home for the runtime smoke,
independent of the broader development `GEM_PATH`. The canary's runtime dependency
remained `optparse`; it did not acquire a runtime dependency on the toolkit.

The baseline `bundle install --local` changed no source files. The upgrade changed
only two lockfile entries, in the GEM and CHECKSUMS sections:

```diff
-    ruby-repo-kit (0.1.0)
+    ruby-repo-kit (0.1.1)
```

All **31 non-lockfile source files** were byte-for-byte unchanged, including
application code, tests, Gemfile, gemspec, `.ruby-repo.yml`, RuboCop/Rake
integration, scripts, workflows and documentation. Coverage/package output is
excluded from this source comparison.

## Snapshot and artifact identity

Tree digests below hash the sorted sequence of
`relative_path + NUL + file_sha256 + newline`, using the exclusions above.
These describe this experiment's snapshots and artifacts, not a published release.

| Item | SHA-256 |
| --- | --- |
| Original canary source, 32 files | `da9b0619d021cc3d52ceb0c90270605e06280a6f91cf2d6eb8912ecf8178858e` |
| Unchanged canary non-lockfile source | `53b8506dffb3b90ae38ce5c3705ca30aa946749be6bb5dddfbe036abf2dda675` |
| Toolkit 0.1.0 source snapshot | `f32d0bc93fac2d235d5a00f0b065b6c62717a0c31cf192c7d24781fc55fb6f7d` |
| Toolkit 0.1.1 source snapshot | `98f8c4d7e42af63834837f93453f877a98e4e81d462381abf4a44b73280a11ab` |
| Toolkit 0.1.0 `.gem` | `21aa06837167a5af747fc55e620c03525753270f3d5da70ad656be39caa94f32` |
| Toolkit 0.1.1 `.gem` | `413dde00fecfb632a5ee8cb50a8c0928de42f89550dbb4a862b2fc850a098b0b` |
| Canary lockfile before | `08efc53fedf7a223757b5ab2c6ae3a51e072ef3f42c7ab2f4d8f046ad2a74d7c` |
| Canary lockfile after | `544b3e26e8248077549a60ec8f46e1c19a9d753d6c5818789799751fa265b7cd` |

All ten build/install/bundle/adoption/check commands exited 0. Raw command logs,
lockfile copies, JSON summary and the local harness are retained under the
ignored `tmp/upgrade-proof/` directory for this session. No repository was
committed, no remote was contacted, and no gem was published by this rehearsal.
