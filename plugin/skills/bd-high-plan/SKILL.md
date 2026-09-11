---
name: bd-high-plan
description: "Plan a new capability at high altitude — a small set of simple, discrete, separately testable steps (the count agreed with the user) decided one question at a time, captured as a single planning parent issue BEFORE any detailed decomposition. Trigger this skill when the user says 'bd-high-plan', 'high plan', 'plan this at a high level', 'keep the planning very high level', 'just the big pieces', or describes a new capability, integration, or architecture direction and wants the shape of the work settled simply before bd-build-up or bd-mega-build-up breaks any part of it into implementable issues. Also trigger when the user hands over an outside analysis or proposal document and wants it evaluated and turned into a simple plan. When you are working at high altitude, you need a good simple plan."
metadata:
  suite: builddown
---

# High-Plan Skill

A bd-high-plan settles the **shape** of a new capability — a small number of simple steps and
the handful of decisions that order them — and files exactly **one planning parent issue** in
the tracker. It sits **in front of** the build-up skills: bd-high-plan decides the shape; bd-build-up
later extracts one step at a time into implementable child issues (its High-Plan Extraction mode).

**Cardinal rule: altitude discipline.** Every output stays at the level a non-implementer could
read in two minutes. Steps are one line plus a test. Decisions are one question at a time with a
recommendation. No file paths, no schemas, no code. The moment detail wants in, that detail
belongs to a future child issue — write the step, not the step's contents.

**The user sets the pace.** bd-high-plan is a dialogue, not a deliverable drop. Nothing is filed
without showing the draft; nothing proceeds past the filed parent until the user has reviewed it.

---

## Configuration

Same bindings as bd-build-up (`{{TRACKER}}`, workspace/team, KG binding), plus `{{ADR_DIR}}` —
the repo's decision-record directory, as bd-mega-build-up binds it. No pipeline designation is
ever applied by this skill — see Filing.

## When to Use / When Not

- **Use** when the work is a new capability or architecture direction whose overall shape is
  still open — especially when an outside analysis, vendor doc, or brainstorm needs to be
  reduced to a simple plan.
- **Don't use** when the shape is already settled and the need is implementable issues → that is
  bd-build-up. When the design itself needs adversarial deep review with a full implementation
  plan → that is bd-mega-build-up. bd-high-plan can precede either.

## The Process

### Phase 1 — KG recon (before any proposal)

If a KG is bound, run recon per `../bd-shared/kg-recon.md` **before proposing anything**: 2–4
hybrid-search probes derived from the capability in the user's words, plus probes for adjacent
prior art and reusable infrastructure (existing auth, existing services, prior decisions on the
same surface). Open the response by stating what the recon found that shaped the plan — prior
intent, reusable components, and decisions already made are the difference between a plan and a
guess. If an outside analysis was provided, the recon is also the fact-check: say where the
analysis was right, wrong, or moot for this project.

**Documentation recon (same pass, always — KG or no KG).** Look in `{{ADR_DIR}}` and the
repo's reference docs (`docs/*.md`, or wherever the repo's `docs/README.md` says subsystem
references live) for the files that describe each subsystem the capability touches. Report one
line per subsystem: **documented** (name the file), **partly** (name the file and the gap), or
**undocumented**. This is the other half of the fact-check: a subsystem with no reference is a
subsystem whose current behaviour the plan is guessing at, and the gap is filled before the
parent is filed (Phase 5), not left for the children to discover.

### Phase 2 — The ideas (the step count is itself a decision)

