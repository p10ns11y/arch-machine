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

### stdio (Neovim) vs `acp serve` (WebSocket)

These are **different jobs**. Daily Neovim/avante does **not** need `acp serve`.

```text
Neovim avante  ──stdio──►  grok agent stdio     (child of nvim, this machine)
Phone / laptop / other   ──WS──►  grok agent serve  ◄── groxy acp serve
```

| | **stdio** (avante / CodeCompanion) | **serve** (`groxy acp serve`) |
|--|------------------------------------|--------------------------------|
| **Transport** | Child process, pipes | WebSocket (`127.0.0.1:2419` + secret) |
| **Who starts the agent** | The IDE spawns `grok agent stdio` | Operator keeps a long-lived server |
| **Lifetime** | One chat ↔ one agent process | Multiple clients can attach to one bind/cwd |
| **Best for** | Daily coding in Neovim | Remote / multi-client **control** of a workspace |

**Use stdio when:** editing in Neovim, agent should die with the chat, nothing outside the editor needs to drive that session.

**Use `acp serve` when:**

1. **Remote control** — laptop/phone over SSH/Tailscale to a home agent on a fixed project cwd (not spawned by local nvim).  
2. **Headless / no IDE** — machine runs agent; a thin ACP client or script sends prompts.  
3. **Shared long-lived agent** — reconnect to one serve process for a workspace without restarting via the editor.  
4. **Multi-client** — more than one ACP client on the **same** serve bind (stdio is always “this editor’s child”).  
5. **Separation from notify** — `inject` = XChat status only; **serve** = real control plane when DMs cannot drive the host.

| Path | Job |
|------|-----|
| **avante + stdio** | Local IDE agent (primary daily path) |
| **groxy acp serve** | Optional remote/long-lived control of a cwd |
| **groxy inject** | Host → XChat notify only (not control) |

### ACP secret: static on disk (rotate on leak)

The serve secret is **not** dynamic per restart. That is intentional for local loopback + clients that must know a stable token.

| Source | Behavior |
|--------|----------|
| `~/.local/state/groxy/acp-agent.secret` | Created on first serve; **reused** until deleted (mode `0600`) |
| `GROK_AGENT_SECRET` / `--secret` | Overrides the file when set |
| Restart serve alone | **Same** secret (static file) |

**Static is the right default** here: loopback bind, long-lived serve, clients need a stable value. Auto-rotate every boot without a secure handoff only breaks clients. Prefer rotate **on leak** (screenshot, `ps` argv, shared log), not continuous background rotation.

**Harden around leaks:** do not paste secrets into PR screenshots/chat; prefer not exposing secret on process argv if the CLI allows env/file; status may show presence/length only.

**Rotate (incident response):**

```bash
# 1) stop serve
pkill -f 'groxy acp serve' 2>/dev/null || true
pkill -f 'grok agent serve' 2>/dev/null || true

# 2) drop persisted secret (and clear env if you use it)
rm -f ~/.local/state/groxy/acp-agent.secret
unset GROK_AGENT_SECRET

# 3) start again → NEW secret written (or pass a fresh one)
./bin/groxy acp serve --cwd /path/to/workspace
# optional force:
# ./bin/groxy acp serve --cwd /path/to/workspace --secret "$(openssl rand -hex 24)"
```

If `GROK_AGENT_SECRET` is set in systemd user env or shell rc, clear that too or serve keeps the old value. After rotation, **all clients** must use the new secret.

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

# Control (WebSocket ACP server — any ACP client)
./bin/groxy acp serve --cwd /path/to/workspace
```

---

## IDE clients: Neovim (ACP) vs Cursor

| Client | ACP with Grok? | How |
|--------|----------------|-----|
| **Neovim** (avante.nvim / CodeCompanion) | **Yes** | Plugin spawns `grok agent stdio` (or custom command) |
| **Zed** | Yes | External agents |
| **Cursor Agents** | **No** | Cursor’s own agent stack; use terminal + ACP elsewhere |
| **Emacs** | Yes | agent-shell |

**Which chat is targeted?** The editor opens **one ACP agent process per chat/session** (stdio child). That process’s cwd (or `session/new` cwd) is the workspace. Opening a second Neovim ACP chat → second agent (or leader mode) — not “all DMs go to the focused buffer.”

```text
Neovim (avante / CodeCompanion)
        │  ACP over stdio (spawn child)
        ▼
  grok agent stdio     ←── Grok Build CLI
        │  tools, AGENTS.md, cwd = project root
        ▼
  your files / shell

