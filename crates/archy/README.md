# archy — Ratatui control plane

**Main entry and loop controller** for arch-machine on Omarchy (and any Arch host).

You stay oriented: **Home › job › live stdio › next actions**.  
Heavy work stays in **shell scripts**, **Go `tinfoil`**, and **`install.sh`**.

**Palette:** eye-comfort **light or dark** at startup (restrained sage/amber).

### Theme detection (startup only)

Ratatui cannot inherit a full OS/GTK theme. archy picks **light vs dark** once, in this order (same as `theme::resolve_theme_mode` / `detect_theme_mode`):

1. `ARCHY_THEME=light|dark` (override)
2. Omarchy `~/.config/omarchy/current/theme/colors.toml` **background** luminance (`#RRGGBB` → light if bright paper)
3. `~/.config/omarchy/current/theme.name` (eye-comfort / Omarchy package name heuristics, including TN packages)
4. `COLORFGBG` terminal background index
5. default **dark**

No live phase hot-reload. Details: `?` help.

## Co-pilot (Grok)

| Mode | What it is |
|------|------------|
| **Brief (split)** `g` | Sparse side panel — job + suggested ask. **Not a live chat.** |
| **Launch** `G` / **Enter** in brief / next `[p]` | Suspends TUI, writes `logs/archy-grok-context.txt`, runs `grok`. |

Env on launch: `ARCHY_ROOT`, `ARCHY_GROK_ASK`, `ARCHY_GROK_CONTEXT_FILE`, `TINFOIL_ROOT`.

After a job finishes, the **NEXT** bar shows one primary action (amber) plus muted secondaries.
Primaries are **job-aware**: inventory uses `tools_yaml_miss` / `upgradable` from the summary line
(missing tools → install dry-run; upgradable → pkg dry-run; clean → audit).

## Build

```bash
cargo build --release --manifest-path crates/archy/Cargo.toml
# binary: crates/archy/target/release/archy
```

```bash
cargo run --manifest-path crates/archy/Cargo.toml
TINFOIL_ROOT=$PWD cargo run --manifest-path crates/archy/Cargo.toml -- --grok-split
```

## Keys

| Key | Action |
|-----|--------|
| ↑↓ / j k | Menu or scroll output |
| Enter | Run command · in brief: launch Grok · on next focus: primary |
| Tab | Focus: menu → stdio → brief → next |
| g | Toggle co-pilot **brief** |
| G / p | Launch Grok (`p` from NEXT bar) |
| Esc | Home |
| Ctrl+C | Cancel job / quit if idle |
| q | Quit (Home) |
| ? | Help (keys + theme limits) |

## Backends (not reimplemented in Rust)

| Menu | Command |
|------|---------|
| Inventory | `maintenance/inventory.sh` |
| Catalog | `maintenance/catalog.sh` |
| Omarchy status | `maintenance/omarchy-status.sh` |
| Audit | `security-audit.sh` / tinfoil |
| Install dry-run | `install.sh --profile … --dry-run` |
| Evidence | `extract-evidence.sh --dry-run` |
| Actuate dry-run | `package-actuate.sh` |

## Architecture — Eagle + Satellites (TEA / xstate-inspired)

```
  Key / JobLine / JobFinished
              │
              ▼
        ┌───────────┐
        │   Eagle   │  fsm::Phase + eagle::update(msg) → Cmd
        │  (TEA)    │  routes only — no domain builders
        └─────┬─────┘
              │ Cmd::FireSatellite | KillJob | LaunchGrok | Quit
              ▼
   satellites/*  (Inventory, Catalog, Omarchy, Audit, Install, …)
              │  each owns: build Command + finish → NEXT plan
              ▼
        jobs.rs   offline runner: fire → stream lines → poll exit
```

| Piece | Role (xstate analogy) |
|-------|------------------------|
| `fsm::Phase` | Finite **states** (Home / Help / Running / Review) |
| `msg::Msg` | **Events** |
| `App` fields | **Context** |
| `eagle::update` | Transition table + assigns |
| `cmd::Cmd` | **Actions** / invoked services |
| `satellites` | Domain orchestrators (offline when jobs) |
| `main` loop | Interprets Cmd (spawn, kill, suspend Grok) |

**Phases:** `Home → (Fire) → Running → (JobFinished) → Review → (NEXT / Esc) → Home`  
Offline satellites: no heartbeats — trigger, structural shell work, verify exit + stdio.

Gum TEA (`lib/tui`) is the same discipline in bash; this crate mirrors it in Rust.

**Iron peak:** JSON/scripts under `maintenance/`. This crate only steers.

## Wire as default `tinfoil tui`

When the release binary is on `PATH` as `archy`, the Go dispatcher can exec it first (see `bin/tinfoil.go`). Gum remains fallback.
