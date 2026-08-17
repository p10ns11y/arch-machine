#!/usr/bin/env bash
# Personal Omarchy tweaks: waybar heading chip, 20:00 timer, kanithanj.ai.
# Usage: ./install.sh --yes [--dry-run]
# Never writes ~/.local/share/omarchy/.
set -euo pipefail

HERE="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
YES=0
DRY=0
PLUGINS_ROOT="${PLUGINS_ROOT:-$HOME/Work/personal/plugins}"
KANITHANJ_URL="${KANITHANJ_URL:-https://github.com/p10ns11y/collab-finder/releases/download/v2/kanithanj.ai-linux-x86_64}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --yes) YES=1; shift ;;
    --dry-run) DRY=1; shift ;;
    --agent-expand)
      date -Iseconds >"$HERE/.agent-expanded"
      echo "agent_expand_ok: personal-tweaks (dry stamp; run install.sh --yes on the host)"
      exit 0
      ;;
    -h|--help)
      sed -n '2,4p' "$0"
      exit 0
      ;;
    *)
      echo "unknown arg: $1" >&2
      exit 2
      ;;
  esac
done

if (( !YES && !DRY )); then
  echo "consent: re-run with --yes to write ~/.config/waybar, systemd user units, and ~/.local/bin" >&2
  exit 2
fi

run() {
  if (( DRY )); then
    echo "DRY: $*"
  else
    "$@"
  fi
}

WB_CFG="${XDG_CONFIG_HOME:-$HOME/.config}/waybar/config.jsonc"
WB_CSS="${XDG_CONFIG_HOME:-$HOME/.config}/waybar/style.css"
SYS_USER="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
LOCAL_BIN="$HOME/.local/bin"
APPS="$HOME/.local/share/applications"
ICONS="$HOME/.local/share/icons/hicolor/128x128/apps"
MM_SCRIPTS="$PLUGINS_ROOT/mission-map/scripts"

run mkdir -p "$LOCAL_BIN" "$SYS_USER" "$APPS" "$ICONS"

if [[ -x "$MM_SCRIPTS/mm-lifeos-graph" ]]; then
  run ln -sfn "$MM_SCRIPTS/mm-lifeos-graph" "$LOCAL_BIN/mm-lifeos-graph"
fi
if [[ -x "$MM_SCRIPTS/mm-waybar" ]]; then
  run ln -sfn "$MM_SCRIPTS/mm-waybar" "$LOCAL_BIN/mm-waybar"
fi

if [[ ! -x "$LOCAL_BIN/kanithanj.ai" ]]; then
  if (( DRY )); then
    echo "DRY: curl -fsSL $KANITHANJ_URL -o $LOCAL_BIN/kanithanj.ai"
  else
    curl -fsSL "$KANITHANJ_URL" -o "$LOCAL_BIN/kanithanj.ai"
    chmod 755 "$LOCAL_BIN/kanithanj.ai"
  fi
fi

run cp "$HERE/systemd/mission-map-graph.service" "$SYS_USER/"
run cp "$HERE/systemd/mission-map-graph.timer" "$SYS_USER/"
run cp "$HERE/desktop/kanithanj.ai.desktop" "$APPS/"

ICON_SRC="$HOME/Work/personal/collab-finder/src-tauri/icons/128x128.png"
if [[ -f "$ICON_SRC" ]]; then
  run cp "$ICON_SRC" "$ICONS/kanithanj.ai.png"
fi

patch_waybar() {
  python3 - "$WB_CFG" "$WB_CSS" "$HERE/waybar/mission-map.css" <<'PY'
import pathlib, sys

cfg_p, css_p, css_src = map(pathlib.Path, sys.argv[1:4])
block = """
  "custom/mission-map": {
    "exec": "$HOME/.local/bin/mm-waybar",
    "return-type": "json",
    "interval": 120,
    "signal": 12,
    "tooltip": true,
    "on-click": "$HOME/.local/bin/mm-waybar open",
    "on-click-right": "$HOME/.local/bin/mm-waybar notify"
  },
"""

def insert_after_object(text: str, key: str, extra: str) -> str:
    needle = f'"{key}":'
    i = text.find(needle)
    if i < 0:
        return text
    brace = text.find("{", i)
    if brace < 0:
        return text
    depth = 0
    for j, ch in enumerate(text[brace:], brace):
        if ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
            if depth == 0:
                return text[: j + 1] + "," + extra + text[j + 1 :]
    return text

if cfg_p.is_file():
    t = cfg_p.read_text(encoding="utf-8")
    if "custom/mission-map" not in t:
        t = t.replace('"custom/focus-now"', '"custom/focus-now", "custom/mission-map"', 1)
        t = insert_after_object(t, "custom/focus-now", block)
        cfg_p.write_text(t, encoding="utf-8")
        print("patched", cfg_p)
    else:
        print("waybar config already has custom/mission-map")
if css_p.is_file():
    css = css_p.read_text(encoding="utf-8")
    extra = css_src.read_text(encoding="utf-8")
    if "#custom-mission-map" not in css:
        css_p.write_text(css.rstrip() + "\n\n" + extra, encoding="utf-8")
        print("patched", css_p)
    else:
        print("waybar css already has #custom-mission-map")
PY
}

if (( DRY )); then
  echo "DRY: patch waybar $WB_CFG $WB_CSS"
else
  patch_waybar
fi

if (( !DRY )); then
  systemctl --user daemon-reload
  systemctl --user enable --now mission-map-graph.timer
  update-desktop-database "$APPS" 2>/dev/null || true
fi

echo "personal-tweaks ok"
echo "then: omarchy restart waybar"
