#!/bin/bash
# Omarchy theme-set.d hook: Yazi cannot hot-reload flavors (immutable config).
# When Ghostty dark/light flips under an open Yazi, the file list can go dark-on-dark
# (or light-on-light). Pin theme.toml to the active SoT flavor and soft-quit
# open instances so the next launch re-queries the terminal correctly.

THEME_NAME="${1:-}"
YAZI_CFG="${XDG_CONFIG_HOME:-$HOME/.config}/yazi"
THEME_TOML="$YAZI_CFG/theme.toml"
LIGHT_MODE="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/current/theme/light.mode"

if [[ ! -d "$YAZI_CFG/flavors" ]]; then
  exit 0
fi

if [[ -f "$LIGHT_MODE" ]]; then
  FLAVOR="eye-comfort-light"
else
  FLAVOR="eye-comfort-dark"
fi

# Both keys pin the same pack so a wrong terminal dark/light detect cannot load
# the opposite palette after the next start.
mkdir -p "$YAZI_CFG"
cat >"$THEME_TOML" <<EOF
# Managed by eye-comfort theme-set hook / eye-comfort-theme.
# Both dark and light pin the active SoT so auto-detect cannot mismatch.
[flavor]
dark = "${FLAVOR}"
light = "${FLAVOR}"
EOF

if ! pgrep -x yazi >/dev/null 2>&1; then
  exit 0
fi

# Soft-quit: Yazi has no live flavor API. Shell wrappers that use --cwd-file
# keep the directory for the next launch.
pkill -TERM -x yazi >/dev/null 2>&1 || true

if [[ -n "${EC_THEME_HOOK_DEBUG:-}" ]]; then
  echo "eye-comfort theme-set.d: yazi flavor=${FLAVOR} theme=${THEME_NAME} (quit open instances)" >&2
fi
