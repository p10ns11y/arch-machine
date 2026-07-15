#!/usr/bin/env python3
"""Structural gates for eye-comfort Waybar CSS (crisp HiDPI mono).

Drives the shipped module CSS on disk — not a reimplementation of styling.
Fails if synthetic Medium (500) or soft letter-spacing reappears on the TN chip.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

# lib/ → waybar/eye-comfort.css (module source of truth)
MODULE_ROOT = Path(__file__).resolve().parent.parent
CSS_PATH = MODULE_ROOT / "waybar" / "eye-comfort.css"

# Softening rules that made CaskaydiaMono look classic-but-blurry @ scale 2
FORBIDDEN_WEIGHT = re.compile(r"font-weight\s*:\s*500\b", re.I)
FORBIDDEN_SOFT_TRACKING = re.compile(
    r"letter-spacing\s*:\s*(?!0(?:\.0+)?(?:em|px|rem)?;)([0-9]*\.[0-9]+|0\.[0-9]+)(em|px|rem)?",
    re.I,
)
# Chip block must pin real Regular + zero tracking
CHIP_BLOCK = re.compile(
    r"#custom-eye-comfort\s*\{([^}]+)\}",
    re.S,
)
WEIGHT_400 = re.compile(r"font-weight\s*:\s*400\b", re.I)
TRACKING_ZERO = re.compile(r"letter-spacing\s*:\s*0\b", re.I)


def load_css() -> str:
    assert CSS_PATH.is_file(), f"missing shipped CSS: {CSS_PATH}"
    return CSS_PATH.read_text(encoding="utf-8")


def test_no_synthetic_medium_weight():
    css = load_css()
    hits = FORBIDDEN_WEIGHT.findall(css)
    assert not hits, f"font-weight 500 (no Medium face) in {CSS_PATH}: {hits}"


def test_no_soft_letter_spacing():
    css = load_css()
    # Allow letter-spacing: 0; forbid fractional soft tracking
    for m in re.finditer(r"letter-spacing\s*:\s*([^;]+);", css, re.I):
        val = m.group(1).strip()
        if val in ("0", "0em", "0px", "normal"):
            continue
        # any non-zero length softens mono at 12px@2x
        assert False, f"non-zero letter-spacing softens glyphs: {val!r} in {CSS_PATH}"


def test_chip_uses_real_regular_and_zero_tracking():
    css = load_css()
    block = CHIP_BLOCK.search(css)
    assert block, f"#custom-eye-comfort block missing in {CSS_PATH}"
    body = block.group(1)
    assert WEIGHT_400.search(body), f"chip must set font-weight: 400 (Regular), got:\n{body}"
    assert TRACKING_ZERO.search(body), f"chip must set letter-spacing: 0, got:\n{body}"


def test_no_fractional_css_px_in_module():
    css = load_css()
    frac = re.findall(r"[0-9]+\.[0-9]+px", css)
    assert not frac, f"half-pixel values blur under scale 2: {frac} in {CSS_PATH}"


def test_tooltip_crisp_type_and_tamil_fallback():
    css = load_css()
    assert "tooltip label" in css
    # Body ink from theme tokens — not hard-coded washed gold
    assert "color: @foreground" in css
    assert re.search(r"tooltip\s*\{[^}]*font-weight:\s*400", css, re.S)
    assert "Noto Sans Tamil" in css
    assert not re.search(r"tooltip[^}]*font-weight:\s*500", css, re.S)


def main() -> int:
    tests = [
        test_no_synthetic_medium_weight,
        test_no_soft_letter_spacing,
        test_chip_uses_real_regular_and_zero_tracking,
        test_no_fractional_css_px_in_module,
        test_tooltip_crisp_type_and_tamil_fallback,
    ]
    failed = 0
    for t in tests:
        try:
            t()
            print(f"ok  {t.__name__}")
        except AssertionError as e:
            failed += 1
            print(f"FAIL {t.__name__}: {e}", file=sys.stderr)
    if failed:
        print(f"{failed} failed", file=sys.stderr)
        return 1
    print(f"{len(tests)} passed  css={CSS_PATH}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
