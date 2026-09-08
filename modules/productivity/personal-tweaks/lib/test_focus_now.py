#!/usr/bin/env python3
"""Smoke tests for focus-now (Season slots + chip JSON)."""
from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
FOCUS = HERE.parent / "bin" / "focus-now"


def test_chip_json() -> None:
    out = subprocess.check_output([sys.executable, str(FOCUS), "chip"], text=True)
    payload = json.loads(out)
    assert "text" in payload and "tooltip" in payload
    assert "class" in payload


def test_slots_include_season() -> None:
    # Import by exec — script is not a package module.
    src = FOCUS.read_text(encoding="utf-8")
    ns: dict = {}
    exec(compile(src, str(FOCUS), "exec"), ns)
    slots = ns["SLOTS"]
    assert slots["1"]["short"] == "SEA"
    assert slots["1"]["name"] == "Season"
    assert "Season" in slots["1"]["row"]
    assert slots["2"]["short"] == "CSH"


def test_usage_exit() -> None:
    proc = subprocess.run(
        [sys.executable, str(FOCUS), "nope"],
        capture_output=True,
        text=True,
    )
    assert proc.returncode == 2


if __name__ == "__main__":
    test_chip_json()
    test_slots_include_season()
    test_usage_exit()
    print("focus-now tests ok")
