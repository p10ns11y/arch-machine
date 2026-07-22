# arch-machine — Agent Guide

Profile-based Arch Linux bootstrap + **archy** control plane (Ratatui) + thin **tinfoil** shim. Shell backends + evidence-first maintenance.

## Control flow (read this first for UI work)

```text
  keys / job lines  →  Msg  →  Eagle update  →  Cmd  →  Satellite / shell
                              (phase FSM)
```

Skill: **eagle-satellite-elomaxz** · Doc: `docs/archy.md` · Code: `tools/archy/`

## Grok plugin ↔ archy (cyclic)

| Direction | Surface | Entry |
|-----------|---------|--------|
| Agent → host | Grok plugin `arch-machine` | `/arch-status`, `/arch-audit`, `/arch-control`, `/arch-init`, `/arch-expand` |
| Host → agent | archy co-pilot | `p` / `G` / brief Enter → `grok --cwd … "<preload>"` |

Plugin: [p10ns11y/plugins](https://github.com/p10ns11y/plugins) `arch-machine/` · cycle docs in `docs/archy.md`  
Do not tell users to run `am-*` by hand — slash commands only.

## Active skills

| Skill | Kind | Use when |
|-------|------|----------|
| **master-planner** | in-repo | Master plan / pack install / overlay tweak / ontology |
| **eagle-satellite-elomaxz** | in-repo | Edit archy / TEA / job routing |
| **session-unit-order** | in-repo | User systemd + UWSM/Hyprland; Omarchy → also **omarchy** skill |
| ai-optimization | locked | Large bash/Rust/Go scout; token budgets |
| fusion-sage | locked | Cross-module synthesis + surplus |
| higher-order-decision-architect | locked | Material architecture/security choices |
| stellar-roadmap | locked | `arch-design/coming-next.md`, SN-* cards |
| verification-cockpit | locked | Regenerate `.agents/verification/` |
| agent-orchestrator | locked | Multi-step / multi-agent delivery |
| looper | locked | Budgeted agent loops + HITL gates |
| git-worktrees | locked | Isolated worker worktrees |

**Catalog:** [skills.sh/p10ns11y/skills](https://www.skills.sh/p10ns11y/skills) · **Lock:** `skills-lock.json`  
**Install / restore:** `npx skills experimental_install` (or `.agents/skills/master-planner/scripts/pull-skills.sh .`)  
**Overlays:** `.agents/overlays/arch-machine-*.md` — project tweaks only; do not edit locked skill bodies.  
**Ontology:** `.agents/ontology/` — load by intent (`control` · `install` · `evidence` · `remote` · `vault` · `verify`).  
**Agent links:** `.cursor/skills/*` and `.grok/skills/*` → relative `../../.agents/skills/<name>`.

## Fused abstraction

```text
archy (Eagle + satellites)  →  maintenance/*.sh / install.sh  →  evidence bundles
        ↑ TEA Msg/Cmd                    iron peak                    logs/
tinfoil.go / gum TUI          (optional shim / legacy)

groxy:  inject → host job → XChat notify
        acp serve → grok agent serve (client picks cwd)
        (no ambient XChat → open TUI)
```

**Sentinel surface** (`tools/archy`, optional `bin/tinfoil.go`, `lib/tui.sh`) → **profile installer** (`install.sh`, `lib/installer.sh`, `modules/*/`) → **maintenance heart** (`maintenance/*`, `policies/security-remediation.md`) → **evidence loop** (`lib/evidence.sh`, `logs/evidence-bundle-*.{json,toon}`).  
**Remote:** `tools/groxy` / `bin/groxy` — inject + ACP only (see `docs/groxy.md`).

## Verify before done

```bash
make lint                    # shellcheck + yamllint + markdownlint
make validate-profiles       # profile-validation-harness.sh
cargo test --manifest-path tools/archy/Cargo.toml
cargo test --manifest-path tools/groxy/Cargo.toml
cargo test --manifest-path tools/keeper/Cargo.toml
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
| **Control plane (main)** | `tools/archy` · `docs/archy.md` · skill `eagle-satellite-elomaxz` |
| **Remote surfaces** | `tools/groxy` · `tools/groxy/README.md` · `docs/groxy.md` · `bin/groxy` (`inject` notify · `acp serve` control) |
| **Threshold vault** | `tools/keeper` · `tools/keeper/README.md` · `arch-design/keeper.md` · install via `modules/security/install.sh --agent-expand` |
| TUI (Elm/gum legacy) | `lib/tui/{model,view,update,messages}.sh` |
| CLI shim | `bin/tinfoil.go` (thin dispatcher; prefer shell backends) |
| Inventory | `maintenance/inventory.sh` → `tinfoil inventory` / schema v1 + ownership tags |
| Catalog | `maintenance/catalog.sh` → `tinfoil search` / schema `tinfoil.catalog.v1` |
| Package actuate | `maintenance/package-actuate.sh` → `tinfoil pkg` (dry-run default) |
| Omarchy | `docs/omarchy.md` + `docs/omarchy-commands.md` · `tinfoil omarchy` status |
| Evidence | `maintenance/extract-evidence.sh`, `lib/evidence.sh` |
| Surfaces | **archy** (main) · [Grok plugin](https://github.com/p10ns11y/plugins) `arch-machine` · gum legacy |
| Plugin ↔ archy cycle | `docs/archy.md` · plugin `docs/CROSS-REF.md` |

## Expand commands

- `expand tui` / `expand archy` / `expand control` — Eagle+Satellites TEA (`tools/archy`, ontology `control`)
- `expand groxy` / `expand remote` — inject + ACP (`tools/groxy`, ontology `remote`)
- `expand keeper` / `expand vault` — threshold vault (`tools/keeper`, ontology `vault`)
- `expand profiles` / `expand install` — YAML profiles + modules (ontology `install`)
- `expand evidence` — bundle schema + extraction (ontology `evidence`)
- `expand master-plan` — pull/tweak skill pack + ontology (skill `master-planner`)
