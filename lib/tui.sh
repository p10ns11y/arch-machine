#!/usr/bin/env bash
# lib/tui.sh — The Good Sentinel Interactive TUI (gum + Elm Architecture)
# Invoked via: tinfoil tui   (or ./install.sh --tui)
# Architecture: Model → View → Update (TEA)
# Zero new deps (uses gum, yq, jq, fzf, whiptail if present — all available in env)
# Follows Security Remediation Policy for any destructive actions.

set -euo pipefail

TUI_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

find_root() {
  if [ -d "/usr/share/tinfoil" ]; then
    echo "/usr/share/tinfoil"
  else
    cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd
  fi
}
ROOT="$(find_root)"
export ROOT

if [ -f "$ROOT/lib/logger.sh" ]; then
  # shellcheck disable=SC1090
  source "$ROOT/lib/logger.sh" 2>/dev/null || true
fi

# shellcheck disable=SC1091
source "$TUI_DIR/tui/messages.sh"
# shellcheck disable=SC1091
source "$TUI_DIR/tui/model.sh"
# shellcheck disable=SC1091
source "$TUI_DIR/tui/view.sh"
# shellcheck disable=SC1091
source "$TUI_DIR/tui/update.sh"

trap graceful_exit INT TERM

tui_run
