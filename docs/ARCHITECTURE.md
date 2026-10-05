# Architecture and integration contract

Ruby Repo Kit is one Ruby gem with separate internal components for generation,
local checks, packaging, release and GitHub policy. Its CLI and Rake tasks are
adapters. It has one scaffold profile: an executable Ruby gem.

## Ownership and updates

| Content | Owner | How it changes |
| --- | --- | --- |
| Application code, executable, tests, README and other product documents | Consumer | Normal project edits |
| Release, packaging and repository-check algorithms | Toolkit | Dependency update |
| Shared RuboCop baseline | Toolkit, with consumer overrides | Dependency update |
| Consumer Rakefile, configuration and workflow YAML | Consumer | Reviewed integration edits |
| GitHub repository settings | Repository administrator, under explicit toolkit policy | Plan, then explicit apply |
| RubyGems trusted publisher | Gem owner | Separate RubyGems configuration |

Generation copies the starting files once. There is no generic template reapply,
merge engine, plugin registry or framework controlling the application.
Introducing a library scaffold or separating packages requires a concrete
consumer or dependency/versioning constraint.

## Local project configuration

The consumer's .ruby-repo.yml uses schema 1. A complete initial configuration is:

    schema: 1
    name: useful-cli
    repository: your-account/useful-cli
    version_file: lib/useful_cli/version.rb
    gemspec: useful-cli.gemspec
    changelog: CHANGELOG.md
    generated_paths: []
    generate_command: [bundle, exec, rake, generate]
    check_command: [bundle, exec, rake, check]
    required_checks:
      - quality
      - commits
      - audit
      - fresh-dependencies
      - test (ubuntu-latest, 3.4)
      - test (ubuntu-latest, 4.0)
      - test (macos-latest, 4.0)
    workflow: release.yml
    environment: release
    protect_hotfix_branches: true
    require_review_thread_resolution: true

Project.load rejects unknown settings and unsupported schemas. Paths are
relative to the consumer root; paths escaping it through traversal or symlinks
are rejected. Commands are argv arrays, not shell snippets. The schema describes
one gem, one version source and one changelog per consumer repository.

