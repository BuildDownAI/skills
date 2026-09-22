# Contributing to BuildDown Skills

Thanks for your interest. This is a small project; most contributions land via PRs against the default branch.

## Contributor License Agreement — required

**Before we can merge your pull request, you need to sign a Contributor License Agreement.** It's a one-time signature that covers everything you contribute to BuildDown projects in future.

| You are… | Sign this |
|---|---|
| An individual contributing your own work | [Individual CLA](legal/ICLA.md) |
| Contributing on behalf of an employer, or using employer time or equipment | Your employer signs the [Corporate CLA](legal/CCLA.md), **and** you sign the Individual CLA |

When you open your first PR, the CLA bot will comment with a link. The status check blocks merge until it's signed.

**You keep ownership of your code.** The CLA is a licence, not an assignment — you can keep using, licensing and distributing your contribution however you like, including in competing projects.

**BuildDown gets a broad licence, including the right to relicense.** Section 4 is the part worth reading. It lets us distribute your contribution under a commercial or proprietary licence, change the project's licence in future, offer the project under several licences at once, and include your contribution in paid products and hosted services — without asking again and without paying you. If that's not acceptable, please don't sign and don't contribute.

**Check your employment agreement first.** If you're employed as a developer, it may assign to your employer everything you write — including on your own time and equipment. Section 5.2 of the Individual CLA asks you to represent that you're entitled to grant the licence. If your employer owns your work, we need a Corporate CLA from them instead.

Questions: **[PLACEHOLDER: cla@builddown.ai]**

## What this repo is

This repository is a **Claude Code plugin** (`builddown`) made of **skill definitions** — one `SKILL.md` per skill under `plugin/skills/**`, plus shared references and a few shell scripts. There is **no compile or test step**: the skills are Markdown that Claude Code loads at runtime.

## Setting up

```bash
git clone https://github.com/BuildDownAI/skills.git builddown-skills
cd builddown-skills
./install.sh                 # symlink the skills into ~/.claude/skills so a git pull updates them
```

See [README.md](README.md) for the full install matrix (plugin marketplace, script options, channels).

## Before opening a PR

1. **Bump the plugin version when you change shipped plugin content.** Any change under `plugin/skills/**` (or other shipped plugin content) **must** bump `version` in [`plugin/.claude-plugin/plugin.json`](plugin/.claude-plugin/plugin.json) in the *same* PR — it's the only signal that tells `/plugin update` and the marketplace to pull new content. **Compute the new version from `main`, not from the previous `testing` value** (`git fetch origin main --depth=1 && git show origin/main:plugin/.claude-plugin/plugin.json`):
   - **Release target, set once per cycle.** If `testing` still carries `main`'s version, set `main` + `0.1.0` for additive or backward-compatible work, or `main` + `1.0.0` for a breaking change. This happens once between releases, however many PRs land.
   - **Patch per PR.** Every later PR that changes shipped content adds `0.0.1`. A PR that touches no shipped content leaves the version alone.
   Worked example: `main` is `1.4.0`; the first content PR sets `1.5.0`; the next two set `1.5.1` and `1.5.2`; the release is tagged `v1.5.2`. `testing` never reaches `1.6.0` before a release. The full rule, including how a release is cut, is `CLAUDE.md` → *Releasing*.
2. **Declare `metadata.client` and `metadata.requires` in every SKILL.md.** Every new or changed `SKILL.md` must declare `metadata.client` (`any` or `claude-code`) and `metadata.requires` (the list of hard-stop tools, empty if none), and must call `../bd-shared/session-start.md` first in its opening declaration, step 1, or Phase 1, with the words "its printed lines open the reply" (the chat-bundle workflow checks for them, because a skill that names its own first line otherwise hides the session-start lines). A change that moves a step onto the shell, git, a local checkout, or a browser must update the declaration in the same PR. See `docs/adr/0003-every-skill-declares-its-client-and-required-tools.md` for the full inventory and stop-line format.
3. **Keep other skill frontmatter valid.** Every BuildDown `SKILL.md` carries `metadata.suite: builddown` in its frontmatter; follow the shape of the existing skills for `name`, `description`, and trigger phrasing. A `description` must not contain `<` or `>`: the claude.ai plugin upload rejects a description that looks like it holds an XML tag, so write a placeholder as `AII-123` or `{ticket}`, never `<ticket>`. The chat-bundle workflow checks this.
4. **Lint any shell you touch.** If you change `install.sh` or another script, run `shellcheck` on it if you have it installed.
5. **No secrets, no client-specific data** — the skills are generic and tooling-agnostic; service names appear as `{{PLACEHOLDER}}` tokens, not hardcoded workspaces, repos, or client names. Double-check before pushing.
6. **Disclose third-party and AI-generated material** — if your contribution includes code or text under a third-party licence, or was generated in substantial part by an AI system, mark it and say so in the PR description. Sections 5.4 and 5.5 of the CLA. This is a disclosure requirement, not a prohibition.

## Commit messages

Conventional commits aren't required but appreciated. Concise subject line, optional body explaining the *why*.

## Bugs and feature requests

Open an issue. Include enough context to reproduce — for a skill that misbehaved, that means which skill, what you asked it to do, and what it did instead.

## Security

See [SECURITY.md](SECURITY.md). Do not file public issues for security reports.

## License

The project is licensed under the **Apache License, Version 2.0** — see [LICENSE](LICENSE).

By contributing, you agree that your contributions are licensed under Apache 2.0, and that BuildDown AI LLC additionally receives the rights set out in the CLA you signed.
