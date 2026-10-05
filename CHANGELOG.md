# Changelog

## [Unreleased]

### Fixed

- Detect missing or empty RubyGems lockfile checksums in doctor and repo:check before frozen CI fails, without fetching or changing dependencies.
- Keep generated CLI release notes under Unreleased so the first 0.1.0 release can be prepared without correcting a premature release history.

## [0.1.0] - 2026-10-05

### Added

- Generate focused Ruby CLI projects with tests, linting, documentation and release workflows.
- Share release preparation, recovery, artifact verification and isolated package checks through a development gem.
- Validate repository contracts and plan, verify or apply the initial GitHub maintenance policy.

[Unreleased]: https://github.com/hvpaiva/ruby-repo-kit/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/hvpaiva/ruby-repo-kit/releases/tag/v0.1.0
