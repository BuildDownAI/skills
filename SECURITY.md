# Security Policy

## Reporting a Vulnerability

If you discover a security issue, **do not open a public GitHub issue**. Instead:

- Open a private security advisory at https://github.com/BuildDownAI/skills/security/advisories/new.

Please include enough detail for the issue to be reproduced (the skill or script affected, configuration, and repro steps). You'll get an acknowledgement within 5 business days.

## What's in scope

This repository ships **skill definitions (Markdown) and shell scripts** — it is not a running service and holds no credentials. In-scope issues are those where the repository's own content can cause harm on a user's machine:

1. `install.sh` and any shell script — arbitrary file write outside the target skills directory, command injection, or unsafe handling of a `--from-git` source.
2. Skill instructions (`plugin/skills/**/SKILL.md`) that, as written, would drive an AI coding agent to take a destructive or credential-leaking action the operator did not intend.
3. The plugin manifest and marketplace metadata — anything that would cause `/plugin install` to fetch or run unexpected content.

## What's out of scope

- The **AI-Implement** orchestrator service — report those in that repository's own advisories (https://github.com/BuildDownAI/AI-Implement).
- The MCP servers, tracker credentials, and GitHub tokens configured in **your** project — those are your deployment's responsibility, not this repository's.
- Vulnerabilities in dependencies that have not yet been disclosed upstream — please report those to the upstream project first.

## Disclosure

We aim to publish a fix and an advisory within 30 days of confirmation, coordinated with the reporter. Credit is given by default unless you ask otherwise.
