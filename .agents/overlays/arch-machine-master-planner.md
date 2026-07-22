# Overlay — arch-machine master planner

**Pairs with:** [master-planner](../skills/master-planner/SKILL.md)

**Mission:** Self-remediating Arch guardian — Eagle routes; shells act; evidence closes.

**Catalog:** [skills.sh/p10ns11y/skills](https://www.skills.sh/p10ns11y/skills) · **Lock:** `skills-lock.json`

```text
npx skills add p10ns11y/skills -s … --copy
        │
.agents/skills/  ← portable (locked) + in-repo (eagle, session, master-planner)
        │
.agents/overlays/  ← THIS repo’s tweaks only
.cursor/skills + .grok/skills  →  ../../.agents/skills/*
```

## Active pack

| Skill | Kind |
|-------|------|
| master-planner | in-repo (until published to catalog) |
| eagle-satellite-elomaxz | in-repo |
| session-unit-order | in-repo |
| ai-optimization · fusion-sage · HODA · stellar-roadmap · verification-cockpit · agent-orchestrator · looper · git-worktrees | locked from p10ns11y/skills |

## Friction web

| Removes | Wire |
|---------|------|
| Rediscovering control flow | ontology `control` + eagle skill |
| Profile/module drift | `make validate-profiles` |
| Unsafe remediation | policy + dry-run evidence |
| Agent overwrite collisions | git-worktrees + orchestrator |
| Token bloat | ai-optimization overlay |

## Restore / verify

```bash
npx skills experimental_install
.agents/skills/master-planner/scripts/verify-pack.sh .
make lint && make validate-profiles
```
