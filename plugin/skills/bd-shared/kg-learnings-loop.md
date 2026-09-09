# KG learnings loop — feeding operations back into the base template

The shared procedure for contributing KG-operating learnings back to
**`BuildDownAI/bd-knowledge-graph-base`** (the template every project KG is built
from). Referenced by `bd-kg-create` and `bd-kg-refresh` — defined once here, the
same pattern as `./kg-binding.md` and `./kg-recon.md`.

> **Two learnings loops, two documents.** This doc is the **base-repo** loop:
> sanitized pattern files (`learnings/YYYY/MM/…`) PR'd into the public template.
> The **tracker** loop — build-up/build-down learnings *comments* on issues, and
> where each one lands — is `./learnings-comments.md`. A tracker learning about
> KG operations may feed both: the issue comment records the instance, the base
> PR records the sanitized pattern.

## When to run this step

At the **close** of a `bd-kg-create` or `bd-kg-refresh` run, ask: *did this run
surface something the base template should absorb?* Qualifying learnings:

- an **ingest failure class** (a source shape the ingesters mishandled)
- a **classifier miss** (learning/decision comments mis-captured)
- a **portability gap** (something that only worked because of this machine/org)
- a **search-quality or performance** pattern
- a **process defect** in how the KG is built or validated

A routine, uneventful run produces **no** learning PR. Do not spam the base.
This step is advisory and never blocks the create/refresh that triggered it.

## Inputs from the rail

The `bd-kg-refresh` rail opens a refresh PR with a commit message of the form
`kg-refresh: snapshot @ <stamp>`. When the rail posts a `# ai-implement-kg-refresh-learnings`
comment on that PR (once AII-596 ships), treat it as an additional input to the base-note
decision: review the comment for anomalies that qualify as learnings before deciding whether
to write a base PR. The operator writes the sanitized learning note — the runner never PRs
the base repo directly.

## What to write

One time-based note in the **base repo**:

```
learnings/YYYY/MM/DD-<project-slug>.md
```

Format (canonical version: the base repo's `learnings/README.md`):

```markdown
# <one-line title of the pattern>

- **Date:** YYYY-MM-DD
- **From:** <project-slug>
- **Area:** ingest | classifier | search | snapshot | mcp | portability | perf
- **Priority (suggested):** P1 | P2 | P3

## Symptom
## Root cause
## Suggested base change
```

**Sanitization is a hard rule** (the base will be public): no ticket contents,
no internal names beyond the project slug, no private code, no graph extracts.
Describe the *pattern*, never the proprietary instance.

## How to submit

```bash
cd <local clone of bd-knowledge-graph-base>
git checkout testing && git pull
git checkout -b kg-learnings/YYYY-MM-DD-<project-slug>
# write learnings/YYYY/MM/DD-<project-slug>.md
git add learnings/ && git commit -m "learning: <title> (from <project-slug>)"
git push -u origin kg-learnings/YYYY-MM-DD-<project-slug>
gh pr create --repo BuildDownAI/bd-knowledge-graph-base --base testing \
  --title "learning: <title>" --body "<one-paragraph summary>"
```

**Leave the PR open** — evaluation is human: one approval from the maintainer
team merges the note into `testing`; maintainers triage accepted learnings by
priority and implement base changes by priority (base `CONTRIBUTING.md`). The
submitting skill's job ends at the open PR.

If no local clone of the base exists, clone it first
(`gh repo clone BuildDownAI/bd-knowledge-graph-base ../bd-knowledge-graph-base`);
if that fails (no access), note the learning in the session output for manual
submission and move on — never block.
