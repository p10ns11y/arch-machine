# xchat-remote (binary: **groxy**) — Rust XChat DM satellite

Eagle + satellite remote control for arch-machine hosts.

| Piece | Location |
|-------|----------|
| Cargo package | `tools/xchat-remote/` (explicit name — not a generic dump) |
| Binary | `groxy` |
| Entry shim | `bin/groxy` (prefers Rust build, falls back to Python v1) |
| Eagle skill | `eagle-satellite-elomaxz` |

```text
XChat DM  →  Eagle (process_direct_message_event)
                │ offline host job
                ▼
           inventory / ping / …
                │
                ▼
           outcome package (✓ Done + visual + PR)
                │
                ▼
           xurl dm  (or dry-run files)
```

## Commands

```bash
# Build
cargo build --manifest-path tools/xchat-remote/Cargo.toml
cargo test  --manifest-path tools/xchat-remote/Cargo.toml
# or: make groxy-test

# Help (twice — same banner)
./bin/groxy --help
./tools/xchat-remote/target/debug/groxy help

# Dry-run inject (no network)
./bin/groxy --dry-run --work-dir /tmp/groxy-work inject "ping"

# Dry-run fixture once
./bin/groxy --dry-run once --fixture tools/xchat-remote/tests/fixtures/inbound_status.json \
  --allow-id 100001

# Live one-shot (authenticated xurl)
export GROXY_ALLOW_SELF=1
export GROXY_PR_URL="https://github.com/<org>/<repo>/pull/<n>"
./bin/groxy --live inject "status"

# Live poll — ONE process; interval 90s → worst-case reply wait ≈ 90s
./bin/groxy --live poll --interval 90
```

## Latency

| Setting | Worst-case wait for a new DM |
|---------|------------------------------|
| `--interval 90` (default) | ~90s + job time |
| `--interval 60` | ~60s (still usually under X rate limit with one poller) |
| Rate limit 429 | extra sleep until window reset |

## Data hygiene

- No operator X user ids in source.
- Allowlist: `GROXY_ALLOW_SELF=1`, env ids, or gitignored `config/groxy/allowlist.local.conf`.
- Runtime self via `xurl /2/users/me`.

## Python v1

`tools/groxy/` remains a reference. New work goes in **Rust** `tools/xchat-remote`.

## Module map (readable names)

| Module | Role |
|--------|------|
| `eagle.rs` | Thin route: event → policy → host job → package |
| `command_parse.rs` | DM text → verb/args |
| `allowlist.rs` | Who may command |
| `outcome_package.rs` | Done bullets + visual (no host/cwd noise) |
| `host_job.rs` | Offline shell jobs |
| `dm_adapter.rs` | xurl / dry-run I/O |
| `state_store.rs` | Seen event ids + pending confirms |
| `main.rs` | CLI only |
