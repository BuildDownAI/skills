# Backlog overlap scan

Shared reference for `bd-build-up` and `bd-mega-build-up`. Run during orient, before any issue
is drafted.

A mature backlog almost always holds work that intersects a new build-up. Unaddressed overlap
produces duplicate issues, file conflicts between concurrent runs, and superseded work that
lingers on the board forever.

## Search

Search per the active adapter's **Overlap scan** section. Narrow to the user's team plus any
team the build-up obviously touches; widen when signals suggest cross-team overlap. Over-search
and discard rather than miss a duplicate.

## Classify every hit

| Classification | Definition | Default action |
|---|---|---|
| **Duplicate** | The existing issue describes the same work | Do not re-file. Reference the existing ID. Revive it if stale. |
| **Subset** | The existing issue is broader; our work is one piece of it | Fold our work into its scope, or split it and replace one piece with ours. |
| **Superset** | Our work covers what the existing issue describes | File ours. Close the existing one as superseded and link them. |
| **Adjacent** | Same files or area, different intent | They will conflict when both run. Add `Blocked by:` to one, or sequence them in the plan. |
| **Dependency** | The existing issue must complete before ours starts | Add `Blocked by: {existing-id}` to our issue. Do not duplicate its work. |
| **Stale** | In scope, sitting in the backlog, no activity in 60+ days | Decide: revive, supersede, or close as won't-do. |

## Output — the Overlap Inventory

A list of `{issue-id, title, classification, proposed action}` rows.

**No silent overlap.** Every hit carries a committed action before the design is approved.
"Ignore" is a valid action only with a stated rationale. Carry the inventory into the grill —
each row is a decision the user makes, not one you make for them.

## Execute the reconciliation before filing

These actions are part of filing the build-up, not optional cleanup. Skip them and the backlog
accumulates ghost issues that conflict with active work.

- **Revive** — move the existing issue to the active state, apply the pipeline signal, attach
  it to this build-up's container, and comment with a link to the design record.
- **Fold in** — comment that it has been absorbed into the new scope, then close it once the
  replacing issue is filed, and link them.
- **Split** — edit the existing issue to narrow its scope, and file the remaining pieces as
  part of this build-up.
- **Supersede** — file the new issue first, then close the existing one with a comment linking
  to its superseder.
- **Block-by** — add `Blocked by: {existing-id}` to the new issue's body before filing.
- **Close** — close with a comment stating the decision and linking to this build-up's
  container.
