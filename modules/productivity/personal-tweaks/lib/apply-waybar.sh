#!/usr/bin/env bash
# Patch ~/.config/waybar only. Safe to run after `omarchy refresh waybar`.
set -euo pipefail
HERE="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
export PYTHONPATH="$HERE${PYTHONPATH:+:$PYTHONPATH}"
python3 - "$HERE" <<'PY'
from pathlib import Path
import os, sys
from patch_waybar import apply

here = Path(sys.argv[1])
cfg = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config")) / "waybar" / "config.jsonc"
css = cfg.with_name("style.css")
src = here.parent / "waybar" / "mission-map.css"
for line in apply(cfg, css, src):
    print(line)
PY
