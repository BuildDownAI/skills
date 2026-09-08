---
name: bd-mega-build-up
description: "bd-build-up, but it grills you first. Same decomposition rubric, same tracker filing, plus an adversarial design review that works the open questions in rounds until nothing is silently assumed — and captures what survives as repo ADRs and glossary entries. Trigger when the user says 'bd-mega-build-up', 'mega bd-build-up', 'deep bd-build-up', 'grill me on this bd-build-up', asks to run mega on a step of a bd-high-plan planning parent, or describes an objective and wants the design pressure-tested before any issue gets filed. Use plain bd-build-up when the scope is small and the design is already settled."
metadata:
  suite: builddown
---

# Mega Build-Up Skill

bd-mega-build-up is `bd-build-up` with senior-engineer pushback in front of it. Same
destination, same issue-shape discipline, higher rigor on the design.

**Cardinal rule: grill, then file.** Two gates — the design after the grill, the issue
manifest before filing. The cost of bad scope filed into the tracker is far higher than the
cost of one more question.

**Write every question you ask and every issue you file in Simplified Technical
English** — [`../bd-shared/ste.md`](../bd-shared/ste.md). This is not a stylistic
preference. The people answering these questions vary in technical depth and English fluency,
and STE is what keeps the trade-off visible instead of buried in hedging.

**The grill produces documents, not a plan.** Decisions that are hard to reverse become ADRs
in the repo. Fuzzy terms become glossary entries. There is no separate implementation-plan
artifact — the settled decisions go straight into issue bodies. The implementer is a capable
model working in the repo; it needs the decisions and the surface, not a script.

**Use this over plain `bd-build-up` when** the scope is non-trivial (roughly 8+ issues,
multi-system, schema changes, new architecture), the user wants pushback, or the design needs
to survive as documentation. **Use plain `bd-build-up`** for small, well-trodden scope, for a
confident user who wants speed, or for a convergence pass over a reviewed prototype. If it is
unclear, ask once and default to `bd-build-up`.

## Configuration

- `{{TRACKER}}` — `linear` or `jira`. Selects the `trackers/<id>.md` adapter that every
  tracker-touching step follows.
- `{{REPO}}` — GitHub repo, `owner/name`.
- `{{IMPLEMENT_LABEL}}` — the label or field value that signals pipeline pickup.
- `{{ARCHITECT_NAME}}` — the human who owns migrations, auth, and infrastructure. Optional.
- `{{BUILD_CMD}}` — the verification command (`next build`, `tsc --noEmit`, `pytest`).
- `{{ADR_DIR}}` — where the grill's decision records land. Defaults to `docs/adr/`.

## Shared references

Load each when its phase reaches it:

| Reference | What it holds |
|---|---|
| [`../bd-shared/ste.md`](../bd-shared/ste.md) | Simplified Technical English — questions and issue prose |
| [`../bd-shared/decision-docs.md`](../bd-shared/decision-docs.md) | ADR and glossary format, and when a decision earns an ADR |
| [`../bd-shared/issue-shape.md`](../bd-shared/issue-shape.md) | The decomposition rubric — shape rule, hard rules, soft signals |
| [`../bd-shared/issue-body.md`](../bd-shared/issue-body.md) | The issue body template and the machine-read `## Files` contract |
| [`../bd-shared/pipeline.md`](../bd-shared/pipeline.md) | Pickup, waves, feature-node designation order, pilot-first |
| [`../bd-shared/overlap-scan.md`](../bd-shared/overlap-scan.md) | Backlog overlap scan and reconciliation |
| `../bd-shared/trackers/{{TRACKER}}.md` | The tracker adapter — every tracker-touching step follows its matching section |

## Environment and tracker

State both at session start.

- **Chat** — tracker MCP, GitHub MCP, conversation memory. No local filesystem. Use
  `bd-belay-on` to a code-reading agent for codebase reads, and to a code-execution session
  for writing ADRs into the repo.
- **Code execution** — bash, filesystem, git. Write ADRs and glossary entries directly; hand
  back to chat for filing when the tracker MCP lives there.

