#!/usr/bin/env python3
"""Generate committed Omarchy package host files from OKLCH palette SoT.

One generator → circadian packages (dawn/light/dusk/dark) plus Tamil tinai
packages (eye-comfort-tn-*). Use --check in CI so committed colors.toml /
ghostty.conf / neovim.lua cannot drift from SoT.
"""
from __future__ import annotations

import argparse
import sys
import tempfile
from pathlib import Path

from palette import Phase, css_custom_properties, roles_for_phase
from render import write_theme_package
from tamil_palette import canonical_phase_for_tinai, roles_for_tamil
from tamil_schedule import TINAI, TINAI_THEME

# Canonical phase baked into each committed host package
PACKAGE_PHASE: dict[str, Phase] = {
    "eye-comfort-dawn": "dawn",
    "eye-comfort-light": "midday",
    "eye-comfort-dusk": "dusk",
    "eye-comfort-dark": "night",
}

# Tamil Nadu tinai packages (landscape identity; Siru live-renders luminance)
PACKAGE_TN: dict[str, str] = {TINAI_THEME[t]: t for t in TINAI}

# All schedule phases for CSS token mirrors (morning/afternoon share light package)
CSS_PHASES: tuple[Phase, ...] = (
    "dawn",
    "morning",
    "midday",
    "afternoon",
    "dusk",
    "evening",
    "night",
)

HOST_FILES = ("colors.toml", "ghostty.conf", "neovim.lua", "light.mode")


def themes_root() -> Path:
    return Path(__file__).resolve().parent.parent / "themes"


def tokens_css_path() -> Path:
    return Path(__file__).resolve().parent.parent / "tokens" / "phases.css"


def generate_one(name: str, dest: Path) -> None:
    icons = dest / "icons.theme"
    is_tn = name in PACKAGE_TN
    if is_tn:
        tinai = PACKAGE_TN[name]  # type: ignore[assignment]
        phase, siru = canonical_phase_for_tinai(tinai)  # type: ignore[arg-type]
        roles = roles_for_tamil(
            tinai,  # type: ignore[arg-type]
            siru,
            nazhigai=4,
            ambient="indoor",
            intensity="balanced",
        )
    else:
        phase = PACKAGE_PHASE[name]
        roles = roles_for_phase(phase, ambient="indoor", intensity="balanced")
    write_theme_package(
        dest,
        roles,
        name=name,
        phase=phase,
        icons_src=icons if icons.is_file() else None,
    )
    # TN packages are live-rendered across dark Siru (dusk/night). Do not commit
    # light.mode from a light canonical bake — stale light.mode → Yazi/Ghostty
    # mismatch on dark applies. Live eye-comfort-theme sets light.mode correctly.
    if is_tn:
        stale = dest / "light.mode"
        if stale.exists():
            stale.unlink()


def generate_phases_css(dest: Path | None = None) -> Path:
    """Write [data-ec-phase] OKLCH mirrors for all seven phases (balanced indoor)."""
    out = dest or tokens_css_path()
    chunks = [
        "/* Eye-comfort circadian tokens — OKLCH SoT mirrors (balanced indoor). */",
        "/* Generate: PYTHONPATH=lib python3 lib/generate_packages.py */",
        "",
    ]
    for phase in CSS_PHASES:
        roles = roles_for_phase(phase, ambient="indoor", intensity="balanced")
        body = css_custom_properties(roles, phase)
        chunks.append(
            body.replace(":root {", f'[data-ec-phase="{phase}"] {{').rstrip() + "\n"
        )
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text("\n".join(chunks) + "\n", encoding="utf-8")
    return out


def generate_roles_json(dest: Path | None = None) -> Path:
    """Extract machine-readable role tokens (midday + night locks + semantic map)."""
    import json

    out = dest or (Path(__file__).resolve().parent.parent / "tokens" / "roles.json")
    from palette import HEX_LOCKS, PHASE_SCENE, PHASE_WALLPAPER_HINT

    payload = {
        "version": 1,
        "semantic": {
            "background": "surface paper / umber",
            "foreground": "body ink",
            "selection": "elevated surface",
            "comment": "secondary ink",
            "accent_sage": "structure / success-adjacent",
            "accent_amber": "attention / cursor",
            "accent_clay": "tertiary harmony",
            "error": "critical",
            "warning": "caution",
            "color10": "success lift (ANSI)",
        },
        "locks": {
            "midday": HEX_LOCKS["midday"],
            "night": HEX_LOCKS["night"],
        },
        "scenes": dict(PHASE_SCENE),
        "wallpapers": dict(PHASE_WALLPAPER_HINT),
        "typography": {
            "terminal": {
                "fontFamily": "JetBrainsMono Nerd Font",
                "fontSize": 10,
                "ligatures": True,
                "adjustCellHeight": 3,
            },
            "system": {"fontFamily": "CaskaydiaMono Nerd Font"},
        },
    }
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
    return out


def all_package_names() -> list[str]:
    return list(PACKAGE_PHASE.keys()) + list(PACKAGE_TN.keys())


def generate_all(root: Path) -> None:
    for name in all_package_names():
        dest = root / name
        if not dest.is_dir():
            raise SystemExit(f"missing theme package dir: {dest}")
        generate_one(name, dest)
        if name in PACKAGE_PHASE:
            print(f"generated {name} ← {PACKAGE_PHASE[name]}")
        else:
            print(f"generated {name} ← tinai={PACKAGE_TN[name]}")
    css = generate_phases_css()
    print(f"generated {css.relative_to(root.parent)}")
    roles = generate_roles_json()
    print(f"generated {roles.relative_to(root.parent)}")


def check_all(root: Path) -> int:
    """Return 0 if committed host files match a fresh generate."""
    drifts: list[str] = []
    with tempfile.TemporaryDirectory(prefix="eye-comfort-gen-") as tmp:
        tmp_root = Path(tmp)
        for name in all_package_names():
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
                # TN: light.mode is render-time only (never committed).
                if fname == "light.mode" and name in PACKAGE_TN:
                    if (src / fname).exists():
                        drifts.append(
                            f"{name}/{fname}: must not be committed "
                            "(live render sets luminance; remove from package)"
                        )
                    continue
                a, b = src / fname, dest / fname
                a_exists, b_exists = a.exists(), b.exists()
                if a_exists != b_exists:
                    drifts.append(f"{name}/{fname}: existence mismatch (committed={a_exists})")
                    continue
                if not a_exists:
                    continue
                if a.read_text(encoding="utf-8") != b.read_text(encoding="utf-8"):
                    drifts.append(f"{name}/{fname}: drifts from OKLCH SoT")
        css_tmp = tmp_root / "phases.css"
        generate_phases_css(css_tmp)
        css_src = tokens_css_path()
        if not css_src.is_file():
            drifts.append("tokens/phases.css: missing")
        elif css_src.read_text(encoding="utf-8") != css_tmp.read_text(encoding="utf-8"):
            drifts.append("tokens/phases.css: drifts from OKLCH SoT")
        roles_tmp = tmp_root / "roles.json"
        generate_roles_json(roles_tmp)
        roles_src = Path(__file__).resolve().parent.parent / "tokens" / "roles.json"
        if not roles_src.is_file():
            drifts.append("tokens/roles.json: missing")
        elif roles_src.read_text(encoding="utf-8") != roles_tmp.read_text(encoding="utf-8"):
            drifts.append("tokens/roles.json: drifts from OKLCH SoT")
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
