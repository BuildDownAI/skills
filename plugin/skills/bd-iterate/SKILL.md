---
name: bd-iterate
description: "Prototype. Build toward a goal in waves, with a person testing a running milestone between waves. Trigger this skill when the user says 'bd-iterate', 'iterate on this', 'build this iteratively', 'plan the next wave', 'next milestone', 'resume the iteration', or describes a goal and wants to steer it by testing as it takes shape, not by approving a full plan first. bd-iterate reads the current state and the goal, picks the next testable checkpoint, files only the wave of issues that reaches it, drives that wave to a preview or a local run, collects feedback, and plans the next wave from what was built and what was learned. It repeats until the person says the goal is met. The goal can change between waves."
metadata:
  suite: builddown
  client: any
  requires: [tracker, github]
---

# Iterate Skill (prototype)

bd-iterate builds toward a goal one wave at a time. A **wave** is the smallest set of issues
that makes one **checkpoint** testable. A checkpoint is a running build, on a preview or on
this machine, that a person tries and gives feedback on. After each checkpoint the skill
plans again from the code that exists and from what the person said.

`bd-build-up` and `bd-build-down` plan a whole milestone and then land it. Use them when the
design is settled. Use bd-iterate when the person expects to learn what they want by seeing it
run.

Run [`../bd-shared/session-start.md`](../bd-shared/session-start.md) first; its printed lines open the reply.
Write all prose to the person and all issue prose per [`../bd-shared/ste.md`](../bd-shared/ste.md).

## Why it works this way

Three measured facts shape every rule below. Keep them in mind when a case is not covered.

- **An issue written before its base code exists goes stale.** The issue as written is the
  most common cause of a troubled run. So file issues for one wave only, against code you
  have read in this session.
- **A person adds little at the diff and a lot at the running build.** Hand edits to pipeline
  PRs are rare now. So the person's gate is the checkpoint, not each child PR.
- **Some requirements show only when the thing runs.** Speed, feel, layout, sign-in, empty
  states, error handling. So reach something that runs end to end early, and ask about these
  at every checkpoint.

## Shared references

Load each when the step reaches it.

| Reference | Used for |
|---|---|
| [`../bd-shared/issue-body.md`](../bd-shared/issue-body.md) | The body template, body rules, and the filing check |
| [`../bd-shared/issue-shape.md`](../bd-shared/issue-shape.md) | The shape rule and the size threshold |
| [`../bd-shared/anchor-verification.md`](../bd-shared/anchor-verification.md) | Every path and symbol in a body is opened before it is written |
| [`../bd-shared/pipeline.md`](../bd-shared/pipeline.md) | Wave release, designation order, parks, the gap-fill limit |
| [`../bd-shared/feature-branch-grouping.md`](../bd-shared/feature-branch-grouping.md) | The tree, the roll-up, the top-of-tree PR |
| `../bd-shared/trackers/{{TRACKER}}.md` | Every tracker write |
| [`../bd-smoke-jumper/SKILL.md`](../bd-smoke-jumper/SKILL.md) | How to test a preview or a local boot |

## The iteration record

The session can end at any time. A wave takes longer than most sessions stay open. So the
tracker holds the state, and a new session resumes from it.

