# Contributing

Ruby Repo Kit serves a specific workflow: Ruby CLI projects whose application
code remains independent of their maintenance tools. Read
[architecture](docs/ARCHITECTURE.md), [decisions](docs/DECISIONS.md) and
[current status](docs/STATUS.md) before changing a contract or release behavior.

## Local development

Use Ruby 3.4 or newer and install the development bundle:

    bundle install
    bundle exec rake check
    bundle exec rake audit

Check runs RuboCop, tests with coverage, local repository validation and an
isolated installed-package smoke test. Audit refreshes the advisory database
and needs network access. Use bundle exec rake test for a focused test run and
bundle exec rake -T to inspect available tasks.

Commit Gemfile.lock changes with their corresponding dependency changes. The
ordinary CI matrix uses the lockfile; a separate job resolves fresh dependencies.
Configured CI targets Ruby 3.4 and 4.0 on Linux, and Ruby 4.0 on macOS.

## Tests and review

Cover observable behavior and operational failure cases: version metadata,
partial release preparation, recovery, exact commit/tag identity, artifact
checksums, argv boundaries and paths containing spaces. Keep real subprocess and
installed-gem checks where they detect failures that fake runners cannot.

A changed scaffold must produce a working consumer with passing tests, lint and
packaging. Test the installed toolkit's templates as well as the source checkout.
Consumers must never acquire the toolkit as a runtime dependency.

Use Conventional Commit titles and add user-visible changes under Unreleased in
CHANGELOG.md. Describe the trigger, changed behavior and validation in the PR.
Maintainers may use skip-changelog for changes without user-visible effects.

## Release and infrastructure changes

Keep plan, preparation and publication behavior distinct. A release command
without --dry-run can push branches and open PRs; --push can merge and trigger
publication. Use disposable fixtures or the dedicated canary for rehearsals.

GitHub policy apply changes repository settings. Preview and review its plan;
tests should exercise API response handling without changing live repositories.
Never embed credentials in fixtures, logs, commands or generated files.

Preserve the MIT attribution of code adapted from Slipway and Rich-RI. The
existing product repositories remain outside the initial adoption scope until
the documented canary gates have been satisfied.

Record whether evidence is a unit test, local artifact installation, hosted CI
run or actual RubyGems publication. These prove different things. Update the
implementation status when an acceptance milestone is completed.

Contributions are licensed under [MIT](LICENSE.txt). Participation follows the
[code of conduct](CODE_OF_CONDUCT.md).
