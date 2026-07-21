# grok-acp-plugin (Neovim / avante example)

**Representative use case for Grok ACP over stdio** — the daily Neovim path  
documented in [docs/groxy.md](../../../../../docs/groxy.md).

| This is | This is **not** |
|---------|------------------|
| A **Lazy.nvim / LazyVim plugin spec** (`return { "yetone/avante.nvim", … }`) | A Grok agent slash-plugin under `plugins/arch-machine` |
| How **avante.nvim** spawns `grok agent … stdio` | `groxy acp serve` (WebSocket / remote multi-client) |
| Host UI wiring (login fix, `_x.ai/*` ignore, zen, UI harden) | The vault (`tools/keeper`) or control plane (`tools/archy`) |

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

## Layout

```text
tools/groxy/extras/neovim/plugins/grok-acp-plugin/
  README.md           # this file
  avante-grok.lua     # Lazy spec (copy into host nvim)
```

## Install on a host

```bash
# from arch-machine checkout
cp tools/groxy/extras/neovim/plugins/grok-acp-plugin/avante-grok.lua \
  ~/.config/nvim/lua/plugins/avante-grok.lua

# LazyVim: restart nvim or :Lazy reload avante.nvim
```

Symlink if you want the host file to track the repo:

```bash
ln -sfn "$(pwd)/tools/groxy/extras/neovim/plugins/grok-acp-plugin/avante-grok.lua" \
  ~/.config/nvim/lua/plugins/avante-grok.lua
```

## Prerequisites

1. Neovim (avante often wants 0.11+; 0.12 ok with buffer-harden hooks in the spec)
2. `grok` on PATH (or `~/.grok/bin/grok` — the spec falls back)
3. `yetone/avante.nvim` pullable by Lazy; first build may run `make`

## What the spec configures

| Piece | Purpose |
|-------|---------|
| `provider = "grok-acp"` | ACP provider id |
| `args = { "agent", "stdio", … }` | **stdio** ACP (not WS serve) |
| ACP login re-assert | Avoid false “API key not set” on ACP |
| Ignore `_x.ai/*` notifications | Quiet Grok MCP protocol extensions |
| Zen / full view | `:AvanteZen`, `<leader>az` |
| Pane colors + loop UX harden | Input vs result contrast; safer `nvim_buf_get_name` |
| File selection | Deselect all (`D`); gitignore filter |

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
