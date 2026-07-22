# Looper

**Structured agent loops over raw ReAct** — outer state machine, bounded inner steps, multi-model routing, HITL pause gates.

Agents discover and load the procedure via **[SKILL.md](SKILL.md)** (YAML `name` + `description`). This README is the human-facing index for install, layout, and validation.

## Why

Plain ReAct (Thought → Action → Observation → repeat) is creative but often:

- Implicit (state only in prompt history)
- Brittle (weak exit / retry / cancel)
- Hard to audit or hand off

**Thesis:** keep the agentic loop for adaptation; wrap it in a deterministic skeleton. Full argument: [X post by @Peramanathan](https://x.com/Peramanathan/status/2067890630345494578).

## Quick start

1. Install this skill (see root [README.md](../README.md) or [Portable wiring](SKILL.md#portable-wiring) in SKILL.md).
2. On multi-step work, open a **Loop Card** from [references/loop-card.md](references/loop-card.md).
3. Compose with [agent-orchestrator](../agent-orchestrator/SKILL.md) (triage/workers), not instead of it.
4. Optional Cursor rule: [../rules/looper.mdc](../rules/looper.mdc) (`alwaysApply: false`).

```bash
# From skills library root
mkdir -p ~/.cursor/skills ~/.cursor/rules
ln -sfn "$(pwd)/looper" ~/.cursor/skills/looper
ln -sfn "$(pwd)/rules/looper.mdc" ~/.cursor/rules/looper.mdc

node looper/scripts/validate-skill.mjs
```

## Layout

| Path | Purpose |
|------|---------|
| [SKILL.md](SKILL.md) | Full contract: phases, transitions, budgets, model roles, HITL, anti-patterns |
| [README.md](README.md) | This file — install + orientation |
| [references/loop-card.md](references/loop-card.md) | Copy-paste control surface for sessions |
| [scripts/validate-skill.mjs](scripts/validate-skill.mjs) | Structural contract check (skill body + indexes) |
| [../rules/looper.mdc](../rules/looper.mdc) | Optional Cursor discovery rule |

## What looper is / is not

| Is | Is not |
|----|--------|
| **Control plane** — phase, budget, route, gate | Domain product logic (finder, CV, X API) |
| Procedure + decision tables for agents | A runtime state-machine library / LangGraph |
| Composes with orchestrator, subagents, fusion/fission | A replacement for those skills |

## Model roles (summary)

`fast` · `explore` · `coding` · `deep` · `review` — see matrix in [SKILL.md](SKILL.md#model-routing-matrix). On single-model hosts, simulate roles with phase prompts and fresh review context.

## Related skills

- [agent-orchestrator](../agent-orchestrator/SKILL.md) — triage + multi-worker logistics  
- [subagent-delegation](../subagent-delegation/SKILL.md) — explore return format  
- [fusion-sage](../fusion-sage/SKILL.md) / [ai-optimization](../ai-optimization/SKILL.md) — synthesis / prune  
- [concurrent-cli-agents](../concurrent-cli-agents/SKILL.md) + [git-worktrees](../git-worktrees/SKILL.md) — parallel workers, clean merge  

## Reference

- https://x.com/Peramanathan/status/2067890630345494578
