# Mega-Build-Up — Tracker-Agnostic Core + Jira Adapter (Design)

**Date:** 2026-06-19
**Status:** Approved (design); implementation plan to follow.

## Objective

Let the `bd-mega-build-up` skill drive a milestone bd-build-up into **either Linear or
Jira**, so a customer whose AI-Implement deployment is wired to Jira gets the
same grilling → plan → file pipeline that Linear users get today. The downstream
AI-Implement orchestrator is already provider-abstracted
(`src/providers/types.ts` in `ai-implement`); this change makes the
*planning skill* match that abstraction.

## Scope

**In v1:**
- Refactor `bd-mega-build-up/SKILL.md` into a tracker-neutral shared core.
- Extract Linear-specific mechanics into `bd-mega-build-up/trackers/linear.md`.
- Add `bd-mega-build-up/trackers/jira.md` covering the Jira mechanics.
- Add a Tracker Selection step + `{{TRACKER}}` config so the core loads the
  right adapter.

**Deferred:**
- Applying the same adapter pattern to the rest of the family (`bd-build-up`,
  `bd-build-down`, `bd-super-build-down`, `bd-summit-push`, `bd-smoke-jumper`). They are all
  Linear-coupled and will need the same treatment, but bd-mega-build-up proves the
  pattern first.

**Out of scope:**
- Any change to the AI-Implement orchestrator code. The runtime already supports
  Jira; this is skill-side only.
- A Confluence integration. Design + plan documents live as markdown attachments
  on the container epic (decided below), not as Confluence pages.
- Automated tracker auto-detection beyond a session-start declaration.

## Background — why the trackers differ structurally

The AI-Implement pipeline reads work the same way at runtime through one
`TicketingProvider` interface, but the *trigger and container models are not
cosmetically different*, so simple `{{TRACKER}}` find-replace would lie:

| Concern | Linear | Jira |
|---|---|---|
| Pickup trigger | `state: Todo` + `AI-Implement` **label** | `AI-Implement-Status` custom field = `Ready`, Repo custom field = repoFieldValue, issue satisfies the mapping's **JQL** scope |
| Container | Project (with attached Documents) | **Epic** — issues are flat `parent`-linked children (Jira forbids epics-under-epics); the Jira *project* (e.g. `PROJ`) is fixed config |
| Capacity bucket | team key | mapping ID / JQL scope |
| "Blocked by" | Linear relation | Jira **"Blocks"** issue link (the *blocker* is the inward issue) |
| Overlap scan | `search_issues` | JQL search across all statuses |
| Docs that travel with work | Project Documents | (no native equivalent) |

Reference: `ai-implement/src/providers/jira.ts` (poll JQL is
`(cfg.jql) AND cf[StatusField] in (Ready, "Plan Approved")` plus a Repo-field
equality check), and
the Jira mirror design spec under `ai-implement/docs/superpowers/specs/`
(concrete field IDs and the epic-as-container layout for a live project).

## Architecture

Shared core + per-tracker adapter docs. Symmetric: Linear is an adapter too, not
the privileged default.

### File layout

```
bd-mega-build-up/
  SKILL.md            # shared core: process + rubric, tracker-neutral
  trackers/
    linear.md         # Linear adapter (extracted from today's inline prose)
    jira.md           # Jira adapter (new)
```

### The seam (every adapter answers the same questions)

The core calls into the adapter by named concern. Each adapter document MUST
provide a section for each of these:

| Seam | Linear adapter | Jira adapter |
|---|---|---|
| MCP + tool discovery | `linear-<workspace>` MCP | `atlassian-<workspace>` MCP — ToolSearch for the Jira tools at runtime |
| Container resolution | Project (`list_projects` / create) | Epic under a fixed Jira project; resolve or confirm the epic key |
| Design + plan docs | Project Documents (`create_document`) | **Markdown files attached to the epic** |
| Backlog overlap scan | `search_issues` across all states | JQL search across all statuses |
| Pickup trigger (Wave 1) | `state: Todo` + `AI-Implement` label | `AI-Implement-Status` = `Ready` + Repo field = repoFieldValue + satisfies mapping JQL |
| Parked (Wave 2+) | `state: Backlog` | `AI-Implement-Status` unset (≠ `Ready`); promote by setting `Ready` |
| Architect-routed | Todo, assigned, **no** AI-Implement label | created without `Status=Ready`, assigned to architect |
| Dependency | Linear "Blocked by" relation | "Blocks" issue link, blocker = inward issue |
| Required create fields | minimal | Project, Parent (epic), Issue type, Summary, Description, Priority, **Assigned Team (required custom field)**, Repo field, AI-Implement-Status, labels |
| Issue type derivation | n/a | Feature → Story · Improvement → Task · Bug → Bug |
| Issue URL | Linear URL | `{siteUrl}/browse/{KEY}` |

