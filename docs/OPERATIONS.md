# Ruby Repo Kit operations

Applies to published toolkit 0.1.1. The actual toolkit/canary publication and
recovery evidence is in [CYCLE_0_1_1.md](evidence/CYCLE_0_1_1.md); consult
[STATUS.md](STATUS.md) for current acceptance and consumer migration state.

Commands below run at the consumer repository root unless stated otherwise.
Replace the example identity and version deliberately:

```sh
rrk_repository=your-account/useful-cli
rrk_name=useful-cli
rrk_version=0.2.0
rrk_tag="v$rrk_version"
```

Ruby 3.4+, Bundler, Git, an authenticated gh CLI and working Git commit/tag
signing are prerequisites. Network-dependent operations require access to their
services. Repository-policy verification currently requires administrator access.
Only stable X.Y.Z release versions are supported; base branches are main or the
matching hotfix/MAJOR.MINOR. Do not pass prerelease versions or arbitrary branches.

## Create a new CLI

Install the published toolkit version used by these procedures:

```sh
gem install ruby-repo-kit --version 0.1.1
ruby-repo-kit --version
ruby-repo-kit new useful-cli --repository your-account/useful-cli --author "Your Name" --email you@example.com
cd useful-cli
bin/setup
bundle lock --add-checksums
bundle exec ruby-repo-kit doctor
bundle exec rake check
bundle exec rake audit
```

Confirm --version reports the intended installed generator. Use --directory PATH
to select another destination. Its parent must exist; generation refuses an
existing destination. Generation writes files only: it does not initialize Git,
install dependencies, create GitHub resources or register a RubyGems publisher.

Review the generated files and replace placeholder product behavior/documentation.
Keep initial release notes under Unreleased; the initial VERSION can already be
0.1.0 without a historical 0.1.0 changelog entry. Commit Gemfile.lock, including
checksums populated from the registry. Do not use an unpublished toolkit, a local
path dependency or a workstation cache as a substitute for hosted resolution.

For a new public repository, after reviewing the files and final name:

```sh
git init -b main
git add .
git commit -S -m "chore: bootstrap useful-cli"
git verify-commit HEAD
gh repo create your-account/useful-cli --public --source=. --remote=origin --push
```

This creates public resources. Check GitHub and RubyGems name availability before
choosing the identity. Inspect hosted CI, then plan and explicitly apply policy:

```sh
bundle exec ruby-repo-kit github plan
bundle exec ruby-repo-kit github apply
bundle exec ruby-repo-kit github verify
```

