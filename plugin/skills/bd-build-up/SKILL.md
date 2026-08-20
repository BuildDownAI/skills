---
name: bd-build-up
description: "Plan and file a milestone's worth of tracker issues. Trigger this skill when the user says 'bd-build-up', 'let's do a bd-build-up', 'plan the issues', 'break this down into issues', 'convergence plan', 'design brief', 'build from this design', or describes a product objective and wants it decomposed into sequenced, dependency-aware tracker issues ready for an AI coding agent or a design prototyping tool. Also trigger when the user hands over a design handoff bundle and wants it turned into issues, asks to extract or break out a step of a bd-high-plan planning parent into its own issue, or asks to status-check an existing bd-build-up. A bd-build-up is the creative counterpart to bd-build-down — it turns a product objective (or a prototype handoff) into a concrete issue plan, reviews it, then files it."
metadata:
  suite: builddown
---

# Build-Up Skill

A bd-build-up turns a product objective into a sequenced set of well-scoped tracker issues.
It is the planning half of the loop — bd-build-up creates the work, bd-build-down drives it to
merge.

**Cardinal rule: plan first, file second.** Present the proposed breakdown for review before
creating anything. Planning is where the product decisions live; filing is mechanical. Unlike
bd-build-down, which runs autonomously, bd-build-up needs explicit approval before any issue
is filed.

**Write every decision you put to the user in Simplified Technical
English** — [`../bd-shared/ste.md`](../bd-shared/ste.md). Clarifying questions, scope cuts, the
filing choice, the approval gate, and every issue title and opening paragraph.

**Context awareness.** When this skill triggers mid-conversation, after research or
prototyping has already happened, do not start over. Extract what is established and pick up
from there.

**Reach for `bd-mega-build-up` instead** when the design needs pressure-testing before
anything is filed — non-trivial scope, schema changes, new architecture, or a user who wants
the pushback.

## Configuration

- `{{TRACKER}}` — `linear` or `jira`. Selects the tracker adapter that every tracker-touching
  step follows.
- `{{REPO}}` — the GitHub repo, `owner/name`
- `{{IMPLEMENT_LABEL}}` — the label or field that signals pipeline pickup
- `{{ARCHITECT_NAME}}` — the human who owns migrations, auth, and infrastructure. Optional.
- `{{BUILD_CMD}}` — the verification command (`next build`, `tsc --noEmit`)
- `{{CODE_PROTOTYPE_TOOL}}` — a code-first prototyping tool producing its own repo (Lovable,
  v0, Bolt). Optional.
- `{{DESIGN_PROTOTYPE_TOOL}}` — a design-first tool producing a handoff bundle (Figma Dev
  Mode, Claude Design). Optional.

## Shared references

Load each when its phase reaches it:

| Reference | What it holds |
|---|---|
| [`../bd-shared/ste.md`](../bd-shared/ste.md) | Simplified Technical English — questions and issue prose |
| [`../bd-shared/issue-shape.md`](../bd-shared/issue-shape.md) | The decomposition rubric — shape rule, hard rules, soft signals |
| [`../bd-shared/issue-body.md`](../bd-shared/issue-body.md) | The issue body template, routing, and the machine-read `## Files` contract |
| [`../bd-shared/pipeline.md`](../bd-shared/pipeline.md) | Pickup, waves, feature-node designation order, pilot-first |
| [`../bd-shared/overlap-scan.md`](../bd-shared/overlap-scan.md) | Backlog overlap scan and reconciliation |
| `../bd-shared/trackers/{{TRACKER}}.md` | The tracker adapter — every tracker-touching step follows its matching section |

## Environment and tracker

State both at session start.

### Tracker selection

Infer `{{TRACKER}}` from the connected MCP (`linear-<workspace>` → linear,
`atlassian-<workspace>` → jira), or from `tracker.kind` in `CLAUDE.md`. Ask once if it is
ambiguous.

Read [`../bd-shared/trackers/{{TRACKER}}.md`](../bd-shared/trackers/). Every tracker-touching
step below — container, overlap scan, pickup trigger, wave staging, architect routing,
dependencies, create fields, issue type, issue URL, status check, feature-node grouping —
follows that adapter's matching `##` section. The adapters are shared with
`bd-mega-build-up`; sections marked **(mega only)** cover artifacts this skill does not
produce, so skip them.

