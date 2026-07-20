---
name: eagle-satellite-elomaxz
description: >-
  Architecture skill for arch-machine control flow: Eagle + Satellites (thin top
  orchestrator + domain jobs), xstate-style state machines / DAGs, and Elomaxz /
  Elm TEA message passing (Msg → update → Cmd). Use when editing crates/archy,
  lib/tui TEA, designing agent loops, control-plane UI, job runners, or when the
  user says Eagle, satellite, Elomaxz, TEA, state machine, machine graph, or
  "how does archy route work". Slash: /eagle-satellite-elomaxz.
---

# Eagle · Satellites · Elomaxz message passing

**One sentence:** A thin **Eagle** routes **messages**; **Satellites** own domain work; jobs are **offline** (fire → work → verify exit). The UI loop is **Elm/TEA** (Elomaxz discipline), not a spaghetti `match` in one file.

**In this repo the live implementation is** `crates/archy/`.  
Gum legacy mirrors the same idea in bash: `lib/tui/{messages,model,update,view}.sh`.

Deep diagrams: [references/machine-graph.md](references/machine-graph.md) · Human doc: [docs/archy.md](../../../docs/archy.md).

---

## When to load

| Signal | Load this skill |
|--------|-----------------|
| Edit `crates/archy/**` | **Yes** |
| New menu job / backend wire-up | **Yes** |
| “Where should this control flow live?” | **Yes** |
| Gum TEA (`lib/tui`) redesign | **Yes** (same pattern) |
| Change only `maintenance/*.sh` body logic | No (keep shell; wire from satellite) |
| Pure package/module install | No |

---

## Picture in your head

```text
You press a key  ──►  Message (event)
                          │
                          ▼
                    ┌──────────┐
                    │  EAGLE   │  thin brain: phase + update
                    │  only    │  never builds shell commands
                    └────┬─────┘
                         │ Command (effect)
           ┌─────────────┼─────────────┐
           ▼             ▼             ▼
      Satellite     Satellite      Co-pilot
      Inventory     Audit …        Launch Grok
           │
           ▼
      Offline job: start script → stream lines → check exit
                         │
                         ▼
                   NEXT bar (what to do next)
```

**Eagle** = orchestrator of orchestrators (routes + global view).  
**Satellite** = one domain (inventory, audit, install dry-run, …) that owns its full sub-flow.  
**Offline satellite** = no live chat with Eagle while running; Eagle only starts it and later reads the result.

---

## Elomaxz / TEA message passing (required shape)

Same loop as Elm and the gum TUI. Names in Rust:

| TEA name | archy file | Simple meaning |
|----------|------------|----------------|
| **Model** | `app.rs` (`App`) | All UI + job state |
| **Msg** / Event | `msg.rs` | Something happened (key, line, job done) |
| **Update** | `eagle.rs` | Pure-ish: change model, return a **Cmd** |
| **Cmd** / Effect | `cmd.rs` | Side effect for runtime to run |
| **View** | `ui.rs` | Draw model only |

```text
Runtime loop (main.rs):

  draw(view)
  if pending Grok → suspend TUI
  tick()  → JobLine / JobFinished messages
  key     → Msg::Key
  dispatch(msg) → Cmd
  perform(cmd)  → spawn / kill / quit / launch Grok
```

### Rules agents must not break

1. **Do not** spawn processes inside `eagle::update` — only return `Cmd`.
2. **Do not** put inventory/audit shell paths in Eagle — put them in `satellites/`.
3. **Do not** teach the user in every panel — sparse chrome; long text only on Help (`?`).
4. **Do not** invent a second menu list — menu order is `satellites::MENU` only.
5. Keys become **Msg**; job stdio becomes **Msg**; never mutate model from `main` except via `dispatch` / `perform`.

---

## State machine (xstate-style)

Named **phases** (not “whatever bools we had”):

```text
         ┌──────┐
    ┌───►│ Home │◄──────────────────┐
    │    └──┬───┘                   │
    │       │ FireSatellite         │ Esc / Home action
    │       ▼                       │
    │    ┌─────────┐                │
    │    │ Running │  (job live)    │
    │    └────┬────┘                │
    │         │ JobFinished         │
    │         ▼                     │
    │    ┌────────┐                 │
    └────│ Review │─────────────────┘
         └────────┘
              │
         ┌────┴────┐
         │  Help   │  (? key; Esc → Home)
         └─────────┘
```

