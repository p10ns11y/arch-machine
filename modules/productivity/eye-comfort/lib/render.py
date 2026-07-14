"""Render Omarchy theme host files from role hexes."""
from __future__ import annotations

from pathlib import Path
from typing import Dict

from palette import is_dark_phase, Phase


def ansi_from_roles(roles: Dict[str, str]) -> Dict[str, str]:
    """Map roles → colors.toml / ghostty ANSI slots."""
    return {
        "accent": roles["accent_sage"],
        "cursor": roles["accent_amber"] if is_dark_phase_roles(roles) else roles["foreground"],
        "foreground": roles["foreground"],
        "background": roles["background"],
        "selection_foreground": roles["foreground"],
        "selection_background": roles["selection"],
        "color0": roles["selection"],
        "color1": roles["error"],
        "color2": roles["accent_sage"],
        "color3": roles["accent_amber"],
        "color4": roles["color4"],
        "color5": roles["accent_clay"],
        "color6": roles["color6"],
        "color7": roles["color7"],
        "color8": roles["comment"],
        "color9": roles["color9"],
        "color10": roles["color10"],
        "color11": roles["warning"],
        "color12": roles["color12"],
        "color13": roles["color13"],
        "color14": roles["color14"],
        "color15": roles["color15"],
    }


def is_dark_phase_roles(roles: Dict[str, str]) -> bool:
    """Heuristic: dark if bg relative luminance is low."""
    from oklch import relative_luminance_hex

    return relative_luminance_hex(roles["background"]) < 0.25


def render_colors_toml(roles: Dict[str, str], *, name: str, note: str) -> str:
    a = ansi_from_roles(roles)
    lines = [
        f"# {name} — {note}",
        f'accent = "{a["accent"]}"',
        f'cursor = "{a["cursor"]}"',
        f'foreground = "{a["foreground"]}"',
        f'background = "{a["background"]}"',
        f'selection_foreground = "{a["selection_foreground"]}"',
        f'selection_background = "{a["selection_background"]}"',
        "",
    ]
    for i in range(16):
        lines.append(f'color{i} = "{a[f"color{i}"]}"')
    return "\n".join(lines) + "\n"


def render_ghostty(roles: Dict[str, str]) -> str:
    a = ansi_from_roles(roles)
    lines = [
        f"background = {a['background']}",
        f"foreground = {a['foreground']}",
        f"cursor-color = {a['cursor']}",
        f"selection-background = {a['selection_background']}",
        f"selection-foreground = {a['selection_foreground']}",
        "",
    ]
    for i in range(16):
        lines.append(f"palette = {i}={a[f'color{i}']}")
    return "\n".join(lines) + "\n"


def render_neovim(roles: Dict[str, str], *, dark: bool) -> str:
    """Render LazyVim theme plugin spec.

    gruvbox.nvim with contrast=\"soft\" reads dark0_soft / light0_soft for Normal
    bg — overriding only dark0/light0 leaves stock soft greys and looks like a
    half-applied theme after light↔dark switches.
    """
    bg = roles["background"]
    surface = roles["selection"]
    fg = roles["foreground"]
    if dark:
        overrides = f"""        dark0 = "{bg}",
        dark0_soft = "{bg}",
        dark1 = "{surface}",
        light1 = "{fg}","""
    else:
        overrides = f"""        light0 = "{bg}",
        light0_soft = "{bg}",
        light1 = "{surface}",
        dark1 = "{fg}","""
    return f"""return {{
  {{
    "ellisonleao/gruvbox.nvim",
    opts = {{
      contrast = "soft",
      palette_overrides = {{
{overrides}
      }},
    }},
  }},
  {{
    "LazyVim/LazyVim",
    opts = {{
      colorscheme = "gruvbox",
    }},
  }},
}}
"""


def write_theme_package(
    dest: Path,
    roles: Dict[str, str],
    *,
    name: str,
    phase: Phase,
    icons_src: Path | None = None,
) -> None:
    dest.mkdir(parents=True, exist_ok=True)
    dark = is_dark_phase(phase)
    note = f"circadian {phase} (OKLCH SoT → hex)"
    (dest / "colors.toml").write_text(
        render_colors_toml(roles, name=name, note=note), encoding="utf-8"
    )
    (dest / "ghostty.conf").write_text(render_ghostty(roles), encoding="utf-8")
    (dest / "neovim.lua").write_text(render_neovim(roles, dark=dark), encoding="utf-8")
    if not dark:
        (dest / "light.mode").write_text("", encoding="utf-8")
    elif (dest / "light.mode").exists():
        (dest / "light.mode").unlink()
    if icons_src and icons_src.is_file():
        (dest / "icons.theme").write_text(icons_src.read_text(encoding="utf-8"), encoding="utf-8")
