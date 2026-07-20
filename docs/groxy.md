# groxy — multi-session Grok remote surfaces

Package: **`tools/groxy`** · Binary: **`groxy`** · Launch: **`bin/groxy`**

groxy is **not** “arch-machine only.” It is a thin **router + notify helper** for any Grok workspace on the laptop. arch-machine jobs (`inventory`, …) run only when the workspace provides those scripts.

---

## The missing nuance: who is the DM for?

Several Grok processes can run at once:

| Process | What it is |
|---------|------------|
| Grok TUI session A | Interactive chat, cwd = project X |
| Grok TUI session B | Interactive chat, cwd = project Y |
| `grok agent serve` (ACP) | Remote-controllable agent, one bind/cwd (or leader) |
| `groxy inject` | One-shot host job → XChat notify |

**None of these automatically “listen” to XChat.**  
A Grok session only receives work when something **delivers a prompt** into it:

- Human types in the TUI  
- An **ACP client** sends `session/prompt`  
- A script runs `grok -p …` (new one-shot process, not “that open TUI”)

So even if a phone DM arrived perfectly, the system still needs a rule:

```text
incoming message  →  which session_id / cwd / agent?
```

Without that rule, “DM to Grok” is underspecified.

### Addressing (required for multi-session)

| Scheme | Example | Meaning |
|--------|---------|---------|
| **Explicit (best)** | ACP client connects to agent for cwd `/proj/A` | Client chooses the session |
| **Label on notify** | inject with `--session-label proj-a` | Outbound DM says *which* workspace finished work |
| **Keyword prefix** *(future inbound only)* | `!a status` → session alias `a` | Needs a registry + reliable inbound |
| **Broadcast to all TUIs** | — | Almost always wrong |

**There is no magic “listeners on the DM.”** Listeners must **register** (cwd, alias, ACP endpoint). Delivery is **push into that handle**, not ambient XChat.

---

## What we use today (no webhooks)

We are **not** building X Account Activity / webhooks / developer-platform inbound for DMs. Reasons: access tier, ops cost, and **routing still required** even with perfect delivery.

| Direction | Mechanism | Role |
|-----------|-----------|------|
| **Control Grok** | **ACP** (`groxy acp serve` → `grok agent serve`) | Production remote control |
| **Notify human** | **inject** → `xurl dm` | Reliable host → XChat |
| **XChat → host** | ~~`dm_events` poll~~ | **Not supported** |

```text
                    ┌──────────────────────┐
  ACP client ──────►│ grok agent serve     │──► tools in chosen cwd
  (picks endpoint)  │ (session + prompts)  │
                    └──────────────────────┘
                              │ optional
                              ▼
                    groxy inject ──► XChat  (notify only)

  Grok TUI A / B    separate; not DM listeners
  Phone XChat ──✗── no production path into a chosen TUI
```

---

## ACP (control any project)

```bash
./bin/groxy acp explain
./bin/groxy acp status
# Agent for THIS workspace (any git repo, not only arch-machine):
./bin/groxy acp serve --cwd /path/to/any/project
```

- Default bind: `127.0.0.1:2419` + secret (`GROK_AGENT_SECRET` or `~/.local/state/groxy/acp-agent.secret`)
- Remote: SSH/Tailscale to that port — **not** open internet without policy
- **Which chat?** The ACP client targets a **specific serve/cwd** (or leader socket). That *is* the addressing.
- Multiple projects: run multiple serves on different binds, or one agent with explicit cwd per session via the client’s `session/new`

`grok agent --leader` can share one backend among clients; clients still open distinct sessions. See Grok user-guide agent mode.

---

## inject (notify; optional workspace label)

```bash
# Workspace = cwd for host jobs (default: repo containing tools/groxy or GROXY_ROOT)
./bin/groxy --live inject "ping"
./bin/groxy --live inject "status" --session-label arch-machine

./bin/groxy --dry-run inject "ping" --session-label my-other-app
```

Outcome DMs can include a **session label** so when several projects notify the same X account, you know which workspace finished.

Host verbs like `status` / `inventory` look for `maintenance/*.sh` under the workspace; other projects without those scripts get a clear miss — use `run <prompt>` or ACP for general coding work.

---

## Why Grok TUI “listeners” don’t exist for DMs

| Idea | Reality |
|------|---------|
| “All open Groks hear my DM” | False — no bus from X → TUI |
| “The focused window gets it” | Would need a **focus registry** + inbound transport |
| “ACP knows my XChat” | ACP has no X integration; client sends prompts |
| “inject is inbound” | inject is **outbound** (host initiates) |

---

## If inbound XChat is ever revisited (not now)

Minimum production design (even without “webhooks” branding):

1. **Reliable event source** that actually delivers operator messages (push or equivalent product).  
2. **Session registry** file, e.g. `~/.local/state/groxy/sessions.json`:  
   `{ "alias": "am", "cwd": "…", "acp": "ws://127.0.0.1:2419", "updated_at": … }`  
3. **Addressing in the DM**: `!am status` or reply in a bound conversation.  
4. **Dispatcher**: resolve alias → send ACP `session/prompt` or spawn `grok -p` in that cwd.  
5. **Never** broadcast to every TUI.

Until (1) exists, shipping (2–5) only creates a dead control plane. That is why poll was removed.

---

## Commands (current)

```bash
make groxy-test
./bin/groxy --help

# Notify
export GROXY_ALLOW_SELF=1
./bin/groxy --live inject "status" --session-label my-workspace

# Control
./bin/groxy acp serve --cwd /path/to/workspace
```

## Data hygiene

- No operator X ids in git.  
- `GROXY_ALLOW_SELF=1` or gitignored local allowlist.

## Modules

| Module | Role |
|--------|------|
| `acp_remote.rs` | Launch/status for `grok agent serve` |
| `eagle.rs` | inject path: policy → job → package |
| `command_parse` / `allowlist` / `outcome_package` | Pure logic |
| `host_job.rs` | Optional workspace scripts + `grok -p` |
| `dm_adapter.rs` | Outbound `xurl dm` |
