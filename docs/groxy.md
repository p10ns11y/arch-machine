# groxy — host→XChat notify + ACP remote control

Package: **`tools/groxy`** · Binary: **`groxy`** · Launch: **`bin/groxy`**

## Two supported surfaces

| Goal | Command | Transport |
|------|---------|-----------|
| **Notify** phone/self on XChat | `groxy --live inject "…"` | `xurl dm` (reliable) |
| **Control** Grok on this host | `groxy acp serve` | **ACP** WebSocket (`grok agent serve`) |

| Goal | Status |
|------|--------|
| XChat DM → host via `GET /2/dm_events` poll | **Not supported** (missing events + rate limits) |

## ACP remote control (production inbound to Grok)

ACP ([Agent Client Protocol](https://agentclientprotocol.com)) is the stable way to drive Grok with sessions, prompts, tools, and permissions—same protocol IDEs use.

```bash
# Explain architecture
./bin/groxy acp explain

# Check listener / secret / grok binary
./bin/groxy acp status

# Start ACP WebSocket agent (loopback + secret)
export GROK_AGENT_SECRET="your-long-secret"   # optional; else auto file under ~/.local/state/groxy/
./bin/groxy acp serve --cwd "$PWD"
# default bind: 127.0.0.1:2419
```

```text
ACP client (IDE / custom / phone over Tailscale)
        │  JSON-RPC WebSocket + secret
        ▼
  grok agent serve   ◄──  groxy acp serve
        │
        ▼
  host tools (files, shell, maintenance)

Optional notify:
  groxy --live inject "status"  →  XChat
```

**Security:** bind stays on **127.0.0.1** by default. For remote access use **SSH/Tailscale** to that port; do not open `0.0.0.0` without a secret and network policy.

**Multi-session:** several ACP clients can attach (see also `grok agent --leader`). Interactive Grok TUI windows remain separate; they do not auto-receive XChat DMs.

## Host → XChat (`inject`)

```bash
cargo build --manifest-path tools/groxy/Cargo.toml
make groxy-test

./bin/groxy --dry-run inject "ping"
export GROXY_ALLOW_SELF=1
./bin/groxy --live inject "status"
```

## Why not XChat → host poll?

Operator messages often never appear on `GET /2/dm_events` while inject works; the list endpoint is low-rate (~15/window). That is not a production control plane. **ACP replaces that role** for driving Grok; inject remains for notifications.

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
