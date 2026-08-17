#!/usr/bin/env bash
# Re-apply heading chip after Omarchy theme-set or post-update (refresh waybar wipes ~/.config/waybar).
set -euo pipefail
APPLY="${HOME}/.local/lib/personal-tweaks/apply-waybar.sh"
if [[ -x "$APPLY" ]]; then
  "$APPLY"
fi
