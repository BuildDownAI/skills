# Issue shape — the decomposition rubric

Shared reference for `bd-build-up` and `bd-mega-build-up`. Every issue passes this rubric or
gets split before it is filed.

Shape replaces abstract sizing. A story-point estimate never predicted whether a cold agent
one-shots an issue. Shape does, because shape is what the runner actually feels: how many
files it must open, and how much it must reason at each one.

## The shape rule (hard constraint)

Every issue is **either** wide-and-shallow **or** deep-and-targeted. Never both.

- **Wide & shallow** — many files, each touch mechanical: rename, propagate a type, add the
  same import, add a tracking call. Low cognitive load per file. Two risks. *Missing a file* —
  mitigate with an explicit `## Files` list. *Turn-budget exhaustion* — see below.
- **Deep & targeted** — few files, each touch requires reasoning: a new algorithm, a state
  machine, component logic. Concentrated load. Risk: wrong logic. Mitigate with testable
  acceptance criteria.
- **Wide & deep is unsplit work.** Many files AND reasoning at each touch point. Refuse to
  file. Split into a deep core change plus a wide propagation that is `Blocked by:` it.

**Turn budget.** The runner caps Claude turns per implement pass (a project Max-Turns setting,
commonly ~50). Budget ~2–4 turns per file — read, edit, verify. An issue touching more than
~12–15 files risks hitting the cap before the agent finishes and pushes. File count is the
tell; check it at planning time. When an issue approaches the threshold, either **split**
(deep core + wide propagation blocked by it) or **raise the project's Max Turns** before
dispatch and note it on the issue.

## Hard rules

A violation splits the issue. No exceptions.

1. **Migration isolation.** A schema migration is its own issue and its own PR. Consumers —
   API, UI — are downstream issues with `Blocked by:`.
2. **Backfill isolation.** A data backfill is its own issue. It runs after the migration that
   enables it and blocks any consumer that depends on the backfilled state. Backfills carry
   the same blast radius and rollback properties as migrations.
3. **Backend before frontend.** API endpoints ship before the UI that calls them. Same issue =
   rejected.
4. **Scope matches the title.** The issue touches only what its title claims. A drive-by
   refactor is a separate issue.
5. **Spec readable cold.** Title, files, steps, and acceptance criteria all live in the issue
   body. The pipeline reads the body cold and does not follow links. "See the design doc" with
   nothing inlined is a filing failure.
6. **Acceptance criteria are testable.** Each criterion is a checkbox with a verifiable
   outcome. "Works correctly" is rejected.
7. **Information-coupled work counts as deep.** If a per-touch decision needs context outside
   the issue's named files — *"for each viewset, decide whether to paginate based on what the
   frontend expects"* — the issue is deep-and-targeted on a smaller surface, not
   wide-and-shallow, even when each edit is one line. The agent's real load is
   `per-file edit + lookup`. The symptom is the phrase *"for each X, decide whether…"* with no
   inlined rule. The fix: inline the decision rule so each touch is mechanical, or split into
   one deep issue per surface.
8. **Declarative schema tools — push back on column renames.** A project on Atlas or a similar
   declarative tool manages schema as code. A column rename there is a manual multi-step
   cutover (add → backfill → cut over reads → cut over writes → drop) that the pipeline cannot
   one-shot safely. Default: refuse to file it as a pipeline issue, and recommend a scripted
   human-driven sequence. Override only when the user confirms they want the agent to do one
   named phase as its own issue.
9. **Schema tightening needs a writer census.** See the section below.
10. **A feature-node parent defers its own work.** The parent's closing work is `Blocked by:`
    every one of its designated children. It dispatches only after each child is terminal,
    onto the parent's own feature branch. Children PR **into the parent's branch**, never the
    reverse. A parent that must merge to the default branch *before* its children is a
    grouping violation — split the parent's closing work out and block it on the children.
    Full mechanics: [`pipeline.md`](./pipeline.md).

## The writer census (hard rule 9)

