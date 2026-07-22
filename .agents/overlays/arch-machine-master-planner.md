# Overlay — arch-machine master planner

**Pairs with:** [master-planner](../skills/master-planner/SKILL.md)

**Mission:** Self-remediating Arch guardian — Eagle routes; shells act; evidence closes.

**Pack:** `arch-guardian` · **Ontology:** [../ontology/INDEX.md](../ontology/INDEX.md)

```text
Library skills ──symlink──► .agents/skills/
        │
        ├── eagle-* / session-unit-order  (in-repo)
        └── overlays + ontology           (project coords)
```

## Active pack

| Skill | Role |
|-------|------|
| master-planner | Pull / tweak / ontology |
| eagle-satellite-elomaxz | TEA control plane |
| session-unit-order | user-systemd / UWSM |
| ai-optimization | Token budget |
| fusion-sage | Fused loop + surplus |
| higher-order-decision-architect | Material bets |
| stellar-roadmap | SN-* cards |
| verification-cockpit | `av` cockpit |
| agent-orchestrator | Multi-step delivery |
| looper | Budgeted loops |
| git-worktrees | Isolated workers |

## Friction web (automations)

| Removes | Wire |
|---------|------|
| Rediscovering control flow | ontology `control` + eagle skill |
| Profile/module mismatch | `make validate-profiles` |
| Unsafe remediation | policy + dry-run evidence |
| Agent overwrite collisions | git-worktrees + orchestrator |
| Token bloat | ai-optimization overlay |

## Verify

```bash
# library: local or https://github.com/p10ns11y/skills (--from-remote)
"$HOME/Work/personal/skills/master-planner/scripts/verify-pack.sh" --project "$(pwd)"
make lint && make validate-profiles
cargo test --manifest-path tools/archy/Cargo.toml
./install.sh --thin --validate
```
