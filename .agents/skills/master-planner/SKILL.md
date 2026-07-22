---
name: master-planner
description: >-
  Builds a project master plan as an interconnected web of friction-removing
  automations aimed at impossible missions. Installs portable skills via
  npx skills from https://skills.sh/p10ns11y/skills (skills-lock.json), tweaks
  via project overlays, and adds ontology for large/complex repos. Use for
  master plans, skill packs, overlay tweaks, ontology, or /master-planner.
---

# Master Planner

> A true master plan, to me, is only one thing: an interconnected, inter-related web of friction-removing automations aimed at impossible missions that great vision makes real.

**Job:** Live skill web for this project — install, lock, overlay, verify. Not a slide deck.

```text
https://skills.sh/p10ns11y/skills
        │  npx skills add …  →  skills-lock.json
        ▼
   .agents/skills/<name>/     (portable bodies — do not fork)
        │
   .agents/overlays/*.md      (THIS repo’s tweaks)
   .agents/ontology/          (optional addressable map)
        │
   .cursor/skills + .grok/skills  →  relative links to .agents/skills
```

**Catalog:** [skills.sh/p10ns11y/skills](https://www.skills.sh/p10ns11y/skills) · **Source:** [github.com/p10ns11y/skills](https://github.com/p10ns11y/skills)

**In this repo:** `master-planner` is **in-repo** until published to the catalog. Keep overlays here either way.

---

## When to run

| Signal | Action |
|--------|--------|
| Master plan / skill pack / `/master-planner` | Full workflow |
| Cold clone / teammate setup | `npx skills experimental_install` + verify |
| Project-only tweak | Edit overlay only — leave locked skills alone |
| Portable improvement | PR upstream → `npx skills update` → commit lock |

**Skip:** one-file typo, single bug with known path.

---

## Core law

Every skill, overlay, and ontology node must answer: **what impossible mission does this make routine?**

---

## Workflow

```
- [ ] 1. Orient — AGENTS.md, .agents/skills, overlays, mission one-liner
- [ ] 2. Pack — map stack → skill names from skills.sh/p10ns11y/skills
- [ ] 3. Install — npx skills add (writes skills-lock.json)
- [ ] 4. Wire — relative .cursor/skills + .grok/skills → .agents/skills
- [ ] 5. Tweak — Orwell overlays (never edit portable SKILL.md)
- [ ] 6. Ontology — if complex
- [ ] 7. Verify — lock present, links resolve, project checks
```

### Install / restore (shared)

```bash
# List catalog
npx skills add p10ns11y/skills -l

# Install pack into this project (Cursor → .agents/skills/)
npx skills add p10ns11y/skills \
  -s ai-optimization -s fusion-sage -s higher-order-decision-architect \
  -s stellar-roadmap -s verification-cockpit -s agent-orchestrator \
  -s looper -s git-worktrees \
  -a cursor -y --copy

# Teammates / CI: restore pinned hashes
npx skills experimental_install
```

Commit **`skills-lock.json`**. Prefer `--copy` so skill trees are real directories in-repo (no machine-local absolute paths).

### Wire agents (relative only)

```bash
mkdir -p .cursor/skills .grok/skills
for s in .agents/skills/*/; do
  name="$(basename "$s")"
  ln -sfn "../../.agents/skills/$name" ".cursor/skills/$name"
  ln -sfn "../../.agents/skills/$name" ".grok/skills/$name"
done
```

### Tweak (overlays)

| Write | Path |
|-------|------|
| Token / never-compress | `.agents/overlays/<project>-ai-optimization.md` |
| Fused aggregates | `.agents/overlays/<project>-fusion-sage.md` |
| Decision zones | `.agents/overlays/<project>-decision-hooks.md` |
| Roadmap scout | `.agents/overlays/<project>-stellar-roadmap.md` |
| Pack map | `.agents/overlays/<project>-master-planner.md` |

**Tweak law:** Orwell short English · action verbs · one arch diagram · tables over prose · real paths for *this* repo. See [references/orwell-tweak.md](references/orwell-tweak.md).

**Lock vs overlay:** `skills-lock.json` pins portable skills. Overlays are project-owned and **not** in the lock — that is correct.

### Ontology (large / complex)

When agents re-derive architecture every turn: `.agents/ontology/INDEX.md` + `*.graph.yaml`. Template: [references/ontology-template.md](references/ontology-template.md).

---

## Pack: arch-guardian (this project)

| Skill | Kind |
|-------|------|
| master-planner | in-repo (until catalog) |
| eagle-satellite-elomaxz | in-repo |
| session-unit-order | in-repo |
| ai-optimization, fusion-sage, higher-order-decision-architect, stellar-roadmap, verification-cockpit, agent-orchestrator, looper, git-worktrees | locked from p10ns11y/skills |

---

## Anti-patterns

- Absolute path symlinks into a private machine layout
- Editing locked `SKILL.md` for one-repo tweaks (use overlays)
- Committing skills without `skills-lock.json`
- Pulling the whole catalog “just in case”

---

## Extra

- [references/orwell-tweak.md](references/orwell-tweak.md)
- [references/ontology-template.md](references/ontology-template.md)
- [examples/arch-machine-pack.md](examples/arch-machine-pack.md)
- Router: `.cursor/rules/master-planner.mdc`