Optional notify (separate):
  :! groxy --live inject "status" --session-label this-repo
```

---

## Neovim setup guide (Grok via ACP)

### Prerequisites

1. **Neovim** 0.10+ (avante often wants 0.11+ — check plugin README).
2. **Grok Build CLI** on `PATH` (`grok` works; auth via `grok login` or `XAI_API_KEY`).
3. Optional: this repo’s `bin/groxy` for XChat notify only (not required for ACP).

Verify:

```bash
which grok
grok agent stdio --help   # or: grok agent --help
# optional:
./bin/groxy acp status
```

### Option A — avante.nvim (recommended Cursor-like UX)

[avante.nvim](https://github.com/yetone/avante.nvim) supports **ACP providers** via `acp_providers` + `provider = "…"`.

#### lazy.nvim

```lua
-- ~/.config/nvim/lua/plugins/avante-grok.lua  (or merge into your lazy specs)
return {
  "yetone/avante.nvim",
  event = "VeryLazy",
  build = "make",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "MunifTanjim/nui.nvim",
  },
  opts = {
    -- Use the custom ACP provider name below
    provider = "grok-acp",
    -- ACP agents are registered here (command must speak ACP on stdio)
    acp_providers = {
      ["grok-acp"] = {
        command = "grok",
        args = {
          "agent",
          -- Optional: model / always-approve (see grok agent --help)
          -- "--model", "grok-build",
          -- "--always-approve",
          "stdio",
        },
        -- Env for this child process only
        env = {
          -- Prefer logged-in CLI auth; or set key if you use API path:
          -- XAI_API_KEY = os.getenv("XAI_API_KEY"),
        },
      },
    },
    -- Optional: when ACP agent edits, follow locations in buffers
    behaviour = {
      acp_follow_agent_locations = true,
      -- auto_approve_tool_permissions = true,  -- or false / list of tools
    },
  },
}
```

**Notes:**

- Prefer **`grok agent stdio`** for Neovim (plugin spawns the agent).  
  `groxy acp serve` is WebSocket-oriented; most Neovim plugins use **stdio** ACP, not WS.
- If `command` must be absolute: `command = vim.fn.expand("~/.grok/bin/grok")`.
- Project rules: put `AGENTS.md` / `avante.md` in the project root so the agent sees them.
- Switch provider: `:AvanteSwitchProvider grok-acp` (or your name).

**Known interop (avante WARN spam — not a misconfig):**

Grok agent emits **proprietary** JSON-RPC notifications under `_x.ai/*`
(e.g. `_x.ai/mcp/init_progress`, `_x.ai/mcp/server_status`, `_x.ai/mcp/servers_updated`)
while MCP servers (xapi, etc.) start. Stock [avante.nvim](https://github.com/yetone/avante.nvim)
`ACPClient:_handle_notification` only handles `session/*` and `fs/*` and otherwise
calls `vim.notify("Unknown notification method: …", WARN)`.

| Classification | Details |
|----------------|---------|
| **Not** | Wrong provider, missing `grok` PATH, failed build, or broken ACP session |
| **Is** | Client whitelist vs agent protocol extension (noise; session/tools still work) |
| Mitigations | (1) Ignore `_x.ai/*` in a small post-setup hook (see host `avante-grok.lua`); (2) wait for upstream avante to drop unknown-method WARNs; (3) optional: trim MCP servers in Grok config if you do not need them in that chat |

Operator re-check: `tools/groxy/scripts/verify-nvim-avante.sh`.

#### Usage in Neovim

| Action | Typical |
|--------|---------|
| Open sidebar / ask | `:AvanteAsk` / leader maps from plugin |
| Chat | `:AvanteChat` |
| Toggle | `:AvanteToggle` |
| Zen-mode CLI feel | see avante README (`avante` alias) |

Confirm the agent is Grok: first message should use Grok tools/session (not Claude/Gemini keys).

---

### Option B — CodeCompanion.nvim

[CodeCompanion](https://github.com/olimorris/codecompanion.nvim) supports ACP adapters (plugin version matters — need ACP-enabled release).

Pattern (check current docs for exact adapter names; shape is “CLI adapter that runs an ACP agent”):

```lua
-- Sketch — adjust adapter name to your CodeCompanion version’s ACP docs
{
  "olimorris/codecompanion.nvim",
  dependencies = { "nvim-lua/plenary.nvim" },
  opts = {
    strategies = {
      chat = {
        -- Many builds use an ACP/CLI adapter; wire command to grok:
        adapter = "grok_acp", -- if you register a custom adapter
      },
    },
    adapters = {
      -- Custom adapter example (verify against CodeCompanion’s ACP adapter API):
      grok_acp = function()
        return require("codecompanion.adapters").extend("acp", { -- or "cmd" / plugin-specific base
          name = "grok_acp",
          commands = {
            default = {
              "grok",
              "agent",
              "stdio",
            },
          },
        })
      end,
    },
  },
}
```

If your CodeCompanion version documents **ACP agents** differently (e.g. `adapters.acp` table), keep the same principle: **`command = grok`, `args = { "agent", "stdio" }`**.

---

### Option C — Terminal-only (no plugin)

Inside Neovim `:terminal`:

```bash
cd %:p:h   " or project root
grok                    # full Grok Build TUI (not ACP)
# or headless one-shot:
grok -p "review this file" --cwd .
```

For ACP WebSocket (other clients, remote):

```bash
./bin/groxy acp serve --cwd "$PWD"
# then connect from Zed / custom WS client — not from avante’s stdio path
```

---

### Multi-project / multi-session in Neovim

| Goal | Approach |
|------|----------|
| One project | Open Neovim in that root; ACP agent inherits cwd |
| Second project | New Neovim (or tab) in other root → **another** ACP child with that cwd |
| Shared backend | `grok agent --leader` (advanced; see Grok agent docs) |
| Label XChat notify | `:! groxy --live inject "status" --session-label this-repo` |

There is still **no** link from phone XChat DMs into the Avante buffer unless you build registry + inbound transport later.

---

### Troubleshooting (Neovim + Grok ACP)

| Symptom | Check |
|---------|--------|
| Plugin starts Claude/Gemini instead | `provider` / adapter name points at `grok-acp` |
| `Unknown notification method: _x.ai/mcp/…` WARN spam | Grok proprietary ACP extensions; avante only handles `session/*` + `fs/*`. Ignore `_x.ai/*` (host hook) or wait for upstream — **not** a broken install |
| `Sending message to fast!, API key is not yet set` | **Not** a missing XAI key for ACP. Stock avante sets `vim.g.avante_login=false` for ACP providers; `Sidebar:submit_input` then blocks. Host `avante-grok.lua` re-asserts login for ACP (and wraps Providers.setup / submit). Restart nvim after config change; `:AvanteSwitchProvider grok-acp` if needed |
| Do I need `acp serve` if avante works? | **No** for daily Neovim — avante uses **stdio**. Use serve for remote/long-lived/multi-client control only (see [stdio vs acp serve](#stdio-neovim-vs-acp-serve-websocket)) |
| Leaked serve secret / rotate | Secret is **static** on disk; restart does not rotate. See [ACP secret](#acp-secret-static-on-disk-rotate-on-leak) |
| `command not found: grok` | PATH / `~/.grok/bin` in Neovim’s env (`:echo $PATH`) |
| Auth errors | `grok login` in a real shell; or `XAI_API_KEY` for the child `env` |
| Wrong project files | Open Neovim with `nvim /path/to/project` so cwd is correct |
| Permissions every tool call | avante `auto_approve_tool_permissions` or pass `--always-approve` to `grok agent` (powerful — local only) |

---

### Cursor (for contrast)

Cursor Agents **do not** speak Grok ACP. From Cursor: use the **terminal** for `grok` / `groxy acp serve`, or an external ACP client. See multi-session section above.

---

## Data hygiene

- No operator X ids in git.  
- `GROXY_ALLOW_SELF=1` or gitignored local allowlist.

## Modules

| Module | Role |
|--------|------|
| `acp_remote.rs` | Launch/status for `grok agent serve` (WS); Neovim usually uses **stdio** directly |
| `eagle.rs` | inject path: policy → job → package |
| `command_parse` / `allowlist` / `outcome_package` | Pure logic |
| `host_job.rs` | Optional workspace scripts + `grok -p` |
| `dm_adapter.rs` | Outbound `xurl dm` |

## Related

- Grok agent mode: `~/.grok/docs/user-guide/15-agent-mode.md`
- ACP overview: [agentclientprotocol.com](https://agentclientprotocol.com)
- avante ACP: [yetone/avante.nvim#acp-support](https://github.com/yetone/avante.nvim#acp-support)
- CodeCompanion: [olimorris/codecompanion.nvim](https://github.com/olimorris/codecompanion.nvim)
- Control plane: [archy.md](archy.md) · `tools/archy`

