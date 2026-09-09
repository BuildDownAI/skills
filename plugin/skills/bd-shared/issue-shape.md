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

**The consumer test (mechanical).** Read the `## Files` list. If any `Create:` entry has more
than **three** `Modify:` consumers — files that import or call the new module — the issue is
wide-and-deep whatever it was labelled. Split it: the module with its own tests and **no
consumers** first, then a wiring issue `Blocked by:` it. Observed: a new classification module
wired into eight call sites, a callback contract, and a database column was filed as
"deep-and-targeted, ~9 files". It took three review rounds, and every blocking finding was at a
seam, not in the module. A reviewer looking only at wiring would have caught them in one.

**Count every entry.** The file limit counts `Test:` and `Modify:` docs entries too, not only
source files. The same issue above was "9 files" counted as source and 14 as declared; the PR
touched 15, then 24.

**Turn budget, by shape.** The runner caps Claude turns per implement pass (a project Max-Turns
setting, commonly ~50). Budget by shape, not by a flat per-file number:

| Shape | Turns per file | Ceiling |
|---|---|---|
| Wide & shallow | 2–4 (read, edit, verify) | ~12–15 files |
| Deep & targeted | 8–15 (read, reason, edit, test, re-read) | ~5 files |

Observed: a 14-file deep issue ran 130–139 turns per pass; the flat 2–4 estimate predicted 30–60.
When an issue approaches its ceiling, either **split** (deep core + wide propagation blocked by
it) or **raise the project's Max Turns** before dispatch and note it on the issue.

**The shape linter checks all three.** `tools/verify-issue-files.py` fails on a `Create:` with more
than three consumers, on more than 12 declared entries, and on a contract surface changed in the
same issue as a new module (hard rule 13). Run it before filing; do not file over a red result.

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
10. **Changing a shared value's shape needs a reader census.** See the section below.
11. **Branching logic enumerates every state.** If the issue's behaviour depends on a
    selection, an enum, a mode, or a combination of flags, the body carries a table with
    **every** state and its expected outcome — not the states worth mentioning. Write the
    table before the prose; it is a decomposition tool, not documentation. The failure it
    prevents is silent and repeatable: a three-state model gets specified as its two obvious
    states, the implementer builds exactly that, the reviewer confirms it matches, and the
    third state fails in production. When a state is genuinely out of scope, list it with
    "out of scope" as its outcome so the omission is a decision rather than an oversight.
12. **A feature-node parent defers its own work.** The parent's closing work is `Blocked by:`
    every one of its designated children. It dispatches only after each child is terminal,
    onto the parent's own feature branch. Children PR **into the parent's branch**, never the
    reverse. A parent that must merge to the default branch *before* its children is a
    grouping violation — split the parent's closing work out and block it on the children.
    Full mechanics: [`pipeline.md`](./pipeline.md).
13. **Contract change isolation.** A new field on a callback body, a new column on a persisted
    record, a new envelope field, a schema or API shape — anything with readers and validators
    on the other side of a process boundary — is its own issue, the way a migration is. The
    issue that produces the value and the issue that carries it across the boundary are
    different reviews: the producer's reviewer checks the value, the contract's reviewer checks
    every reader, the validator, and what happens on version skew. Observed: a callback field
    added in the same issue as its producer shipped with a validator that rejected the **whole**
    callback on an unrecognised value, which would have stalled every failed ticket on the next
    runner/orchestrator version skew. Nobody was reviewing the contract as a contract.

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

## The reader census (hard rule 10)

The writer census protects a **column** whose constraint is tightening. This is its mirror:
any plan that changes the **shape or meaning of a value other code already reads** —
a context field, a hook's return type, an API response body, an exported type, a query
parameter's semantics — **enumerates every reader** before the change ships.

**Search for the underlying state, not only the accessor.** This is the whole rule, and it is
the step that gets skipped. A codebase that offers a tidy accessor (`useThingFilter()`) almost
always also has consumers that reached past it to the raw state (`thing.activeId`) because the
accessor did not exist yet, or did not fit. Those consumers are invisible to a search for the
accessor, and they are the ones that break — silently, because they keep compiling and keep
returning *something*.

Walk both:

- **The accessor** — the hook, selector, helper, or wrapper the change is expressed in.
- **The underlying state** — the context field, store key, prop, or column the accessor reads.
  Search for its name directly.
- **Derived spellings** — a value copied into a local (`const id = ctx.activeThing?.id`), a
  destructure, a prop drilled two levels down, a template literal that builds a query string.

**A silent reader is worse than a broken one.** A reader that fails to compile is found by CI.
A reader that keeps compiling and quietly returns the wrong scope — everything instead of a
subset, the first item instead of the union — ships, and the screen looks plausible. Prefer a
change shape that *breaks* stale readers: make the new argument required rather than optional,
rename rather than widen, so the compiler produces the census you forgot to write.

**Output:** the issue lists every reader found, one checkbox each. If the count is large enough
to violate the shape rule, split it — a deep core change that alters the contract, plus a wide
propagation issue `Blocked by:` it that updates the readers. Name the exact search terms used,
so a reviewer can re-run them.

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
| **Chain position** | Is this the first issue in a dependency chain? | Make it the **smallest** issue in the chain, not the largest. It sets the pattern every later issue mirrors, and it is the one issue nothing else can start before. Cap it at half the normal ceiling. |


## A worked split

The shape violation that is hardest to see is the one where a single "foundation" issue looks
cohesive. This is a real case, names generalised.

**As filed (wide-and-deep, rejected):** *Add a shared failure taxonomy and evidence record.*
`Create:` one classifier module. `Modify:` the pipeline runner, three step modules, the loop
that calls them, the runner entry point, the callback handler, the database module, two docs.
Three tests. Fourteen entries; labelled deep-and-targeted.

Result: three review rounds, ~135 turns and ~$5 per pass, and every blocking finding at a seam —
a check ordered wrong at a call site, a field dropped by a wrapper, the runner rethrowing an
unclassified error, the callback validator rejecting the whole body.

**As it should have been filed (three issues):**

| # | Issue | Shape | Files | Blocked by |
|---|---|---|---|---|
| 1 | Add the failure classifier module | deep, no consumers | 1 create + 1 test | — |
| 2 | Attach failure records at every pipeline throw site | wide-and-shallow | 6 modify + 3 test | 1 |
| 3 | Carry the failure record on the completion callback | deep, contract (rule 13) | 3 modify + 1 test | 1 |

Issue 1 reviews as an algorithm. Issue 2 reviews as wiring, and a wiring reviewer would have
caught all four seam defects in one round. Issue 3 reviews as a contract: validator, readers,
version skew. Issues 2 and 3 run in parallel. Total cost is lower, not higher, because each pass
fits its turn budget and no pass repeats work a reviewer rejected.

The tell was available before filing: the `Create:` entry had eight consumers, and the chain's
first issue was its largest.

**If it was filed anyway:** the first review tells you. Findings concentrated at the seams
between the new module and its consumers mean the shape was wrong, and the right move is to
close the PR and split — not to drive it through gap-fill rounds. `bd-build-down`'s round cap
and split signal exist for exactly this case.

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
