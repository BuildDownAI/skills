---
name: build-up
description: "Plan and file a milestone's worth of tracker issues. Trigger this skill when the user says 'build-up', 'let's do a build-up', 'plan the issues', 'break this down into issues', 'convergence plan', 'design brief', 'build from this design', or describes a product objective and wants it decomposed into sequenced, dependency-aware tracker issues ready for an AI coding agent or a design prototyping tool. Also trigger when the user hands over a design handoff bundle and wants it turned into issues, or asks to status-check an existing build-up. A build-up is the creative counterpart to build-down — it turns a product objective (or a prototype handoff) into a concrete issue plan, reviews it, then files it."
---

# Build-Up Skill

A build-up turns a product objective into a sequenced set of well-scoped tracker issues. It's the planning half of the development loop — build-up creates the work, build-down drives it to merge.

**Cardinal rule: plan first, file second.** Always present the proposed issue breakdown for the user's review before creating anything in the tracker. Planning is where product decisions live; filing is mechanical. Unlike build-down (which runs autonomously), build-up requires the user's explicit approval of the plan before any issue gets filed. The plan is the artifact.

**Context awareness.** If this skill triggers mid-conversation where research, prototyping, or discussion has already happened, don't start from scratch. Extract what's already established — objectives, design decisions, codebase findings — and pick up from there.

---

## Configuration

This skill assumes setup similar to build-down. Substitute as needed.

- `{{TRACKER}}` — the issue tracker (Linear, Jira, GitHub Issues, etc.)
- `{{REPO}}` — the GitHub repo, owner/name format
- `{{IMPLEMENT_LABEL}}` — the label that triggers the AI coding agent pipeline
- `{{ARCHITECT_NAME}}` — the human who owns risky changes (migrations, auth, infra). Optional for single-operator setups.
- `{{BUILD_CMD}}` — verification command for typed code (e.g., `next build`, `tsc --noEmit`)
- `{{CODE_PROTOTYPE_TOOL}}` — a code-first prototyping tool that produces a separate repo (e.g., Lovable, v0, Bolt). Optional.
- `{{DESIGN_PROTOTYPE_TOOL}}` — a design-first prototyping tool that produces a handoff bundle (e.g., Figma + Dev Mode, Claude Design). Optional.

---

## Environment and Pipeline Context

### Environment detection

State the environment at session start and adapt.

**Chat environment (web/mobile):**
- Has: tracker MCP, GitHub MCP, project context, conversation memory, past-chat search
- Lacks: local filesystem, bash, ability to read repo files directly
- Use for: strategic planning, issue body drafting, tracker filing, plan presentation
- Belay-on to a code-reading agent when: need to read prototype/production codebase to verify assumptions, check existing patterns, or compare prototype against production

**Code-execution environment (terminal):**
- Has: bash, local filesystem, git, can read both repos directly
- Lacks: project memory, broad strategic context
- Use for: convergence-mode codebase reads, cross-repo diffing
- Belay-on to chat when: session needs strategic framing or past build-up context

**Code-reading agent:**
- Has: deep codebase reading, grep across files
- Lacks: tracker MCP, GitHub MCP
- Use for: narrow pattern searches when chat's read operations are too slow
- Return findings to chat for filing — code-reading agent can't file issues

**Opening declaration:** State the environment and primary tools. Example: *"Running in chat. Tracker MCP for filing, belay-on to a code-reading agent if we need to verify prototype structure."*

### The AI coding agent pipeline (what happens after filing)

- Issues filed with `state: Todo` and label `{{IMPLEMENT_LABEL}}` are picked up within minutes
- Issues filed with `state: Backlog` sit until explicitly promoted
- The default filing state depends on the build-up's intent — see Phase 3

---

## Mode Detection

Every build-up runs in one of three modes. Infer the mode from the user's framing before asking.

**Default inference rules:**

