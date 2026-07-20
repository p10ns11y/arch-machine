# arch-machine — Agent Guide

Profile-based Arch Linux bootstrap + **archy** control plane (Ratatui) + thin **tinfoil** shim. Shell backends + evidence-first maintenance.

## Control flow (read this first for UI work)

```text
  keys / job lines  →  Msg  →  Eagle update  →  Cmd  →  Satellite / shell
                              (phase FSM)
```

Skill: **eagle-satellite-elomaxz** · Doc: `docs/archy.md` · Code: `crates/archy/`

## Active skills (symlinked or in-repo)

| Skill | Path | Use when |
|-------|------|----------|
| **eagle-satellite-elomaxz** | `.agents/skills/eagle-satellite-elomaxz` (in-repo) | Edit archy / TEA / job routing; Eagle+Satellites+Elomaxz message passing |
| ai-optimization | `.agents/skills/ai-optimization` | Large bash/Go scout; token budgets |
| fusion-sage | `.agents/skills/fusion-sage` | Cross-module synthesis + surplus |
| higher-order-decision-architect | `.agents/skills/higher-order-decision-architect` | Material architecture/security choices |
| session-unit-order | `.agents/skills/session-unit-order` (in-repo; `~/skills/session-unit-order` → same; also published to [p10ns11y/skills](https://github.com/p10ns11y/skills)) | User systemd + UWSM/Hyprland; on Omarchy also load **omarchy** skill; forbid `Wants=graphical-session` on Persistent timers |
| stellar-roadmap | `.agents/skills/stellar-roadmap` | `arch-design/coming-next.md`, SN-* cards |
| verification-cockpit | `.agents/skills/verification-cockpit` | Regenerate `.agents/verification/` |

**Overlays:** `.agents/overlays/arch-machine-*.md` (repo-specific; do not edit symlinked skill bodies).

## Fused abstraction

```text
archy (Eagle + satellites)  →  maintenance/*.sh / install.sh  →  evidence bundles
        ↑ TEA Msg/Cmd                    iron peak                    logs/
tinfoil.go / gum TUI          (optional shim / legacy)
```

**Sentinel surface** (`crates/archy`, optional `bin/tinfoil.go`, `lib/tui.sh`) → **profile installer** (`install.sh`, `lib/installer.sh`, `modules/*/`) → **maintenance heart** (`maintenance/*`, `policies/security-remediation.md`) → **evidence loop** (`lib/evidence.sh`, `logs/evidence-bundle-*.{json,toon}`).

## Verify before done

```bash
make lint                    # shellcheck + yamllint + markdownlint
make validate-profiles       # profile-validation-harness.sh
cargo test --manifest-path crates/archy/Cargo.toml
go build -o /tmp/tinfoil ./bin/tinfoil.go && go vet ./cmd/... ./bin/...
./install.sh --thin --validate
./maintenance/extract-evidence.sh --dry-run
```

**CI mirror:** `.github/workflows/ci.yml` (shellcheck, yamllint, go build/vet, profile validation stub, evidence smoke).

**Cockpit:** `av` delegates here when `.agents/verification/tmux-layout.sh` exists (requires host `~/.config/shell` verify libs).

## Never compress (agents)

- `install.sh`, `lib/installer.sh`, `policies/security-remediation.md`
- Files you will edit; module `install_*` contracts (`docs/MODULES.md`)
- `config/profiles/*.yaml` when changing profiles
- Destructive maintenance paths without dry-run first

## Key paths

| Area | Path |
|------|------|
| Architecture index | `docs/INDEX.md` |
| Roadmap | `arch-design/coming-next.md` |
| Keeper architecture | `arch-design/keeper.md` |
| Keeper backlog | `arch-design/coming-next-keeper.md` (SN-KEEP-*) |
| Profiles | `config/profiles/` |
| Modules | `modules/{system,development,ml_ai,security,productivity}/` |
| **Control plane (main)** | `crates/archy` · `docs/archy.md` · skill `eagle-satellite-elomaxz` |
| TUI (Elm/gum legacy) | `lib/tui/{model,view,update,messages}.sh` |
| CLI shim | `bin/tinfoil.go` (thin dispatcher; prefer shell backends) |
| Inventory | `maintenance/inventory.sh` → `tinfoil inventory` / schema v1 + ownership tags |
| Catalog | `maintenance/catalog.sh` → `tinfoil search` / schema `tinfoil.catalog.v1` |
| Package actuate | `maintenance/package-actuate.sh` → `tinfoil pkg` (dry-run default) |
| Omarchy | `docs/omarchy.md` + `docs/omarchy-commands.md` · `tinfoil omarchy` status |
| Evidence | `maintenance/extract-evidence.sh`, `lib/evidence.sh` |
| Surfaces | **archy** (main) · Grok plugin / dock · gum legacy |

## Expand commands

- `expand tui` / `expand archy` — Eagle+Satellites TEA control plane (`crates/archy`, `docs/archy.md`)
- `expand profiles` — YAML profile composition
- `expand evidence` — bundle schema + extraction pipeline
