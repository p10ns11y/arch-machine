#!/usr/bin/env python3
"""Tests for Omarchy 4 shell.json bar chip patcher."""

from __future__ import annotations

import json
import os
from pathlib import Path

from patch_shell_bar import (
    HEADING_CHIP,
    TINAI_CHIP,
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

LEGACY = {
    "version": 1,
    "bar": {
        "centerAnchor": "omarchy.clock",
        "layout": {
            "left": [
                {"id": "omarchy.menu"},
                {"id": "omarchy.workspaces"},
                {
                    "id": "focus-now",
                    "type": "command",
                    "exec": "focus-now",
                    "interval": 30,
                    "onClick": "focus-now picker",
                    "onRightClick": "focus-now notify",
                },
                {
                    "id": "mission-map",
                    "type": "command",
                    "exec": "mm-bar-json",
                    "interval": 120,
                    "onClick": "mm-bar-json open",
                },
            ],
            "center": [
                {"id": "omarchy.indicators"},
                {"id": "omarchy.clock"},
                {"id": "omarchy.weather"},
                {
                    "id": "eye-comfort",
                    "type": "command",
                    "exec": "eye-comfort-theme waybar --plain",
                    "interval": 60,
                },
                {"id": "omarchy.system-update"},
            ],
            "right": [{"id": "omarchy.tray"}],
        },
    },
}


def section_ids(doc: dict, name: str) -> list[str | None]:
    return [widget_id(entry) for entry in doc["bar"]["layout"][name]]


def test_stock_layout_zones_chips():
    doc = apply_layout(json.loads(json.dumps(STOCK)))
    assert section_ids(doc, "left") == [
        "omarchy.menu",
        "omarchy.workspaces",
    ]
    center = section_ids(doc, "center")
    assert "omarchy.indicators" in center
    assert "omarchy.clock" in center
    assert "tinai" in center
    assert center.index("tinai") > center.index("omarchy.weather")
    assert "omarchy.system-update" not in center
    assert "focus-now" not in section_ids(doc, "left")
    assert "eye-comfort" not in center
    right = section_ids(doc, "right")
    assert "heading" in right
    assert right.index("heading") > right.index("omarchy.tray")
    assert "omarchy.system-update" in right
    assert right.index("omarchy.system-update") > right.index("omarchy.tray")


def test_removes_legacy_command_chips():
    doc = apply_layout(json.loads(json.dumps(LEGACY)))
    left = section_ids(doc, "left")
    center = section_ids(doc, "center")
    assert left == ["omarchy.menu", "omarchy.workspaces"]
    assert "heading" not in left
    assert "focus-now" not in left
    assert "mission-map" not in left
    assert "eye-comfort" not in center
    assert "tinai" in center
    heading = next(
        entry for entry in doc["bar"]["layout"]["right"] if widget_id(entry) == "heading"
    )
    assert heading == HEADING_CHIP
    tinai = next(
        entry for entry in doc["bar"]["layout"]["center"] if widget_id(entry) == "tinai"
    )
    assert tinai == TINAI_CHIP


def test_idempotent_refresh_keeps_single_chip():
    first = apply_layout(json.loads(json.dumps(STOCK)))
    second = apply_layout(json.loads(json.dumps(first)))
    assert section_ids(first, "left") == section_ids(second, "left")
    assert section_ids(first, "center").count("tinai") == 1
    assert section_ids(second, "center").count("tinai") == 1
    heading = next(
        entry
        for entry in second["bar"]["layout"]["right"]
        if widget_id(entry) == "heading"
    )
    assert heading == HEADING_CHIP
    assert "type" not in heading
    assert "exec" not in heading


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
    assert "heading" in section_ids(doc, "right")
    assert "heading" not in section_ids(doc, "left")
    assert "tinai" in section_ids(doc, "center")


if __name__ == "__main__":
    import tempfile

    test_stock_layout_zones_chips()
    test_removes_legacy_command_chips()
    test_idempotent_refresh_keeps_single_chip()
    with tempfile.TemporaryDirectory() as temp_dir:
        test_apply_writes_and_backs_up(Path(temp_dir))
    print("shell bar patcher tests ok")
