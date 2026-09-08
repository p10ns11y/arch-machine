#!/usr/bin/env python3
"""Tests for ensure_focus_now_bind."""
from __future__ import annotations

from pathlib import Path

from ensure_focus_now_bind import MARKER_BEGIN, apply, snippet


def test_apply_inserts_and_is_idempotent(tmp_path: Path) -> None:
    bindings = tmp_path / "bindings.lua"
    bindings.write_text("-- Keep personal overrides here.\n", encoding="utf-8")
    focus = tmp_path / "focus-now"
    msg = apply(bindings, focus)
    assert "focus-now bind:" in msg
    text = bindings.read_text(encoding="utf-8")
    assert MARKER_BEGIN in text
    assert f'"{focus} picker"' in text
    apply(bindings, focus)
    assert bindings.read_text(encoding="utf-8").count(MARKER_BEGIN) == 1
    apply(bindings, focus)
    assert bindings.read_text(encoding="utf-8").count(MARKER_BEGIN) == 1


def test_snippet_shape() -> None:
    block = snippet(Path("/tmp/focus-now"))
    assert 'o.bind("SUPER + CTRL + code:47"' in block
    assert "/tmp/focus-now picker" in block


if __name__ == "__main__":
    import tempfile

    with tempfile.TemporaryDirectory() as temp_dir:
        test_apply_inserts_and_is_idempotent(Path(temp_dir))
    test_snippet_shape()
    print("ensure_focus_now_bind tests ok")
