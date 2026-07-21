# grok-acp-plugin (Neovim / avante example)

**Representative use case for Grok ACP over stdio** — the daily Neovim path  
documented in [docs/groxy.md](../../../../../docs/groxy.md).

| This is | This is **not** |
|---------|------------------|
| A **Lazy.nvim / LazyVim plugin spec** (`return { "yetone/avante.nvim", … }`) | A Grok agent slash-plugin under `plugins/arch-machine` |
| How **avante.nvim** spawns `grok agent … stdio` | `groxy acp serve` (WebSocket / remote multi-client) |
| Host UI wiring (login fix, **consume `_x.ai/*` MCP status**, zen, UI harden) | The vault (`tools/keeper`) or control plane (`tools/archy`) |

```text
  Neovim (avante)
       │  spawn child
       ▼
  grok agent … stdio     ← this extras tree documents that path
       │
       ▼
  tools / cwd (project)

  groxy acp serve        ← different job (remote WS); not required for avante
```

## Publish decision

**Keep this tree in arch-machine only** (`tools/groxy/extras/…`) until:

1. Host patches shrink (monkey-patches on avante ACP / file selector / sidebar), **or**
2. Equivalent hooks land upstream in `yetone/avante.nvim` / Grok agent.

Do **not** publish as a standalone Lazy plugin or nest under `plugins/arch-machine` yet.  
SoT for dogfooding stays: this directory.

## Layout

```text
tools/groxy/extras/neovim/plugins/grok-acp-plugin/
  README.md           # this file
  avante-grok.lua     # Lazy spec (SoT — host must track this)
```

## Install on a host (keep in sync)

**SoT:** `tools/groxy/extras/neovim/plugins/grok-acp-plugin/avante-grok.lua`  
**Host:** `~/.config/nvim/lua/plugins/avante-grok.lua`

Prefer a **symlink** so Lazy always loads the repo copy:

```bash
# from arch-machine checkout
ln -sfn "$(pwd)/tools/groxy/extras/neovim/plugins/grok-acp-plugin/avante-grok.lua" \
  ~/.config/nvim/lua/plugins/avante-grok.lua
```

Or copy after each pull (files should match size / content):

```bash
cp tools/groxy/extras/neovim/plugins/grok-acp-plugin/avante-grok.lua \
  ~/.config/nvim/lua/plugins/avante-grok.lua
```

```bash
# sanity: host must track SoT
diff -q ~/.config/nvim/lua/plugins/avante-grok.lua \
  tools/groxy/extras/neovim/plugins/grok-acp-plugin/avante-grok.lua
```

LazyVim: restart nvim or `:Lazy reload avante.nvim` after changing the spec.

## Prerequisites

1. Neovim (avante often wants 0.11+; 0.12 ok with buffer-harden hooks in the spec)
2. `grok` on PATH (or `~/.grok/bin/grok` — the spec falls back)
3. `yetone/avante.nvim` pullable by Lazy; first build may run `make`

## Avante pin

The Lazy spec **pins** `yetone/avante.nvim` by commit (not floating tip):

| Field | Value |
|-------|--------|
| `version` | `false` (Lazy: use commit, not tags) |
| `commit` | `ff3fc33b7deeb35a277a211d95d6f2b599fbdf19` (release-v0.1-32-gff3fc33) |

**Why:** host patches (ACP `_x.ai` consumer, file-selector filter, sidebar deselect-all, buffer-name harden) break when Lazy tracks tip.  
**Bump policy:** change `commit` only after re-testing ACP stdio + selection + notifications on your host.

## What the spec configures

| Piece | Purpose |
|-------|---------|
| `provider = "grok-acp"` | ACP provider id |
| `args = { "agent", "stdio", … }` | **stdio** ACP (not WS serve) |
| `commit = "ff3fc33…"` | Pin avante (see above) |
| ACP login re-assert | Avoid false “API key not set” on ACP |
| **Use** `_x.ai/*` notifications | Throttled MCP / session UI; `:GrokMcpStatus` |
| Zen / full view | `:AvanteZen`, `<leader>az` |
| Pane colors + loop UX harden | Input vs result contrast; safer `nvim_buf_get_name` |
| File selection | Deselect all (`D`); **batched** `git check-ignore --stdin` filter |

## `_x.ai/*` notifications (used, not ignored)

| Method (examples) | UI |
|-------------------|-----|
| `_x.ai/mcp/init_progress` | Throttled **echo** only: `Grok MCP · server: message (pct)` |
| `_x.ai/mcp/server_status` | Toast only on ready/error **transitions**; else echo |
| `_x.ai/mcp/servers_updated` | One INFO toast: `N server(s) connected` |
| `_x.ai/session_notification` | **Suppress** generic method-name cards; human text only (throttled); quiet volume → delayed echo |
| structured `kind`/`title`/`body` | INFO toast when body is human-readable |
| other `_x.ai/*` | Silent store; inspect via `:GrokMcpStatus` |

Throttle: ~2.5s same-signature toast, ~0.6s echo; never toast body/title equal to `session_notification` / bare method names (the “Grok ACP / session_notification” stack).

State: `vim.g.grok_acp_mcp` (`servers`, `last_progress`, `ready`, `event_count`).

```vim
:GrokMcpStatus
```

Statusline snippet (optional):

```lua
-- example: show MCP ready flag
local s = vim.g.grok_acp_mcp
return (s and s.ready) and "MCP✓" or "MCP…"
```

## File selection filter

Multi-path ops (`handle_path_selection`, folder add, picker list) use one:

```text
git -C <root> check-ignore --stdin
```

Single-path add still uses a one-shot check. Deselect all: `D` / `X` / `:AvanteDeselectFiles`.

## Verify

```bash
# Prefer in-tree SoT when checking the packaged example:
AVANTE_SPEC=tools/groxy/extras/neovim/plugins/grok-acp-plugin/avante-grok.lua \
  ./tools/groxy/scripts/verify-nvim-avante.sh

# Default still checks host copy if AVANTE_SPEC unset:
# ./tools/groxy/scripts/verify-nvim-avante.sh
```

## Related

- [docs/groxy.md](../../../../../docs/groxy.md) — stdio vs `acp serve`, full operator guide  
- [tools/groxy/README.md](../../../README.md) — inject + serve overview  
- Host path (if installed): `~/.config/nvim/lua/plugins/avante-grok.lua`
