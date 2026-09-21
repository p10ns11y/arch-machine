"""Sweden realm palettes — warm OKLCH with restrained saga hue leans."""
from __future__ import annotations

from typing import Dict, Tuple

from oklch import contrast_ratio, hex_to_oklch, oklch_to_hex
from palette import Ambient, Intensity, Phase, is_dark_phase, roles_for_phase, validate_roles
from sweden_schedule import Realm

# Warm/restrained — no ice-blue cyber Nordic (~230°) or metal kitsch.
_REALM_ACCENT_H: Dict[Realm, Dict[str, float]] = {
    "asgard": {  # sky hall — soft gold-amber high light
        "accent_sage": 155.0,
        "accent_amber": 72.0,
        "accent_clay": 58.0,
        "color4": 200.0,
        "color6": 175.0,
        "bg_H": 75.0,
    },
    "midgard": {  # meadow — balanced sage/clay (closest to base)
        "accent_sage": 162.0,
        "accent_amber": 68.0,
        "accent_clay": 55.0,
        "color4": 202.0,
        "color6": 172.0,
        "bg_H": 78.0,
    },
    "jotunheim": {  # fells — stone grey-green, ochre clay
        "accent_sage": 148.0,
        "accent_amber": 62.0,
        "accent_clay": 48.0,
        "color4": 195.0,
        "color6": 165.0,
        "bg_H": 65.0,
    },
    "vanaheim": {  # forest — deep sage, warm amber
        "accent_sage": 150.0,
        "accent_amber": 82.0,
        "accent_clay": 95.0,
        "color4": 185.0,
        "color6": 168.0,
        "bg_H": 88.0,
    },
    "nifl": {  # mist winter — muted umber, low chroma (not pure white snow)
        "accent_sage": 158.0,
        "accent_amber": 65.0,
        "accent_clay": 52.0,
        "color4": 198.0,
        "color6": 178.0,
        "bg_H": 62.0,
    },
}


def _retarget_hue(hexv: str, target_h: float, *, blend: float = 0.55) -> str:
    L, C, H = hex_to_oklch(hexv)
    d = ((target_h - H + 540) % 360) - 180
    new_h = (H + d * blend) % 360.0
    return oklch_to_hex(L, C, new_h)


def _nudge_bg(hexv: str, *, realm: Realm, dark: bool, mikrosteg: int) -> str:
    L, C, H = hex_to_oklch(hexv)
    meta = _REALM_ACCENT_H[realm]
    target_h = meta["bg_H"]
    d = ((target_h - H + 540) % 360) - 180
    H = (H + d * 0.35) % 360.0
    C = min(0.028 if not dark else 0.018, C + 0.003)
    bias = (mikrosteg - 2.5) / 2.5
    if dark:
        L = max(0.14, min(0.34, L - bias * 0.005))
    else:
        L = max(0.90, min(0.97, L + bias * 0.004))
    if realm == "nifl" and not dark:
        L = min(0.955, L - 0.006)  # avoid snow glare
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
    for key in ("background", "foreground"):
        if roles[key].upper() in ("#000000", "#FFFFFF"):
            L, C, H = hex_to_oklch(roles[key])
            if key == "background":
                L = 0.20 if dark else 0.95
            else:
                L = 0.91 if dark else 0.27
            roles[key] = oklch_to_hex(L, max(C, 0.006), 67.0 if dark else 78.0)
    return roles


def roles_for_sweden(
    realm: Realm,
    phase: Phase,
    *,
    mikrosteg: int = 0,
    ambient: Ambient = "indoor",
    intensity: Intensity = "balanced",
    high_contrast: bool = False,
) -> Dict[str, str]:
    if not (0 <= mikrosteg <= 5):
        raise ValueError(f"mikrosteg must be 0–5, got {mikrosteg}")
    dark = is_dark_phase(phase)
    roles = dict(
        roles_for_phase(
            phase,
            ambient=ambient,
            intensity=intensity,
            high_contrast=high_contrast,
        )
    )
    meta = _REALM_ACCENT_H[realm]
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
            roles[key] = _retarget_hue(roles[key], th, blend=0.55)

    roles["background"] = _nudge_bg(
        roles["background"], realm=realm, dark=dark, mikrosteg=mikrosteg
    )
    sel_L, sel_C, sel_H = hex_to_oklch(roles["selection"])
    bg_L, bg_C, bg_H = hex_to_oklch(roles["background"])
    sel_L = bg_L - 0.06 if not dark else bg_L + 0.07
    roles["selection"] = oklch_to_hex(sel_L, max(sel_C, bg_C), bg_H)

    roles = _ensure_aa(roles, dark=dark)
    fails = validate_roles(roles, dark=dark)
    if fails:
        roles = dict(roles_for_phase(phase, ambient="indoor", intensity="balanced"))
        for key, th in hue_map.items():
            if key in roles:
                roles[key] = _retarget_hue(roles[key], th, blend=0.3)
        roles = _ensure_aa(roles, dark=dark)
    return roles


def canonical_phase_for_realm(realm: Realm) -> Tuple[Phase, int]:
    """Bake each package at a characteristic phase + mikrosteg."""
    defaults: Dict[Realm, Tuple[Phase, int]] = {
        "asgard": ("midday", 3),
        "midgard": ("morning", 2),
        "jotunheim": ("dusk", 4),
        "vanaheim": ("dawn", 1),
        "nifl": ("night", 5),
    }
    return defaults[realm]
