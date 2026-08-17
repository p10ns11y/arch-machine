#!/usr/bin/env python3
"""Idempotent waybar heading-chip insert. Stock Omarchy has no focus-now."""

from __future__ import annotations

import re
from pathlib import Path

MODULE_NAME = "custom/mission-map"
MODULE_BLOCK = """
  "custom/mission-map": {
    "exec": "$HOME/.local/bin/mm-waybar",
    "return-type": "json",
    "interval": 120,
    "signal": 12,
    "tooltip": true,
    "on-click": "$HOME/.local/bin/mm-waybar open",
    "on-click-right": "$HOME/.local/bin/mm-waybar notify"
  },
"""


def ensure_center(text: str) -> str:
    if re.search(r'"modules-center"\s*:\s*\[[^\]]*custom/mission-map', text, re.S):
        return text
    m = re.search(r'"modules-center"\s*:\s*\[', text)
    if not m:
        return text
    start = m.end()
    end = text.find("]", start)
    if end < 0:
        return text
    inner = text[start:end]
    token = '"custom/mission-map"'
    if '"custom/focus-now"' in inner:
        inner = inner.replace('"custom/focus-now"', '"custom/focus-now", "custom/mission-map"', 1)
    elif '"clock"' in inner:
        inner = inner.replace('"clock"', '"clock", "custom/mission-map"', 1)
    else:
        inner = " " + token + ("," if inner.strip() else "") + inner
    return text[:start] + inner + text[end:]


def _insert_after_object(text: str, key: str, extra: str) -> str | None:
    needle = f'"{key}":'
    i = text.find(needle)
    if i < 0:
        return None
    brace = text.find("{", i)
    if brace < 0:
        return None
    depth = 0
    for j, ch in enumerate(text[brace:], brace):
        if ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
            if depth == 0:
                return text[: j + 1] + "," + extra + text[j + 1 :]
    return None


def ensure_object(text: str) -> str:
    if re.search(r'"custom/mission-map"\s*:', text):
        return text
    for key in ("custom/focus-now", "clock", "custom/omarchy"):
        nxt = _insert_after_object(text, key, MODULE_BLOCK)
        if nxt is not None:
            return nxt
    brace = text.find("{")
    if brace < 0:
        return text
    return text[: brace + 1] + MODULE_BLOCK + text[brace + 1 :]


def ensure_css(css: str, extra: str) -> str:
    if "#custom-mission-map" in css:
        return css
    return css.rstrip() + "\n\n" + extra.rstrip() + "\n"


def apply(cfg_path: Path, css_path: Path, css_src: Path) -> list[str]:
    notes: list[str] = []
    if cfg_path.is_file():
        before = cfg_path.read_text(encoding="utf-8")
        after = ensure_object(ensure_center(before))
        if after != before:
            cfg_path.write_text(after, encoding="utf-8")
            notes.append(f"patched {cfg_path}")
        else:
            notes.append(f"ok {cfg_path}")
    else:
        notes.append(f"missing {cfg_path}")
    if css_path.is_file() and css_src.is_file():
        before = css_path.read_text(encoding="utf-8")
        after = ensure_css(before, css_src.read_text(encoding="utf-8"))
        if after != before:
            css_path.write_text(after, encoding="utf-8")
            notes.append(f"patched {css_path}")
        else:
            notes.append(f"ok {css_path}")
    return notes
