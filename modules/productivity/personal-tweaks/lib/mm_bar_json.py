#!/usr/bin/env python3
"""Omarchy 4 shell bar JSON for mission-map.

mm-waybar emits a single-line tooltip (fine for Waybar). Quickshell tooltips
use Text.NoWrap, so one long line becomes a screen-wide strip. Wrap here.
"""
from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
import textwrap

DEFAULT_WIDTH = 56


def tooltip_width() -> int:
    raw = os.environ.get("MM_TOOLTIP_WIDTH", str(DEFAULT_WIDTH))
    try:
        return max(24, int(raw))
    except ValueError:
        return DEFAULT_WIDTH


def wrap_tooltip(text: str, width: int) -> str:
    if not text:
        return text
    lines: list[str] = []
    for paragraph in text.splitlines() or [text]:
        if not paragraph.strip():
            lines.append("")
            continue
        wrapped = textwrap.wrap(
            paragraph,
            width=width,
            break_long_words=True,
            break_on_hyphens=False,
        )
        lines.extend(wrapped or [paragraph])
    return "\n".join(lines)


def load_payload() -> dict:
    mm_waybar = shutil.which("mm-waybar")
    if not mm_waybar:
        return {
            "text": "Map?",
            "tooltip": "mm-waybar not on PATH",
            "class": "empty",
        }
    completed = subprocess.run(
        [mm_waybar],
        check=False,
        capture_output=True,
        text=True,
    )
    try:
        payload = json.loads(completed.stdout or "{}")
    except json.JSONDecodeError:
        return {
            "text": "Map?",
            "tooltip": "mm-waybar returned invalid JSON",
            "class": "empty",
        }
    if not isinstance(payload, dict):
        return {
            "text": "Map?",
            "tooltip": "mm-waybar returned non-object JSON",
            "class": "empty",
        }
    tip = payload.get("tooltip")
    if isinstance(tip, str) and tip and "\n" not in tip and len(tip) > tooltip_width():
        payload["tooltip"] = wrap_tooltip(tip, tooltip_width())
    return payload


def main(argv: list[str]) -> int:
    if len(argv) > 1 and argv[1] in ("open", "notify"):
        mm_waybar = shutil.which("mm-waybar")
        if not mm_waybar:
            print("mm-waybar not on PATH", file=sys.stderr)
            return 1
        os.execvp(mm_waybar, [mm_waybar, argv[1]])
    sys.stdout.write(json.dumps(load_payload(), ensure_ascii=False) + "\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
