#!/usr/bin/env bash
# Patch ~/.config/waybar only. Safe to run after `omarchy refresh waybar`.
# Snapshots config+style to ~/.local/share/personal-tweaks/waybar-backups/ first.
set -euo pipefail
HERE="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
export PYTHONPATH="$HERE${PYTHONPATH:+:$PYTHONPATH}"

CSS_SRC="$HERE/mission-map.css"
if [[ ! -f "$CSS_SRC" ]]; then
  CSS_SRC="$HERE/../waybar/mission-map.css"
fi

python3 - "$HERE" "$CSS_SRC" <<'PY'
from pathlib import Path
import os, sys
from patch_waybar import apply

here = Path(sys.argv[1])
css_src = Path(sys.argv[2])
cfg = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config")) / "waybar" / "config.jsonc"
css = cfg.with_name("style.css")
for line in apply(cfg, css, css_src):
    print(line)
PY