Any plan whose endpoint is a tighter constraint on an existing column — `NOT NULL`, `UNIQUE`,
a narrowed type, a new `CHECK`, a new foreign key — **enumerates every writer to that
table and column** before the cleanup issue ships. Production code, test fixtures, and seed
scripts all count. Each writer is updated to satisfy the new constraint in the *additive*
phase.

The additive phase is not done when the column and the backfill are in. It is done when every
future write also satisfies the future constraint. Skip this and the cleanup PR detonates
against unmigrated writers, and the only signal is CI failing on the destructive PR.

**The census is stack-agnostic.** The goal is enumeration, not a search syntax. Walk whichever
of these surfaces the stack has:

- **ORM creates and updates** — `Model.objects.create` / `bulk_create` / `save` (Django);
  `DbSet.Add` + `SaveChanges` (EF Core); `session.add` (SQLAlchemy); `Model.create` /
  `findOrCreate` (Sequelize, ActiveRecord); `insertInto(...).values(...)` (Kysely, Knex).
- **Raw SQL** — `INSERT INTO <table>` and `UPDATE <table> SET` in string literals, migration
  files, fixture SQL, seed scripts.
- **Test fixtures and factories** — FactoryBoy, factory_bot, Bogus, fishery, fixture JSON and
  YAML, `@BeforeEach` helpers, shared seeders. **Fixtures are writers.** Forgetting them is
  the most common census miss.
- **Background jobs and importers** — cron tasks, queue workers, CSV/email/SFTP ingestion,
  third-party webhooks.
- **Admin tooling** — Django admin save hooks, scaffolded CRUD, internal scripts, notebooks
  committed to the repo.

**Output:** the additive issue lists every writer found, one checkbox each, for "now satisfies
the future constraint." A writer the plan cannot list is a writer the plan has not found.

**Cleanup preflight is a code question, not a data question.** Replace "all existing rows
satisfy the constraint" with **(a)** no writer in the census omits the column, **and (b)** CI
is green on a throwaway branch with the constraint pre-applied. `SELECT COUNT(*) WHERE col IS
NULL` tells you about the past. It tells you nothing about the next write.

## Soft signals

Every issue answers every signal. "No, and that is fine because X" is a valid answer. Silence
is not.

| Signal | Question | Action when the answer is "no" |
|---|---|---|
| **Pattern anchor** | Is there a file or PR the agent can mirror? | Name the closest analog. **For a new file, cite an existing sibling file by exact path** — *"create `django/x/tests_pagination.py`, sibling to `tests_lifecycle.py`"* — never by description. Agents do not infer path conventions: three parallel agents pick three different paths. Parallel siblings each anchor inside their own surface, not in a peer issue's. |
| **Test fixture** | Is there an analogous test to copy? | If it is first of its kind, inline the full test in the issue body. |
| **Trust boundary** | Does this cross user input, an external API, or a tenant edge? | Name what is validated where, and what is authorized where. |
| **Rollback path** | If this breaks in production, what is the recovery? | Risky changes need a flag or a revert note. Mechanical changes need neither. |
| **Observability** | What log or metric confirms it works in production? | If the issue adds behaviour worth verifying, name the signal. |
| **Parallel safety** | Does this share file edits with another unblocked issue? | One blocks the other, or they merge into one issue. |

## Reshaping an existing detailed issue

The rubric above authors issues from scratch. Reshaping an already-detailed issue carries a
distinct risk: **right-sizing silently drops a substantive acceptance item.** Before you
finalize a reshape:

1. **Diff the reshaped version against the original.** Identify every substantive acceptance
   item and confirm each one is preserved or explicitly split out.
2. **Split, do not drop.** A requirement that does not fit moves to a sibling issue.
3. **Surface the cut.** Name what moved and get explicit confirmation before filing.

## Rubric evolution

This rubric is living. After each bd-build-down, capture the failure classes:

- *"This issue needed four gap-fill rounds because we never specified the auth pattern"* → add
  an **Auth pattern anchor** soft signal.
- *"This one-shotted but regressed because we never stated the existing-data assumption"* →
  add an **Existing-data invariants** soft signal.

When a failure class recurs across two build-ups, promote it from a lesson to a rubric entry.
Edit this file. Do not keep the rubric in someone's head.