### Tracker selection

- Add a **Tracker Selection** step next to the existing Environment Detection
  section, and a `{{TRACKER}}` entry to Configuration.
- At session start the skill declares the tracker (operator states it, or infers
  it from which MCP / orchestrator mapping is present), then reads
  `trackers/<id>.md` and uses its mechanics in Phases 1 and 4, the Conventions
  section, and Status Check Mode.
- Opening declaration gains one line, e.g.
  *"…Tracker: Jira (epic PROJ-1234, project PROJ)."*

### Refactor depth of SKILL.md

Clean, symmetric extraction. Pull Linear specifics *out* of SKILL.md into
`linear.md` so the core carries no default-tracker bias. The phase *prose* (what
each phase achieves, the rubric, the grilling tree) stays in SKILL.md; only the
"how to talk to the tracker" lines become "follow the active tracker adapter for
X." More up-front edits to SKILL.md than an override-only approach, but it keeps
the two providers true peers and avoids drift.

## Jira adapter — required content

The Jira adapter (`trackers/jira.md`) must cover, at minimum:

1. **MCP + discovery** — `atlassian-<workspace>`; ToolSearch for Jira create /
   edit / get / JQL-search / comment / attachment / issue-link tools at runtime
   (tool names are discovered, not hardcoded, because the MCP surface can shift).
2. **Container** — resolve the target epic key under the fixed Jira project;
   confirm with the operator. All bd-build-up issues are flat children with
   `parent = <epic>`.
3. **Doc home** — write the two markdown docs locally (as today) and attach them
   to the epic as file attachments.
4. **Overlap scan** — JQL recipes equivalent to the Linear keyword / label /
   project / file-path heuristics, run across all statuses including Backlog.
5. **Pickup trigger** — set `AI-Implement-Status = Ready`, set the Repo field to
   the mapping's repoFieldValue, and ensure the issue satisfies the mapping's
   JQL scope (confirm scope with the operator / orchestrator mapping).
6. **Wave staging** — Wave 1 = `Status=Ready`; Wave 2+ = `Status` unset, promoted
   to `Ready` in bd-build-down as blockers merge; architect-routed = assigned with
   `Status` unset so the pipeline ignores it.
7. **Dependencies** — create "Blocks" issue links with the blocker as the inward
   issue; spell out direction so dependencies actually serialize.
8. **Required create fields** — enumerate the fields Jira demands on create,
   noting that custom-field IDs (`Assigned Team`, `AI-Implement-Status`, `Repo`)
   are instance-specific and must be read from the orchestrator mapping / the
   mirror design doc, not hardcoded.
9. **Issue-type derivation** — Feature → Story · Improvement → Task · Bug → Bug.
10. **Issue URL** — `{siteUrl}/browse/{KEY}`.
11. **Status Check Mode** — fetch design/plan docs from the epic's attachments;
    group issues by `AI-Implement-Status`.

## Jira gotchas (must surface as red flags in the adapter)

- **The trigger is the Status field, not a label.** A Jira issue with the
  `AI-Implement` label but no `AI-Implement-Status = Ready` is never picked up.
  This is the single most likely Jira filing mistake.
- **ADF vs markdown.** Jira descriptions are ADF. Rely on the MCP's markdown
  conversion and **verify rendering on the pilot issue** before filing the wave.
- **Instance-specific field IDs.** Custom-field IDs vary per instance — point at
  the orchestrator mapping / mirror design doc for live IDs; never hardcode.
- **Blocks-link direction.** The pipeline treats an *inward* "Blocks" link to a
  non-done issue as "blocked." Get the direction right or dependencies won't
  serialize.

## Components & responsibilities

- **`SKILL.md`** — owns process, rubric, grilling, plan-document discipline,
  parallel-safety, and the approval gates. Tracker-neutral. Delegates every
  tracker-touching action to the active adapter.
- **`trackers/linear.md`** — owns Linear mechanics for each seam. Extracted from
  the current SKILL.md so behavior is unchanged for existing Linear users.
- **`trackers/jira.md`** — owns Jira mechanics for each seam, plus the Jira
  gotchas.

## Testing / validation

No automated tests (these are prose skill files). Validation is:
1. **Linear parity** — a Linear user reads the refactored SKILL.md +
   `linear.md` and gets the same instructions as today (diff the extracted
   content against the current inline prose; nothing dropped).
2. **Jira dry-run walkthrough** — walk the Jira adapter against a live Jira project
   epic mentally / on a pilot issue: file one issue end-to-end, confirm it gets
   picked up (Status=Ready triggers the pipeline), confirm a Blocks link
   serializes, confirm an attachment lands on the epic.

## Open questions

None blocking. Tracker auto-detection (vs. session-start declaration) and rolling
the pattern out to the rest of the skill family are explicitly deferred.
