#!/usr/bin/env bash
# Install heading + tinai Omarchy bar-widget plugins from this module.
# Does not patch shell.json (call apply-shell-bar.sh after enable).
set -euo pipefail
HERE="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
ROOT="$(CDPATH= cd -- "$HERE/.." && pwd)"
SRC="$ROOT/omarchy-plugins"
DEST="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/plugins"
DRY="${PERSONAL_TWEAKS_DRY:-0}"

run() {
  if [[ "$DRY" == "1" ]]; then
    echo "DRY: $*"
  else
    "$@"
  fi
}

run mkdir -p "$DEST"
for id in heading tinai; do
  if [[ ! -d "$SRC/$id" ]]; then
    echo "missing plugin source: $SRC/$id" >&2
    exit 1
  fi
  run rsync -a --delete "$SRC/$id/" "$DEST/$id/"
  if [[ "$DRY" != "1" ]]; then
    omarchy plugin validate "$DEST/$id"
  else
    echo "DRY: omarchy plugin validate $DEST/$id"
  fi
done

if [[ "$DRY" != "1" ]]; then
  # Discover newly rsynced folders before enable (Omarchy caches the catalog).
  omarchy-shell shell rescanPlugins 2>/dev/null \
    || omarchy shell rescanPlugins 2>/dev/null \
    || true
  omarchy plugin enable heading right || true
  omarchy plugin enable tinai center || true
else
  echo "DRY: omarchy-shell shell rescanPlugins"
  echo "DRY: omarchy plugin enable heading right"
  echo "DRY: omarchy plugin enable tinai center"
fi

echo "omarchy plugins installed: heading tinai → $DEST"
