# bd-shared — cross-skill reference

`bd-shared` is a library, not a skill a person runs. It holds the reference material the
BuildDown skills point at with `../bd-shared/<file>.md`, so a rule that governs several skills
has exactly one home. It carries a minimal `SKILL.md` for one reason: claude.ai loads a plugin's
`skills/*/` folders only when each has a `SKILL.md`, and a chat session could not read these
files without it (found live 2026-09-21 on 1.5.23: "session-start.md isn't present in this
environment"). Invoked directly, it prints one line and stops.

It ships with the skills on every install channel — the marketplace sources `./plugin` whole,
and `install.sh` copies and removes this directory alongside the skills so those relative
pointers resolve in an installed tree. Material that lives in the repo root instead of here
does **not** reach an installed skill.

| File | What it holds | Pointed at by |
|---|---|---|
| `ste.md` | the rules for all prose a skill writes: messages, decisions, issues, and learnings comments | all skills (via `session-start.md`) |
| `issue-shape.md` | The decomposition rubric — shape rule, hard rules, writer census, soft signals | build-up, mega-build-up |
| `issue-body.md` | The issue body template, routing, and the machine-read `## Files` contract | build-up, mega-build-up |
| `pipeline.md` | AI-Implement pickup, wave staging, feature-node designation order, pilot-first | build-up, mega-build-up |
| `overlap-scan.md` | Backlog overlap scan, classification, and reconciliation | build-up, mega-build-up |
| `anchor-verification.md` | Every path, symbol, route, table, or key named in a plan or body is opened and grepped before it is written; docs, memories, KG hits, and handoffs are leads, not verification | high-plan, build-up, mega-build-up |
| `decision-docs.md` | ADR and glossary format, and the test for when a decision earns an ADR | mega-build-up |
| `feature-branch-grouping.md` | The full feature-branch model, both providers — operator reference | build-down, super-build-down, smoke-jumper, summit-push, project-setup, mega adapters |
| `learnings-comments.md` | The `# ai-implement-*-learnings` comment convention | build-up, mega-build-up, build-down, super-build-down, belay-on |
| `session-state.md` | The `.bd/session.md` landing-session state file — shape, state vocabulary, write points, resume, renderers | build-down, super-build-down, smoke-jumper |
| `tools/bd-statusline.sh` | Claude Code statusline renderer for `session-state.md` | (installed once per machine, see `session-state.md`) |
| `VERSION` | Present only inside the chat bundle: the plugin version, one line, written by the release workflow from `plugin.json`; `session-start.md` reads it when `.claude-plugin/plugin.json` is not mounted (chat) | session-start |
| `session-start.md` | Session start — Step 0 client and required-tool check (stops with a named message if `client: claude-code` in chat or a required tool is absent), then orchestrator discovery by tool suffix, repo slug, binding, tracker workspace check, per-repo facts; every skill except bd-belay-on runs it first | all skills except bd-belay-on |
| `pickup-label.md` | The pickup-label resolution procedure — three-tier chain (orchestrator → project binding → default), re-resolve rule, Jira carve-out | build-up, mega-build-up (landing skills added by BDS-77/78) |
| `kg-binding.md` | The `get_project_binding` response shape; discovery lives in `session-start.md` | kg-create, kg-refresh, kg-search |
| `orchestrator-auth.md` | Orchestrator auth health — the 48-hour refresh-expiry warning after `get_session_identity`, and the one-line 401 recovery hint per client path | kg-refresh, mega-kg-refresh, kg-search, system-questions |
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
- Changing anything here is a change to shipped plugin content, so change `version` in
  `plugin/.claude-plugin/plugin.json` in the same PR. The rule is in the repo root `CLAUDE.md`
  (Releasing): one release target per cycle computed from `main`, then `+0.0.1` per PR.
