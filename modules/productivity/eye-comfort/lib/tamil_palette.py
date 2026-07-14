"""Tamil tinai palettes — eye-comfort OKLCH family with landscape hue leans.

Starts from circadian phase roles (same AA bar), then applies restrained
tinai chroma/hue shifts + Nazhigai micro-tint. Never pure #000/#FFF; warm dark.
"""
from __future__ import annotations

from typing import Dict, Tuple

from oklch import contrast_ratio, hex_to_oklch, oklch_to_hex
from palette import (
    Ambient,
    Intensity,
    Phase,
    is_dark_phase,
    roles_for_phase,
    validate_roles,
)
from tamil_schedule import SIRU_TO_PHASE, Siru, Tinai

# Tinai accent hue leans (OKLCH H°) — warm/restrained; no cool cyber blue (~230°)
# and no SaaS cream decoration. Landscape identity via accent + soft bg chroma.
_TINAI_ACCENT_H: Dict[Tinai, Dict[str, float]] = {
    "kurinji": {  # mountain mist — cool-leaning sage slate, still warm family
        "accent_sage": 155.0,
        "accent_amber": 72.0,
        "accent_clay": 48.0,
        "color4": 198.0,
        "color6": 168.0,
        "bg_H": 62.0,
    },
    "mullai": {  # forest jasmine — greener sage, cream-jasmine amber
        "accent_sage": 148.0,
        "accent_amber": 88.0,
        "accent_clay": 100.0,
        "color4": 178.0,
        "color6": 165.0,
        "bg_H": 85.0,
    },
    "marutham": {  # fertile plains — rice green / warm clay (closest to base)
        "accent_sage": 162.0,
        "accent_amber": 68.0,
        "accent_clay": 55.0,
        "color4": 202.0,
        "color6": 172.0,
        "bg_H": 78.0,
    },
    "neythal": {  # seashore sand + water lily teal (H≈190, not 230)
        "accent_sage": 168.0,
        "accent_amber": 78.0,
        "accent_clay": 52.0,
        "color4": 192.0,
        "color6": 185.0,
        "bg_H": 70.0,
    },
    "palai": {  # dry wasteland — ochre/dust, higher midday heat feel
        "accent_sage": 142.0,
        "accent_amber": 60.0,
        "accent_clay": 45.0,
        "color4": 188.0,
        "color6": 155.0,
        "bg_H": 58.0,
    },
}

# Roles whose hue we retarget toward tinai accents
_ACCENT_KEYS = (
    "accent_sage",
    "accent_amber",
    "accent_clay",
    "color4",
    "color6",
    "color10",
    "color12",
    "color13",
    "color14",
)


def _retarget_hue(hexv: str, target_h: float, *, blend: float = 0.55) -> str:
    L, C, H = hex_to_oklch(hexv)
    # Blend current hue toward tinai target (restrained, not a costume remix)
    # Shortest-arc blend on hue circle
    d = ((target_h - H + 540) % 360) - 180
    new_h = (H + d * blend) % 360.0
    return oklch_to_hex(L, C, new_h)


def _nudge_bg(hexv: str, *, tinai: Tinai, dark: bool, nazhigai: int) -> str:
    L, C, H = hex_to_oklch(hexv)
    meta = _TINAI_ACCENT_H[tinai]
    target_h = meta["bg_H"]
    d = ((target_h - H + 540) % 360) - 180
    H = (H + d * 0.35) % 360.0
    # Slight chroma toward landscape (never cream SaaS blowout)
    C = min(0.028 if not dark else 0.018, C + 0.004)
    # Nazhigai soft step: ± micro L within Siru (10 steps spanning ~0.012)
    # Early steps slightly brighter by day / deeper by night
    bias = (nazhigai - 4.5) / 4.5  # -1..+1 approx
    if dark:
        L = max(0.14, min(0.34, L - bias * 0.006))
    else:
        L = max(0.90, min(0.97, L + bias * 0.005))
    # Palai midday heat: tiny L lift + ochre chroma
    if tinai == "palai" and not dark:
        L = min(0.965, L + 0.008)
        C = min(0.022, C + 0.004)
    return oklch_to_hex(L, max(0.0, C), H)


