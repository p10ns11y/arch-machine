#!/usr/bin/env python3
"""Idempotent Omarchy 4 shell.json bar chips (command modules).

Omarchy 4 replaced Waybar with Quickshell. Custom chips use bar.layout
entries with type=command and Waybar-style JSON from existing CLIs.

Zoning (keeps omarchy.indicators clear of long text / tooltips):
  left   — focus-now, mission-map (after workspaces)
  center — leave indicators + clock; eye-comfort after weather
  right  — move omarchy.system-update here when present in center
"""

from __future__ import annotations

import json
import os
import shutil
from datetime import datetime
from pathlib import Path
from typing import Any

KEEP_BACKUPS = 20

FOCUS_CHIP: dict[str, Any] = {
    "id": "focus-now",
    "type": "command",
    "exec": "focus-now",
    "interval": 30,
    # Waybar had on-click → picker; Omarchy 4 command modules need onClick.
    "onClick": "focus-now picker",
    "onRightClick": "focus-now notify",
}

MISSION_CHIP: dict[str, Any] = {
    "id": "mission-map",
    "type": "command",
    "exec": "mm-bar-json",
    "interval": 120,
    "onClick": "mm-bar-json open",
}

EYE_CHIP: dict[str, Any] = {
    "id": "eye-comfort",
    "type": "command",
    "exec": "eye-comfort-theme waybar --plain",
    "interval": 60,
    "onClick": "bash -c '${HOME}/.local/lib/eye-comfort/waybar/tn-status.sh notify'",
}


def default_backup_root() -> Path:
    override = os.environ.get("PERSONAL_TWEAKS_BACKUP")
    if override:
        return Path(override)
    data = os.environ.get("XDG_DATA_HOME", str(Path.home() / ".local/share"))
    return Path(data) / "personal-tweaks" / "shell-bar-backups"


def default_shell_json() -> Path:
    return Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config")) / "omarchy" / "shell.json"


def widget_id(entry: Any) -> str | None:
    if isinstance(entry, dict):
        chip_id = entry.get("id")
        return str(chip_id) if chip_id is not None else None
    return None


def find_index(section: list[Any], chip_id: str) -> int | None:
    for index, entry in enumerate(section):
        if widget_id(entry) == chip_id:
            return index
    return None


def upsert_after(
    section: list[Any],
    chip: dict[str, Any],
    after_ids: list[str],
    *,
    fallback: str = "append",
) -> list[Any]:
    """Insert or refresh chip after the first matching after_id present."""
    chip_id = chip["id"]
    existing = find_index(section, chip_id)
    if existing is not None:
        section[existing] = dict(chip)
        return section

    insert_at: int | None = None
    for after_id in after_ids:
        anchor = find_index(section, after_id)
        if anchor is not None:
            insert_at = anchor + 1
            break

    if insert_at is None:
        if fallback == "prepend":
            section.insert(0, dict(chip))
        else:
            section.append(dict(chip))
    else:
        section.insert(insert_at, dict(chip))
    return section


def move_to_section(
    layout: dict[str, Any],
    chip_id: str,
    *,
    from_section: str,
    to_section: str,
    after_ids: list[str] | None = None,
) -> None:
    source = list(layout.get(from_section) or [])
    dest = list(layout.get(to_section) or [])
    index = find_index(source, chip_id)
    if index is None:
        layout[from_section] = source
        layout[to_section] = dest
        return
    entry = source.pop(index)
    if find_index(dest, chip_id) is None:
        insert_at = None
        for after_id in after_ids or []:
            anchor = find_index(dest, after_id)
            if anchor is not None:
                insert_at = anchor + 1
                break
        if insert_at is None:
            dest.append(entry)
        else:
            dest.insert(insert_at, entry)
    layout[from_section] = source
    layout[to_section] = dest


def apply_layout(doc: dict[str, Any]) -> dict[str, Any]:
    bar = doc.setdefault("bar", {})
    if not isinstance(bar, dict):
        raise ValueError("shell.json bar must be an object")
    layout = bar.setdefault("layout", {})
    if not isinstance(layout, dict):
        raise ValueError("shell.json bar.layout must be an object")

    left = list(layout.get("left") or [])
    center = list(layout.get("center") or [])
    right = list(layout.get("right") or [])

    layout["left"] = left
    layout["center"] = center
    layout["right"] = right

    # Prefer actionable chips on the left, clear of indicators tooltips.
    upsert_after(left, FOCUS_CHIP, ["omarchy.workspaces", "omarchy.menu"])
    upsert_after(left, MISSION_CHIP, ["focus-now", "omarchy.workspaces", "omarchy.menu"])

    # TN / circadian text after weather (right of clock cluster).
    upsert_after(
        center,
        EYE_CHIP,
        ["omarchy.weather", "omarchy.clock", "omarchy.indicators"],
    )

    # Update pill out of the dense center cluster when it lives there.
    move_to_section(
        layout,
        "omarchy.system-update",
        from_section="center",
        to_section="right",
        after_ids=["omarchy.tray"],
    )

    if not bar.get("centerAnchor"):
        bar["centerAnchor"] = "omarchy.clock"

    return doc


def snapshot_shell(path: Path, backup_root: Path | None = None) -> Path | None:
    if not path.is_file():
        return None
    root = backup_root or default_backup_root()
    stamp = datetime.now().strftime("%Y%m%dT%H%M%S")
    dest = root / stamp
    suffix = 1
    while dest.exists():
        suffix += 1
        dest = root / f"{stamp}-{suffix}"
    dest.mkdir(parents=True, exist_ok=True)
    shutil.copy2(path, dest / path.name)
    last_good = root / "last-good"
    last_good.mkdir(parents=True, exist_ok=True)
    shutil.copy2(path, last_good / path.name)
    prune_backups(root)
    return dest


def prune_backups(root: Path, keep: int = KEEP_BACKUPS) -> None:
    if not root.is_dir():
        return
    stamped = sorted(
        path for path in root.iterdir() if path.is_dir() and path.name != "last-good"
    )
    for old in stamped[:-keep]:
        shutil.rmtree(old, ignore_errors=True)


def load_shell(path: Path) -> dict[str, Any]:
    if not path.is_file():
        raise FileNotFoundError(path)
    data = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(data, dict):
        raise ValueError("shell.json root must be an object")
    return data


def write_shell(path: Path, doc: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(doc, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def apply(path: Path | None = None, *, backup: bool = True) -> list[str]:
    shell_path = path or default_shell_json()
    lines: list[str] = []
    if backup:
        dest = snapshot_shell(shell_path)
        if dest is not None:
            lines.append(f"backup: {dest}")
    doc = apply_layout(load_shell(shell_path))
    write_shell(shell_path, doc)
    lines.append(f"patched: {shell_path}")
    left_ids = [widget_id(entry) for entry in doc["bar"]["layout"]["left"]]
    center_ids = [widget_id(entry) for entry in doc["bar"]["layout"]["center"]]
    right_ids = [widget_id(entry) for entry in doc["bar"]["layout"]["right"]]
    lines.append(f"left: {left_ids}")
    lines.append(f"center: {center_ids}")
    lines.append(f"right: {right_ids}")
    return lines


if __name__ == "__main__":
    for line in apply():
        print(line)
