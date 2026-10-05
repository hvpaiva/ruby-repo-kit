# Investigation and architecture rationale

This records the original audit, before adoption. It is not a claim about the
current state of either product: Rich-RI is receiving fixes in another session.
Baseline: Slipway `c8e9bde21af9c687247aef06d18aa0f6ef559b95`; Rich-RI
`379ea1d9b7b806bbe3beb0b0fac5e54fbaed731f`. A later documentation-only Rich-RI
baseline at kickoff was `ba6f1db83b302df8c0f1d0489911fcb999ed2aee`.

## What the comparison established

| Area | Evidence at the original audit | Reusable contract |
| --- | --- | --- |
| Release orchestration | Rich-RI had a recoverable, multi-file release implementation; both projects carried their own implementation and hardcoded project details. | One versioned engine; explicit project data; thin CLI/Rake adapters. |
| Release identity | Rich-RI carried a tested artifact and checksum to publication. Slipway rebuilt in separate stages. Slipway's automatic push path used the exact merge SHA, but manual guidance could tag a later main HEAD. | Build once; verify the same digest through install/attestation/publication; sign the exact release merge commit. |
| Packaging | Slipway's `git ls-files` manifest failed to include lib files outside a Git checkout. Rich-RI's allowlist worked in a source archive. | Repository-independent manifest; build and install outside the checkout/bundle. |
| Shell coverage | Slipway's dedicated shell job selected completion scripts but omitted newer completion-directory tests. Rich-RI's helper cleared the strict-shell flag, allowing unexpected skips. | Assert the intended test selection and required tools; do not equate a green job with executed coverage. |
| Repository policy | Slipway protected main while supporting hotfix releases; Rich-RI protected main and hotfix branches. Both had signed/merge-only rules and release environments restricted to tags. | Read-only policy plan/check, explicit apply, configurable required checks, preservation of unrelated protections. |
| Changelog | Slipway checked historical consistency inside private test helpers; Rich-RI had stronger release-target validation. | Shared version/history/link validation, with release preparation and validation using the same rules. |
| Coverage | Slipway used stronger application thresholds (97/96 plus per-file); Rich-RI used 90/80. Tooling was largely outside those application coverage scopes. | Treat thresholds as policy, cover toolkit code independently, and preserve consumer choices. |
| Optional artifacts | Rich-RI and Slipway differ in documentation, completions, runtime features and generated artifacts. | Keep application generators and domain checks in their own projects; configure explicit commands/owned paths. |

Historical test results: Slipway 1,534 tests / 5,750 assertions, eight shell skips;
its tooling subset 105 / 337 without skips. Rich-RI 173 / 2,653, six skips. All
reported no failures. These counts identify the audit baseline, not migration
acceptance. Future migration must recapture these baselines and explain skips.

## Alternatives considered

| Approach | What it solves | Why it is not the whole solution |
| --- | --- | --- |
| `bundle gem` options | Conventional gem layout and common CI/lint/test choices. | The desired release/policy/artifact contracts still need local integration. Wrapping then replacing most generated files adds two sources of truth. |
| GitHub template repository | Convenient one-time repository creation. | Names/metadata need substitution; copied executable tooling immediately starts drifting. |
| A focused ERB generator inside the toolkit gem | One versioned template, validated names, CLI profile, testable output, offline generation. | Integration files still belong to the consumer and need explicit migrations. This is the initial choice. |
| A standalone central CLI | Commands improve centrally through version updates. | A global installation makes repeatability less clear; the lockfile should select the same tooling for local and CI use. Provide a CLI in the development gem instead. |
| One gem per maintenance feature | Independent dependency/release boundaries. | Premature release coordination and compatibility work with only two real consumers. Keep modules internally separable first. |
| Reusable GitHub workflows | Can centralize repeated Actions execution. | Caller permissions, publisher identity and repository policy still require local contracts; it adds a second version reference. Reconsider after canary stabilization. |
| Copier-style template updates | Structured evolution of generated files. | Merge/conflict ownership becomes a product of its own. Prefer reviewed dependency updates plus explicit integration migrations until this pain is demonstrated. |

There are two lifecycles, but they do not require two repositories. Generation
copies project-owned application files once. Maintenance behavior executes from a
versioned development dependency on every use. The gem contains both, with separate
internal modules. Consumer gemspecs must never acquire a runtime toolkit dependency.

The initial profile is Ruby CLIs. A library profile is justified when a real
consumer needs it; the toolkit being a gem is not itself a reason to build a
general-purpose profile/plugin framework. Separate packages become worthwhile if
compatibility, dependency footprint or release cadence actually diverge.

## Limits and scaling to more repositories

Dependency updates are intentional adoption points, not automatic remote execution
of a mutable latest script. With ten consumers, one fix produces one gem version;
each consumer reviews a lockfile update. CI reports local integration drift.
Workflow/configuration changes may still require small migration PRs. The design
reduces duplicated executable logic; it does not claim zero local configuration.

The canary must demonstrate initial generation, installed behavior, release failure
and recovery, hosted CI, OIDC publication and a subsequent toolkit update before
existing products are migrated. No finite test suite guarantees absence of all
regressions. Gates establish observable evidence and preserve a rollback path.

## Primary references

- [Bundler gem generator](https://guides.rubygems.org/command-reference/bundle-gem/)
- [Gemfile and gemspec responsibilities](https://guides.rubygems.org/gemfile-and-gemspec/)
- [RubyGems trusted publishing](https://guides.rubygems.org/trusted-publishing/)
- [RuboCop configuration inheritance](https://docs.rubocop.org/rubocop/latest/configuration/inheritance.html)
- [GitHub reusable workflows](https://docs.github.com/en/actions/concepts/workflows-and-actions/reusing-workflow-configurations)
- [Copier updates](https://copier.readthedocs.io/en/stable/updating/)
