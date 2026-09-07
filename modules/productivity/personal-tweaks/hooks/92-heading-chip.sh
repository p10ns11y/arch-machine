#!/usr/bin/env bash
# Re-apply Omarchy 4 shell bar chips after theme-set or post-update.
# (Waybar is gone; do not call apply-waybar.sh on Omarchy 4+.)
set -euo pipefail
APPLY="${HOME}/.local/lib/personal-tweaks/apply-shell-bar.sh"
if [[ -x "$APPLY" ]]; then
  "$APPLY"
fi
