#!/usr/bin/env bash
# Patch ~/.config/omarchy/shell.json for Omarchy 4 command-module chips.
# Safe after `omarchy refresh shell` / `omarchy update`.
# Snapshots to ~/.local/share/personal-tweaks/shell-bar-backups/ first.
set -euo pipefail
HERE="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
export PYTHONPATH="$HERE${PYTHONPATH:+:$PYTHONPATH}"
python3 - <<'PY'
from patch_shell_bar import apply
for line in apply():
    print(line)
PY