Keep one document named `Iteration record` in the tracker container for the goal (the
adapter's **Doc home** section says where a document lives). It holds, in this order:

1. **Goal.** What done looks like, in the person's words, as things a person can observe.
   Include the non-functional requirements they named.
2. **Verification.** How a checkpoint is tested: the preview URL pattern, or the commands that
   run the build on this machine, and the sign-in a tester needs.
3. **Milestones.** One line each. Only the current one has issues. Later ones are sketches and
   are expected to change.
4. **Log.** One entry per checkpoint: the date, what was tested, what the person said, what
   changed in the goal or the milestones, and each decision with its reason.

The record is the audit trail. Update it at every checkpoint, before planning the next wave.
An entry in the log is never rewritten; a changed decision gets a new entry.

## The loop

### 1. Orient

On a first run, agree the goal with the person and write the record. Ask only what you cannot
read from the repo or the tracker. Confirm how a checkpoint will be verified. If there is no
preview and the build cannot run on this machine, stop and say so; the loop has no gate
without one.

On a resume, read the record, the tracker state of the current wave, and the open PRs. Then
go to the step the state calls for. Do not ask the person to restate anything the record
holds.

In both cases read the code as it is now on the default branch. Plan from the code, not from
the last plan.

### 2. Choose the checkpoint, then the wave

Choose the checkpoint first. State it as what the person will do and what question it
answers, for example "sign in, open the order list, and scroll 500 rows: is it fast enough,
and is this the right layout?" Then derive the smallest set of issues that makes it testable.

- **The first checkpoint is a thin slice that runs end to end.** Real route, real data path,
  plain looks. It exposes the non-functional problems while they are cheap to change.
- **Prefer a checkpoint that settles the largest open question.** If the person is unsure
  about something, build toward the thing that lets them decide.
- **Keep a wave small enough to test in one sitting.** Three to six issues is the starting
  guess. A wave past eight issues usually hides two checkpoints.
- **Leave out what the checkpoint does not need.** It goes on a later milestone line, not in
  an issue.

Show the person the checkpoint and the wave in one short message: the checkpoint, the issue
titles with one line each, and what is put off. Proceed when they agree. This is the only
approval before filing.

### 3. File the wave

One wave is one feature tree. File a parent issue for the milestone with an empty task of its
own, then the wave's issues as its children, each per `issue-body.md` and `issue-shape.md`.
Run the filing check on every child. Set blocking relations between children that touch the
same file. Then designate the whole tree in one pass, parent first, per `pipeline.md`
§ Wave release.

The tree gives the wave one integrated branch and one top-of-tree PR. That PR is the
checkpoint: its preview, or a checkout of its branch, is what the person tests.

Add the wave's issue keys to the record.

### 4. Drive the wave

Bring each child PR to merge on the feature branch. The person does not review child PRs.

- **Lean toward merging.** Merge a child when its checks pass and its gap analysis shows the
  acceptance criteria met. A defect that does not block the checkpoint becomes a **residual**:
  a one-line entry in the record, filed as an issue in a later wave. A merged child with a
  known residual teaches more at the checkpoint than a child held for polish.
- **Send a real gap back once.** If an acceptance criterion is not met, post one
  `{{AGENT_MENTION}}` comment that names the gap and the evidence. The PR has a limit on
  these runs (`pipeline.md`), so if the second attempt also misses, fix the issue body or
  split the issue; do not post a third comment.
- **Bring architecture and code decisions to the person when they come up.** A decision that
  changes a schema, a public contract, a security boundary, or the structure later waves will
  build on is the person's. Ask it at once if it blocks the wave. Otherwise hold it for the
  checkpoint. Put it as one question with your recommendation and what each answer costs.
  Record the answer and its reason in the log.
- **Read a stalled issue before acting on it.** An issue that carries the pickup signal and
  does not move may be parked. See `pipeline.md` and `bd-system-questions`.

`bd-build-down` holds the detailed rules for conflicts, roll-up conflicts, and tracker
hygiene. Read its section when one of those cases arises. Where it and this skill differ on
when to merge, this skill's lean toward merging wins inside a wave.

When every child is merged or cancelled, the orchestrator opens the top-of-tree PR. If the
session will not last that long, tell the person what is in flight and that "resume the
iteration" picks it up.

### 5. Check it yourself first

Before asking the person for time, test the checkpoint build. On a preview, follow
`bd-smoke-jumper` against the top-of-tree PR. On this machine, check out the feature branch,
run the verification commands from the record, and exercise the checkpoint path.

Fix what is plainly broken before the person sees it: file it as a child of the wave's parent
per `bd-super-build-down` § 4d (fixes in a grouped tree). One difference: here the fix gets
the pickup signal at filing, because the person already agreed the checkpoint it serves. The person's attention is the scarce
resource in this loop. Do not spend it on a page that does not load.

### 6. The checkpoint

Give the person one message that holds:

- The link to the preview, or the exact commands to run it.
- What to try, as three to five steps.
- Three or four questions. At least one about the checkpoint's own question, and at least one
  about a non-functional quality that this build is the first chance to judge.
- Known residuals, so they do not report them again.
- Decisions held for them, each with your recommendation.

Then wait. Their feedback is the input to the next wave. Ask a follow-up only when an answer
could mean two different next waves.

### 7. Re-orient

Sort the feedback and write the log entry first.

| Feedback | What to do |
|---|---|
| It blocks the milestone from merging | File a fix as a child of the wave's parent, drive it, and repeat the checkpoint for that part |
| It is wrong but can ship | Residual. Merge the top-of-tree PR; the fix is a candidate for the next wave |
| It changes what the person wants | Change the goal or the milestone lines in the record, with the reason. This is the loop working, not a failure |
| It is fine | Merge the top-of-tree PR |

Lean toward merging the milestone. Work on the default branch is what the next wave is
written against, and an unmerged milestone makes every later issue stale. The person gives
the word to merge the top-of-tree PR; do not merge it without that.

Then return to step 2 with the merged code, the residuals, and the changed goal. Residuals
compete with new work for a place in the next wave; they are not owed one.

### 8. Done

The goal is met when the person says so at a checkpoint. Then close the record with a final
log entry: what shipped, what residuals remain and where they are filed, and what was dropped
from the goal and why. File the remaining residuals as standalone issues without the pickup
signal, so the person chooses which ones run.

Stop and ask if three checkpoints in a row end in a goal change with no milestone merged. The
goal is not yet clear enough to build toward, and a conversation will cost less than a fourth
wave.

## What this prototype does not settle

These are open questions for the runs that test it. Note what you see in the log.

- Whether three to six issues is the right wave size.
- Whether one tree per wave is better than one long-lived tree for the whole goal with a
  roll-up at each milestone.
- Whether a fix filed under a parent whose top-of-tree PR is open behaves as described in
  `bd-super-build-down`.
- How the loop should feel when the person is present for the whole wave, compared with when
  they come back hours later.