- If the user references a code-prototype repo, prototype path, or says "converge" → **Mode 1: Convergence**
- If the user hands over a design handoff bundle, prototype link, or says "build from this design" → **Mode 2: New Design** (handoff-bundle variant)
- If the user describes an objective without mentioning a prototype tool → **Mode 2: New Design**
- If the user says "code-prototype brief," "spec for {code-prototype tool}," or mentions plan-mode prototyping → **Mode 3a: Code-Prototype Brief**
- If the user says "design brief" or mentions a design-system tool → **Mode 3b: Design Brief**

Ask only when signals conflict. If asking, ask one clear question, not a menu.

### Mode 1: Convergence (Code Prototype → Production)

The user has a code-first prototype checked into GitHub. Job: compare it against the production app and write issues that bridge the gap.

Code-first prototypes ship fast but use mock data, simplified routing, and aren't wired to the real backend. Convergence issues make them real.

**Mode 1 is for code-first prototypes only.** Design-first work does not flow to Mode 1. Design-first prototypes don't produce a separate repo to converge against — when design-first work is ready to ship, its handoff bundle feeds Mode 2 (New Design) directly as issue source material.

### Mode 2: New Design (Objective → Issues)

No prototype repo to converge against. The user describes a product objective OR hands over a design handoff bundle. Job: understand the input, research the codebase where needed, write issues from scratch.

**Two flavors:**

- **Pure objective:** the user describes the goal. Research codebase, design feature breakdown, draft issues.
- **Handoff-bundle variant:** the user provides a design handoff bundle (export, screenshots, or a link to the design project). Treat the bundle as the specification — use it to scope issues directly. Do NOT treat it as a prototype to "converge against" — it's a spec to build from.

When the input is a handoff bundle, the build-up produces issues that treat the bundle as the source of truth, not a target to reconcile against. The bundle IS the brief.

### Mode 3a: Code-Prototype Brief (Objective → Prototype Spec)

Output is a markdown file the user pastes into the code-prototype tool's plan mode. The brief must be self-contained — the tool will one-shot from it without follow-up questions, so everything needed (pages, components, data shapes, interactions, edge cases) must be in the document.

A Mode 3a brief often becomes input to a later Mode 1 convergence build-up.

### Mode 3b: Design Brief (Objective → Design Tool Kickoff)

Output is a markdown file the user pastes or attaches into a design-system tool. The tool already knows the team's design system (colors, typography, components) from onboarding — the brief should NOT redescribe brand or styling. It should be a conversation-starter, not a one-shot spec.

Mode 3b briefs are lighter than Mode 3a briefs. Design-system tools iterate conversationally, so the brief opens the iteration rather than closes it. Reference existing components by name if known.

A Mode 3b output does NOT feed Mode 1 later. When the design prototype is ready to ship, its handoff bundle feeds Mode 2 (handoff-bundle variant) directly.

---

## Phase 1: Orient

Understand current state before planning. What exists? What's in flight? What are the dependencies?

### Clarifying questions (all modes)

Ask at most **2 clarifying questions** before drafting a plan. If critical information is still missing after 2 questions, draft with explicit stated assumptions and let the user correct. Users with a clear vision want translation, not debate.

Good clarifying questions (examples):
- "Is this v1-MVP scope or are we building to production-complete?"
- "Should this tie into the existing X table or is it a separate data model?"

Weak clarifying questions to avoid:
- "What do you want this to do?" (already said)
- "Who is this for?" (usually obvious from context)
- Anything answered by reading the tracker or existing code

### Mode 1: Convergence orient

1. **Read the prototype codebase.** Confirm the path with the user if not given. Map key components, pages, and data structures. Note what the prototype does, what UI patterns it uses, where it uses mock data. In chat: belay-on to a code-reading agent for this read.

2. **Read the production codebase.** Compare against the prototype:
   - Which pages/routes exist in the prototype but not in prod?
   - Which components exist in both but differ?
   - What the prototype mocks that prod would need real APIs/queries for?
   - What prototype patterns conflict with prod conventions (component libraries, styling)?

3. **Check the tracker.** `list_issues` filtered by team/project. Look for in-flight work that overlaps with the convergence scope. Don't propose duplicates.

