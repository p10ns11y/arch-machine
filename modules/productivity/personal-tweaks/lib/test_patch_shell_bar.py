#!/usr/bin/env python3
"""Tests for Omarchy 4 shell.json bar chip patcher."""

from __future__ import annotations

import json
import os
from pathlib import Path

from patch_shell_bar import (
    FOCUS_CHIP,
    apply,
    apply_layout,
    widget_id,
)

STOCK = {
    "version": 1,
    "bar": {
        "centerAnchor": "omarchy.clock",
        "layout": {
            "left": [
                {"id": "omarchy.menu"},
                {"id": "omarchy.workspaces"},
            ],
            "center": [
                {"id": "omarchy.indicators"},
                {
                    "id": "omarchy.clock",
                    "format": "dddd HH:mm",
                },
                {"id": "omarchy.keyboard-layout"},
                {"id": "omarchy.weather"},
                {"id": "omarchy.system-update"},
            ],
            "right": [
                {"id": "omarchy.tray"},
                {"id": "omarchy.audio"},
                {"id": "omarchy.power"},
            ],
        },
    },
    "plugins": [],
}


def section_ids(doc: dict, name: str) -> list[str | None]:
    return [widget_id(entry) for entry in doc["bar"]["layout"][name]]


def test_stock_layout_zones_chips():
    doc = apply_layout(json.loads(json.dumps(STOCK)))
    assert section_ids(doc, "left") == [
        "omarchy.menu",
        "omarchy.workspaces",
        "focus-now",
        "mission-map",
    ]
    center = section_ids(doc, "center")
    assert "omarchy.indicators" in center
    assert "omarchy.clock" in center
    assert "eye-comfort" in center
    assert center.index("eye-comfort") > center.index("omarchy.weather")
    assert "omarchy.system-update" not in center
    right = section_ids(doc, "right")
    assert "omarchy.system-update" in right
    assert right.index("omarchy.system-update") > right.index("omarchy.tray")


def test_idempotent_refresh_keeps_single_chip():
    first = apply_layout(json.loads(json.dumps(STOCK)))
    second = apply_layout(json.loads(json.dumps(first)))
    assert section_ids(first, "left") == section_ids(second, "left")
    assert section_ids(first, "center").count("eye-comfort") == 1
    assert section_ids(second, "center").count("eye-comfort") == 1
    focus = next(
        entry
        for entry in second["bar"]["layout"]["left"]
        if widget_id(entry) == "focus-now"
    )
    assert focus["exec"] == FOCUS_CHIP["exec"]
    assert focus["type"] == "command"


def test_apply_writes_and_backs_up(tmp_path: Path):
    shell = tmp_path / "shell.json"
    shell.write_text(json.dumps(STOCK, indent=2) + "\n", encoding="utf-8")
    backup_root = tmp_path / "backups"
    os.environ["PERSONAL_TWEAKS_BACKUP"] = str(backup_root)
    try:
        lines = apply(shell, backup=True)
    finally:
        os.environ.pop("PERSONAL_TWEAKS_BACKUP", None)
    assert any(line.startswith("patched:") for line in lines)
    assert (backup_root / "last-good" / "shell.json").is_file()
    doc = json.loads(shell.read_text(encoding="utf-8"))
    assert "mission-map" in section_ids(doc, "left")
    assert "eye-comfort" in section_ids(doc, "center")


if __name__ == "__main__":
    import tempfile

    test_stock_layout_zones_chips()
    test_idempotent_refresh_keeps_single_chip()
    with tempfile.TemporaryDirectory() as temp_dir:
        test_apply_writes_and_backs_up(Path(temp_dir))
    print("shell bar patcher tests ok")
