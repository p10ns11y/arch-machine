#!/usr/bin/env bash
# Snapshot / list / restore ~/.config/waybar without touching Omarchy source.
# Usage:
#   backup-waybar.sh              # snapshot now
#   backup-waybar.sh --list
#   backup-waybar.sh --restore last-good
#   backup-waybar.sh --restore 20260817T203911
set -euo pipefail
HERE="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
export PYTHONPATH="$HERE${PYTHONPATH:+:$PYTHONPATH}"

ACTION=snapshot
NAME=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --list) ACTION=list; shift ;;
    --restore)
      ACTION=restore
      NAME="${2:-}"
      [[ -n "$NAME" ]] || { echo "usage: $0 --restore <stamp|last-good>" >&2; exit 2; }
      shift 2
      ;;
    -h|--help)
      sed -n '2,8p' "$0"
      exit 0
      ;;
    *)
      echo "unknown arg: $1" >&2
      exit 2
      ;;
  esac
done

python3 - "$ACTION" "$NAME" <<'PY'
import os, shutil, sys
from pathlib import Path
from patch_waybar import default_backup_root, snapshot_waybar, mark_last_good

action, name = sys.argv[1], sys.argv[2]
cfg_dir = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config")) / "waybar"
paths = [cfg_dir / "config.jsonc", cfg_dir / "style.css"]
root = default_backup_root()

if action == "snapshot":
    dest = snapshot_waybar(paths, root)
    if all(p.is_file() for p in paths):
        mark_last_good(paths, root)
    print(dest)
    raise SystemExit(0)

if action == "list":
    if not root.is_dir():
        print(f"(none) {root}")
        raise SystemExit(0)
    for p in sorted(root.iterdir()):
        if p.is_dir():
            files = " ".join(sorted(c.name for c in p.iterdir()))
            print(f"{p.name}\t{p}\t{files}")
    raise SystemExit(0)

src = root / name
if not src.is_dir():
    print(f"missing backup: {src}", file=sys.stderr)
    raise SystemExit(1)
# Safety copy of whatever is live now
snapshot_waybar(paths, root)
for item in ("config.jsonc", "style.css"):
    src_f = src / item
    if src_f.is_file():
        shutil.copy2(src_f, cfg_dir / item)
        print(f"restored {cfg_dir / item} <- {src_f}")
print("then: omarchy restart waybar")
PY
