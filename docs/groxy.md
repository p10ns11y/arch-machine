# groxy — XChat DM remote control (Rust)

Package: **`tools/groxy`** · Binary: **`groxy`** · Launch: **`bin/groxy`**

Eagle + satellite: one host poller reads XChat DMs, runs offline host jobs, replies with outcome packages.

```text
XChat DM  →  single groxy poller  →  host job (inventory/ping/…)
                                      →  ✓ Done + visual + PR  →  XChat DM
```

## Build & run

```bash
cargo build --manifest-path tools/groxy/Cargo.toml
cargo test  --manifest-path tools/groxy/Cargo.toml   # or: make groxy-test

./bin/groxy --help
./bin/groxy about

# Dry-run (no network)
./bin/groxy --dry-run inject "status" --sender-id 100001

# Live one-shot
export GROXY_ALLOW_SELF=1
export GROXY_PR_URL="https://github.com/<org>/<repo>/pull/<n>"
./bin/groxy --live inject "status"

# Live poll — ONE process only
./bin/groxy --live poll --interval 90
```

Worst-case reply latency ≈ **poll interval** (default 90s) + job time. X `dm_events` ≈ 15 reads/window.

## Data hygiene

- No operator X ids in git.
- `GROXY_ALLOW_SELF=1` (runtime `xurl /2/users/me`) or gitignored `config/groxy/allowlist.local.conf`.

## How an XChat message reaches the laptop (multi-Grok)

See **[Multi-Grok / XChat routing](#multi-grok--xchat-routing)** below (also summarized in the root README).

### Multi-Grok / XChat routing

**Short answer:** only the **groxy daemon** polls XChat. Interactive Grok TUI sessions (many windows) do **not** each receive DMs.

```text
                    ┌─────────────────────┐
   You (phone) ──DM─►│  X API dm_events    │
                    └──────────┬──────────┘
                               │ poll ~90s (one process)
                               ▼
                    ┌─────────────────────┐
                    │  groxy (tools/groxy) │  allowlist + parse + host job
                    └──────────┬──────────┘
                               │ reply DM
                               ▼
                            XChat you

   Grok TUI #1  ──┐
   Grok TUI #2  ──┼── separate sessions: code/chat in terminal
   Grok TUI #3  ──┘   they do NOT auto-subscribe to XChat DMs
```

| Surface | Receives XChat DMs? | Role |
|---------|---------------------|------|
| **`groxy --live poll`** | **Yes** (single poller) | Host remote control |
| **Grok Build TUI** (any number) | No (unless you run inject/tools yourself) | Interactive coding agents |
| **archy** TUI | No | Local menu control plane |

**Why one poller:** X rate-limits `dm_events` (~15/window). Multiple pollers burn the budget (429) and fight over state.  
**Session isolation:** each Grok TUI has its own transcript under `~/.grok/sessions/…`; groxy writes host effects under `~/.local/state/groxy/` and replies on XChat—it does not inject into a random open Grok window.  
**If you want a Grok session to act on a DM:** either (a) the poller runs a `run <prompt>` host job that invokes `grok -p`, or (b) you paste/inject from the laptop—there is no automatic fan-out to all open TUIs.

## Modules

| Module | Role |
|--------|------|
| `eagle.rs` | Route event → policy → job → package |
| `command_parse.rs` | DM text → verb |
| `allowlist.rs` | Who may command |
| `outcome_package.rs` | Done bullets + visual |
| `host_job.rs` | Offline shell jobs |
| `dm_adapter.rs` | xurl / dry-run I/O |
| `state_store.rs` | Seen events + confirms |
| `main.rs` | CLI |

## Related

- Control plane: [archy.md](archy.md) · `tools/archy`
- Skill: `eagle-satellite-elomaxz`
