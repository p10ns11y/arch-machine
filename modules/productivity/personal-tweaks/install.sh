#!/usr/bin/env bash
# Personal Omarchy tweaks: shell bar chips (Omarchy 4), 20:00 timer, kanithanj.ai.
# Usage: ./install.sh --yes [--dry-run]
# Never writes /usr/share/omarchy/ or ~/.local/share/omarchy/.
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
  echo "consent: re-run with --yes to write ~/.config/omarchy/shell.json, systemd user units, and ~/.local/bin" >&2
  exit 2
fi

run() {
  if (( DRY )); then
    echo "DRY: $*"
  else
    "$@"
  fi
}

SYS_USER="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
LOCAL_BIN="$HOME/.local/bin"
APPS="$HOME/.local/share/applications"
ICONS="$HOME/.local/share/icons/hicolor/128x128/apps"
MM_SCRIPTS="$PLUGINS_ROOT/mission-map/scripts"
LIB="$HERE/lib"
LOCAL_LIB="$HOME/.local/lib/personal-tweaks"
HOOKS_THEME="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/hooks/theme-set.d"
HOOKS_UPDATE="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/hooks/post-update.d"
SHELL_JSON="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/shell.json"

run mkdir -p "$LOCAL_BIN" "$SYS_USER" "$APPS" "$ICONS" \
  "$LOCAL_LIB" "$HOOKS_THEME" "$HOOKS_UPDATE"

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

run cp "$HERE/units/mission-map-graph.service" "$SYS_USER/"
run cp "$HERE/units/mission-map-graph.timer" "$SYS_USER/"
run cp "$HERE/desktop/kanithanj.ai.desktop" "$APPS/"
run install -m 755 "$LIB/apply-shell-bar.sh" "$LOCAL_LIB/apply-shell-bar.sh"
run install -m 644 "$LIB/patch_shell_bar.py" "$LOCAL_LIB/patch_shell_bar.py"
# Keep Waybar helpers for Omarchy ≤3 hosts / archaeology; hooks no longer call them.
run install -m 755 "$LIB/apply-waybar.sh" "$LOCAL_LIB/apply-waybar.sh"
run install -m 755 "$LIB/backup-waybar.sh" "$LOCAL_LIB/backup-waybar.sh"
run install -m 644 "$LIB/patch_waybar.py" "$LOCAL_LIB/patch_waybar.py"
run install -m 644 "$HERE/waybar/mission-map.css" "$LOCAL_LIB/mission-map.css"
run install -m 755 "$HERE/hooks/92-heading-chip.sh" "$HOOKS_THEME/92-heading-chip.sh"
run install -m 755 "$HERE/hooks/92-heading-chip.sh" "$HOOKS_UPDATE/92-heading-chip.sh"

ICON_SRC="$HOME/Work/personal/collab-finder/src-tauri/icons/128x128.png"
if [[ -f "$ICON_SRC" ]]; then
  run cp "$ICON_SRC" "$ICONS/kanithanj.ai.png"
fi

if (( DRY )); then
  echo "DRY: apply-shell-bar.sh (requires $SHELL_JSON)"
else
  if [[ -f "$SHELL_JSON" ]]; then
    PYTHONPATH="$LIB${PYTHONPATH:+:$PYTHONPATH}" "$LIB/apply-shell-bar.sh"
  else
    echo "skip shell bar: missing $SHELL_JSON (is Omarchy 4+ installed?)" >&2
  fi
fi

if (( !DRY )); then
  systemctl --user daemon-reload
  systemctl --user enable --now mission-map-graph.timer
  update-desktop-database "$APPS" 2>/dev/null || true
fi

echo "personal-tweaks ok"
echo "Omarchy 4: focus-now + mission-map on left; eye-comfort after weather; system-update on right"
echo "theme-set + post-update hooks re-apply shell.json chips after refresh/update"
echo "shell backups: ~/.local/share/personal-tweaks/shell-bar-backups/ (last-good + stamps)"
echo "live map JSON stays in ~/.grok/mission-maps/ (not this repo)"
echo "then: omarchy restart shell   # not refresh"