**Do not default to a fixed number of steps.** The count is agreed with the user: if they named
a number ("give me about five ideas", "three big pieces"), that is the count; if they didn't,
propose a count with a one-line reason ("this splits naturally into N separately-testable
pieces") and let them adjust it — some users know the granularity they want, others lean on the
agent to find it. A count that keeps growing past what fits on one screen is a signal the
capability wants a different skill (bd-mega-build-up) or more than one high-plan.

Rules for the ideas themselves:

- Each idea is a **discrete unit of work that can be done and tested separately** — one line of
  what, one line of how it's verified.
- **Lead with the decision the user flagged first.** If they said "the first thing to decide
  is X," idea 1 resolves X and says why.
- **Simplest implementation as the default.** Reuse before build; placement before mechanism;
  no new security surface without naming it.
- Plain prose, no jargon chains. A reader who missed the conversation must follow it cold.

### Phase 3 — Decision loop, one question at a time

Settle open decisions **one per round**:

- One question, the simplest form it can take, two or three concrete options, **always with a
  recommendation and its reason**.
- When the user answers with a question ("how would agents connect?"), answer it plainly —
  a small diagram is often the fastest answer — then re-confirm the decision. Never treat a
  clarifying question as an approval.
- Never bundle questions, never present a menu of paths without a recommendation, never
  re-litigate a decision already made.

### Phase 4 — Small soundness review (security + architecture)

Before drafting the parent, run one **brief** review pass over the settled plan — a few bullets,
not a report, still at altitude:

- **Security lens:** does any step add public surface, credentials, or a new data path? For
  each one, name the door and who holds the key (e.g., "one public endpoint, OAuth on it; the
  data store binds localhost only"). A step that adds exposure without naming its control is
  not settled.
- **Architecture lens:** does each step reuse before building, keep the simplest placement,
  and stay independently testable? Does the order let each step be verified before the next
  depends on it?

Report the pass in 3–5 bullets. Anything that fails a lens goes **back to the Phase 3 loop as
its own question** — it does not ride into the parent as an unstated risk. If everything holds,
say so in one line and move on; this phase should cost minutes, not a session.

### Phase 5 — File the planning parent

One issue, in the tracker (not a local file — the tracker feeds the KG and is where breakdown
natively happens). **Show the draft body and get approval before filing.**

**Subsystem documentation rides in the parent.** For every subsystem the recon marked
**undocumented**, draft its reference `.md` in the repo's house style (the conventions in its
`docs/README.md`; the ADR format under `{{ADR_DIR}}` for a decision this plan settles). For one
marked **partly**, draft the update as replacement text for the affected section. Put each
draft under `## Subsystem documentation` in the parent body: one fenced block per file, headed
by its target path and `new` or `update`. Write at reference altitude — how the subsystem works
and why — and verify every claim against the code as you write; a wrong reference is worse than
none. The drafts are the one place bd-high-plan goes below altitude, because they describe what
exists, not what a child will build.

**The drafts leave the issue when the work lands.** Each step names the docs it carries. The
child that changes a subsystem takes that subsystem's draft into `docs/` or `{{ADR_DIR}}` in the
same PR, re-verified against the landed code; a repo with no such child gets one docs child.
After transfer the parent's copy is the historical draft, not the reference.

Body template:

```
**Objective:** {one paragraph — the end state, who uses it, the one non-negotiable}

## Settled design decisions ({date})
- {each decision from Phase 3, one bullet, with the one-line why}

## Steps (each becomes a child issue)
1. {step} — test: {how this step alone is verified} — docs: {files from the section below this step carries, or none}
2. …

## Subsystem documentation (transfers to the repo with the step that changes each subsystem)
### `docs/{subsystem}.md` — new
~~~markdown
{the full reference draft}
~~~
### `docs/{existing}.md` — update of section "{heading}"
~~~markdown
{replacement text for that section}
~~~

## Process
This parent is a planning umbrella and must be broken into child issues before
implementation — one per step, or a standalone related issue where that fits better.
Once a child/related issue exists for a step, all accounting for that step (status,
discussion, learnings) moves to that issue; this parent tracks only the breakdown
and overall completion.
```

**Never designate the parent for pipeline pickup during planning.** The parent is a planning
artifact; a designated planning parent would be dispatched as work (see Tracker notes for what
"designate" means per tracker). After extraction, the tree is filed feature-set capable
(bd-build-up Mode 4), and the user MAY later designate the parent as the feature-set go-lever
— that is a deliberate post-planning opt-in, never something bd-high-plan does.

After filing, **stop**. Point the user at the issue and wait for their review. The filed parent
is a checkpoint, not a waypoint.

### Phase 6 — Hand off to bd-build-up

Breakdown happens later via **bd-build-up's High-Plan Extraction mode** — one step at a time,
or the whole parent in one pass (Mode 4's full-set variant): children file as native sub-issues
with `Blocked by:` relations, shaped so the set can optionally run as a feature set from the
parent, and each extraction leaves a comment on the parent noting where that step's accounting
now lives. bd-high-plan's job ends at the reviewed parent; it never writes child issues itself.

## Tracker Notes

The parent must be visible to the pipeline's tracker but invisible to its pickup trigger:

- **Linear:** file the parent with **no `AI-Implement` label**. Children created later by
  extraction are native sub-issues of the parent; they get the label only when actually ready
  for the pipeline. The grouping rule (a labelled parent + labelled children becomes a feature
  node) is the *later opt-in*, not a planning-time action: never label the planning parent to
  "group" its children during planning — labelling it later, parent-first, is exactly how the
  user turns the extracted set into a feature-set run (bd-build-up Mode 4).
- **Jira:** file the parent with **`AI-Implement-Status` unset** (the field, not the label, is
  the trigger). Children are sub-tasks or linked issues under the tracking Epic per the
  bd-build-up Jira conventions; they get a Status value only when ready.

## Red Flags — stop and correct course

| Symptom | Correction |
|---|---|
| An idea has grown file paths, schemas, or a second paragraph | Cut it back to one line + test; the detail moves to the future child issue |
| Two questions in one message, or a question with no recommendation | Split; recommend |
| About to start building "since the design is settled" | The parent must be filed **and reviewed by the user** first |
| Parent drafted without the Process/accounting section | Add it — breakdown-before-implementation is the contract with bd-build-up |
| Parent about to be filed with a pipeline designation | Remove it; planning parents are never dispatchable |
| Step count asserted instead of agreed | Ask the user, or propose a count with its reason and confirm |
| Parent drafted without the soundness pass | Run the Phase 4 lenses first; unresolved risks become Phase 3 questions |
| Plan written as a local doc "to file later" | File the parent in the tracker; the tracker is what the KG ingests |
| A subsystem the plan touches is undocumented and the parent carries no draft for it | Draft it (Phase 5); an undocumented subsystem is a guessed subsystem |
| Doc drafts still sit in the parent after the child that changed the subsystem landed | The child's PR carries them into `docs/` or `{{ADR_DIR}}`; the parent's copy is never the reference |

## Integration

- **bd-build-up** — consumes the parent via High-Plan Extraction mode (one step → one child).
  A step's doc drafts become `Create:` / `Modify:` entries in the child's `## Files`, so the
  transfer is part of the child's acceptance, not a follow-up.
- **bd-mega-build-up** — when one step turns out to need deep adversarial design, extract it as
  a standalone related issue and run mega on it.
- **bd-kg-refresh** — the parent and its decision trail are ingested with the tracker; write
  decisions into the issue (body or comments), not only into chat.