The two policy settings accept only YAML booleans and default to true. Setting
protect_hotfix_branches to false keeps the managed branch ruleset limited to
main; otherwise it also protects hotfix/*. Setting
require_review_thread_resolution to false preserves a repository policy that
allows merging with unresolved review threads. These choices do not change
signature, required-check, merge-method or tag protections, or the release
engine's allowed base branches. Set them explicitly when preserving an existing
repository policy. CLI, Rake and release preflight all read the same configuration.

The generated_paths list names project-owned artifacts refreshed during release
preparation. It does not mark files for template updates. A newly generated CLI
has no such artifacts; its generation tasks have no work until the project
introduces them.

## Ruby and Rake adapters

Install tasks explicitly in the consumer Rakefile:

    require "ruby_repo_kit"
    require "ruby_repo_kit/rake_tasks"

    RubyRepoKit::RakeTasks.install(
      project: RubyRepoKit::Project.load(root: __dir__)
    )

This provides build, package:check, repo:check, lint:commits, audit, release
tasks and GitHub policy tasks. It rejects a competing existing release task.
The consumer defines its own test, coverage, lint, generate and combined check
tasks. Do not also load another tool's publishing tasks under the same names.

The CLI entry point is:

    RubyRepoKit::CLI.run(argv, root: project_root, out: stdout, err: stderr)

It returns 0 for success, 2 for command-line usage errors and 1 for toolkit
operational errors. Thin local wrappers delegate arguments and root to it.
Internal service classes may evolve; use the CLI and Rake adapters for ordinary
consumer integration.

### Supported composition for existing consumers

From 0.1.1, the following Ruby entry points are supported consumer integration
APIs in addition to CLI.run and RakeTasks.install:

- RakeTasks.install_release(project:) registers the release verification,
  artifact and publication tasks. Define build separately and remove competing
  release tasks, including files Rake auto-loads from rakelib. This method does
  not register package, commit-policy, audit or GitHub tasks.
- Package.new(project:, out: $stdout), build(output: nil), and
  check(artifact: nil, environment: {}) provide shared packaging with local smoke
  assertions. An explicit artifact is verified and installed without rebuilding.

Patches within a 0.MINOR series preserve these documented interfaces. A breaking
integration change requires a minor version, release notes and migration guidance.
Corrections may reject invalid configurations that earlier patches accepted.
Template updates affect new projects and do not rewrite existing consumers.
Other internal service APIs remain implementation details. Consumers can keep
their current commit checks, CI orchestration and domain-specific smoke checks.
For example, after requiring ruby_repo_kit/package and ruby_repo_kit/rake_tasks:

```ruby
project = RubyRepoKit::Project.load(root: __dir__)
package = RubyRepoKit::Package.new(project: project)
RubyRepoKit::RakeTasks.install_release(project: project)
task(:build) { package.build }
task "package:check", [:artifact] do |_task, args|
  package.check(artifact: args[:artifact], environment: { "RI" => nil, "PAGER" => "cat" }) do |env, home, directory|
    InstalledSmoke.new(env: env, gem_home: home, directory: directory).run
  end
end
```

InstalledSmoke is the consumer's own assertion object, not a toolkit component.
The environment mapping applies to installation and the generic --version/--help
smoke before the block runs. Keys must be environment variable names and values
strings without NUL or nil; nil removes a variable from child processes. The
mapping does not modify the caller's ENV or the supplied hash. Package-owned
GEM_HOME, GEM_PATH, RUBYOPT, RUBYLIB, BUNDLER_SETUP, RUBYGEMS_GEMDEPS,
XDG_CONFIG_HOME and NO_COLOR override any supplied values, preserving package
isolation and disabling RubyGems/Bundler automatic dependency activation.
The block receives that effective environment, the installed gem home and the
temporary working directory. Those directories exist only for the block's
lifetime. A failed assertion must raise.

For repositories whose historical policy protects only main and does not require
thread resolution, the complete policy override is local data:

```yaml
protect_hotfix_branches: false
require_review_thread_resolution: false
```

The canonical github plan/verify/apply and release commands use those values,
including the command printed for recovery. No alternative policy implementation
or hidden wrapper configuration is necessary.

## Components

- Project validates configuration and resolves paths from the consumer root.
- Commands runs explicit argv arrays with the consumer working directory.
- Scaffold renders packaged ERB files into an exclusively created directory.
- Checks inspects local metadata, files, runtime/development boundaries and lint
  integration. It does not run the full quality suite.
- Package builds, installs and smoke-tests the artifact outside its checkout.
- Release separates metadata, preparation/recovery, PR workflow, publication
  state, artifact verification and the guarded publishing operation.
- GitHub separates HTTP access, the initial repository policy and reconciliation.

Gemspec inspection runs in a separate interpreter to avoid stale version constants
after a bump. Isolation does not make project Ruby code untrusted-safe; these
files are part of the consumer's trusted development environment.

## Release and artifact identity

Preparation changes only declared release files and rejects unrelated changes.
The workflow targets a matching release PR, checks the expected commit, and tags
its merge commit. Retries inspect prior progress rather than replacing tags or
unconditionally publishing again.

The hosted release pipeline builds one gem and records metadata, release notes
and SHA-256. Package checks consume that artifact. Later jobs download the same
artifact, verify its checksum against the verify job's output and use it for
attestation, RubyGems publication and GitHub release assets.

The release environment and OIDC publisher are external configuration. A dry-run
checks build and verification; successful OIDC publication requires an actual
hosted publishing run and separate recorded evidence.

## Self-hosting and the canary

The toolkit's Gemfile uses its local gemspec, and its Rakefile requires its own
task implementation. It does not need a released copy of itself to run its
development checks or build an artifact.

The dedicated canary consumes an installed toolkit artifact to exercise packaging,
templates, runtime independence and upgrade behavior. Path dependencies alone
cannot prove those properties. Its external CI/publication gates remain distinct
from local tests; consult [current status](STATUS.md) and [the plan](PLAN.md).

## Attribution

Release infrastructure adapts code from Slipway and Rich-RI, Copyright (c) 2026
Highlander Paiva, under the MIT license retained in this repository. The
architecture consolidates their reusable practices without importing either
application's runtime implementation.
