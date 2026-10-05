# Local failed-preparation recovery evidence

Observed on 2026-10-04 at 22:07:51–22:07:55 America/Sao_Paulo
(2026-10-05 01:07 UTC), using Ruby 4.0.7 on x86_64 Linux and Bundler 4.0.22.

**Passed:** a temporary copy of the real generated `ruby-repo-canary` recovered
from a failure after metadata edits and successful real checks. The retry used a
clock one day later, preserved the original prepared date and version/changelog
bytes, and produced exactly one signed release commit on the same release branch.
The original canary remained byte-for-byte unchanged and its worktree stayed clean.

This establishes local preparation recovery. Git and consumer checks were real;
GitHub policy and PR responses were strict simulations. No public remote was
contacted, no tag or hosted release was created, and no gem was published. This
does not satisfy the hosted CI/OIDC gates required before migrating existing repos.

## Reproduction

From the toolkit root, with the toolkit artifact already installed locally and
the canary's development dependencies available:

```sh
ruby script/rehearse_canary.rb \
  --source ../ruby-repo-canary \
  --gem-home tmp/installed-toolkit/gems \
  --output tmp/recovery-local
```

The script loads the release engine from the current toolkit source. Its real
consumer subprocesses load the installed `ruby-repo-kit` gem, using the specified
`GEM_HOME` plus this interpreter's `Gem.default_dir` in `GEM_PATH`. Inherited
Bundler state, `RUBYOPT` and `RUBYLIB` are cleared for these subprocesses. This run's
installed toolkit was 0.1.0; it was not a `path:` dependency in the consumer.

The command requires working Git signing and verification in the caller's normal
Git configuration. It never disables signing or bypasses hooks. It fails and
records the limitation if the configured signing capability is unavailable.

## Method and results

1. Fingerprint the real canary and copy its source into a temporary directory,
   excluding `.git`, `.bundle`, `coverage`, `pkg`, `tmp`, and `vendor`. The captured
   canary commit was `c295b44743a8e71fb6f18e0b4983318d38d8aa85`.
2. Add a rehearsal changelog note only in that copy and initialize real Git
   repositories: a working repository and a temporary bare origin. Create and
   verify a signed initial commit. Git operations retain the configured GitHub
   origin identity, but `fetch`, `push` and `ls-remote` use a per-command
   `url.file://….insteadOf` mapping. `GIT_ALLOW_PROTOCOL=file` forbids Git network
   transports. GitHub calls never execute a `gh` process.
3. Run release preparation for 0.1.1, with a temporary external check wrapper.
   The wrapper runs the real `bundle exec rake check`, then exits 73 once with
   `INJECTED_REHEARSAL_FAILURE_AFTER_REAL_CHECKS`. The release engine reports
   failure. `CHANGELOG.md`, `Gemfile.lock` and the version file remain prepared;
   the branch remains `release/v0.1.1`. No release commit, remote release branch
   or simulated PR exists at this point.
4. Retry using the same project and branch, advancing the injected clock from
   2026-10-05 to 2026-10-06 UTC. The real checks run again. The engine preserves
   the existing 2026-10-05 date and the exact prepared version/changelog bytes,
   creates one signed release commit, pushes it to the local bare repository,
   and opens exactly one simulated PR. The worktree is clean afterward.
5. Verify the release commit with real `git verify-commit`; compare its SHA to
   the bare repository's branch; confirm exactly one commit since the initial
   commit and zero tags. Recompute the original source fingerprint. All pass.

Both real check runs reported **7 tests, 29 assertions, no failures/errors/skips**,
100% line and branch coverage, and **11 linted files with no offenses**. Both
also passed repository/generated-file checks and built and installed the
0.1.1 canary artifact into an isolated gem home for its runtime smoke check.

Git reported a good SSH signature for both commits using the caller's existing
ED25519 signing configuration. The temporary release commit was
`10e1228da6dcf7217cb8b85648f4aa65fa2768f1`; it is local evidence, not a commit in
the original canary or a public repository.

The GitHub policy verifier was an explicit stub. The command fake accepts only
the exact expected `gh pr list` and `gh pr create` arguments, including repository
identity and a real PR body file; any unexpected GitHub command fails the rehearsal.
The returned PR URL uses `example.invalid`. Merge, tag, workflow execution,
GitHub environment/ruleset enforcement, RubyGems authentication and publication
remain untested by this script.

## Identity and retained evidence

| Item | SHA-256 |
| --- | --- |
| Unchanged real canary source snapshot | `2a38fc7ba3972eccd83567d3206215494bed0d77d19894b64bbb6aea8f768105` |
| Installed toolkit 0.1.0 artifact | `73f331a40e8f8765ae1e073c3c3f637d123c2999fa1a441483b9f355ce6b5eb3` |
| Source release-engine snapshot | `542922c97ae758f0f83091d72708dc46ffee65fef1ca4f4d86d42a8f4c32bdaf` |

The source snapshot hashes the JSON encoding of the sorted map from relative
source filenames to file SHA-256 values. The release-engine snapshot hashes the
concatenation of sorted `lib/ruby_repo_kit/release*.rb` and
`lib/ruby_repo_kit/release/*.rb` contents. These algorithms differ from the
upgrade rehearsal's tree digest and are not interchangeable.

Raw command/output logs and the machine-readable report for this run remain in
ignored `tmp/recovery-20261005T010751Z.log` and `.json`. The script writes both
reports on failure as well as success and removes its temporary working copy and
bare repository afterward. Its transport fake is in
`script/support/canary_rehearsal_transport.rb`. Scoped RuboCop passed for both
script files without suppressions. The same experiment had also passed before
the final script refactoring at 01:02:59–01:03:04 UTC.
