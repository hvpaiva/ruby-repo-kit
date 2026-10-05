# Security

Report suspected vulnerabilities privately to contact@hvpaiva.dev. Include the
affected toolkit version, environment, impact and a minimal reproduction.
Remove credentials and private repository data. Avoid a public issue until a
fix or coordinated disclosure has been discussed.

Security fixes target the latest released toolkit version. During initial
development, report issues against the current main branch. Maintainers do not
promise a response deadline.

## Trust boundaries

The toolkit executes a consumer's trusted Ruby project files, including its
gemspec, Gemfile, Rake tasks and configured commands. It is not a sandbox for
untrusted repositories. Templates shipped in the installed toolkit are also
trusted executable ERB.

GitHub operations use the GitHub CLI's authentication. Policy apply changes
repository settings, and release operations can push branches, merge PRs and
publish tags. RubyGems publication is intended for the tagged GitHub release
workflow using OIDC, a configured release environment and a verified artifact.
The toolkit does not provision the RubyGems trusted publisher.

Please report paths that escape declared project boundaries, unintended command
execution, wrong-commit publication, artifact substitution, credential exposure,
or recovery behavior that could overwrite an immutable release.

Keep dependency updates and workflow action pins reviewed. Neither the generated
baseline nor successful local checks guarantee the security of a consumer's
application or its external repository settings.
