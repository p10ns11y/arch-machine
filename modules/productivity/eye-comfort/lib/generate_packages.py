#!/usr/bin/env python3
"""Generate committed Omarchy package host files from OKLCH palette SoT.

One generator → four packages (dawn / light / dusk / dark). Use --check in CI
so committed colors.toml / ghostty.conf / neovim.lua cannot drift from SoT.
"""
from __future__ import annotations

import argparse
import sys
import tempfile
from pathlib import Path

from palette import Phase, roles_for_phase
from render import write_theme_package

# Canonical phase baked into each committed host package
PACKAGE_PHASE: dict[str, Phase] = {
    "eye-comfort-dawn": "dawn",
    "eye-comfort-light": "midday",
    "eye-comfort-dusk": "dusk",
    "eye-comfort-dark": "night",
}

HOST_FILES = ("colors.toml", "ghostty.conf", "neovim.lua", "light.mode")


def themes_root() -> Path:
    return Path(__file__).resolve().parent.parent / "themes"


def generate_one(name: str, dest: Path) -> None:
    phase = PACKAGE_PHASE[name]
    roles = roles_for_phase(phase, ambient="indoor", intensity="balanced")
    icons = dest / "icons.theme"
    write_theme_package(
        dest,
        roles,
        name=name,
        phase=phase,
        icons_src=icons if icons.is_file() else None,
    )


def generate_all(root: Path) -> None:
    for name in PACKAGE_PHASE:
        dest = root / name
        if not dest.is_dir():
            raise SystemExit(f"missing theme package dir: {dest}")
        generate_one(name, dest)
        print(f"generated {name} ← {PACKAGE_PHASE[name]}")


def check_all(root: Path) -> int:
    """Return 0 if committed host files match a fresh generate."""
    drifts: list[str] = []
    with tempfile.TemporaryDirectory(prefix="eye-comfort-gen-") as tmp:
        tmp_root = Path(tmp)
        for name in PACKAGE_PHASE:
            src = root / name
            if not src.is_dir():
                drifts.append(f"missing {name}")
                continue
            dest = tmp_root / name
            dest.mkdir(parents=True)
            icons = src / "icons.theme"
            if icons.is_file():
                (dest / "icons.theme").write_text(icons.read_text(encoding="utf-8"), encoding="utf-8")
            generate_one(name, dest)
            for fname in HOST_FILES:
                a, b = src / fname, dest / fname
                a_exists, b_exists = a.exists(), b.exists()
                if a_exists != b_exists:
                    drifts.append(f"{name}/{fname}: existence mismatch (committed={a_exists})")
                    continue
                if not a_exists:
                    continue
                if a.read_text(encoding="utf-8") != b.read_text(encoding="utf-8"):
                    drifts.append(f"{name}/{fname}: drifts from OKLCH SoT")
    if drifts:
        print("eye-comfort generate --check FAILED:", file=sys.stderr)
        for d in drifts:
            print(f"  {d}", file=sys.stderr)
        print(
            "Run: PYTHONPATH=lib python3 lib/generate_packages.py",
            file=sys.stderr,
        )
        return 1
    print("eye-comfort generate --check: OK")
    return 0


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument(
        "--check",
        action="store_true",
        help="exit non-zero if committed host files drift from SoT",
    )
    ap.add_argument(
        "--root",
        type=Path,
        default=None,
        help="themes directory (default: ../themes next to this file)",
    )
    args = ap.parse_args()
    root = args.root or themes_root()
    if args.check:
        return check_all(root)
    generate_all(root)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