Infer `{{TRACKER}}` from the connected MCP (`linear-<workspace>` → linear,
`atlassian-<workspace>` → jira), or from `tracker.kind` in `CLAUDE.md`. Ask once if it is
ambiguous. Read [`../bd-shared/trackers/{{TRACKER}}.md`](../bd-shared/trackers/); every
tracker-touching step follows its matching section. The adapters are shared with
`bd-build-up`; sections marked **(mega only)** are the ones plain build-up skips.

**Opening declaration:** environment, tracker and container, and mode. *"Running in chat.
Tracker: Linear, team BDS. Mode 2, new design."*

## Modes

Same four modes as `bd-build-up` — read its Mode Detection section. Infer from framing; ask
only on conflicting signals.

The grill applies to every mode. Mode 3 briefs keep the grill and skip filing; the brief
replaces the issue set.

**Mode 4 carries one mega-specific rule.** The grill **may** challenge a decision the planning
parent already records — but a surviving challenge is presented to the user as an explicit
proposed revision, and if accepted, noted on the parent issue. Never silently override a
high-plan decision.

---

## Phase 1: Orient

Understand the current state. Produce a working understanding, not a plan. Draft no issues
yet.

1. **Read the codebase** for adjacent patterns, or for the prototype-versus-production delta
   in Mode 1.
2. **Read `CONTEXT.md` and the existing ADRs** in the area you are touching. A decision
   already recorded is not a decision to re-grill.
3. **KG recon**, if a knowledge graph is bound — follow `../bd-shared/kg-recon.md`. Advisory and
   non-blocking. Skip silently when no KG is bound.
4. **List existing containers** per the adapter's **Container** section, so you know whether
   this build-up creates a project or joins one.
5. **Run the backlog overlap scan** — [`../bd-shared/overlap-scan.md`](../bd-shared/overlap-scan.md).
   Not optional. Its Overlap Inventory becomes grill questions in Phase 2.

Ask at most **two** clarifying questions here. After that, state assumptions and move to the
grill, where questions are the whole point.

---

## Phase 2: Grill

The senior-engineer review. Adversarial in tone, collaborative in intent.

### Work the frontier in rounds

Map the design as a **tree**: every decision branches into the decisions hanging off it. The
**frontier** is every decision whose prerequisites are already settled — the questions you can
ask *now* without guessing at an answer you have not heard.

**Ask the whole frontier in one round.** Number each question and give your recommended
answer. Then wait. The user's answers reshape the tree, push the frontier outward, and unblock
the next round. A question whose answer depends on another question still open in this round
belongs to a *later* round.

Format each question:

```
❓ **Q1** — **{Question title}**: {The question in STE. One decision. Name each option and
what it does. State each trade-off as a concrete failure, not a category.}

➡️ {Your recommended answer, stated plainly, with the reason in its own sentence.}
```

Recommendations are opinionated, not safe defaults. The user accepts one (fast) or pushes back
(better answer). Either way the decision gets made deliberately.

### Facts are your job, never the user's

When a frontier question needs a fact from the environment — what the code does, what the
schema holds, what the tracker says — go find it. Dispatch a code-reading agent or read it
yourself. Never ask the user something you could look up.

Do not block on it. A running lookup is an unsettled prerequisite, so only the questions
*downstream* of it wait. Ask the rest of the frontier now.

The **decisions** are the user's. Put each one to them and wait.

### Write the docs as decisions land

The moment a decision resolves, capture it — see
[`../bd-shared/decision-docs.md`](../bd-shared/decision-docs.md).

- **Hard to reverse, surprising, and a real trade-off** → write the ADR into `docs/adr/` now.
  Most decisions fail this test; that is expected.
- **A fuzzy or overloaded term** → sharpen it and write the glossary entry into `CONTEXT.md`
  now. Challenge a term that contradicts the existing glossary. Check the user's claim about
  how something works against the code.

Batching these to the end loses the alternatives that made the decision worth recording.

### Branches to cover

Walk the tree until the frontier is empty. These branches are where the tree usually goes —
not a checklist to march through:

**Scope boundary** · **Data model** · **API surface** · **UI surface** · **Trust boundaries**
(asked against a census — [`../bd-shared/blast-radius.md`](../bd-shared/blast-radius.md); no census, no settled boundary)
· **Failure modes** (empty, error, race, partial) · **Rollout** (flag, migration, backfill) ·
**Testing** · **Observability** · **Explicit out-of-scope confirmation** · **Every row of the
Overlap Inventory**

