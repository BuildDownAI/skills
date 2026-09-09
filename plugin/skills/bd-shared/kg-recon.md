# Knowledge Graph Recon

Shared recon procedure for the four session-owning skills (`bd-build-up`, `bd-mega-build-up`, `bd-build-down`, `bd-super-build-down`). After these skills post learnings to the tracker, the recon step here reads them back and closes the loop. When a project has a knowledge graph bound, recon orients the operator with relevant prior decisions and gaps.

## Guard

Read the project's CLAUDE.md for a `## Knowledge graph` block (format: `./kg-binding.md`). If `kg.present` is false or the block is absent, **skip silently — no output, no warning**. (This is an incidental step, one input among many; projects without a graph proceed unaffected.)

When the block is present and `kg.present: true`, continue to the query step.

## Query

Derive **1–3 short queries** from the work at hand — e.g. the objective's key nouns, or an issue key + title + gap topics from its gap analysis. These queries are brief and direct (2–4 words), surfacing the core concept(s) the operator needs orientation on.

Resolve the target per `./kg-binding.md` *Dual-target resolution* (try `kg.prefer` — default
orchestrator — fall back to the other bound target on error), then call its hybrid-search tool
(and only hybrid-search) with `{query, limit: 8}`. Repeat for each derived query. **Open the
recon output with the one-line target announce** (`KG: orchestrator …` / `KG: LOCAL FALLBACK —
…`) so the operator knows which graph oriented them.

## Use the results

Surface the top relevant learnings, decisions, and prior issues from the graph hits as **orientation context**. Where a hit changes a plan choice or closes a gap, cite it inline — e.g., "prior learning AII-259 says … so …" — to anchor the connection.

**Docs-grounded claims cite the section URL** (BDS-38). A `DocSection` hit's IRI encodes
`docpage/<url-encoded-page-url>#<anchor>` — decode it and cite the live anchor link (e.g.
"the SSO docs say … — https://docs.example.com/setup/sso#wire-the-orchestrator"), never just
the node title. Docs pages are crawled **at ingest**, so a docs citation is at most as fresh
as the graph stamp; when the staleness-delta (below) flags an old graph, append "docs as of
<stamp date>" to any docs-grounded citation so the reader knows the page may have moved on.

**Advisory, not required.** If nothing in the hits is relevant to the work at hand, say so in one line and move on. Do not force citations when the KG has no signal.

## Staleness-delta

The graph **stamps its own age at ingest** (`dcterms:modified` on the spine IRI) — ask the
graph, not the filesystem. Read the stamp from **whichever target served the recon queries**
(both serve it identically) with `kg_neighbors` on the spine IRI:

```
kg_neighbors(iri: "<namespace>resource/graph/spine")   # namespace from the graph's IRIs,
                                                       # e.g. https://kg.builddown.dev/
→ the dcterms:modified edge is the ingest date (ISO, UTC)
```

This is the **one sanctioned exception** to the hybrid-search-only rule (`./kg-binding.md`),
scoped strictly to reading the staleness stamp.

Compare to now and **always note the age in one line** — e.g., "graph as of 2026-08-08 (2 days
old)" or "KG is fresh (4 hours old)".

**If the KG is older than 24 hours**, list what the KG is blind to at its standard ingest points. The threshold is hour-granular, so use an ISO timestamp, not a bare date, in both queries:

- Tracker issues **updated** since the build time — query the project's bound tracker MCP (Linear "updated after `<ISO timestamp>`", Jira likewise) and report the count.
- PRs **merged** since — `gh pr list --state merged --search "merged:>=<YYYY-MM-DDTHH:MM:SSZ>" --limit 20` — and report the count.

Present the gap explicitly ("graph as of `<date>` (`<age>` ago); since then `N` issues changed, `M` PRs merged — treat results as missing these") and nudge the operator: run `bd-kg-refresh` (rail) for a fresh orchestrator graph; run `bd-mega-kg-refresh` (forthcoming — see BDS-49) if a source repo is missing from the ingest.

**If the KG is fresher than 24 hours**, skip these delta queries — stay fast. A recent build is good enough; no need to dig into tracker history.

## Failure tolerance

Any error — tool unavailable, degraded response, empty index, tracker or `gh` hiccup — generates **one-line note** and **proceeds**. Recon is advisory, never blocking.

- Missing tool → "KG search unavailable (tool error); proceeding without orientation."
- Auth failure, local bound → fall back per the dual-target rule and announce `KG: LOCAL FALLBACK — …`.
- Auth failure, no local bound → "orchestrator MCP token expired (1h TTL) — re-auth via /mcp in an interactive session; proceeding without orientation."
- Degraded index → "deployed sidecar is lexical-only (`degraded: true`); run `bd-kg-refresh` — the rail rebuilds embeddings."
- Empty index → "KG index empty; no prior learnings to draw on."
- No age stamp → "graph has no age stamp (pre-AII-326 snapshot); staleness unknown — a `bd-kg-refresh` adds it."
- Tracker query fails → "Tracker unavailable; staleness gap unknown."

The session continues unaffected.