4. **Map the delta.** Group gaps: new pages, new components, new API endpoints, schema changes, data wiring, styling alignment.

### Mode 2: New Design orient

Two flavors — pure objective and handoff-bundle.

**Pure objective:**

1. **Understand the objective.** Capture the goal, audience, and success definition. Ask at most 2 clarifying questions.

2. **Research the codebase.** Identify:
   - Adjacent features this builds on
   - Existing API patterns, component patterns, data models
   - Schema changes required
   - What's reusable vs. built fresh

   In chat: belay-on to a code-reading agent for this read.

3. **Check the tracker.** `list_issues` for related in-flight work or existing blockers.

**Handoff-bundle variant:**

1. **Ingest the bundle.** Read what the design tool produced — component list, page flows, data shapes, interactions. The bundle is the spec; don't re-scope it from scratch.

2. **Research the codebase minimally.** The handoff bundle was built against your design system so component names and patterns should already match prod. Verify only where the bundle references something unclear, and check for real API/schema wiring the bundle can't have figured out.

3. **Check the tracker.** Same as pure objective.

4. **Do not convergence-compare.** The bundle is the brief, not a prototype to reconcile. Write issues that implement the bundle directly.

### Mode 3a: Code-Prototype Brief orient

1. **Understand the objective** — same as Mode 2 pure objective.
2. **Research the codebase** briefly — enough to reference real schema and endpoints in the brief so the prototype is convergence-ready later.
3. **Check past briefs.** In chat: look in project files. In code-execution: check the designated briefs folder. If unavailable, proceed without and match general format preferences.

### Mode 3b: Design Brief orient

1. **Understand the objective** — same as Mode 2 pure objective.
2. **Skip codebase deep-dive.** The design tool already knows the design system from onboarding. Only research the codebase if the feature touches specific existing components you want the brief to reference by name.
3. **Check past briefs** — same as Mode 3a, but design briefs are lighter and conversational, so matching past Mode 3a formats would produce an over-specified brief.

---

## Phase 2: Draft the Plan

Core creative work. Output is a structured plan document — not filed, just presented.

### Issue design principles

**Right-sized for the AI coding agent. Use the sizing test:**

An issue is right-sized when ALL of these hold:
- Touches ≤ 5 files
- One primary concern (a page, an endpoint, a migration, not a mix)
- Can be described without requiring knowledge of the whole system
- Has clear, testable acceptance criteria
- Rated 3 story points or fewer

If any of those fail, split the issue.

**Sizing guide:**
- **1 point** — trivial: single-file change, label swap, copy change
- **2 points** — single API endpoint, one migration, straightforward component
- **3 points** — page with multiple components, API + frontend wiring
- **5 points** — complex page with multiple interactions, multi-file changes, needs careful testing (borderline — prefer splitting)
- **8 points** — too big; must split

**Explicit dependencies.** If issue B can't start until issue A merges, say so: "Blocked by: {ISSUE-ID} (reason)." Use "Blocked by" consistently — not "Depends on." This drives build-down merge sequencing.

**Backend before frontend.** Schema migrations and API endpoints are separate issues that ship before UI issues that consume them. Prevents the build-down footgun where a frontend PR merges but its migration hasn't been applied.

**Routing rules:**
- **Architect (`{{ARCHITECT_NAME}}`)** — schema migrations, security policies, infra, complex architecture. Assign these directly, do not label `{{IMPLEMENT_LABEL}}`.
- **AI coding agent pipeline** — frontend convergence, UI fixes, well-defined backend tasks. Label `{{IMPLEMENT_LABEL}}`, leave unassigned.
- **User decision** — anything requiring product judgment that can't be pre-decided. Call it out explicitly in the issue body.

For single-operator setups: drop the architect routing rule. Risky-change issues still get filed but go directly to the user's queue.

**Prototype reference (Mode 1 and Mode 2 handoff-bundle variant):**