def _ensure_aa(roles: Dict[str, str], *, dark: bool) -> Dict[str, str]:
    cr = contrast_ratio(roles["foreground"], roles["background"])
    if cr < 4.5:
        fg_L, fg_C, fg_H = hex_to_oklch(roles["foreground"])
        step = 0.02 if dark else -0.02
        for _ in range(12):
            fg_L = min(0.98, max(0.12, fg_L + step))
            roles["foreground"] = oklch_to_hex(fg_L, fg_C, fg_H)
            if contrast_ratio(roles["foreground"], roles["background"]) >= 4.5:
                break
    if dark:
        bg = roles["background"]
        h = bg.lstrip("#")
        r, g, b = int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)
        if r <= b:
            L, C, H = hex_to_oklch(bg)
            roles["background"] = oklch_to_hex(L, max(C, 0.008), 67.0)
    # Ban pure extremes
    for key in ("background", "foreground"):
        if roles[key].upper() in ("#000000", "#FFFFFF"):
            L, C, H = hex_to_oklch(roles[key])
            if key == "background":
                L = 0.20 if dark else 0.95
            else:
                L = 0.91 if dark else 0.27
            roles[key] = oklch_to_hex(L, max(C, 0.006), 67.0 if dark else 78.0)
    return roles


def roles_for_tamil(
    tinai: Tinai,
    siru: Siru,
    *,
    nazhigai: int = 0,
    ambient: Ambient = "indoor",
    intensity: Intensity = "balanced",
    high_contrast: bool = False,
) -> Dict[str, str]:
    """Role→hex for tinai × siru with Nazhigai micro-tint."""
    if not (0 <= nazhigai <= 9):
        raise ValueError(f"nazhigai must be 0–9, got {nazhigai}")
    phase = SIRU_TO_PHASE[siru]
    dark = is_dark_phase(phase)  # type: ignore[arg-type]
    roles = dict(
        roles_for_phase(
            phase,  # type: ignore[arg-type]
            ambient=ambient,
            intensity=intensity,
            high_contrast=high_contrast,
        )
    )
    meta = _TINAI_ACCENT_H[tinai]
    # Retarget structure accents toward tinai landscape
    hue_map = {
        "accent_sage": meta["accent_sage"],
        "accent_amber": meta["accent_amber"],
        "accent_clay": meta["accent_clay"],
        "color4": meta["color4"],
        "color6": meta["color6"],
        "color10": meta["accent_sage"],
        "color12": meta["color4"],
        "color13": meta["accent_clay"],
        "color14": meta["color6"],
    }
    for key, th in hue_map.items():
        if key in roles:
            roles[key] = _retarget_hue(roles[key], th, blend=0.6)

    roles["background"] = _nudge_bg(
        roles["background"], tinai=tinai, dark=dark, nazhigai=nazhigai
    )
    # Keep selection near bg
    sel_L, sel_C, sel_H = hex_to_oklch(roles["selection"])
    bg_L, bg_C, bg_H = hex_to_oklch(roles["background"])
    sel_L = bg_L - 0.06 if not dark else bg_L + 0.07
    roles["selection"] = oklch_to_hex(sel_L, max(sel_C, bg_C), bg_H)

    roles = _ensure_aa(roles, dark=dark)
    fails = validate_roles(roles, dark=dark)
    if fails:
        # Soften: re-base from indoor balanced then light tinai-only hue lean
        roles = dict(
            roles_for_phase(phase, ambient="indoor", intensity="balanced")  # type: ignore[arg-type]
        )
        for key, th in hue_map.items():
            if key in roles:
                roles[key] = _retarget_hue(roles[key], th, blend=0.35)
        roles = _ensure_aa(roles, dark=dark)
    return roles


def canonical_phase_for_tinai(tinai: Tinai) -> Tuple[Phase, Siru]:
    """Bake each package at its table Siru (characteristic landscape light)."""
    from tamil_schedule import TINAI_META

    siru = TINAI_META[tinai]["siru"]  # type: ignore[assignment]
    phase = SIRU_TO_PHASE[siru]  # type: ignore[index]
    return phase, siru  # type: ignore[return-value]
