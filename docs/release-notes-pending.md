# Pending release — what `testing` carries that `main` does not

**Status:** open. `testing` is not merged to `main` on any schedule tied to this work. The
operator cuts the release when other work is ready too. This file records what the release
will contain and what must be decided at that moment.

**Rule for contributors and agents:** do not propose or perform a `testing` → `main` merge,
tag, or catalog repoint as part of feature work. Append to this file instead. The release
procedure itself is in `CLAUDE.md` → *Cutting a release*.

## State at time of writing

| Item | Value |
|---|---|
| `main` plugin version | `1.4.0`, tag `v1.4.0` |
| `testing` plugin version | `1.5.4` |
| Commits on `testing` not on `main` | 69 |
| Release tag the merge will need | `vX.Y.Z` where `X.Y.Z` is what `testing` carries at merge time |

## What the release carries

Grouped by skill. One line per landed PR.

**Knowledge-graph skills (the refresh rail)**
- #78 BDS-48 — bd-shared KG docs: the rail is the refresh; the laptop path is retired.
- #79 BDS-47 — bd-kg-refresh: the rail is the only path.
- #80 BDS-49 — bd-mega-kg-refresh: a local, interactive KG refresh.
- #82 BDS-50 — bd-mega-kg-refresh merges the base template upstream.
- #81 BDS-51 — bd-kg-refresh reports base template drift before triggering.
- #88 BDS-57 — bd-kg-refresh step 3 becomes read-only (preflight rows).
- #89 BDS-56 — bd-mega-kg-refresh fast loop queries the local graph.
- #90, #91 BDS-58 — the rail owns KG scope; the fast loop needs no scope edit.
- #94 BDS-61 — bd-kg-refresh and bd-mega-kg-refresh are admin-only.
- #95 BDS-63 — issue-shape: an emitter change in a KG repo must carry a `Snapshot delta:`.
- #96 BDS-64 — bd-mega-kg-refresh: the proof loop is a rail dry-run.
- #97 BDS-65 — bd-kg-refresh: on a guard refusal, show the part table and ask once.
- #98, #99 BDS-62 — the dry-run proof loop in bd-mega-kg-refresh (feature node).
- #101 BDS-67 — bd-kg-refresh step 7 has no path when `kg.search_tool` is absent.

**Other skills**
- #84 BDS-52 — bd-system-questions discovers the orchestrator MCP's tools.
- #85 BDS-53 — issue-body: a new operator setting declares its admin surface.
- #86, #87 BDS-55 — discovery-driven bd-system-questions and related.
- #93 — bd-high-plan docs recon.
- #105 — bd-shared anchor verification: open the file and grep the symbol before naming it in a plan or body (high-plan, build-up, mega-build-up).
- #118 BDS-79 — orchestrator-auth.md branches the 401 recovery on the literal `clientPath` values
  (`loopback` | `https` | `unknown`); follow-up found by the BDS-69 live checks.
- #112, #113, #114, #115, #116 BDS-69 — the project binding is one `get_project_binding` call (`bd-shared/kg-binding.md`,
  ADR 0001); KG-aware skills read it with the legacy `CLAUDE.md` block as fallback; new `bd-shared/orchestrator-auth.md`
  (48-hour refresh warning, one-line 401 recovery); bd-mega-kg-refresh reads base drift from `get_tenant_health`;
  remaining clone steps labelled "Needs clone".
- #106, #107, #108, #109, #110 BDS-75 — every skill resolves the pickup label from the orchestrator
  (`bd-shared/pickup-label.md`); shared adapters and grouping docs name `{{IMPLEMENT_LABEL}}`.
- #92 — session-state: persistent landing-session state file (`bd-shared/session-state.md`) + Claude Code statusline script (`bd-shared/tools/bd-statusline.sh`) for build-down, super-build-down, smoke-jumper.

**Repo configuration (not shipped in the plugin)**
- #100 — `CLAUDE.md` binds the testing orchestrator's knowledge graph to this repo, and
  `.mcp.json` gains the `orch-ai-implement-testing` server.
- ADR 0001 (`docs/adr/`) and the first `CONTEXT.md` glossary: the project binding is one
  orchestrator call. Repo docs, not shipped in the plugin.
- Orchestrator server renamed `orch-ai-implement-testing` → `builddown-aii-orchestrator` in `.mcp.json`,
  `.claude/settings.json` and `CLAUDE.md` (BDS-80 decision 4). Not shipped; each session re-authenticates once.
- #77 — sync from AI-Implement. #59 — release instructions fix.

## Decisions to make at release time

1. **Version.** Confirm `plugin/.claude-plugin/plugin.json` on `testing` is the intended
   release version. `main` is `1.4.0`; the first content PR set the target to `1.5.0`, so the
   tag is `v1.5.x`.
2. **Catalog repoint.** After the merge and tag, open a `main`-only PR that sets
   `.claude-plugin/marketplace.json` `ref` to the new tag. `testing` keeps `./plugin`.
3. **KG binding in `CLAUDE.md`.** The binding names the *testing* orchestrator. It is for
   developing this repo and is not shipped. Confirm that is still right for `main`.
4. **README channel text.** *Versions and channels* describes stable vs dev. Confirm it needs
   no change for the new tag.
5. **GitHub release notes.** Use the *What the release carries* list above as the draft.

## Items to append

Add a dated line here whenever `testing` gains something the release will need.

- 2026-09-14 — initial list, written after BDS-67 landed on `testing` at `1.5.4`.
- 2026-09-17 — BDS-75 tree landed on `testing` at `1.5.11` (#110). ADR 0001 and `CONTEXT.md` added. BDS-69 tree next; its four children take `testing` to `1.5.15` or `1.5.16`.
- 2026-09-17 — BDS-69 tree landed on `testing` at `1.5.15` (#116). Release decision to add: the legacy five-key `kg.*` block is read-only for one release; file the retirement issue after `v1.5.x` ships (ADR 0001).
- 2026-09-18 — BDS-79 landed on `testing` at `1.5.16` (#118).