Review the plan before apply: it reconciles repository merge/security settings,
managed branch/tag rulesets, required checks and release-environment restrictions.
Additional deployment branch policies in that managed environment are removed.
Do not apply the scaffold's required-check names to a different CI layout.
For a new gem, its owner must separately create a pending RubyGems trusted
publisher with the exact gem, GitHub owner/repository, workflow filename
release.yml and environment release. Same-repository workflows leave the optional
workflow-repository fields blank. Existing gems use their own trusted-publisher
settings. See the [RubyGems setup guide](https://guides.rubygems.org/trusted-publishing/).

The ruby-repo-kit and ruby-repo-canary registrations have already been exercised
successfully by their 0.1.0 and 0.1.1 publications. That does not register a publisher for
the next gem. GitHub policy apply never changes the RubyGems account.

## Adopt an existing repository

Use an isolated integration branch after any project-specific acceptance gates.
Recapture the consumer's current HEAD, clean/dirty state, package manifest and
runtime dependencies, installed CLI behavior, CI contexts, quality thresholds,
generated files, release workflow and live repository policy.

1. Add ruby-repo-kit to the Gemfile development/test group, with a reviewed
   constraint such as ~> 0.1.1. Never add it to runtime gemspec dependencies.
2. Add schema-1 .ruby-repo.yml with the real names, relative paths, argv commands,
   required-check names and existing workflow/environment identity. Mark only
   actual generated release artifacts as generated_paths.
3. Compose the documented CLI/Rake APIs. Remove old release engines, competing
   publisher tasks and auto-loaded rakelib actions before installing shared tasks.
   Keep product-specific CI, commit-policy and installed-package assertions local.
4. Inherit the shared RuboCop preset and retain deliberate local thresholds and
   exclusions. Review workflow integration as source code; do not overwrite it
   with a newly generated template.
5. Run doctor, the consumer's full checks, audit, isolated artifact smoke and
   hosted CI. Compare package contents, runtime dependencies and behavior with
   the baseline. Review github plan separately and preserve intentional policy.
6. Submit and merge a normal dependency/integration PR after required checks.
   Record how to reverse its dependency and adapter changes.

The two policy booleans default to true:
protect_hotfix_branches and require_review_thread_resolution. Explicit false
values preserve a main-only ruleset and a policy without mandatory review-thread
resolution. Both accept actual YAML booleans only. Main, signature, tag, merge
and required-check protections are otherwise retained. The canonical CLI and
release recovery read the same project data; no hidden policy wrapper is needed.

## Upgrade through a dependency PR

Read the toolkit release notes and identify the version actually published.
Create a consumer branch, adjust its Gemfile constraint if necessary, then:

```sh
bundle update ruby-repo-kit
bundle exec ruby-repo-kit --version
git diff -- Gemfile Gemfile.lock
bundle exec ruby-repo-kit doctor
bundle exec rake check
bundle exec rake audit
bundle exec ruby-repo-kit github plan
```

Review every resolved dependency change. Commit the Gemfile/lockfile and any
explicit integration changes, update the consumer changelog according to its
policy, and use its normal protected PR workflow. Hosted CI must resolve the
published gem and pass the supported platform/Ruby matrix. Do not replace the
whole lockfile with a generated one.

The upgrade changes shared algorithms and inherited lint configuration. It does
not regenerate application code, tests, documentation or workflow YAML, and it
does not apply remote repository policy. Treat a nonempty github plan as a
separate administrative decision, not an automatic dependency-update side effect.

### Compatibility in 0.1.x

Patches in a 0.MINOR series preserve documented integration interfaces. A breaking
integration change requires a minor version, release notes and migration guidance.
Corrections may reject previously accepted invalid configuration. New templates
affect new projects only. Internal service classes are not stable consumer APIs.

Alongside CLI.run and RakeTasks.install(project:), 0.1.1 documents:

- RakeTasks.install_release(project:): only release tasks; the consumer supplies
  build. It refuses an already registered release task before changing tasks.
- Package.new(project:, out:), build(output: nil), and
  check(artifact: nil, environment: {}): an explicit artifact is installed without
  rebuilding; the block receives effective environment, gem home and working
  directory for local smoke assertions.

Environment overrides apply before generic help/version smoke, but GEM_HOME,
GEM_PATH, RUBYOPT, RUBYLIB, BUNDLER_SETUP, RUBYGEMS_GEMDEPS, XDG_CONFIG_HOME and
NO_COLOR remain package-owned. Do not depend on overriding these controls.
See [the integration contract](ARCHITECTURE.md) for configuration and Ruby examples.

## Prepare, review and publish

Start from a clean main matching origin/main, or the matching maintenance branch.
The configured origin must identify the exact GitHub repository. Release notes
must contain a nonempty Unreleased bullet section and valid historical links.

```sh
git status --short
git fetch origin --tags
git switch main
git pull --ff-only
bundle exec ruby-repo-kit release 0.2.0 --dry-run
```

The plan verifies live GitHub policy, fetches refs and inspects the appropriate
release state/metadata. It does not edit working files or GitHub release state.
It is not offline and does not execute the full quality suite.

```sh
bundle exec ruby-repo-kit release 0.2.0
```

Even without --push, this is a write operation. It creates or resumes
release/v0.2.0, updates version/changelog/lockfile, runs generation and the
configured full checks, signs a commit, pushes the branch and opens/reuses a PR.
Review that PR and its checks before the final step.

For a nonpublishing hosted rehearsal of that prepared branch:

```sh
gh workflow run release.yml --repo "$rrk_repository" --ref release/v0.2.0 -f dry_run=true
gh run list --repo "$rrk_repository" --workflow release.yml --branch release/v0.2.0 --limit 5
```

Record the selected run ID and head SHA. Inspect/watch that exact run; a branch
name alone is insufficient if the PR changes. The generated workflow also runs
artifact attestation in a dry run, while publish and github-release are skipped.
A successful rehearsal does not prove RubyGems authentication or publication.
[Manual dispatch syntax](https://cli.github.com/manual/gh_workflow_run).

```sh
bundle exec ruby-repo-kit release 0.2.0 --push
```

This validates the exact release PR head, waits for its checks, merges using that
head, verifies ancestry, signs an annotated tag at the merge commit, pushes the
tag and follows its release run. The hosted workflow builds one artifact, verifies
installed behavior, attests it, publishes those bytes and creates the GitHub
Release. --push and --dry-run cannot be combined.

For 0.2.1 from a maintained branch, append --branch hotfix/0.2 to every release
command, including retries. That base branch must already exist. A policy setting
that omits hotfix protection does not create or prohibit a maintenance branch.

release:verify is a local metadata check. It does not verify live GitHub settings,
run the full suite, publish a gem or apply policy. Use github verify explicitly
for settings; the release CLI also performs that verification as a preflight.
Only github apply mutates the managed settings. The Rake release task is the
guarded publisher used inside tagged Actions; it is not the local preparation
command. Do not manufacture Actions environment variables to run it locally.

## Diagnose before retrying

Collect the tag, exact merge/head SHA, run ID and current jobs:

```sh
git fetch origin --tags
git status --short
git verify-tag "$rrk_tag"
git rev-parse "$rrk_tag^{commit}"
gh run list --repo "$rrk_repository" --workflow release.yml --branch "$rrk_tag" --limit 20 --json databaseId,headSha,event,status,conclusion
gh run view RUN_ID --repo "$rrk_repository" --json status,conclusion,jobs
gh run view RUN_ID --repo "$rrk_repository" --log-failed
gh release view "$rrk_tag" --repo "$rrk_repository" --json tagName,isDraft,assets,url
gh api "repos/$rrk_repository/releases/tags/$rrk_tag" --jq '{draft, immutable, tag_name, assets: [.assets[].name]}'
```

Run tag commands only once a tag exists. A missing GitHub Release is evidence to
investigate, not permission to repeat gem push. Use databaseId from the jobs JSON
for --job, not a copied browser job identifier.
[Job-ID guidance](https://cli.github.com/manual/gh_run_rerun).

### Local preparation or open PR

For failure after version/changelog edits, remain on the same release/vX.Y.Z.
Inspect git status and git diff; fix the actual check failure or local prerequisite,
then repeat the same release command/version. Recovery accepts only declared
release files, preserves the prepared date and reruns generation/checks before
committing. It rejects unexpected metadata edits and unrelated files rather than
discarding them. There is no release reset or force flag.

If the signed release commit exists but pushing/opening the PR failed, the same
command rechecks and reuses it. If the PR already exists, the local release branch
must match its recorded remote head. Push only reviewed signed changes and let
CI run again. A closed, unmerged release PR must be explicitly reopened before
retrying; do not create a second PR with the same release head.

The retry does not integrate a moving base branch or resolve merge conflicts.
Handle those through normal reviewed Git operations, preserve unrelated work,
and recheck the resulting release metadata. Repeated --dry-run validates existing
PR metadata/signature but does not repair it or run the full suite.

### Merged PR, tag not pushed

Repeat the same release command with --push from the configured base or release
branch and a clean worktree. A valid existing signed local tag is reused. A tag
pointing at another commit, an unsigned/lightweight tag, multiple matching PRs or
a remote tag without the matching merged release PR causes a stop for inspection.
Do not delete or move tags to make the command continue.

### Tag exists, publication never started

If the run's publish job is absent/skipped because an earlier check failed,
identify that failure first. For a transient service/environment problem that
requires no source change, the toolkit reports:

```sh
gh run rerun RUN_ID --failed --repo "$rrk_repository"
gh run watch RUN_ID --repo "$rrk_repository" --exit-status
```

This retry can proceed into publication on a tag; it is not another dry run.
Confirm publish really did not start. If it ran and failed/cancelled, use the
uncertain-result procedure below instead.

GitHub reruns retain the original source SHA/ref. A fix committed on main does
not repair the tagged run. Source/workflow defects that cannot be corrected by
environment changes require a reviewed new release version; retain the old tag
and document the abandoned attempt.
[GitHub rerun semantics](https://docs.github.com/en/actions/how-tos/manage-workflow-runs/re-run-workflows-and-jobs).

If no run exists, inspect Actions/workflow availability and exact tag identity.
Only after confirming no publication attempt or accepted version, an operator
can intentionally dispatch the existing tag with:

```sh
gh workflow run release.yml --repo "$rrk_repository" --ref "$rrk_tag" -f dry_run=false
```

That is a publishing operation. Monitor its exact run ID. The toolkit recognizes
a successful manual recovery only when publish and github-release both succeeded;
a successful manual dry run does not count as a release.

### RubyGems succeeded, GitHub Release failed

When publish is success and github-release failed, first inspect whether GitHub
Release creation partially succeeded. If it does not exist, correct the concrete
GitHub-side problem and retry only the terminal github-release job:

```sh
gh run rerun RUN_ID --job GITHUB_RELEASE_DATABASE_ID --repo "$rrk_repository"
gh run watch RUN_ID --repo "$rrk_repository" --exit-status
```

This job has no downstream jobs in the generated workflow. It downloads the
existing release-gem artifact and verifies the original checksum; it does not
invoke the publisher. Do not rerun the whole workflow or the publish job.
GitHub's endpoint reruns the chosen job and its dependent jobs, not its successful
prerequisites.
[GitHub job rerun API](https://docs.github.com/en/rest/actions/workflow-runs#re-run-a-job-from-a-workflow-run).

Record jobs from each `/actions/runs/RUN_ID/attempts/ATTEMPT/jobs` endpoint,
original timestamps/logs, tag object and registry `created_at`/SHA before and
after. GitHub can assign new job IDs to carried successes, so IDs alone do not
prove whether a publisher executed again. The real canary 0.1.1 exercise in
[CYCLE_0_1_1.md](evidence/CYCLE_0_1_1.md) demonstrates this terminal-job recovery.

If a release already exists, inspect its draft/immutable state, notes and every
existing asset before retrying gh release create: that command is not idempotent.
Drafts can receive missing verified assets; a published immutable release cannot.
Never use --clobber to replace an existing gem asset. If complete, record the
actual state without pushing the gem again. See manual reconciliation below.

### RubyGems publication result is uncertain

A timeout, cancelled job or failed gem push step does not establish that RubyGems
rejected the version. Stop publishing retries and inspect the logs plus the exact
version endpoint, not the latest-version endpoint:

```sh
curl --fail --silent --show-error "https://rubygems.org/api/v2/rubygems/$rrk_name/versions/$rrk_version.json?platform=ruby"
```

The response includes version/platform and sha; compare that SHA256 with the
retained Actions artifact and independently downloaded registry gem. An API
error or one missing response alone is insufficient to resolve an interrupted
request. Recheck the registry/service state and owner-visible version before a
human decides whether any retry is appropriate.
[Version API](https://guides.rubygems.org/rubygems-org-api/#get---apiv2rubygemsgem-nameversionsversion-numberjsonyaml-api-v2).

- Accepted, matching bytes: never retry publish. Complete only the GitHub Release
  from the original artifact. The toolkit does not query RubyGems automatically
  or rewrite a failed publish job to success.
- Accepted, different bytes: stop and investigate identity/provenance. Do not
  overwrite assets, move tags or attempt to republish that version.
- Confirmed not accepted: after correcting the failure, the operator can rerun
  the failed job(s) from the same run. If the failure needs a source change, use
  a new version rather than altering the tagged source.
- Still uncertain: keep the release stopped and retain evidence. Do not turn an
  ambiguous outcome into a blind full-workflow retry.

### Independent byte checks and manual GitHub reconciliation

Use an empty evidence directory and the original run ID; never rebuild merely
to recover missing assets. The generated workflow's artifact name is release-gem.

```sh
rrk_evidence=$(mktemp -d)
gh run download RUN_ID --repo "$rrk_repository" --name release-gem --dir "$rrk_evidence/actions"
curl --fail --location --silent --show-error "https://rubygems.org/downloads/$rrk_name-$rrk_version.gem" --output "$rrk_evidence/registry.gem"
ruby -rdigest -e 'puts Digest::SHA256.file(ARGV.fetch(0)).hexdigest' "$rrk_evidence/registry.gem"
ruby -rdigest -e 'puts Digest::SHA256.file(ARGV.fetch(0)).hexdigest' "$rrk_evidence/actions/$rrk_name-$rrk_version.gem"
cat "$rrk_evidence/actions/SHA256SUMS"
```

All three digests must match the original verify job's SHA256 and registry API
sha. Also inspect the retained notes, exact signed tag/merge identity and
attestation. For the same-repository generated workflow:

```sh
gh attestation verify "$rrk_evidence/actions/$rrk_name-$rrk_version.gem" --repo "$rrk_repository" --signer-workflow "$rrk_repository/.github/workflows/release.yml" --source-digest EXACT_RELEASE_MERGE_SHA --source-ref "refs/tags/$rrk_tag" --format json
```

This constrains repository, workflow, tagged ref and source identity in addition to the
artifact signature. Preserve the JSON evidence.
[Attestation verification](https://cli.github.com/manual/gh_attestation_verify).

Only after RubyGems acceptance and artifact identity are confirmed, and only if
the GitHub Release is absent, the equivalent GitHub-only completion is:

```sh
gh release create "$rrk_tag" --repo "$rrk_repository" --verify-tag --title "$rrk_tag" --notes-file "$rrk_evidence/actions/release-notes.md" "$rrk_evidence/actions/$rrk_name-$rrk_version.gem" "$rrk_evidence/actions/SHA256SUMS"
```

For an existing release, download its assets to another directory and verify
their digests. If creation stopped as a draft, upload only an individually
confirmed missing asset with gh release upload, without --clobber; then publish
with gh release edit TAG --draft=false after notes/assets are complete and verified.

The toolkit's GitHub policy enables immutable releases. Once published, such a
release cannot accept, replace or delete assets. If its assets are incomplete,
retain the evidence and plan a reviewed new version; do not disable immutability,
delete the release or move its tag to repair the old one. Notes/title can still
be corrected. A legacy mutable release must be identified explicitly before any
asset addition; keep the same identity checks and never replace existing bytes.
[GitHub release immutability](https://docs.github.com/en/repositories/releasing-projects-on-github/managing-releases-in-a-repository#editing-a-release).

Manual reconciliation outside a successful workflow does not turn the original
run green. Record the failure, registry acceptance and manual completion; the
release CLI can continue to report the old failed run. Do not claim automatic
recovery or retry RubyGems merely to obtain a green status. If original artifacts
have expired or identity cannot be established, escalate to a reviewed recovery
decision; a rebuild is not proof of the original published bytes.

## Confirm completion

Verify successful publish and github-release jobs, exact tag/merge identity,
registry version/bytes, GitHub release assets and attestation. Exercise the
downloaded gem outside the checkout using the documented Package#check artifact
argument and the consumer's domain smoke tests. A green CI or dry run alone is
not evidence of an accepted publication.

Repeating the same release command after a successful hosted publication reuses
the successful run without a new tag or upload. Record that as completed-release
idempotence; distinguish it from an injected failure/recovery exercise.

## Roll back tooling through a PR

Create a consumer branch. Pin a previously accepted toolkit version exactly in
the Gemfile, restore any corresponding adapter/configuration changes, then resolve
and review the lockfile:

```sh
bundle update ruby-repo-kit
bundle exec ruby-repo-kit --version
git diff -- Gemfile Gemfile.lock
bundle exec ruby-repo-kit doctor
bundle exec rake check
bundle exec rake audit
```

The preceding step requires editing the Gemfile to the chosen exact version;
bundle update alone does not select an older version. Compare the resulting
lockfile with the known-good one and preserve unrelated dependency updates.
Reverting a dedicated upgrade commit is also possible, but resolve conflicts and
review any old lockfile entries reintroduced by that revert.

An integration using APIs first documented in 0.1.1 cannot simply select 0.1.0:
it also needs compatible adapter/configuration reversal. Keep the rollback scoped
to tooling, retain product behavior and run normal hosted checks before merging.
Remote settings previously applied are independent: review an explicit github
plan/apply if policy itself must change. Never weaken required checks or signatures
as a shortcut to merging the rollback.

Rollback changes future maintenance operations. It does not modify a published
consumer gem. To correct an already published product, prepare a new version.
Never move/delete a release tag or republish an existing version as a rollback.

## Evidence to retain

For each adoption, upgrade, release or recovery record the toolkit version,
consumer commit, command, platform/Ruby version, run/PR URLs, event/ref, exact
artifact SHA256, registry response and remaining limitations. Keep credentials
out of logs. Distinguish local checks, hosted rehearsal, accepted publication,
completed-release idempotence and recovery after a demonstrated failure.

Implementation references: lib/ruby_repo_kit/cli.rb, rake_tasks.rb,
release/workflow.rb, release/preparation.rb, release/publication.rb,
release/artifact.rb, release/publisher.rb and the consumer's actual release.yml.
The project-owned workflow can differ from the template: inspect it before using
the job names and repair commands in this guide.