- **Mode 1 (Code-prototype convergence):** Include the prototype route path: `Design reference: code-prototype at /app/path/to/feature`. Gives the AI coding agent a concrete target.
- **Mode 2 handoff-bundle variant:** Reference the design project or specific screens: `Design reference: design project "{name}" — screen "{screen-name}"`. The handoff bundle itself can be attached to the tracker project or included in the issue body.

### Plan structure

Numbered sequence. For each issue:

1. **Title** — concise, matches existing tracker patterns
2. **Type** — Bug / Feature / Improvement
3. **Labels** — e.g., `{{IMPLEMENT_LABEL}}`, `frontend`, `convergence`, `backend`
4. **Priority** — High / Medium / Low
5. **Estimate** — story points (1, 2, 3, 5)
6. **Dependencies** — which issues in this plan must complete first
7. **Brief description** — 2-3 sentences. Full issue body comes at filing time, not in the plan.
8. **Routing** — agent / architect / needs user decision

Group into phases or tracks when ≥ 8 issues or when parallel execution paths exist.

### Plan metadata (top of document)

- **Build-up name** — short label the user can reference later
- **Objective** — one sentence on what this build-up achieves
- **Mode** — Convergence / New Design (pure) / New Design (handoff-bundle) / Code-Prototype Brief / Design Brief
- **Issue count** — total
- **Estimated scope** — total story points
- **Critical path** — longest dependency chain, so the user sees minimum time-to-complete

### Present and iterate

Share the plan. Explicit approval is required before filing.

**"Approval" means:** an unambiguous affirmative signal like "looks good," "file it," "go," "proceed," or "let's do it." Questions ("what about X?"), observations ("interesting"), or partial feedback ("I'd change Y") are NOT approval signals — they're input for revision.

Common revisions:
- Splitting or merging issues
- Re-sequencing dependencies
- Changing routing
- Dropping scope ("not needed for v1")
- Adding issues that weren't in the plan

After each revision, present the updated plan. Continue until an unambiguous approval signal. Do not file after "I think this is close" or "mostly good" — ask: "Ready to file as-is?"

---

## Phase 3: File the Issues

After explicit approval, file via `save_issue` (or tracker equivalent).

### Project attachment

Before filing, resolve the tracker project:

- **New project:** Default the project name to the build-up name. Confirm with the user if not already named.
- **Existing project:** Use `list_projects` to match. If multiple candidates, present them and ask.

Every issue in the build-up attaches to the same project so the body of work is queryable as a unit.

### Filing state — stage the waves

Build-up's job is to launch work, not park it. Get the agents going. File issues into dependency-minded waves: Wave 1 (no blockers) starts immediately; later waves promote to Todo as their blockers merge.

**Default filing (applies unless the user says otherwise):**

- **Wave 1** (issues with no dependencies) → `state: Todo` with `{{IMPLEMENT_LABEL}}`. Pipeline picks up within minutes.
- **Wave 2+** (issues with unmet dependencies) → `state: Backlog`. Promote to Todo during build-down as blockers merge.
- **Architect-routed issues** (schema, security, infra) → `state: Todo`, assigned to the architect, no `{{IMPLEMENT_LABEL}}`. The architect decides their own sequencing.

This is the point of a build-up. A well-staged build-up has Wave 1 running by the time the session ends.

**Exceptions (rare — the user must signal):**

- **"Stage only, don't start"** — user explicitly wants the plan filed but no pipeline pickup yet. All issues → `Backlog`.
- **"Brief only"** (Mode 3) — no tracker filing at all, just the markdown spec.

If the signal is ambiguous, ask one clear question: *"File Wave 1 to Todo to start the pipeline, or stage everything to Backlog for later?"*

Mid-session discoveries in build-down are a different skill's concern — that skill files scoped fixes to Todo + `{{IMPLEMENT_LABEL}}` directly. Build-up is about launching a coordinated wave, not parking work.

### Filing order

File in dependency order — issues with no dependencies first. This lets each subsequent issue reference its dependencies by their real issue IDs instead of placeholders.

### Issue body format

Write the full body at filing time, not in the plan.

