# BuildDown Skills — Plugin Reference

Quick-reference table of every skill shipped in this plugin. Trigger phrases and full step-by-step
instructions are in each skill's `SKILL.md`.

| Skill | What it does |
|---|---|
| `bd-project-setup` | Wire a project's MCP servers, OAuth flows, and `CLAUDE.md` bindings once per project. |
| `bd-build-up` | Plan and file a milestone's worth of tracker issues from a product objective or design handoff. |
| `bd-mega-build-up` | `bd-build-up` with an adversarial design-review phase and repo ADR/glossary output. |
| `bd-high-plan` | Settle the high-level shape of a new capability as a small set of discrete steps before decomposing. |
| `bd-summit-push` | Optimize issue sequencing and body quality before sending a batch to the AI coding agent. |
| `bd-build-down` | Drive open PRs to merge: gap analysis, agent re-runs, verdicts, minimal follow-up issues. |
| `bd-super-build-down` | Autonomous, high-throughput `bd-build-down` for lean-back runs with many PRs. |
| `bd-smoke-jumper` | Autonomous PR smoke-testing — log into a preview deploy, run adaptive tests, post verdicts. |
| `bd-belay-on` | Formalize pause-and-recon handoffs between tools mid-session. |
| `bd-system-questions` | Ask the orchestrator about system health, in-flight jobs, project list, or runner mode. |
| `bd-kg-create` | Bootstrap a new KG repo from the `bd-knowledge-graph-base` template. |
| `bd-kg-refresh` | Refresh a project's KG via the orchestrator's refresh rail: preflight, reconcile scope, trigger, poll five stages to serving, verify. |
| `bd-mega-kg-refresh` | Local, interactive KG refresh: interrogate the served graph, propose and test ingest changes with the user, PR manifest/ingest changes to the KG repo, then hand off to bd-kg-refresh for the snapshot. Triggers: "bd-mega-kg-refresh", "change the ingest", "why is X not in the KG", "interactive KG refresh". |
| `bd-kg-search` | Hybrid-search the bound KG directly without running a full build-up/build-down session. |
