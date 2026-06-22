# Overlay — arch-machine fusion playbook

**Pairs with:** [fusion-sage](../skills/fusion-sage/SKILL.md)

## Fused abstraction: Vigilant Guardian Loop

```
tinfoil (CLI/TUI) ──► install.sh + profiles ──► modules/install_* ──► maintenance orchestration
        ▲                                                      │
        └──────── evidence bundles (JSON/TOON) ◄────────────────┘
```

**Binding energy:** High — appears in `docs/INDEX.md`, `install.sh`, `maintenance/weekly-check.sh`, `lib/evidence.sh`, `bin/tinfoil.go`.

## Domain aggregates

| Aggregate | Sources | Stable API |
|-----------|---------|------------|
| **SentinelSurface** | `bin/tinfoil.go`, `lib/tui.sh`, `lib/tui/*` | `tinfoil`, `tinfoil tui`, audit/cleanup/evidence subcmds |
| **ProfileEngine** | `install.sh`, `lib/installer.sh`, `config/profiles/` | `--profile`, `--thin`, `--validate`, `--dry-run` |
| **ModuleBay** | `modules/*/install.sh` | `install_<name>()` per `docs/MODULES.md` |
| **EvidenceReactor** | `lib/evidence.sh`, `maintenance/extract-evidence.sh` | `logs/evidence-bundle-*.{json,toon}` |
| **RemediationPolicy** | `policies/security-remediation.md`, `maintenance/apply-remediation.sh` | 6-step audit→fix→kill meta-rule |

## Surplus targets (Q > 1)

1. **Single `ModuleRegistry` manifest** — derive profile validation + docs tables from `config/tools.yaml` (+47 tokens saved per profile task)
2. **TUI Message enum doc** — generate from `lib/tui/messages.sh` for agent-safe TUI edits
3. **Evidence schema pin** — `fusion-state.json` node for bundle fields agents may rely on

## Expand

- `expand SentinelSurface` → full Cobra + gum TUI graph
- `expand ProfileEngine` → harness + YAML includes graph
- `expand EvidenceReactor` → JSON/TOON field reference