Two branches carry a hard requirement:

- **Rollout ending in a tighter constraint** — `NOT NULL`, `UNIQUE`, a narrowed type, a new
  FK or CHECK — forces the **writer census** in this phase. Enumerate every writer to the
  affected column: production code, test fixtures, factories, seed scripts, background jobs,
  importers, admin tooling. See hard rule 9 in
  [`../bd-shared/issue-shape.md`](../bd-shared/issue-shape.md). Do not defer this to "we will
  find them when CI breaks."
- **Every Overlap Inventory row** gets a committed action from the user, not from you.

### Adversarial principles

- **Be specific.** *"What happens when two users edit the same record?"* beats *"have you
  thought about edge cases?"*
- **Name the failure.** *"If two users submit at the same time, the design charges the
  customer twice. Do we accept this, or do we add an idempotency key?"*
- **Refuse to be deflected.** "We will figure that out later" is not an answer to a
  load-bearing question. Name what depends on it and ask again. *"This answer decides whether
  issue 4 is one issue or three. We decide it now."*
- **Acknowledge a good answer** and move on. Do not grill for grilling's sake.
- **Be the senior engineer the user wants on the review, not the one they avoid.**

### Gate 1 — the design is settled

The grill ends when the **frontier is empty**: every branch visited, nothing silently assumed.
Not when you run out of questions, and not when the user seems tired.

Present a short summary: the scope in and out, the decisions with their ADR paths, the
glossary terms added, the overlap actions committed, and any question left genuinely open with
its proposed default. Get explicit approval. A question or partial feedback is input for
revision, not approval.

---

## Phase 3: Decompose and file

### Step 1 — draft the issue set

One unit of parallelizable work = one issue. Every issue passes
[`../bd-shared/issue-shape.md`](../bd-shared/issue-shape.md) before it reaches the manifest.

Use [`../bd-shared/issue-body.md`](../bd-shared/issue-body.md) for the body. Declare the
surface — exact paths, contracts, acceptance criteria, pattern anchors — and do not script the
work. Link the ADR as design reference for the human reviewer, and inline anything the agent
needs, because the pipeline reads the body cold and does not follow links.

Mega-specific: write the title as one short STE statement of the work. Do not reuse a
decision's phrasing verbatim as a title.

### Step 2 — the cross-sibling file audit (mandatory output)

For every grouped tree, produce the file-intersection result **explicitly**. Silence fails the
audit.

- **Parse each sibling's files with the dispatch guard's own contract** — the
  `- Create|Modify|Test|Delete:` bullets under `## Files`. **A sibling that parses to zero
  files fails the audit** until its body carries the canonical block. The guard is blind to
  prose and fail-opens on it.
- **State the verdict per pair** — `A ∩ B = ∅`, or the shared paths.
- **Any intersection chains the pair with `Blocked by:`** or re-splits the boundary.

Sequencing beyond serialization belongs to `bd-summit-push`. Reference it; do not duplicate
it.

### Step 3 — resolve the container and attach the design record

Resolve the container per the adapter's **Container** section. Attach or link the ADRs per its
**Doc home** section, so a board reader can reach the design without a repo checkout.

### Step 4 — execute the overlap reconciliation

Work through the committed actions from the Overlap Inventory **before** filing new issues —
[`../bd-shared/overlap-scan.md`](../bd-shared/overlap-scan.md).

### Gate 2 — the issue manifest

Present the manifest before filing. Never file and then ask.

```
| # | Title | Shape | Migration? | Wave | Labels | Blocked by | Parallel-safe with | Files overlap | Routing |
```

**Files overlap** carries the Step 2 verdict per issue: `∅`, or `sibling-key: paths` with the
`Blocked by:` that resolves it. `UNPARSEABLE` means the audit failed — fix the `## Files`
block before filing.

### Step 5 — file

