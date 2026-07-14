#!/bin/bash
# Omarchy theme-set.d hook: reload hosts that do not pick up swaps alone.
# Installed to ~/.config/omarchy/hooks/theme-set.d/ by eye-comfort install.sh
#
# - tmux (omarchy-theme-set never calls omarchy-restart-tmux)
# - open Neovim (force re-read Omarchy theme + soft gruvbox overrides)

THEME_NAME="${1:-}"

if command -v omarchy-restart-tmux >/dev/null 2>&1; then
  omarchy-restart-tmux >/dev/null 2>&1 || true
elif pgrep -x tmux >/dev/null 2>&1; then
  tmux source-file "${HOME}/.config/tmux/tmux.conf" >/dev/null 2>&1 || true
fi

# Forceful apply via a temp lua file — avoids stale in-memory LazyReload callbacks
# that flip vim.o.background without re-running gruvbox.setup(palette_overrides).
write_apply_lua() {
  local dest="$1"
  cat >"$dest" <<'LUA'
package.loaded["plugins.theme"] = nil
local ok, theme_spec = pcall(require, "plugins.theme")
if not ok then
  return
end
local light = vim.fn.filereadable(vim.fn.expand("~/.config/omarchy/current/theme/light.mode")) == 1
vim.o.background = light and "light" or "dark"
local colorscheme = "gruvbox"
for _, spec in ipairs(theme_spec) do
  if spec[1] == "ellisonleao/gruvbox.nvim" and type(spec.opts) == "table" then
    local gok, gruvbox = pcall(require, "gruvbox")
    if gok and gruvbox.setup then
      gruvbox.setup(spec.opts)
    end
  end
  if spec[1] == "LazyVim/LazyVim" and spec.opts and spec.opts.colorscheme then
    colorscheme = spec.opts.colorscheme
  end
end
pcall(vim.cmd.colorscheme, colorscheme)
vim.api.nvim_exec_autocmds("ColorScheme", { modeline = false })
pcall(function()
  local lualine = require("lualine")
  if lualine.refresh then
    lualine.refresh()
  end
end)
vim.cmd("redraw!")
LUA
}

reload_nvim_servers() {
  local runtime="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
  local sock
  local -a socks=()
  local apply_lua="${runtime}/eye-comfort-nvim-apply.lua"

  write_apply_lua "$apply_lua"

  shopt -s nullglob
  socks+=("$runtime"/nvim*.*)
  socks+=("$runtime"/nvim/*.sock)
  socks+=(/tmp/nvim*/0)
  socks+=(/tmp/nvim-"$(id -u)"/*.sock)
  shopt -u nullglob

  for sock in "${socks[@]}"; do
    [[ -S "$sock" ]] || continue
    # dofile the apply script; fall back to LazyReload for older sessions
    if ! nvim --server "$sock" --remote-expr "luaeval(\"dofile([[${apply_lua}]])\")" >/dev/null 2>&1; then
      nvim --server "$sock" --remote-send \
        $'<Cmd>lua vim.api.nvim_exec_autocmds("User", { pattern = "LazyReload" })<CR>' \
        >/dev/null 2>&1 || true
    fi
  done
}

if command -v nvim >/dev/null 2>&1; then
  reload_nvim_servers
fi

stamp="${HOME}/.config/omarchy/current/theme-reload.stamp"
mkdir -p "$(dirname "$stamp")" 2>/dev/null || true
date +%s >"$stamp" 2>/dev/null || true

if [[ -n "${EC_THEME_HOOK_DEBUG:-}" ]]; then
  echo "eye-comfort theme-set.d: theme=${THEME_NAME} nvim+tmux reload requested" >&2
fi
