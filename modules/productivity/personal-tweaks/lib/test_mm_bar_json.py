#!/usr/bin/env python3
"""Tests for mission-map Omarchy bar JSON wrapper."""

from __future__ import annotations

from mm_bar_json import wrap_tooltip


def test_wrap_breaks_long_single_line():
    tip = "Submit one relevant application next week — do not wait for replies. " * 3
    out = wrap_tooltip(tip, 40)
    assert "\n" in out
    assert all(len(line) <= 40 for line in out.splitlines() if line)
    assert "Submit one relevant" in out


def test_wrap_preserves_short():
    assert wrap_tooltip("Apply next", 56) == "Apply next"


if __name__ == "__main__":
    test_wrap_breaks_long_single_line()
    test_wrap_preserves_short()
    print("mm_bar_json tests ok")