State the tracker in the opening declaration.

### Environment detection

- **Chat (web/mobile)** — tracker MCP, GitHub MCP, project memory, past-chat search. No
  filesystem or bash. Use for strategic planning, drafting, filing, and plan presentation.
  `bd-belay-on` to a code-reading agent to verify assumptions against the codebase.
- **Code execution (terminal)** — bash, filesystem, git, both repos readable. No project
  memory. Use for convergence-mode reads and cross-repo diffing. `bd-belay-on` to chat when
  the session needs strategic framing or past build-up context.
- **Code-reading agent** — deep reads and grep. No tracker or GitHub MCP, so it returns
  findings for chat to file.

**Opening declaration:** state the environment and primary tools. *"Running in chat. Tracker
MCP for filing, bd-belay-on to a code-reading agent if we need to verify prototype
structure."*

---

## Mode Detection

Every bd-build-up runs in one of four modes. Infer from the user's framing before asking.

- Points at a bd-high-plan planning parent, or says "extract step N" → **Mode 4**
- References a code-prototype repo or path, or says "converge" → **Mode 1**
- Hands over a design handoff bundle, or says "build from this design" → **Mode 2**,
  handoff-bundle variant
- Describes an objective with no prototype tool mentioned → **Mode 2**
- Says "code-prototype brief" or names a code-first tool's plan mode → **Mode 3a**
- Says "design brief" or names a design-system tool → **Mode 3b**

Ask only when signals conflict. One clear question, not a menu.

### Mode 1: Convergence (code prototype → production)

The user has a code-first prototype in GitHub. Compare it against production and write the
issues that bridge the gap. Code-first prototypes ship fast on mock data, simplified routing,
and no real backend; convergence issues make them real.

**Mode 1 is for code-first prototypes only.** Design-first work never flows here — it produces
no repo to converge against. When design-first work is ready to ship, its handoff bundle feeds
Mode 2 directly.

### Mode 2: New Design (objective → issues)

No prototype repo. Two flavors:

- **Pure objective** — the user describes the goal. Research the codebase, design the
  breakdown, draft the issues.
- **Handoff-bundle variant** — the user provides a design export, screenshots, or a project
  link. **The bundle is the specification.** Scope issues from it directly. Do not treat it as
  a prototype to reconcile against.

### Mode 3a: Code-Prototype Brief (objective → prototype spec)

Output is a markdown file the user pastes into the prototyping tool's plan mode. The tool
one-shots from it with no follow-up questions, so the brief is self-contained. A Mode 3a brief
often becomes the input to a later Mode 1 convergence.

### Mode 3b: Design Brief (objective → design tool kickoff)

Output is a markdown file for a design-system tool that already knows the team's design system
from onboarding. Do not redescribe brand or styling. The brief opens a conversation rather
than closing a spec, so it is lighter than a Mode 3a brief.

A Mode 3b output does **not** feed Mode 1. Its finished bundle feeds Mode 2.

### Mode 4: High-Plan Extraction (planning parent → child issue)

**Most build-ups have nothing to do with a high plan.** This mode activates only when the user
points at a bd-high-plan planning parent. No other mode goes looking for one.

The input is one **step** of a planning parent — or, in the **full-set variant**, the whole
parent at once. Default: turn a single step into one implementable issue. When the user asks
to extract the entire parent, extract **all steps in one pass**: one child per step, filed as
native sub-issues, with `Blocked by:` relations mirroring the parent's step order.

- **Scope is the step, verbatim.** The parent's step line is the objective, and its settled
  decisions are binding context. Do not re-open what the high-plan dialogue already settled.
- **Output shape:** a child issue of the parent by default. When the work outgrows child shape
  — its own tree, a different repo, a mega candidate — file it standalone and link it to the
  parent instead. Same content rules.
- **Feature-set capable shape, always.** File children as native sub-issues with every
  `Blocked by:` relation set, and everything **undesignated**. The go-lever stays with the
  user. The planning parent is never designated during planning; it may later be designated as
  the feature-set go-lever when the user opts in.
- **Recursive breakdown.** An extracted child that later outgrows single-issue shape becomes
  its own parent/child tree under the same rules. Grouping cascades handle nested trees
  natively.
