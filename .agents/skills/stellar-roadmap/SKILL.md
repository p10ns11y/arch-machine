---
name: stellar-roadmap
description: >-
  Authors evidence-driven architecture backlog docs (coming-next style): scorecards,
  mermaid diagrams, blueprint cards SN-*, thrive vision, gantt order. Use when
  creating or updating roadmaps, arch-design/coming-next.md, backlog after PRs,
  or when the user wants blueprint cards, Musk 5-step, or optimistic 10-year plans.
  Pairs with ai-optimization, fusion-sage, and higher-order-decision-architect.
---

# Stellar Roadmap — Architecture Backlog Blueprint

**Mission:** Produce **high-quality, scannable backlog docs** — diagrams and tables over prose, optimism grounded in evidence, blueprint cards agents can execute.

**Provenance:** collab-finder blueprint style; see [examples/shell-kernel.md](examples/shell-kernel.md) for a shell-kernel overlay pattern.

---

## When to use

- Create or refresh `coming-next.md`, `ROADMAP.md`, or `arch-design/*` backlog
- After a large PR: split **done log** vs **next blueprint cards**
- User asks for: blueprint cards, scorecard, thrive vision, SN-* items, gantt sprint order
- User attaches `/ai-optimization` `/fusion-sage` `/higher-order-decision-architect` for roadmap work

**Do not use for:** single-file bug fixes, code-only tasks, or pessimistic "this feature will die" post-mortems without a thrive north star.

---

## Companion skills (load together)

| Skill | Role in this workflow |
|-------|------------------------|
| [ai-optimization](../../ai-optimization/SKILL.md) | Hierarchy first; compress scout; tables > prose; never drop evidence columns |
| [fusion-sage](../../fusion-sage/SKILL.md) | Fused abstraction (1 diagram); surplus item at end; binding energy on backlog items |
| [higher-order-decision-architect](../../higher-order-decision-architect/SKILL.md) | Consequence chain table; guardrails not funeral; confidence % on thrive bets |

**Internal order:** scout (Context Sage) → decide (HODA) → synthesize (Fusion) → **write doc** (this skill).

---

## Tone rules (non-negotiable)

1. **Thrive, not survive** — platform shifts are cosmic weather you punch through; bottlenecks are judgment/trust, not typing.
2. **Evidence columns** — every scorecard row: Grade | One line | **Evidence** (file, test, metric).
3. **Short Orwellian English** — one idea per line; no hedge walls.
4. **Metaphor tier** — default **spacecraft** (ship computer, command bridge, hull, launch). User may say "plain" to drop metaphor.
5. **Risk ≠ defeat** — pre-mortem becomes **trajectory guardrails** (refuse vs build toward 2036). No "optional workflow that may die" framing for core product pillars the user cares about.
6. **Plain rule** — one closing sentence at footer; memorable, actionable.

---

## Mandatory workflow

### 1. Intake (ask only if missing)

| Input | Required |
|-------|----------|
| Target file path | Yes |
| Mission (one sentence) | Yes |
| What shipped (PR / commits) | Yes |
| Thrive picture (3–5 year horizon) | Yes |
| Backlog items (raw bullets OK) | Yes |
| Metaphor tier | Default spacecraft |

### 2. Structure (13 sections)

Use [references/document-template.md](references/document-template.md). For **scout**, load a repo-type overlay first: [examples/](examples/README.md) (`shell-kernel`, `eve-agent`) — expand full `coming-next.md` only for cards being edited.

Section map:

| § | Purpose |
|---|---------|
| 0 | Mission one sentence |
| 0b | Ten-year thrive picture (mermaid + table) |
| 1 | Scorecard shipped vs open |
| 2 | System map today |
| 3 | Precedence / data-flow (if applicable) |
| 4 | Musk 5-step on backlog |
| 5 | Trajectory forces (not "why we'll fail") |
| 6 | Guardrails refuse vs build |
| 7 | Blueprint cards SN-* |
| 8 | Scope lock (user decisions) |
| 9 | Gantt sprint order |
| 10 | Monitoring signals |
| 11 | Done log |
| 12 | File touch mindmap |
| 13 | References |

### 3. Blueprint card format (batch-2 style)

Each card **must** include:

```markdown
### SN-N · Title (verb-first)

**Problem:** One line.

```mermaid
[flow | sequence | state — pick one]
```

| File | Work |
|------|------|
| path | action |

**Done when:** Observable pass condition.

**Verify:** Commands or dogfood steps.
```

Priority: **SN-1 dogfood gate** (no new code) before feature cards.

### 4. Mermaid guardrails

- No spaces in node IDs (use camelCase)
- Subgraph titles in quotes if they contain special chars
- Prefer `flowchart` / `sequenceDiagram` / `stateDiagram-v2` / `gantt` / `mindmap`

### 5. Fusion pass before write

One fused abstraction in §0b or §2, e.g.:

> Kernel (ship computer) + Bridge (verification) + PLUGIN (hull bays) → host-agnostic manifest

Trace to ≥2 real paths in the repo.

### 6. Close with surplus

End agent reply (not necessarily the doc) with one **⚡ Fusion Surplus** line: backlog item or invariant that saves future roadmap tokens.

---

## External style sources (§13 pattern)

Always include a **References** table linking:

| Source | Use |
|--------|-----|
| Project boundary doc | e.g. PLUGIN.md |
| Risk / depth analysis | optional; thrive §0b is north star |
| collab-finder [intuitive-shell-plan](https://github.com/p10ns11y/collab-finder/blob/main/reports/intuitive-shell-plan.md) | Blueprint cards |
| collab-finder [batch-2-blueprints](https://github.com/p10ns11y/collab-finder/blob/main/reports/batch-2-engineering-blueprints.md) | Scorecard, gantt, done-when |
| collab-finder [single-pr-intuitive-product](https://github.com/p10ns11y/collab-finder/blob/main/reports/single-pr-intuitive-product.md) | Musk 5-step, 2nd/3rd order |

Full list: [references/external-sources.md](references/external-sources.md).

---

## Output checklist

- [ ] §0 mission is optimistic and concrete
- [ ] §0b thrive mermaid + 2036 table present
- [ ] Scorecard has Evidence column
- [ ] ≥3 blueprint cards with done-when + verify
- [ ] Gantt matches card priority
- [ ] No defeatist language on pillars user wants to keep
- [ ] References §13 complete
- [ ] Footer plain rule present

---

## Additional resources

- Full section template: [references/document-template.md](references/document-template.md)
- Lens integration detail: [references/companion-skills.md](references/companion-skills.md)
- **Repo-type overlays (scout ~30% cheaper):** [examples/README.md](examples/README.md) — [shell-kernel](examples/shell-kernel.md) · [eve-agent](examples/eve-agent.md) ([Eve](https://vercel.com/eve))
- Example output pattern: [examples/shell-kernel.md](examples/shell-kernel.md)
- Repo-specific full doc: copy overlay into target project or see skills library [shellyxz-shell-kernel overlay](../../examples/overlays/shellyxz-shell-kernel.md)

---

## Install

**Global** (skills library):

```bash
SKILLS_ROOT=~/skills   # clone path for the agent skills library
ln -sfn "$SKILLS_ROOT/stellar-roadmap" ~/.cursor/skills/stellar-roadmap
```

**Per-project:**

```bash
ln -sfn "$SKILLS_ROOT/stellar-roadmap" /path/to/repo/.agents/skills/stellar-roadmap
# or .cursor/skills/stellar-roadmap
```

Invoke: `/stellar-roadmap` or attach skill with companion skills for full pipeline.
