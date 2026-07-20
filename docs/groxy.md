# groxy — host → XChat outcome packages

Package: **`tools/groxy`** · Binary: **`groxy`** · Launch: **`bin/groxy`**

## What works (supported)

**Host → XChat** via **`inject`**: run a host job (ping, status, …), build an outcome package (`✓ Done: …` + visual panel + optional PR), send with `xurl dm` (or dry-run files).

```bash
cargo build --manifest-path tools/groxy/Cargo.toml
cargo test  --manifest-path tools/groxy/Cargo.toml   # make groxy-test

./bin/groxy --help
./bin/groxy about

# Dry-run (no network)
./bin/groxy --dry-run inject "ping"
./bin/groxy --dry-run inject "status"

# Live (authenticated xurl)
export GROXY_ALLOW_SELF=1
export GROXY_PR_URL="https://github.com/<org>/<repo>/pull/<n>"
./bin/groxy --live inject "ping"
./bin/groxy --live inject "status"
```

## What does **not** work (removed from product UX)

**XChat DM → host control** (live `poll` / reading `GET /2/dm_events` in a loop) is **not** a supported remote-control path.

| Direction | Status | Mechanism |
|-----------|--------|-----------|
| Host / Grok → XChat | **Supported** | `inject` + `xurl dm` |
| XChat → host / Grok | **Deferred** | Live poll removed from CLI |

**Why removed:** operator messages often **never appear** on `GET /2/dm_events` while inject sends reliably; the list endpoint is low-rate (~15/window) and multi-reader load causes 429s. Polishing poll is not production-grade without a **push** product (e.g. X Account Activity / webhooks) that we do not have on this host.

Revisit DM→host only with a documented push subscription and proof that a real phone/self-DM shows up as an event.

## Multi-Grok sessions

Interactive **Grok TUI** windows do **not** receive XChat DMs. They are separate laptop coding sessions under `~/.grok/sessions/…`.

```text
Laptop:  ./bin/groxy --live inject "status"  ──►  XChat (you)

Grok TUI #1 / #2 / #3  ── independent; not auto-driven by DMs
```

To notify yourself from the host or agent: use **inject**. To control the host from the phone via DM: **not available** until a real inbound transport exists.

## Data hygiene

- No operator X ids in git.
- `GROXY_ALLOW_SELF=1` or gitignored `config/groxy/allowlist.local.conf`.

## Modules

| Module | Role |
|--------|------|
| `eagle.rs` | Route synthetic/event → policy → job → package (used by inject + tests) |
| `command_parse.rs` | Text → verb |
| `allowlist.rs` | Who may command (inject path) |
| `outcome_package.rs` | Done bullets + visual |
| `host_job.rs` | Offline shell jobs |
| `dm_adapter.rs` | `xurl` send (+ list helper unused by CLI) |
| `main.rs` | CLI: about / inject / demo-outbound only |

## Related

- Control plane: [archy.md](archy.md) · `tools/archy`
- Skill: `eagle-satellite-elomaxz`
