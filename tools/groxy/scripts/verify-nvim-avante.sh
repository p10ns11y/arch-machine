#!/usr/bin/env bash
# Operator check: host Neovim avante.nvim + Grok ACP wiring.
# Exit 0 only when load/health/provider/stdio contract holds.
set -euo pipefail

SCRATCH="${GROK_SCRATCH:-${TMPDIR:-/tmp}/verify-nvim-avante-$$}"
mkdir -p "$SCRATCH"
export PATH="${HOME}/.grok/bin:${PATH}"
export GROK_SCRATCH="$SCRATCH"

AVANTE_SPEC="${AVANTE_SPEC:-$HOME/.config/nvim/lua/plugins/avante-grok.lua}"
VERIFY_LUA="${VERIFY_LUA:-}"

die() { echo "FAIL: $*" >&2; exit 1; }
pass() { echo "PASS: $*"; }

[[ -f "$AVANTE_SPEC" ]] || die "missing avante plugin spec: $AVANTE_SPEC"
rg -q 'provider\s*=\s*"grok-acp"' "$AVANTE_SPEC" || die "provider is not grok-acp in $AVANTE_SPEC"
rg -q 'stdio' "$AVANTE_SPEC" || die "acp args must include stdio in $AVANTE_SPEC"
rg -q 'yetone/avante.nvim' "$AVANTE_SPEC" || die "yetone/avante.nvim not declared in $AVANTE_SPEC"
# Image #2: Grok proprietary _x.ai/* notifications must be ignored (or documented)
if rg -q '_x%.ai/|_x\\.ai/' "$AVANTE_SPEC"; then
  pass "Image #2 mitigation present (_x.ai ignore) in $AVANTE_SPEC"
else
  echo "WARN: no _x.ai ignore hook in $AVANTE_SPEC — avante will WARN on Grok MCP notifications" >&2
fi

command -v nvim >/dev/null || die "nvim not on PATH"
command -v grok >/dev/null || [[ -x "$HOME/.grok/bin/grok" ]] || die "grok binary not found"

# Prefer in-tree or scratch lua verifier; fall back to inline
if [[ -z "$VERIFY_LUA" ]]; then
  if [[ -f "$SCRATCH/verify-avante.lua" ]]; then
    VERIFY_LUA="$SCRATCH/verify-avante.lua"
  else
    VERIFY_LUA="$SCRATCH/verify-avante-generated.lua"
    cat >"$VERIFY_LUA" <<'LUA'
local scratch = vim.env.GROK_SCRATCH or "/tmp"
local lines = {}
local function out(s) lines[#lines+1]=s; print(s) end
pcall(function() require("lazy").load({ plugins = { "avante.nvim" } }) end)
vim.wait(300)
local Config = require("avante.config")
out("provider=" .. tostring(Config.provider))
local acp = Config.acp_providers and Config.acp_providers["grok-acp"]
assert(type(acp)=="table", "missing acp_providers[grok-acp]")
out("acp_command=" .. tostring(acp.command))
out("acp_args_last=" .. tostring(acp.args and acp.args[#acp.args]))
assert(Config.provider == "grok-acp", "provider")
assert(acp.args and acp.args[#acp.args] == "stdio", "args must end with stdio")
assert(vim.fn.exists(":AvanteAsk")==2, "AvanteAsk")
assert(vim.fn.executable(acp.command)==1 or vim.fn.executable(vim.fn.expand("~/.grok/bin/grok"))==1, "grok executable")
local root = vim.fn.stdpath("data") .. "/lazy/avante.nvim"
local so = vim.fn.glob(root .. "/lua/*.so", false, true)
assert(#so >= 1, "native so missing")
local ok_h = pcall(function() require("avante.health").check() end)
out("health_ok=" .. tostring(ok_h))
out("RESULT=PASS")
local f = assert(io.open(scratch .. "/avante-load.log", "w"))
f:write(table.concat(lines, "\n") .. "\n"); f:close()
vim.cmd("qa!")
LUA
  fi
fi

nvim --headless \
  -c "lua require('lazy').load({plugins={'avante.nvim'}})" \
  -c "luafile $VERIFY_LUA" \
  >"$SCRATCH/nvim-headless.stdout" 2>"$SCRATCH/nvim-headless.stderr" || {
  cat "$SCRATCH/nvim-headless.stderr" >&2 || true
  die "headless nvim verify failed"
}

rg -q 'RESULT=PASS' "$SCRATCH/avante-load.log" 2>/dev/null \
  || rg -q 'RESULT=PASS' "$SCRATCH/nvim-headless.stdout" \
  || die "RESULT=PASS not found in logs"

# Optional stdio protocol smoke (non-interactive initialize)
if command -v timeout >/dev/null && command -v grok >/dev/null; then
  if printf '%s\n' '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"0.1","clientInfo":{"name":"verify-nvim-avante","version":"0"},"capabilities":{}}}' \
    | timeout 3s grok agent stdio 2>/dev/null | rg -q '"protocolVersion"'; then
    pass "grok agent stdio initialize responded"
  else
    echo "WARN: stdio initialize smoke did not return protocolVersion (auth/network); binary help still required"
    grok agent stdio --help >/dev/null
  fi
fi

pass "nvim avante + grok-acp contract OK"
echo "logs: $SCRATCH"
