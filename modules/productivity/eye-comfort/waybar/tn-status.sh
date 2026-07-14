#!/usr/bin/env bash
# Waybar custom module exec — compact TN/circadian text + rich tooltip JSON.
# Install: ~/.local/lib/eye-comfort/waybar/tn-status.sh (via install.sh)
set -euo pipefail

export PYTHONPATH="${HOME}/.local/lib/eye-comfort${PYTHONPATH:+:$PYTHONPATH}"
_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Dev checkout: …/eye-comfort/waybar → ../lib
if [[ -d "${_SCRIPT_DIR}/../lib" ]]; then
  export PYTHONPATH="${_SCRIPT_DIR}/../lib:${PYTHONPATH}"
fi

MODE="${1:-waybar}"
case "$MODE" in
  waybar|json)
    python3 - <<'PY'
from waybar_status import waybar_payload
import json
print(json.dumps(waybar_payload(), ensure_ascii=False))
PY
    ;;
  notify)
    # Additional lightweight surface: desktop notification with full scene
    body="$(python3 - <<'PY'
from waybar_status import notify_body
print(notify_body())
PY
)"
    if command -v notify-send >/dev/null 2>&1; then
      notify-send -u low "eye-comfort" "$body"
    else
      printf '%s\n' "$body"
    fi
    ;;
  status)
    python3 - <<'PY'
from waybar_status import status_text
print(status_text())
PY
    ;;
  *)
    echo "usage: $0 [waybar|notify|status]" >&2
    exit 2
    ;;
esac
