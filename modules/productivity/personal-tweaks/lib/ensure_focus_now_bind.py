#!/usr/bin/env python3
"""Idempotent: inject Super+Ctrl+semicolon → focus-now picker into bindings.lua."""
from __future__ import annotations

import os
import sys
from pathlib import Path

MARKER_BEGIN = "-- BEGIN personal-tweaks focus-now"
MARKER_END = "-- END personal-tweaks focus-now"


def default_bindings() -> Path:
    return Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config")) / "hypr" / "bindings.lua"


def snippet(focus_bin: Path) -> str:
    return (
        f"{MARKER_BEGIN}\n"
        "-- Slot picker (Omarchy menu). Chip click also runs focus-now picker.\n"
        f'o.bind("SUPER + CTRL + code:47", "Focus now", "{focus_bin} picker")\n'
        f"{MARKER_END}\n"
    )


def apply(bindings: Path, focus_bin: Path) -> str:
    if not bindings.is_file():
        return f"skip focus-now bind: missing {bindings}"
    block = snippet(focus_bin)
    text = bindings.read_text(encoding="utf-8")
    if MARKER_BEGIN in text and MARKER_END in text:
        pre = text.split(MARKER_BEGIN, 1)[0]
        post = text.split(MARKER_END, 1)[1]
        if post.startswith("\n"):
            post = post[1:]
        text = pre + block + post
    else:
        text = text.rstrip() + "\n\n" + block
    bindings.write_text(text, encoding="utf-8")
    return f"focus-now bind: {bindings}"


def main(argv: list[str]) -> int:
    focus_bin = Path(argv[1] if len(argv) > 1 else Path.home() / ".local" / "bin" / "focus-now")
    bindings = Path(argv[2]) if len(argv) > 2 else default_bindings()
    print(apply(bindings, focus_bin))
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
