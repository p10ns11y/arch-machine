# groxy — XChat DM remote control

**groxy** bridges **XChat DMs** ↔ this arch-machine host.

- **Inbound:** allowlisted sender DMs a command → host action (inventory, audit, grok headless, …)
- **Outbound:** result **summary** + **visual explanation** (ASCII panel + PNG) → XChat DM  
  (or identical dry-run files)

Not named xchat-bridge. Does **not** treat public posts as commands.

## Quick start

```bash
# From repo root
./bin/groxy --help

# Build a demo outbound package (no network)
./bin/groxy --dry-run demo-outbound

# Inject a local command (simulates allowlisted DM)
./bin/groxy --dry-run inject "status" --sender-id 295441607

# Process a fixture of DM events once
./bin/groxy --dry-run once --fixture tools/groxy/fixtures/inbound_status.json

# Live: poll X DM events and reply (requires xurl OAuth + DM scopes)
export GROXY_REPLY_TO=Peramanathan   # your X username (no @ required)
./bin/groxy --live once --reply-to Peramanathan
# daemon loop (remote control while this runs):
./bin/groxy --live poll --interval 45 --reply-to Peramanathan
```

**Phone remote control:** keep `groxy --live poll …` running on the host (tmux/systemd). DM yourself:

```text
!g status
ping
status
!g summarize open ports briefly
```

Replies are **outcome-first** (no host/cwd/package dumps):

```text
✓ Done: status
• Inventory: 236 explicit packages
• tools.yaml ok=18 miss=0; upgradable=0
• Ownership: arch-machine 14 · omarchy 157 · user 65
PR: https://github.com/p10ns11y/arch-machine/pull/N

╔════════════════════════════════╗
║ OK    status                   ║
…
╚════════════════════════════════╝
```

PR link sources: `GROXY_PR_URL` env, else `gh pr view` for the current branch, else any PR URL found in the command output.

```bash
export GROXY_PR_URL="https://github.com/p10ns11y/arch-machine/pull/31"  # optional pin
./bin/groxy --live poll --reply-to Peramanathan
```

Install to PATH (optional):

```bash
ln -sf "$PWD/bin/groxy" ~/.local/bin/groxy
```

## Allowlist (required)

Default config: `config/groxy/allowlist.conf`

```
allowlist_ids=295441607
allowlist_usernames=Peramanathan
require_confirm=true
```

Or env:

```bash
export GROXY_ALLOWLIST_IDS=295441607
export GROXY_ALLOWLIST_USERNAMES=Peramanathan
```

Empty allowlist = **fail closed** (nobody can command the host).

## Commands (DM text)

| DM text | Action |
|---------|--------|
| `help` / `!g help` | Command list |
| `ping` | Host liveness + effect log |
| `status` | `maintenance/inventory.sh --text` |
| `inventory` | inventory JSON/text |
| `audit` | security-audit (dry-run when supported) |
| `omarchy` | `omarchy-status.sh` |
| `run <prompt>` | `grok -p` with restricted tools (no YOLO by default) |
| `!g <free text>` | Same as `run` (prefix **required** for free-form) |
| `pkg …` etc. | High-blast → held until `confirm <token> …` |

Optional prefixes: `!g`, `!groxy`, `groxy`.

**Safety:** ordinary chat (e.g. “I have lost MFA…”) is **not** a command. Free-form only runs with `!g …` or an explicit `run …` verb. Single-letter aliases are not used (avoids English “I …” misfires).

## Safety

- Untrusted senders rejected; public posts rejected.
- High-blast verbs require `confirm <token>`.
- Default mode is **dry-run** (writes outbound under work dir, no live DM).
- `--live` sends real DMs via `xurl dm`.
- groxy policy is independent of Grok `always-approve`.

## Layout

| Path | Role |
|------|------|
| `bin/groxy` | Launchable entry |
| `tools/groxy/` | Python package (parse, policy, dispatch, package, I/O) |
| `config/groxy/allowlist.conf` | Operator allowlist |
| `~/.local/state/groxy/` | Default state + effects + outbound packages |
| `tools/groxy/tests/test_groxy.py` | Unit/integration tests |

## Tests

```bash
make groxy-test
# or
python3 tools/groxy/tests/test_groxy.py
```

## Work directory override

```bash
./bin/groxy --dry-run --work-dir /path/to/work inject "ping"
# effects:  work/effects/host-effect-*.txt
# outbound: work/outbound/evt-*/{summary.txt,visual.txt,visual.png,dm_payload.txt}
```
