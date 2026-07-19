# archy — Ratatui control plane

**Main entry and loop controller** for arch-machine on Omarchy (and any Arch host).

You stay oriented: **Home › job › live stdio › next actions**.  
Heavy work stays in **shell scripts**, **Go `tinfoil`**, and **`install.sh`**.  
**Grok** opens fullscreen (TUI suspends) or sits in a **split dock** with session context.

## Build

```bash
cargo build --release --manifest-path crates/archy/Cargo.toml
# binary: crates/archy/target/release/archy
# or:     target/release/archy if using a workspace later
```

```bash
cargo run --manifest-path crates/archy/Cargo.toml
# with explicit root:
TINFOIL_ROOT=$PWD cargo run --manifest-path crates/archy/Cargo.toml
```

## Keys

| Key | Action |
|-----|--------|
| ↑↓ / j k | Menu or scroll output |
| Enter | Run selected command |
| Tab | Focus: menu → output → Grok → actions |
| g | Toggle Grok **split** dock |
| G | **Fullscreen** Grok launch (suspend TUI) |
| Esc | Home / leave Grok full layout |
| Ctrl+C | Cancel job / quit if idle |
| q | Quit (Home) |
| ? | Help |

## Backends (not reimplemented in Rust)

| Menu | Command |
|------|---------|
| Inventory | `maintenance/inventory.sh` |
| Audit global | `tinfoil audit` or `security-audit.sh --global` |
| Audit project | `tinfoil audit .` |
| Install dry-run | `install.sh --profile minimal --dry-run` |
| Evidence | `extract-evidence.sh --dry-run` |

## Architecture

```
archy (ratatui)           ← entry + loop + chrome + stdio beauty
    ├── jobs.rs           → spawn bash / tinfoil / install.sh
    ├── actions.rs        → next fix steps after exit
    └── Grok dock         → context file + suspend → `grok` → resume
```

**Iron peak:** JSON/scripts under `maintenance/`. This crate only steers.

## Wire as default `tinfoil tui`

When the release binary is on `PATH` as `archy`, the Go dispatcher can exec it first (see `bin/tinfoil.go`). Gum remains fallback.
