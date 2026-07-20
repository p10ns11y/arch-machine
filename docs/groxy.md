# groxy — XChat DM remote control

**groxy** bridges **XChat DMs** ↔ this arch-machine host.

- **Inbound:** allowlisted sender DMs a command → host action (inventory, audit, grok headless, …)
- **Outbound:** outcome-first **summary** + **visual** → XChat DM (or dry-run files)

## Quick start (no identities in git)

```bash
# From repo root — live uses the xurl-authenticated account as allowlist + reply target
export GROXY_PR_URL="https://github.com/<org>/<repo>/pull/<n>"   # optional
export GROXY_ALLOW_SELF=1   # default when allowlist empty in live mode

# One poller only. X dm_events ≈ 15 reads/window — use 90s+
./bin/groxy --live poll --interval 90

# Or inject a one-shot without polling:
./bin/groxy --live inject "status"
```

Optional private allowlist (gitignored):

```bash
cp config/groxy/allowlist.conf.example config/groxy/allowlist.local.conf
# edit local file with YOUR id from: xurl /2/users/me
# never commit allowlist.local.conf
```

Env alternatives: `GROXY_ALLOWLIST_IDS`, `GROXY_ALLOWLIST_USERNAMES`, `GROXY_REPLY_TO`.

## Why XChat may not reply

| Cause | Fix |
|-------|-----|
| No poller running | `./bin/groxy --live poll --interval 90` (exactly **one** process) |
| Rate limit 429 | Stop all pollers; wait ~1–2 min; restart with interval ≥ 90 |
| Message not a command | Send `status`, `ping`, or `!g …` — free chat is ignored |
| Empty allowlist without self | `export GROXY_ALLOW_SELF=1` or local allowlist file |
| Seen-event dedupe | New message gets a new event id; resend command if needed |

Dry-run proof (no network):

```bash
./bin/groxy --dry-run inject "status" --sender-id 100001
./bin/groxy --dry-run once --fixture tools/groxy/fixtures/inbound_status.json
```

## Commands (DM text)

| DM text | Action |
|---------|--------|
| `help` | Command list |
| `ping` | Liveness |
| `status` / `inventory` | Inventory summary (not package dump) |
| `audit` / `omarchy` | Maintenance jobs |
| `run <prompt>` or `!g <free text>` | Restricted `grok -p` |
| high-blast (`pkg` …) | Held until `confirm <token> …` |

## Outbound shape (outcome-first)

```text
✓ Done: status
• Inventory: N explicit packages
• …
PR: https://github.com/…/pull/N

╔════════════════════════════════╗
║ OK    status                   ║
…
╚════════════════════════════════╝
```

No host/cwd/package dumps in the DM body.

## Architecture decision (Python v1 → Rust satellite)

### Why Python v1 shipped first

1. **Goal was a working remote loop the same session** (poll → allowlist → host job → DM).
2. **Official surface today is HTTP + `xurl`**, not a first-class “XChat SDK for agents.”
   - X API v2 DM endpoints (`/2/dm_events`, send DM) via authenticated HTTP.
   - This host already had **`xurl`** (OAuth + DM scopes). groxy shells out to it.
   - There is **no** blessed, stable “XChat Bot SDK” comparable to Slack Bolt / Discord.js for this control path. Community HTTP clients exist; they still speak the same REST.
3. Repo already uses **Python for pure logic tests** (eye-comfort). Fast unit tests without cargo link.

### Why that was the wrong long-term fit for *this* repo

- Control plane is **Rust (`crates/archy`)** with **Eagle + Satellites + TEA**.
- groxy should become a **satellite** (offline job style): Eagle starts poll/daemon; domain owns DM I/O + host dispatch — not a side Python tree forever.
- **Data hygiene:** identities belong in env / gitignored local config / runtime `users/me`, never committed.

### Target shape (Eagle / satellite)

```text
  XChat DM events  →  Msg::DmInbound
         │
         ▼
      Eagle (phase: Idle | Polling | RunningHost | Outbound)
         │ Cmd
         ▼
   Satellite: Groxy
     - read events (xurl / HTTP)
     - allowlist (local only)
     - host job (inventory.sh / …)
     - build outcome package
     - send DM
```

Skill: **eagle-satellite-elomaxz** (in-repo + global `~/.grok/skills/eagle-satellite-elomaxz`).

v1 Python stays as the reference loop + tests until a `crates/groxy` (or archy satellite) port lands.

## Safety

- Untrusted senders rejected; public posts rejected.
- High-blast needs confirm.
- Default mode dry-run; `--live` sends DMs.
- groxy policy is independent of Grok always-approve.
- **Do not commit** `allowlist.local.conf` or real user ids.

## Layout

| Path | Role |
|------|------|
| `bin/groxy` | Entry |
| `tools/groxy/` | Python v1 package |
| `config/groxy/allowlist.conf` | Template (no identities) |
| `config/groxy/allowlist.local.conf` | Operator private (gitignored) |
| `docs/groxy.md` | This doc |

## Tests

```bash
make groxy-test
```
