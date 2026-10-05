# Published toolkit adoption and local recovery

Observed 2026-10-05 UTC on Linux/Ruby 4.0.7 and Bundler 4.0.22. This experiment
uses the actual published ruby-repo-kit 0.1.0 and 0.1.1 gems, not rebuilt or
version-only local substitutes. It supplements the protected consumer update and
hosted second-release evidence in [CYCLE_0_1_1.md](CYCLE_0_1_1.md); it does not
itself publish a consumer or simulate successful RubyGems authentication.

## Published artifacts and source identity

The consumer is an archive of ruby-repo-canary's published tag `v0.1.0`, commit
`2604a94dd4d28da7383d0a781997ac7c64524c17`. Its source was extracted to a temporary
directory outside all repository worktrees. The original canary was never edited
by this experiment.

Toolkit 0.1.0 came from the cache populated from its published RubyGems artifact.
Toolkit 0.1.1 was downloaded directly from
[the published gem](https://rubygems.org/downloads/ruby-repo-kit-0.1.1.gem), and its
SHA256 matched the [version API](https://rubygems.org/api/v2/rubygems/ruby-repo-kit/versions/0.1.1.json)
and the digest independently recorded from
[release run 37254345206](https://github.com/hvpaiva/ruby-repo-kit/actions/runs/37254345206).
The API recorded creation at `2026-10-05T02:12:30.860Z`; the toolkit release merge
was `b02066722fe49b68024c45a4491d4a3cf0e3b6e6`.

| Published gem | SHA256 |
| --- | --- |
| ruby-repo-kit 0.1.0 | `a740c0bc435d455a2b03a36dc84b441dabe8c39a3f14bb66b0251f8e6986755f` |
| ruby-repo-kit 0.1.1 | `3a4c3676690f8cd82779d8f7ae8e6dc25d17d25afbe7866ca3503a8cef0673dd` |

Each artifact was installed using `gem install --local --no-document --norc`
with a dedicated GEM_HOME/GEM_PATH. Dependency checking remained enabled; no
`--ignore-dependencies` or `--install-dir` was used. Consumer development commands
could see the published dependency cache and the interpreter's normal gems;
`package:check` separately isolated the installed consumer runtime. Probes before
and after adoption required the loaded toolkit version and installed path to
match the dedicated gem home and its lockfile source to be
`Bundler::Source::Rubygems`.

## Behavioral adoption: same consumer, newer tooling

The final acceptance run took place at 02:15:36–02:15:58 UTC. The consumer's
Gemfile remained unchanged with its normal RubyGems source and
`ruby-repo-kit (~> 0.1.0)` dependency. After installing the verified published
artifact, the copy ran:

```sh
bundle update ruby-repo-kit --conservative
bundle exec rake check
```

Normal RubyGems resolution updated exactly two lines in Gemfile.lock: the toolkit
version, and its version/checksum entry. No other dependency changed. All **31
source files outside Gemfile.lock** remained byte-for-byte identical, including
application code, workflows, Rake adapters, gemspec, configuration and tests.
The consumer application version remained 0.1.0.

The harness removed only the `sha256=...` value from `rake (13.4.2)` in CHECKSUMS,
ran `bundle exec ruby-repo-kit doctor`, and restored the original lockfile bytes:

| Installed toolkit | Same missing rake digest | After restoring the digest |
| --- | --- | --- |
| 0.1.0 | Exit 0: defect was not detected | Exit 0 |
| 0.1.1 | Exit 1: identifies `rake-13.4.2` and recommends `bundle lock --add-checksums` | Exit 0 |

The doctor calls left the incomplete lockfile unchanged in both versions. The
behavior therefore arrived through the development dependency update, with no
copied check implementation or application edit.

Full `rake check` passed before adoption, after adoption, and after restoring the
injected defect: **7 tests / 29 assertions, no failures/errors/skips; 11 Ruby files
linted clean; 100% line and branch coverage; independently installed consumer gem
passed its smoke checks**.

| Source identity | SHA256 |
| --- | --- |
| Original canary archive, all 32 source files | `c933b8367b80156a742c610c73a5b18d4ea4b39e74fa293ecddcf36491935f94` |
| Unchanged 31 non-lock files | `3f7921400de3454f32a903e10a1961d6d9b55d3f0d1cc3ac4b38ca979683e5bf` |
| Gemfile.lock before | `85787a539b67aafa41e6f08b112b32f183666df85c4c84f58b1f7cc084b5e674` |
| Gemfile.lock after | `4212dc32bcdab841819b666ef8949ecbb6a5722035caeb1866736fbc6c26a973` |

Tree digests hash sorted `relative_path + NUL + file_sha256 + newline` entries.
Generated package/coverage output and Git/Bundler working state are excluded.

## Recovery using the published 0.1.1 engine

At 02:16:38–02:16:43 UTC, the already-upgraded consumer copy entered a separate
local release-preparation rehearsal. A temporary copy of the recovery harness
explicitly activated `ruby-repo-kit = 0.1.1` and required the release engine from
the installed published gem. Both engine and consumer commands recorded the
same artifact SHA256 above. This improves on the earlier rehearsal, whose engine
came from the development checkout.

The experiment used real Git repositories and signatures, with fetch/push/remote
lookups redirected to a temporary local bare repository. Git transport was
restricted to `file`. GitHub configuration verification and the exact expected
PR list/create responses were strict simulations; no `gh` process executed.

1. Add a rehearsal note only in the temporary copy; prepare consumer 0.1.1.
2. Run the real full checks, then deliberately exit 73 with
   `INJECTED_REHEARSAL_FAILURE_AFTER_REAL_CHECKS` before a release commit or push.
3. Retry with the clock advanced one day. The prepared date stayed 2026-10-05,
   despite the retry clock being 2026-10-06; prepared version/changelog bytes
   remained identical.
4. Complete exactly one signed release commit and one simulated PR. Verify the
   commit signature and identity against the local bare branch; require a clean
   worktree and zero tags afterward.

Both check runs passed **7 tests / 29 assertions, zero failures/errors/skips,
11 linted files, 100% lines/branches, and isolated installation of the temporary
consumer 0.1.1 gem**. The local release commit was
`02cce8edcb7bffcd10cbb781c6fbe77a3777d8b3`; its real signature verified. Temporary
Git repositories were removed afterward. The upgraded input copy retained its
exact pre-rehearsal manifest.

This proves failed-preparation recovery with published tooling, real consumer
checks and local Git operations. It does not inject a failure into hosted
publication, test GitHub policy enforcement during that simulated recovery, or
establish OIDC behavior; those require the separate hosted release evidence.

## Observed failure and harness correction

An earlier all-local attempt used `bundle update --local`. It adopted 0.1.1 but
left that gem's checksum empty. The new repo:check correctly stopped the run with
its repair instruction. That failed attempt is retained as additional evidence;
it was not treated as a successful acceptance run or bypassed.

That attempt also exposed a harness limitation: keeping the consumer under a
worktree's ignored `tmp` hierarchy caused RuboCop to inspect zero files. The final
experiment above restarted from the tag archive outside the worktree, used normal
RubyGems resolution, and explicitly confirmed all 11 consumer files were linted.
Only that complete rerun supplies the acceptance results above.

## Retained raw evidence

Under the `ruby-repo-kit-lockfile-preflight` worktree:

- `tmp/published-adoption/summary.json`, command logs and before/after lockfiles.
- `tmp/published-adoption/downloads/`: published gem and registry response.
- `tmp/published-adoption/rehearse.py`: artifact installation/adoption harness.
- `tmp/published-adoption/recovery/`: temporary recovery harness and strict transport.
- `tmp/published-adoption/recovery-published-0.1.1.{json,log}`: full recovery report.
- `tmp/published-adoption-local-attempt/`: earlier rejected local-update attempt.

The standalone adoption copy remains at the temporary path recorded in
summary.json for inspection. No product source, original canary source, version
tag, hosted remote branch or publication was changed by these experiments.