```
## Problem / Context

Current state, why this issue exists, what it enables.

## Task

What specifically to build. Be precise:
- File paths and component names in the codebase
- API routes and request/response shapes
- Schema columns and types
- UI layout and interaction details

Reference the prototype when applicable:
Design reference: code-prototype at `/app/path`
OR
Design reference: design project "{name}" — screen "{screen}"

## Acceptance Criteria

- [ ] Checkbox-style, independently verifiable
- [ ] `{{BUILD_CMD}}` passes (for typed-code changes)

## Dependencies

Blocked by: {ISSUE-ID} (brief reason)

## Notes

Edge cases, known gotchas, decisions made during planning.
```

### Labels and metadata per issue

- **Project:** The build-up's project (from the resolution step above)
- **Labels:** Include issue type (Bug/Feature/Improvement). Add `{{IMPLEMENT_LABEL}}` for pipeline pickup. Add `convergence`, `frontend`, `backend`, `full-stack` as applicable.
- **Priority:** As determined in the plan
- **Estimate:** As determined in the plan
- **Assignee:** Architect for schema/security/infra work. Unassigned for agent-pipeline work.

### After filing

Present a manifest table: `Issue # | Title | Labels | Dependencies | Priority | State`

This is the build-up's reference point for later status checks and build-down sessions.

### When to suggest build-down handoff

Only suggest switching to build-down mode when:

- At least one issue from this build-up has reached `In Review` (PR ready)
- OR at least one PR from this build-up is open on GitHub

Do not suggest mid-filing. Do not suggest when issues are all still in Backlog or Todo without PRs — there's nothing to drive down yet.

---

## Phase 4: Brief Output (Mode 3 only)

Skip Phase 3 entirely. Produce a markdown file matching the target tool.

### Phase 4a: Code-Prototype Brief

Detail sufficient for the prototype tool to one-shot the build. Code-first tools have no persistent design system and need everything stated up front.

**Brief structure:**

1. **Overview** — what we're building and why, 2-3 sentences
2. **Pages / Routes** — each with URL path, layout description, key interactions
3. **Components** — reusable components with props and behavior
4. **Data shapes** — TypeScript interfaces or plain data descriptions. Reference real schema where applicable so mock data mirrors prod structure.
5. **Navigation** — how pages connect, sidebar/header integration
6. **Styling direction** — general visual approach (the tool has no baked-in design system)
7. **Interactions** — filtering, sorting, drill-down, modals, form submissions
8. **Edge cases** — empty states, error states, loading states

Save as `.md` in the workspace folder (or `/mnt/user-data/outputs` in chat). Name: `code-prototype-brief-{topic}.md`.

Present via the file-presentation tool. Do not file tracker issues for Mode 3a unless the user explicitly requests both.

### Phase 4b: Design Brief

Lighter than a code-prototype brief. The design tool already knows the design system from onboarding — do not redescribe brand or styling. The brief is a conversation-starter that opens iteration, not a spec that closes it.

**Brief structure:**

1. **Overview** — what we're building and why, 2-3 sentences. What's the primary user action on this screen/flow?
2. **Pages / Flows** — each with purpose and key interactions. High-level, not pixel-level.
3. **Component references** — when known, name existing components the design should use. If unknown, skip — the tool will draw from the system.
4. **Data being shown** — what information the user needs to see and act on. Real field names from the schema where relevant. Not full TypeScript interfaces unless the data shape is genuinely novel.
5. **Interactions that matter** — the 2-3 interactions that define the experience. Don't enumerate every button.
6. **Open questions** — things the user wants the tool to propose approaches for, not dictate. Example: "show three ways to organize the queue — card-based, table-based, kanban."

**What NOT to include:**

- Brand/color/typography guidance (the tool has it)
- Pixel-level layout (conversational iteration will refine)
- Edge case enumeration (surface 2-3 critical ones; the rest comes up in iteration)
- TypeScript interfaces unless genuinely novel

**Staged follow-up prompts (optional):**

Because the tool is conversational, include 2-3 follow-up prompts staged for the iteration loop. Examples:

