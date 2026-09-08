# bd-shared — cross-skill reference

`bd-shared` is **not a skill**. It has no `SKILL.md` and never triggers on its own. It holds
the reference material the BuildDown skills point at with `../bd-shared/<file>.md`, so a rule
that governs several skills has exactly one home.

It ships with the skills on every install channel — the marketplace sources `./plugin` whole,
and `install.sh` copies and removes this directory alongside the skills so those relative
pointers resolve in an installed tree. Material that lives in the repo root instead of here
does **not** reach an installed skill.

| File | What it holds | Pointed at by |
|---|---|---|
| `ste.md` | Simplified Technical English — the rules for questions put to the user and for issue titles and opening paragraphs | build-up, mega-build-up |
| `issue-shape.md` | The decomposition rubric — shape rule, hard rules, writer census, soft signals | build-up, mega-build-up |
| `issue-body.md` | The issue body template, routing, and the machine-read `## Files` contract | build-up, mega-build-up |
| `pipeline.md` | AI-Implement pickup, wave staging, feature-node designation order, pilot-first | build-up, mega-build-up |
| `overlap-scan.md` | Backlog overlap scan, classification, and reconciliation | build-up, mega-build-up |
| `decision-docs.md` | ADR and glossary format, and the test for when a decision earns an ADR | mega-build-up |
| `blast-radius.md` | The blast-radius document: when a path earns one, the section template, the writing rules, and the hooks in other skills | blast-radius, high-plan, mega-build-up, build-down |
| `feature-branch-grouping.md` | The full feature-branch model, both providers — operator reference | build-down, super-build-down, smoke-jumper, summit-push, project-setup, mega adapters |
| `learnings-comments.md` | The `# ai-implement-*-learnings` comment convention | build-up, mega-build-up, build-down, super-build-down, belay-on |
| `kg-binding.md` | The `## Knowledge graph` CLAUDE.md contract and dual-target resolution | kg-create, kg-refresh, kg-search, project-setup |
| `kg-recon.md` | The shared KG recon procedure — guard, query, staleness, silent skip | every KG-aware skill |
| `kg-learnings-loop.md` | Feeding base-relevant patterns back to the KG template | kg-create, kg-refresh |
| `trackers/linear.md`<br>`trackers/jira.md` | The tracker adapters — container, overlap search, pickup trigger, wave staging, create fields, dependencies, status check, feature-node designation | build-up, mega-build-up |

## The tracker adapters

`bd-build-up` and `bd-mega-build-up` share one pair of adapters, so both behave identically
against the same tracker. Each skill resolves `{{TRACKER}}` at session start and reads
`../bd-shared/trackers/{{TRACKER}}.md`; every tracker-touching step follows that file's
matching `##` section.

Sections marked **(mega only)** cover artifacts plain `bd-build-up` does not produce — the ADR
index attached to the container. Plain build-up skips them; everything else applies to both.

Adding a tracker means adding one file here and nothing else. `bd-build-down` keeps its own
adapters under `bd-build-down/trackers/` — landing work has a different seam set (triage,
merge, PR handling), so they are not shared with these.

## Editing rules

- **One meaning, one file.** A rule that appears in two skills belongs here, referenced from
  both — never copied into each.
- **Relative pointers only** — `../bd-shared/NAME` from a skill body, `../../bd-shared/NAME`
  from a `trackers/` adapter, and a plain `./NAME` between files here (where `NAME` is the
  target's filename). An absolute or repo-root path breaks in an installed tree.
- **`feature-branch-grouping.md` cites `docs/feature-branch-grouping.md` twice on purpose.**
  Those two references point at the **upstream `BuildDownAI/AI-Implement` repo**, which is the
  authoritative source. They are not stale local paths — leave them alone.
- Changing anything here is a change to shipped plugin content, so bump `version` in
  `plugin/.claude-plugin/plugin.json` in the same PR.
