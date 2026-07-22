# Companion skill integration

Use when `/stellar-roadmap` is invoked with architecture backlog work.

## ai-optimization (Context Sage — fission)

**When:** Scouting repo before writing §1–§2.

| Apply | In roadmap doc |
|-------|----------------|
| Hierarchy first | §0 → §0b → scorecard before blueprint bodies |
| Relevance scoring | §12 mindmap only lists files that matter |
| Compression | Prose ≤2 sentences per card intro; rest is tables/mermaid |
| Never compress | Boundary docs, files being edited, verify commands |

**Do not** paste Context Sage header into the committed markdown file unless user wants meta headers.

## fusion-sage (synthesis + surplus)

**When:** After cards drafted, before final polish.

| Apply | In roadmap doc |
|-------|----------------|
| Fused abstraction | §0b diagram labels + one table row |
| Binding energy | Scorecard grades reflect reuse (A = iron peak) |
| Surplus | Agent reply ends with one backlog invariant suggestion |
| Traceability | Every fused node maps to ≥2 repo paths |

**Surplus examples for roadmaps:**

- `check-shell` invariant for overlay order (saved review tokens)
- `phase:project` direnv fragment (one pattern for all repos)
- MCP export of manifest (one schema, many hosts)

## higher-order-decision-architect (HODA)

**When:** Material backlog choices (split repo, freeze spec, delete surface).

| Apply | In roadmap doc |
|-------|----------------|
| Step 3 pre-mortem | Honest failure modes — scope creep, vendor anchors, coupling |
| **Step 8 thrive ascent** | Counter funeral drift; high-energy 2036 lens after pre-mortem |
| §5 Trajectory forces | Consequence chain with P() and **Response** column |
| §6 Guardrails | Inversion reframed: refuse vs build toward 2036 |
| Confidence | Note % on thrive bets in SN-7 class cards |
| Monitoring §10 | Leading indicators, not autopsy triggers |

**Step 8 outputs to mirror in docs:** ten-year thrive picture (§0b), iron-peak abstraction, acceleration trigger, refuse vs build table.

**Avoid in HODA + thrive docs:**

- "Pivot to minimal only" without acceleration alternative
- Binary will/won't when probability ranges exist
- Closing on abandon/shrink without thrive north star

## Invocation recipes

```
/stellar-roadmap /ai-optimization /fusion-sage /higher-order-decision-architect
Update arch-design/coming-next.md after PR #6
```

```
/stellar-roadmap
Refresh roadmap for {repo}; spacecraft metaphor; include §13 references
```

## Cursor rules (optional)

Symlink [../assets/cursorrules-template.md](../assets/cursorrules-template.md) to `.cursor/rules/stellar-roadmap.mdc` with `alwaysApply: false` — invoke on roadmap paths only.