- **Cross-repo routing.** A child whose work lives outside the team's mapped repo cannot ride
  the pipeline from this parent. Mark it an **operator child** — completed by hand, moved to
  Done manually. Mixed trees are fine; the grouping parent waits for all children however they
  finish. State the pipeline-able subset plainly.
- **Accounting transfer (required).** After filing, comment on the parent: which steps, which
  new issues, and that each step's status, discussion, and learnings now live there. The
  parent tracks breakdown and overall completion only.

All other phases apply normally.

---

## Phase 1: Orient

Understand the current state. What exists, what is in flight, what depends on what.

**Ask at most two clarifying questions** before drafting. If something critical is still
missing, draft with stated assumptions and let the user correct. A user with a clear vision
wants translation, not debate.

Good questions: *"Do we build a v1 MVP, or the complete production feature?"* · *"Does this
use the existing X table, or its own data model?"*

Weak questions to skip: what the user already said, what is obvious from context, and anything
answered by reading the tracker or the code.

**KG recon**, if a knowledge graph is bound — follow `../bd-shared/kg-recon.md` so we do not re-solve
solved problems. Advisory and non-blocking; skip silently when no KG is bound.

**Backlog overlap scan** — [`../bd-shared/overlap-scan.md`](../bd-shared/overlap-scan.md).
Every hit carries a committed action before filing.

### Per-mode orient

**Mode 1 — Convergence.** Read the prototype: components, pages, data structures, where it
mocks. Read production and compare — which routes exist in one and not the other, which shared
components differ, what the prototype mocks that production needs real APIs for, which
prototype patterns conflict with production conventions. Check the tracker for overlapping
in-flight work. Then map the delta into groups: new pages, new components, new endpoints,
schema changes, data wiring, styling.

**Mode 2 — pure objective.** Capture the goal, audience, and success definition. Research the
codebase for adjacent features, existing API and component patterns, data models, required
schema changes, and what is reusable rather than fresh. Check the tracker.

**Mode 2 — handoff bundle.** Ingest the bundle: component list, page flows, data shapes,
interactions. Research the codebase *minimally* — the bundle was built against your design
system, so names should already match. Verify only what the bundle leaves unclear, plus the
real API and schema wiring it could not know. Do not convergence-compare.

**Mode 3a.** Understand the objective as in Mode 2, then research the codebase just enough to
name real schema and endpoints in the brief, so the prototype is convergence-ready later.
Check past briefs for format.

**Mode 3b.** Understand the objective. Skip the codebase deep-dive — the tool knows the design
system. Research only to name specific existing components. Match past *design* brief format,
not Mode 3a's, which would over-specify.

**Mode 4.** Read the planning parent in full — objective, settled decisions, the step being
extracted, and any accounting-transfer comments from earlier extractions, so you do not
re-extract a step that already has its issue. Scope the KG recon to the step. Research the
codebase for the step only: the parent deliberately holds no file paths, and this is where
they enter. Clarifying questions stay capped at two, and never cover what the parent already
decided.

---

## Phase 2: Draft the plan

The core creative work. The output is a structured plan, presented and not filed.

### Issue design

Every issue passes [`../bd-shared/issue-shape.md`](../bd-shared/issue-shape.md) — the shape
rule, the hard rules, and the soft signals. Split anything that fails.

Shape is the sizing test. An issue is right-sized when it is **either** wide-and-shallow
**or** deep-and-targeted, holds one primary concern, can be described without knowledge of the
whole system, and has testable acceptance criteria.

**Prototype reference** — Mode 1 issues carry the prototype route
(`Design reference: code-prototype at /app/path/to/feature`). Mode 2 handoff-bundle issues
carry the project and screen (`Design reference: design project "{name}" — screen "{screen}"`).
The bundle itself can be attached to the tracker container.

### Plan structure

A numbered sequence. For each issue:

1. **Title** — STE, per [`../bd-shared/ste.md`](../bd-shared/ste.md)
2. **Type** — Bug / Feature / Improvement
3. **Labels**
4. **Priority** — High / Medium / Low
5. **Shape** — wide-and-shallow or deep-and-targeted, and the file count
6. **Dependencies** — which issues in this plan must land first
7. **Brief description** — 2–3 sentences. The full body comes at filing time.
8. **Routing** — agent / architect / needs user decision

Group into phases or tracks at eight or more issues, or wherever parallel paths exist.

