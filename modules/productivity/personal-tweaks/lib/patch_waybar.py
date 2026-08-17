#!/usr/bin/env python3
"""Idempotent waybar heading-chip insert. Stock Omarchy has no focus-now.

Backs up ~/.config/waybar/{config.jsonc,style.css} under
~/.local/share/personal-tweaks/waybar-backups/ before every write.
"""

from __future__ import annotations

import json
import os
import re
import shutil
from datetime import datetime
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

RELATIVE_EYE_IMPORT = '@import "eye-comfort/eye-comfort.css";'
FILE_EYE_IMPORT = re.compile(
    r'@import\s+url\("file://[^"]*eye-comfort\.css"\);\n?',
    re.I,
)
KEEP_BACKUPS = 20


def default_backup_root() -> Path:
    override = os.environ.get("PERSONAL_TWEAKS_BACKUP")
    if override:
        return Path(override)
    data = os.environ.get("XDG_DATA_HOME", str(Path.home() / ".local/share"))
    return Path(data) / "personal-tweaks" / "waybar-backups"


def loads_jsonc(text: str) -> object:
    t = re.sub(r"//.*?$", "", text, flags=re.M)
    t = re.sub(r"/\*.*?\*/", "", t, flags=re.S)
    t = re.sub(r",\s*([}\]])", r"\1", t)
    return json.loads(t)


def is_valid_jsonc(text: str) -> bool:
    try:
        loads_jsonc(text)
        return True
    except (json.JSONDecodeError, ValueError):
        return False


def backup_files(paths: list[Path], dest: Path) -> Path:
    dest.mkdir(parents=True, exist_ok=True)
    for p in paths:
        if p.is_file():
            shutil.copy2(p, dest / p.name)
    return dest


def prune_backups(root: Path, keep: int = KEEP_BACKUPS) -> None:
    if not root.is_dir():
        return
    dirs = sorted(
        p for p in root.iterdir() if p.is_dir() and p.name != "last-good"
    )
    for old in dirs[:-keep]:
        shutil.rmtree(old, ignore_errors=True)


def snapshot_waybar(paths: list[Path], backup_root: Path | None = None) -> Path:
    root = backup_root or default_backup_root()
    stamp = datetime.now().strftime("%Y%m%dT%H%M%S")
    dest = root / stamp
    n = 1
    while dest.exists():
        n += 1
        dest = root / f"{stamp}-{n}"
    backup_files(paths, dest)
    prune_backups(root)
    return dest


def mark_last_good(paths: list[Path], backup_root: Path | None = None) -> Path:
    root = backup_root or default_backup_root()
    return backup_files(paths, root / "last-good")


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
                k = j + 1
                while k < len(text) and text[k] in " \t":
                    k += 1
                had_comma = k < len(text) and text[k] == ","
                if had_comma:
                    k += 1
                block = extra.strip().rstrip(",").rstrip()
                if had_comma:
                    return text[:k] + "\n  " + block + "," + text[k:]
                return text[: j + 1] + ",\n  " + block + text[j + 1 :]
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


def ensure_eye_comfort_import(css: str) -> str:
    """Waybar does not resolve file:// includes; use a path next to style.css."""
    out = FILE_EYE_IMPORT.sub("", css)
    if RELATIVE_EYE_IMPORT in out:
        return out
    m = re.search(r"@import[^\n]+\n", out)
    if m:
        return out[: m.end()] + RELATIVE_EYE_IMPORT + "\n" + out[m.end() :]
    return RELATIVE_EYE_IMPORT + "\n" + out


def stage_eye_comfort_css(style_path: Path) -> Path | None:
    dest_dir = style_path.parent / "eye-comfort"
    dest = dest_dir / "eye-comfort.css"
    if dest.is_file():
        return dest
    candidates = [
        Path.home() / ".local/lib/eye-comfort/waybar/eye-comfort.css",
        Path.home() / "arch-machine/modules/productivity/eye-comfort/waybar/eye-comfort.css",
    ]
    for src in candidates:
        if src.is_file():
            dest_dir.mkdir(parents=True, exist_ok=True)
            shutil.copy2(src, dest)
            return dest
    return None


def apply(
    cfg_path: Path,
    css_path: Path,
    css_src: Path,
    backup_root: Path | None = None,
) -> list[str]:
    notes: list[str] = []
    root = backup_root or default_backup_root()
    snap = snapshot_waybar([cfg_path, css_path], root)
    notes.append(f"backup {snap}")

    if cfg_path.is_file():
        before = cfg_path.read_text(encoding="utf-8")
        after = ensure_object(ensure_center(before))
        if after != before:
            if not is_valid_jsonc(after):
                notes.append(f"refused invalid jsonc {cfg_path} (left untouched)")
            else:
                cfg_path.write_text(after, encoding="utf-8")
                notes.append(f"patched {cfg_path}")
        else:
            if not is_valid_jsonc(before):
                notes.append(f"invalid existing jsonc {cfg_path}")
            else:
                notes.append(f"ok {cfg_path}")
    else:
        notes.append(f"missing {cfg_path}")

    if css_path.is_file():
        before = css_path.read_text(encoding="utf-8")
        after = before
        if css_src.is_file():
            after = ensure_css(after, css_src.read_text(encoding="utf-8"))
        after = ensure_eye_comfort_import(after)
        staged = stage_eye_comfort_css(css_path)
        if staged:
            notes.append(f"css-local {staged}")
        if after != before:
            css_path.write_text(after, encoding="utf-8")
            notes.append(f"patched {css_path}")
        else:
            notes.append(f"ok {css_path}")

    live = [p for p in (cfg_path, css_path) if p.is_file()]
    if cfg_path.is_file() and is_valid_jsonc(cfg_path.read_text(encoding="utf-8")):
        mark_last_good(live, root)
        notes.append(f"last-good {root / 'last-good'}")
    return notes
