#!/usr/bin/env bash
# Patch ~/.config/omarchy/shell.json for heading + tinai plugins.
# Removes legacy focus-now / mission-map / eye-comfort command chips.
# Safe after stock shell reset. Prefer `omarchy restart shell` (not refresh).
# Snapshots to ~/.local/share/personal-tweaks/shell-bar-backups/ first.
set -euo pipefail
HERE="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
export PYTHONPATH="$HERE${PYTHONPATH:+:$PYTHONPATH}"
python3 - <<'PY'
from patch_shell_bar import apply
for line in apply():
    print(line)
PY