**Plan header:** build-up name, one-sentence objective, mode, issue count, and the critical
path — the longest dependency chain, so the user sees the minimum time to complete.

### Present and iterate

Share the plan. Where it asks the user to choose — routing, scope cuts, sequencing — state
each choice and its trade-off in STE.

**Approval means an unambiguous affirmative:** "looks good", "file it", "go", "proceed". A
question ("what about X?"), an observation ("interesting"), or partial feedback ("I'd change
Y") is input for revision, not approval.

Common revisions: splitting or merging issues, re-sequencing dependencies, changing routing,
dropping scope, adding issues that were not in the plan. Present the updated plan after each
one. Never file on "I think this is close" — ask *"Ready to file as-is?"*

---

## Phase 3: File the issues

### Resolve the container

Follow the adapter's **Container** section — a Linear project, or a Jira epic under a fixed
project. Every issue in the build-up attaches to the same container, so the body of work stays
queryable as a unit.

### Write the bodies

Use [`../bd-shared/issue-body.md`](../bd-shared/issue-body.md) — the template, the `## Files`
contract, labels, and routing. Write the body at filing time, not in the plan. The adapter's
**Required create fields**, **Issue type**, and **Issue URL** sections carry what the tracker
demands on top of the template.

Declare the surface; do not script the work. Exact paths, contracts, and testable acceptance
criteria — not a step-by-step edit sequence for a capable implementer.

### Stage the waves

The wave model, feature-node designation order, and pilot-first sequencing are in
[`../bd-shared/pipeline.md`](../bd-shared/pipeline.md); the concrete mechanics are the
adapter's **Pickup trigger**, **Wave staging**, **Architect routing**, **Dependencies**, and
**Feature-node grouping** sections. File in dependency order so each `Blocked by:` resolves to
a real issue ID.

**The pickup signal is tracker-specific.** Linear uses state plus a label; Jira uses the
`AI-Implement-Status` field, where setting only a label is a silent no-op.

**Exceptions, and the user must signal them:** *"stage only, don't start"* files everything
parked; *"brief only"* (Mode 3) files nothing. If the signal is ambiguous, ask one clear
question: *"Do we file Wave 1 to start the pipeline, or stage everything for later?"*

A mid-session discovery during bd-build-down is that skill's concern — it files scoped fixes
directly. bd-build-up launches a coordinated wave.

### After filing

Present a manifest: `Issue # | Title | Labels | Dependencies | Priority | State`. This is the
reference point for later status checks and bd-build-down sessions.

### Closing step — the learnings comment (required)

A build-up that files issues without a learnings comment is not done. **Exactly ONE comment,
on the parent or umbrella issue** — the decision node; children get none of their own (their
merge-time learnings arrive later via build-down, per the placement rule in
`../bd-shared/learnings-comments.md`). Post an `# ai-implement-build-up-learnings` comment:
one canonical comment per issue, edited in place, distilled to the load-bearing *why* a
future reader would find surprising. Not a second copy of the plan. **Name the children the
comment covers** (issue keys), so a reader landing on a child knows where the rationale
lives. Full convention: `../bd-shared/learnings-comments.md`.

The marker is an exact-match first line. Never reuse `# ai-implement.yml` — opposite semantics,
and it gets stripped from the spec.

**Provenance:** self-report the harness and model you planned under, e.g. `Claude Code ·
Opus 5`. If you cannot determine the model, ask the operator once. Never guess, never omit.

```
# ai-implement-build-up-learnings

**Feature:** <one line + tree shape>
**Planned by:** <harness · model>

## Decisions & why
- <decision> — <why; what was rejected and the concrete failure it avoids>

## The one idea worth carrying forward
<the single most reusable insight>

## Applies to
<future situations this generalizes to>
```

### When to suggest a bd-build-down handoff

Only once at least one issue has reached In Review, or at least one PR from this build-up is
open. Not mid-filing, and not while everything sits in Backlog or Todo without PRs — there is
nothing to drive down yet.

---

## Phase 4: Brief output (Mode 3 only)

Skip Phase 3 entirely. Produce a markdown file matching the target tool.

### 4a — Code-prototype brief

Enough detail for the tool to one-shot the build. Code-first tools hold no design system and
need everything stated up front.

1. **Overview** — what we build and why, 2–3 sentences
2. **Pages / routes** — URL path, layout, key interactions
3. **Components** — reusable components with props and behaviour
4. **Data shapes** — interfaces or plain descriptions. Reference real schema so the mock data
   mirrors production structure.
5. **Navigation** — how pages connect, sidebar and header integration
6. **Styling direction** — the general visual approach
7. **Interactions** — filtering, sorting, drill-down, modals, form submission
8. **Edge cases** — empty, error, and loading states

Save as `code-prototype-brief-{topic}.md`.

### 4b — Design brief

Lighter. The tool knows the design system from onboarding, so the brief opens iteration rather
than closing a spec.

1. **Overview** — what we build and why, and the primary user action
2. **Pages / flows** — purpose and key interactions, high-level rather than pixel-level
3. **Component references** — name existing components when known; otherwise skip and let the
   tool draw from the system
4. **Data being shown** — what the user needs to see and act on, with real field names
5. **Interactions that matter** — the two or three that define the experience
6. **Open questions** — where the user wants proposals rather than dictation, e.g. *"show
   three ways to organize the queue — cards, table, kanban"*

**Leave out:** brand, color, and typography guidance (the tool has it); pixel-level layout;
exhaustive edge cases (surface two or three); and type interfaces unless the shape is
genuinely novel.

Optionally add two or three **staged follow-up prompts** for the iteration loop — *"show me
three layout directions before I pick one"*, *"now apply the data-density pattern from
{existing-page}"*.

Save as `design-brief-{topic}.md`.

**After the design session,** the next build-up is Mode 2 handoff-bundle, never Mode 1.

---

## Status Check Mode

Triggered by *"where are we on Feature X?"* or *"status on the Y convergence?"*. A separate
path — skip Phases 1–3.

Follow the adapter's **Status check** section for the tracker mechanics.

1. **Identify the build-up.** Match the user's reference to a container. List candidates if
   ambiguous.
2. **List its issues.**
3. **Group by state:** Done, In Review, In Progress, Todo, Backlog.
4. **Check for blockers:** stuck In Progress issues, unmet dependencies, PRs stale over five
   days.
5. **Report:** X of Y issues done, critical-path status, and any unblocked backlog work ready
   for promotion.
6. **Flag bd-build-down readiness** — issues in review or with open PRs.

If PRs are ready, say *"there are N PRs ready for bd-build-down — want to switch modes?"*
without assuming the answer. If everything sits in Backlog with dependencies already met,
flag promoting the next wave as the likely next action.

---

## Conventions

**Tracker MCP verbs, pickup mechanics, and feature-node designation** all live in the active
adapter — `../bd-shared/trackers/{{TRACKER}}.md`. Do not carry a second copy here; the adapter
is the single source of truth, and it is shared with `bd-mega-build-up` so both skills behave
identically against the same tracker.

**Prototype tool routing (when both kinds are available):**
- Code-first tool → Mode 3a brief, later Mode 1 convergence. Good for code-heavy prototypes
  and fast full-stack iteration.
- Design-first tool → Mode 3b brief, later Mode 2 handoff-bundle. Good for design-system-first,
  brand-consistent, visual iteration.
- If it is unclear which the user wants, ask — the answer sets the brief format.

---

## Key Principles

1. **Plan first, file second.** Planning needs explicit approval. Filing is mechanical.
2. **Explicit approval means explicit words.** "Looks good", "file it", "go" — not "I think
   this is close".
3. **Mode defaults from framing.** Infer first; ask only on conflicting signals.
4. **Two clarifying questions, then draft.** After that, state assumptions.
5. **Shape is the sizing test.** Wide-and-shallow or deep-and-targeted, never both. See
   [`../bd-shared/issue-shape.md`](../bd-shared/issue-shape.md).
6. **Declare the surface, do not script the work.** Exact paths and testable criteria, not a
   step-by-step edit sequence.
7. **Stage waves, do not park.** Wave 1 goes live — get the agents going.
8. **Suggest bd-build-down only when there is something to drive down.**
9. **bd-build-up plans; bd-build-down drives.** Do not mix their autonomy models. This skill
   asks permission to file; that one acts and reports.
10. **Every build-up ends with a learnings comment on the parent.**
11. **Every decision put to the user is in Simplified Technical English.** Issue titles and
    opening paragraphs too.
