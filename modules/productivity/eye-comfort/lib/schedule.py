"""Pure schedule + palette helpers for eye-comfort themes (testable, no display)."""
from __future__ import annotations

DARK_THEME = "eye-comfort-dark"
LIGHT_THEME = "eye-comfort-light"

# Local hour inclusive start of light window; dark from DARK_START through midnight and until LIGHT_START.
LIGHT_START_HOUR = 7
DARK_START_HOUR = 18

# Locked SoT role hexes (must match colors.toml / PALETTE.md)
DARK_ROLES = {
    "background": "#181614",
    "foreground": "#E6DFD3",
    "selection": "#2F2924",
    "comment": "#8A8278",
    "accent_sage": "#7D9A8C",
    "accent_amber": "#C9A66B",
    "accent_clay": "#A88B6E",
    "error": "#C47064",
    "warning": "#D4A05A",
}
LIGHT_ROLES = {
    "background": "#F5F0E8",
    "foreground": "#2A2622",
    "selection": "#E0D9CE",
    "comment": "#6E665C",
    "accent_sage": "#4A6B5C",
    "accent_amber": "#8A6030",
    "accent_clay": "#8B6B4E",
    "error": "#B54A40",
    "warning": "#8B6020",
}


def theme_for_hour(hour: int) -> str:
    """Return theme name for local hour 0–23.

    Light: [LIGHT_START_HOUR, DARK_START_HOUR)
    Dark: otherwise (evening/night).
    """
    if not isinstance(hour, int) or hour < 0 or hour > 23:
        raise ValueError(f"hour must be int 0–23, got {hour!r}")
    if LIGHT_START_HOUR <= hour < DARK_START_HOUR:
        return LIGHT_THEME
    return DARK_THEME


def theme_for_mode(mode: str) -> str:
    m = mode.strip().lower()
    if m in ("day", "light"):
        return LIGHT_THEME
    if m in ("night", "dark", "evening"):
        return DARK_THEME
    raise ValueError(f"unknown mode {mode!r}; use day|night|auto")


def srgb_to_linear(c: float) -> float:
    c = c / 255.0
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def relative_luminance(hex_color: str) -> float:
    h = hex_color.lstrip("#")
    r, g, b = int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)
    R, G, B = srgb_to_linear(r), srgb_to_linear(g), srgb_to_linear(b)
    return 0.2126 * R + 0.7152 * G + 0.0722 * B


def contrast_ratio(fg: str, bg: str) -> float:
    L1, L2 = relative_luminance(fg), relative_luminance(bg)
    lighter, darker = max(L1, L2), min(L1, L2)
    return (lighter + 0.05) / (darker + 0.05)


def is_warm_dark_bg(hex_color: str) -> bool:
    """R channel > B channel (warmer than cool blue-black)."""
    h = hex_color.lstrip("#")
    r, b = int(h[0:2], 16), int(h[4:6], 16)
    return r > b


def validate_palette(roles: dict[str, str], *, dark: bool) -> list[str]:
    """Return list of failure messages (empty if ok)."""
    fails = []
    bg, fg = roles["background"], roles["foreground"]
    if bg.upper() in ("#000000", "#FFFFFF") or fg.upper() in ("#000000", "#FFFFFF"):
        fails.append("pure black/white not allowed for bg/fg")
    cr = contrast_ratio(fg, bg)
    if cr < 4.5:
        fails.append(f"fg/bg contrast {cr:.2f} < 4.5")
    if dark and not is_warm_dark_bg(bg):
        fails.append("dark bg not warm (R should exceed B)")
    return fails
