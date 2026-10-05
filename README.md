# Ruby Repo Kit

Versioned maintenance tools and a focused generator for Ruby CLI repositories.
Create a project once; share release, packaging, repository checks and lint
configuration through a development dependency.

Ruby Repo Kit is in initial development. [Current status](docs/STATUS.md) records
the local, hosted CI and publication gates separately. A configured release
workflow or a passing local test does not prove that RubyGems OIDC publication
has succeeded. The dedicated ruby-repo-canary must pass its acceptance gates
before Slipway or Rich-RI adopt the toolkit.

Requires Ruby 3.4 or newer. GitHub operations additionally require Git, the
authenticated GitHub CLI, and the relevant repository permissions. Releases use
signed commits and tags and require working Git signing configuration.

## Bootstrap from source

The toolkit develops and packages itself without depending on a published copy
of its own gem:

    bundle install
    bundle exec rake check
    bundle exec ruby-repo-kit --help
    bundle exec rake build

The build command prints the artifact path. Install that artifact with
gem install --local PATH_TO_ARTIFACT to exercise its installed executable and
templates. Development dependencies are installed by Bundler; installation of the
toolkit artifact is a separate validation step.

After a version has actually been published, it can also be installed from
RubyGems with gem install ruby-repo-kit.

## Create a CLI

    ruby-repo-kit new useful-cli --repository your-account/useful-cli --author "Your Name" --email you@example.com

Use --directory PATH to select another destination, including a path containing
spaces. Its parent directory must exist. Existing destinations, including
dangling symlinks, are rejected. Existing parent symlinks are resolved and the
command reports the canonical destination.

Generation creates files only: no Git repository, dependency installation,
GitHub resources or publication. The initial CLI prints text and provides help,
version, defined exit statuses and broken-pipe handling. The scaffold includes
tests, coverage, packaging, a shared lint preset, contribution documents,
dependency updates, CI and a release workflow.

Then enter the generated directory and run:

    bin/setup
    bundle exec rake check
    bundle exec rake audit

Commit the resulting Gemfile.lock. The configured toolkit version must be
available to dependency resolution. Before its first publication, a locally
installed toolkit artifact can support a local canary; hosted CI needs an
accessible distribution of that version.

## Adopt the shared tools

A consumer declares ruby-repo-kit in its Gemfile development/test group. Its
runtime gemspec must not depend on the toolkit. Existing projects need a reviewed
integration; the generator does not overwrite or migrate them.

The integration consists of:

- .ruby-repo.yml with project identity, release paths, commands and required checks.
- A Rakefile that installs RubyRepoKit::RakeTasks for that project.
- .rubocop.yml inheriting ruby-repo-kit's config/rubocop.yml.
- Optional thin executable wrappers such as bin/release.
- Project-owned CI and release workflow files.

Inspect the [architecture and configuration contract](docs/ARCHITECTURE.md) for
the Ruby API, ownership boundaries and configuration example.

## Check a repository

    bundle exec ruby-repo-kit doctor
    bundle exec rake check
    bundle exec rake audit

Doctor validates the local maintenance contract: required files, package
metadata, version consistency, package manifest, development dependency and
shared lint configuration. It does not certify code quality, run the full test
suite, or verify hosted settings.

The repository's check task combines lint, tests with coverage, structural checks
and installed-package smoke tests. The separate audit task updates the
vulnerability database and needs network access. Individual shared entry points
include repo:check, package:check, lint:commits and audit.

## Prepare and publish a release

Start with the prospective version in a configured repository:

    bundle exec ruby-repo-kit release 0.2.0 --dry-run

This inspects repository policy and release state and fetches Git refs. It does
not edit source files or change GitHub release state. Local main must match
origin/main, and the release needs a nonempty Unreleased changelog section.

To prepare the release:

    bundle exec ruby-repo-kit release 0.2.0

This creates or resumes the release branch, updates version/changelog/lockfile,
runs generation and checks, makes a signed commit, pushes the branch and opens
or reuses a pull request. It is a write operation even without --push.

After reviewing the release:

    bundle exec ruby-repo-kit release 0.2.0 --push

The additional --push option waits for checks, merges the exact release PR head,
signs and pushes a tag for the merge commit, and follows the hosted release run.
Use --branch hotfix/MAJOR.MINOR to target a maintenance branch for that version.
The --dry-run and --push options are mutually exclusive.

Rerunning the same version inspects existing PRs, tags and workflow runs before
continuing. Existing release tags are never moved. If RubyGems publication
succeeded but GitHub release creation failed, recovery reports the narrower
GitHub retry; it does not silently publish the gem again.

The hosted workflow builds and tests one gem artifact. Subsequent attestation,
RubyGems publishing and GitHub release creation use that artifact and verify its
SHA-256 digest. Publication uses the configured release environment and RubyGems
Trusted Publishing. The publisher must be configured separately on RubyGems;
GitHub policy setup does not register it.

The workflow's manual dry_run option rehearses build/verification without
publication. A matching version tag can publish once the external configuration
is in place. See [the acceptance plan](docs/PLAN.md) for the initial canary sequence.

## Inspect and configure GitHub

    bundle exec ruby-repo-kit github plan
    bundle exec ruby-repo-kit github verify
    bundle exec ruby-repo-kit github apply

Plan and verify read the configured repository. Apply reads its current state,
then applies the planned changes and verifies the result. It changes repository
settings; review a plan before choosing to apply it.

The initial policy is for personal repositories: signed commits, PR-based merge
commits, named required checks, protected release tags, a release environment
restricted to version tags, dependency/security settings, and the skip-changelog
label. It does not require another person's approval. Existing reviewer/timer
environment protections and unmanaged rules are preserved where supported;
unknown protections or unreadable settings stop reconciliation. Additional
deployment branch policies in the managed release environment are removed.
Administrator access and availability of these GitHub features are prerequisites.

## Update without copying scripts

    bundle update ruby-repo-kit
    bundle exec rake check

Review and commit the dependency/lockfile change. Shared operations and the
inherited lint preset then use the new version. Templates affect newly generated
projects; updating the dependency does not rewrite existing application code,
tests, documentation or local workflow YAML. Integration changes are explicit
reviewed edits. During the initial 0.x series, review release notes for each update.

## Contributing and license

See [contributing](CONTRIBUTING.md), [security](SECURITY.md),
[conduct](CODE_OF_CONDUCT.md), [decisions](docs/DECISIONS.md) and the
[implementation plan](docs/PLAN.md).

MIT, Copyright (c) 2026 Highlander Paiva. Release tooling incorporates code adapted
from Highlander Paiva's Slipway and Rich-RI projects under the same MIT license.
See [LICENSE.txt](LICENSE.txt).