| Phase | Operator sees | Next typical event |
|-------|---------------|--------------------|
| **Home** | Menu | Fire satellite / Help / Quit |
| **Running** | Live stdio | JobFinished / Cancel |
| **Review** | NEXT bar | Re-run, other action, Esc home |
| **Help** | Long help text | Esc / Enter → Home |

**DAG for one offline job** (edges only go forward, then branch on NEXT):

```text
Fire → spawn → (JobLine)* → JobFinished → build NEXT plan → Review
                                                      │
                              ┌───────────────────────┼────────────────┐
                              ▼                       ▼                ▼
                         Re-Fire same            Fire other sat     Home
```

Guards live in `eagle::update` (e.g. refuse second Fire while `job` is Some).

---

## Satellites registry

| Satellite | Shell / backend (iron peak) |
|-----------|-----------------------------|
| Inventory | `maintenance/inventory.sh` |
| Catalog | `maintenance/catalog.sh` |
| Omarchy | `maintenance/omarchy-status.sh` |
| Audit global/project | `security-audit` / tinfoil |
| Install dry-run | `install.sh --profile … --dry-run` |
| Evidence | `extract-evidence.sh --dry-run` |
| Actuate dry-run | `package-actuate.sh` |

Each satellite owns:

1. **build** — how to construct the `Command`
2. **title** — short stdio header
3. **on_finished** — exit + lines → NEXT actions (primary first)
4. **grok_ask** — short co-pilot prompt for that job

Co-pilot is **not** a chat pane: brief is layout only; real Grok is `Cmd::LaunchGrok` (suspend TUI).

---

## Adding a new job (agent checklist)

1. Add backend under `maintenance/` if needed (dry-run by default).
2. Add `SatelliteId` + `MenuEntry` in `crates/archy/src/satellites/mod.rs`.
3. Implement `build` / `title` / finish path (reuse `actions::suggest_with_hints` or extend).
4. Map any new `ActionId` in `action_to_satellite` if NEXT should re-fire it.
5. Unit test: menu len / finish primary for the happy path.
6. `cargo test --manifest-path crates/archy/Cargo.toml`
7. Do **not** grow `eagle.rs` with domain strings.

---

## Gum TEA twin (Elomaxz in bash)

| Bash | Role |
|------|------|
| `lib/tui/messages.sh` | Msg constants |
| `lib/tui/model.sh` | Model |
| `lib/tui/update.sh` | Update (no gum I/O) |
| `lib/tui/view.sh` | View |

Prefer archy for new operator surfaces; keep gum as fallback.

---

## Anti-patterns

| Don’t | Do |
|-------|-----|
| One giant `on_key` with package names | Msg → Eagle → satellite |
| Heartbeat threads “is job alive?” spam | Poll exit + line channel (offline) |
| Dyn trait soup for two functions | Enum `SatelliteId` + match |
| Live Grok inside split pane | Brief + suspend launch |
| Dry-run that still `sudo` writes | Honor `DRY_RUN` in install thin path |

---

## Verify after architecture edits

```bash
cargo test --manifest-path crates/archy/Cargo.toml
cargo build --release --manifest-path crates/archy/Cargo.toml
# optional: run inventory from TUI; NEXT primary should match summary hints
```

## Sources (design thesis)

- [Eagle + Satellites](https://x.com/Peramanathan/status/2078680221059039361) — hierarchical swarm control (orchestrator of orchestrators).
- [Offline satellites](https://x.com/Peramanathan/status/2078703537849241742) — fire async → structural work → verify outcome (no constant monitoring).
- [Structured loops over raw ReAct](https://x.com/Peramanathan/status/2067890630345494578) — outer state machine + bounded inner steps.
- Elomaxz / Elm TEA: message in, model out, effects as commands — same as `lib/tui`.

Keep the creative loop; give it a **machine graph** with clear edges.