File in dependency order so each `Blocked by:` resolves to a real ID. Wave staging, feature-node
designation order, and pilot-first sequencing all follow
[`../bd-shared/pipeline.md`](../bd-shared/pipeline.md), with the concrete mechanics in the
adapter's **Pickup trigger**, **Wave staging**, and **Feature-node grouping** sections.

### Step 6 — the post-filing manifest

Container URL, ADR paths, the manifest with real issue IDs, which issues are in Wave 1 and
running, and the critical path — the longest dependency chain, so the user sees the minimum
time to complete.

### Step 7 — the learnings comment (required capstone)

The build-up is not done until this is posted. On the container parent, post an
`# ai-implement-build-up-learnings` comment — one canonical comment per issue, edited in
place, distilled to the load-bearing *why* a future reader would find surprising. Not a second
copy of the decisions. Full convention: `../bd-shared/learnings-comments.md`.

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

---

## Status check mode

Match the user's reference to a container per the adapter's **Container** section, list issues
grouped by state, surface blockers, and flag bd-build-down readiness — issues in review or
with open PRs.

When the user asks *"what was the design for X?"*, read the ADRs. Do not reconstruct the
decision from issue bodies.

---

## Red flags — stop and restart the phase

- **Issues filed without both approvals.** → Close the unapproved issues. Restart from the
  gate you skipped.
- **The grill ended while the frontier still had questions on it.** → The design is not
  settled. Resume the rounds.
- **Grilling skipped because the user seemed sure.** → The grill is what this skill is. If
  skipping it was right, plain `bd-build-up` was the right skill.
- **A decision that is hard to reverse, surprising, and a real trade-off, with no ADR.** → It
  lives only in the session. Write it before Gate 1.
- **An issue that is wide AND deep.** → Shape violation. Split into a deep core plus a wide
  propagation blocked by it.
- **A per-touch decision rule whose inputs are not in the spec** — *"for each viewset, decide
  whether to paginate based on what the frontend expects"*. → Hard rule 7: wide-and-deep in
  disguise. Inline the heuristic, or split per surface.
- **Schema and UI in one issue.** → Backend-before-frontend violation. Split.
- **A migration or backfill bundled with the code that consumes it.** → Hard rules 1 and 2.
  The migration becomes its own issue; the consumer is blocked by it.
- **A schema-tightening plan with no writer census.** → Hard rule 9. The cleanup PR detonates
  against unmigrated writers and surfaces only as CI failures. Run the census in the grill.
- **An Atlas-style project with a "rename column X to Y" issue.** → Refuse to file it for the
  pipeline. Recommend the scripted manual cutover.
- **A new file whose path is given by description** — *"create a pagination test file"*. →
  Pattern-anchor violation. Three agents produce three paths and one collides. Cite an exact
  sibling by full path.
- **A grouped tree filed with no stated file-intersection verdict.** → Step 2 failed silently.
  The guard fail-opens on unparseable files, so the audit is the only protection.
- **A feature-node tree designated out of order.** → Both races are observed. Build the whole
  tree, then the parent, then the children — [`../bd-shared/pipeline.md`](../bd-shared/pipeline.md).
- **Three or more same-template siblings all released at once.** → They will repeat the same
  omission in parallel. Run the pilot first.
- **A wide-and-shallow issue over ~12–15 files with no turn-budget check.** → Split it, or
  raise Max Turns before dispatch and note it on the issue.
- **An issue body that says "see the ADR" without inlining the spec.** → The pipeline does not
  follow links.
- **No Overlap Inventory from Phase 1.** → The scan was skipped or too narrow. A mature
  backlog always has hits.
- **An Overlap Inventory row with no committed action.** → Silent overlap. Force the decision
  in the grill.
- **Issues filed with no learnings comment.** → Step 7 is the capstone, not an extra.

---

## Related skills

- **`bd-build-up`** — the lighter path. Same rubric, same body format, no grill, no ADRs.
- **`bd-high-plan`** — runs *before* this, settling the shape of a capability at high altitude.
  Mode 4 extracts one of its steps.
- **`bd-summit-push`** — optimizes sequencing across a filed issue set.
- **`bd-build-down`** — the next session. Drives the filed issues to merge.
- **`bd-belay-on`** — environment hops: chat to a code-reading agent during orient and the
  grill's fact-finding, code execution to chat for filing.