- "Show me three layout directions for the main screen before I pick one."
- "Now apply our design system's data-density pattern from {existing-page}."
- "Add the empty state and error state for the primary list view."

Save as `.md` in the workspace folder. Name: `design-brief-{topic}.md`.

Present via the file-presentation tool. Do not file tracker issues for Mode 3b unless the user explicitly requests both.

### Handoff after design iteration

When the user returns from a design tool session with a finished prototype, the next build-up is Mode 2 (handoff-bundle variant), NOT Mode 1. Do not offer Mode 1 convergence for design-tool work — the bundle is the brief.

---

## Status Check Mode

Triggered when the user asks where things stand on a named build-up ("where are we on Feature X?", "status on the Y convergence?").

This is a separate path from planning — skip Phases 1-3, run this path only.

### Steps

1. **Identify the build-up.** Match the user's reference (name, project, keyword) to a tracker project via `list_projects`. If ambiguous, list candidates and ask.

2. **List issues** from the matched project via `list_issues` with project filter.

3. **Group by state:** Done, In Review, In Progress (including agent-working), Todo, Backlog.

4. **Check for blockers:** In Progress issues stuck? Dependencies unmet? PRs stale (> 5 days)?

5. **Report progress:**
   - X of Y issues done
   - Z story points remaining
   - Critical path status (which chain is gating completion)
   - Any unblocked Backlog work ready for promotion

6. **Identify build-down readiness:** Issues in `In Review` or with open PRs are candidates for build-down. Flag them.

Present a concise status summary. If there are PRs ready, say "there are N PRs ready for build-down — want to switch modes?" without assuming the answer. If issues are all in Backlog when they should be moving (dependencies met, no reason to wait), flag that as the likely next action — promoting the next wave to Todo.

---

## Conventions

**Tracker MCP patterns (Linear-style — adapt to your tracker):**
- `save_issue` handles both create and update (pass `id` to update)
- Label arrays replace — always pass the full desired label list
- `state: "Todo"` + `{{IMPLEMENT_LABEL}}` triggers pipeline pickup within minutes
- `state: "Backlog"` is for issues with unmet dependencies, not a general default

**Prototype tool routing (when both kinds are available):**
- Code-first tool → Mode 3a brief, later Mode 1 convergence. Good for: code-heavy prototypes, fast iteration on full-stack patterns, when the output needs to look like real code.
- Design-first tool → Mode 3b brief, later Mode 2 handoff-bundle variant. Good for: design-system-first work, brand-consistent output, visual iteration, when the output will be handed to engineering via a bundle rather than repo diff.
- If unclear which tool the user wants, ask — the answer determines the brief format.

**Dependency phrasing:**
- Always "Blocked by: {ISSUE-ID} (reason)"
- Not "Depends on," not "Requires," not "After." One phrase, one pattern.

**Sizing guide (reference):**
- 1 — trivial: single-file, label swap, copy change
- 2 — single API endpoint, one migration, straightforward component
- 3 — page with multiple components, API + frontend wiring
- 5 — complex page, multi-file, careful testing needed (prefer splitting to 2 × 3)
- 8 — must split

---

## Key Principles

1. **Plan first, file second.** Planning requires the user's explicit approval. Filing is mechanical execution of the approved plan.
2. **Explicit approval means explicit words.** "Looks good," "file it," "go." Not "I think this is close."
3. **Mode defaults from framing.** Infer first, ask only on conflicting signals.
4. **Max 2 clarifying questions before drafting.** After that, state assumptions and draft.
5. **Stage waves, don't park.** Wave 1 files to Todo + `{{IMPLEMENT_LABEL}}` — get the agents going. Later waves to Backlog, promoted as blockers merge. Exception: user explicitly says "stage only, don't start."
6. **Suggest build-down only when there's something to drive down.** PR open or issue in In Review.
7. **Build-up is not build-down.** This skill plans; the other drives. Don't mix their autonomy models — build-up asks permission to file, build-down acts and reports.
