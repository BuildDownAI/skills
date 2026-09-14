# Anchor verification

An **anchor** is any concrete name a plan or an issue body relies on: a file path, a module, an
exported function or class, an HTTP route, a database table, a settings key, an environment
variable, a CI job, a workflow file. Anchors tell the implementer where to look and what to
reuse. A wrong anchor sends the agent to a place that does not exist, and the pipeline reads the
body cold.

## The rule

Every anchor is verified in the repository before it is written into a step, a body, a comment,
or a doc draft. Verification means:

1. Open the file at the path. Confirm it is the file the sentence describes, not a neighbour one
   path segment away.
2. For a symbol, grep for its definition or export inside that file. Cite the path and the symbol
   name together.
3. For a route, a table, a key, or a job name, grep for the literal string.
4. Record what was checked (path and line) in the session's working notes. The body carries the
   path.

## What does not count as verification

A repository doc, a memory file, a KG hit, a handoff document, an earlier issue body, a comment.
These are claims. They go stale: modules are deleted, launchers move, functions are renamed.
Treat a name from any of these as a lead to verify, never as a fact to cite.

## When verification fails

Correct the anchor to what exists, or drop it. Never carry a name forward on the strength of the
source that supplied it. When a repository doc is the stale source, record that as a finding — a
docs task in the plan, or a comment on the issue — because the next reader will trust it too.

## Observed cases (2026-09-14, AI-Implement)

- `docs/issueless-runs.md` named `src/kg-push-token-vending.ts` as the push-token endpoint. The
  module had been deleted a week earlier (AII-583). The doc was the only source.
- A feature parent named `docker-entrypoint.sh` as the launcher of the KG sidecar. The script only
  runs `exec node dist/index.js`; the launcher is the `KgSidecar` class in `src/kg-sidecar.ts`.
  The claim came from a handoff document and was repeated into three places before the file was
  opened.

## Tool scope

[`tools/verify-issue-files.py`](./tools/verify-issue-files.py) checks the `## Files` list: paths
exist, `Create:` targets do not, shape limits hold. It does not check symbols, routes, tables, or
keys named in prose. Those are verified by hand, per this page.
