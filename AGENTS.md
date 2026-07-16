# arch-machine — Agent Guide

Profile-based Arch Linux bootstrap + **tinfoil** sentinel (CLI + Bubble Tea/gum TUI). Evidence-first maintenance loop.

## Active skills (symlinked)

| Skill | Path | Use when |
|-------|------|----------|
| ai-optimization | `.agents/skills/ai-optimization` | Large bash/Go scout; token budgets |
| fusion-sage | `.agents/skills/fusion-sage` | Cross-module synthesis + surplus |
| higher-order-decision-architect | `.agents/skills/higher-order-decision-architect` | Material architecture/security choices |
| session-unit-order | `.agents/skills/session-unit-order` (in-repo; `~/skills/session-unit-order` → same; also published to [p10ns11y/skills](https://github.com/p10ns11y/skills)) | User systemd + UWSM/Hyprland; on Omarchy also load **omarchy** skill; forbid `Wants=graphical-session` on Persistent timers |
| stellar-roadmap | `.agents/skills/stellar-roadmap` | `arch-design/coming-next.md`, SN-* cards |
| verification-cockpit | `.agents/skills/verification-cockpit` | Regenerate `.agents/verification/` |

**Overlays:** `.agents/overlays/arch-machine-*.md` (repo-specific; do not edit symlinked skill bodies).

## Fused abstraction

**Sentinel surface** (`bin/tinfoil.go`, `lib/tui.sh`) → **profile installer** (`install.sh`, `lib/installer.sh`, `modules/*/`) → **maintenance heart** (`maintenance/*`, `policies/security-remediation.md`) → **evidence loop** (`lib/evidence.sh`, `logs/evidence-bundle-*.{json,toon}`).

## Verify before done

```bash
make lint                    # shellcheck + yamllint + markdownlint
make validate-profiles       # profile-validation-harness.sh
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
| Profiles | `config/profiles/` |
| Modules | `modules/{system,development,ml_ai,security,productivity}/` |
| TUI (Elm/gum) | `lib/tui/{model,view,update,messages}.sh` |
| CLI | `bin/tinfoil.go` |
| Evidence | `maintenance/extract-evidence.sh`, `lib/evidence.sh` |

## Expand commands

- `expand tui` — full Elm TUI stack
- `expand profiles` — YAML profile composition
- `expand evidence` — bundle schema + extraction pipeline
