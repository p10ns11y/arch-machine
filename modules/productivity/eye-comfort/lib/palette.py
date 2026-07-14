"""Phase palettes in OKLCH — identity-preserving eye-comfort family.

Locked brand: warm umber / parchment / sage / amber / clay.
Phases refine luminance + chroma for circadian eye comfort; they do not invent
a second palette family.
"""
from __future__ import annotations

from typing import Dict, Literal, TypedDict

from oklch import contrast_ratio, hex_to_oklch, oklch_to_hex

Phase = Literal["dawn", "morning", "midday", "afternoon", "dusk", "evening", "night"]
Ambient = Literal["auto", "indoor", "outdoor"]
Intensity = Literal["soft", "balanced", "crisp"]

ROLE_KEYS = (
    "background",
    "foreground",
    "selection",
    "comment",
    "accent_sage",
    "accent_amber",
    "accent_clay",
    "error",
    "warning",
    "color4",
    "color6",
    "color7",
    "color9",
    "color10",
    "color12",
    "color13",
    "color14",
    "color15",
)


class OklchColor(TypedDict):
    L: float
    C: float
    H: float


# Base OKLCH SoT per phase (before ambient/intensity). Hex anchors for day/night
# match committed colors.toml; dawn/dusk are transitional siblings.
_PHASE_OKLCH: Dict[Phase, Dict[str, OklchColor]] = {
    # First light through linen — peach-rose paper, not noon cream glare
    "dawn": {
        "background": {"L": 0.935, "C": 0.020, "H": 52},
        "foreground": {"L": 0.300, "C": 0.012, "H": 55},
        "selection": {"L": 0.880, "C": 0.022, "H": 52},
        "comment": {"L": 0.520, "C": 0.018, "H": 55},
        "accent_sage": {"L": 0.480, "C": 0.045, "H": 160},
        "accent_amber": {"L": 0.520, "C": 0.085, "H": 68},
        "accent_clay": {"L": 0.550, "C": 0.055, "H": 55},
        "error": {"L": 0.520, "C": 0.120, "H": 28},
        "warning": {"L": 0.540, "C": 0.110, "H": 70},
        "color4": {"L": 0.480, "C": 0.028, "H": 205},
        "color6": {"L": 0.500, "C": 0.050, "H": 175},
        "color7": {"L": 0.450, "C": 0.012, "H": 55},
        "color9": {"L": 0.560, "C": 0.125, "H": 28},
        "color10": {"L": 0.540, "C": 0.050, "H": 155},
        "color12": {"L": 0.520, "C": 0.032, "H": 205},
        "color13": {"L": 0.580, "C": 0.060, "H": 55},
        "color14": {"L": 0.560, "C": 0.055, "H": 175},
        "color15": {"L": 0.300, "C": 0.012, "H": 55},
    },
    # Soft cream day (committed light SoT — hex-locked via post-check)
    "morning": {
        "background": {"L": 0.955, "C": 0.014, "H": 78},
        "foreground": {"L": 0.275, "C": 0.010, "H": 67},
        "selection": {"L": 0.900, "C": 0.016, "H": 78},
        "comment": {"L": 0.530, "C": 0.018, "H": 74},
        "accent_sage": {"L": 0.470, "C": 0.045, "H": 164},
        "accent_amber": {"L": 0.500, "C": 0.090, "H": 68},
        "accent_clay": {"L": 0.530, "C": 0.055, "H": 62},
        "error": {"L": 0.510, "C": 0.125, "H": 28},
        "warning": {"L": 0.500, "C": 0.115, "H": 70},
        "color4": {"L": 0.460, "C": 0.032, "H": 205},
        "color6": {"L": 0.500, "C": 0.055, "H": 175},
        "color7": {"L": 0.480, "C": 0.012, "H": 67},
        "color9": {"L": 0.560, "C": 0.130, "H": 28},
        "color10": {"L": 0.540, "C": 0.050, "H": 155},
        "color12": {"L": 0.520, "C": 0.032, "H": 205},
        "color13": {"L": 0.580, "C": 0.060, "H": 60},
        "color14": {"L": 0.550, "C": 0.060, "H": 175},
        "color15": {"L": 0.275, "C": 0.010, "H": 67},
    },
    # Midday cream — committed eye-comfort-light anchors
    "midday": {
        "background": {"L": 0.960, "C": 0.012, "H": 80},
        "foreground": {"L": 0.270, "C": 0.009, "H": 67},
        "selection": {"L": 0.890, "C": 0.014, "H": 80},
        "comment": {"L": 0.520, "C": 0.018, "H": 74},
        "accent_sage": {"L": 0.455, "C": 0.045, "H": 164},
        "accent_amber": {"L": 0.490, "C": 0.090, "H": 68},
        "accent_clay": {"L": 0.520, "C": 0.055, "H": 62},
        "error": {"L": 0.505, "C": 0.125, "H": 28},
        "warning": {"L": 0.490, "C": 0.115, "H": 70},
        "color4": {"L": 0.450, "C": 0.032, "H": 205},
        "color6": {"L": 0.495, "C": 0.055, "H": 175},
        "color7": {"L": 0.470, "C": 0.012, "H": 67},
        "color9": {"L": 0.555, "C": 0.130, "H": 28},
        "color10": {"L": 0.535, "C": 0.050, "H": 155},
        "color12": {"L": 0.510, "C": 0.032, "H": 205},
        "color13": {"L": 0.575, "C": 0.060, "H": 60},
        "color14": {"L": 0.545, "C": 0.060, "H": 175},
        "color15": {"L": 0.270, "C": 0.009, "H": 67},
    },
    # Afternoon — warmer amber lean, still light paper
    "afternoon": {
        "background": {"L": 0.952, "C": 0.016, "H": 72},
        "foreground": {"L": 0.275, "C": 0.011, "H": 60},
        "selection": {"L": 0.885, "C": 0.018, "H": 72},
        "comment": {"L": 0.525, "C": 0.020, "H": 68},
        "accent_sage": {"L": 0.460, "C": 0.045, "H": 162},
        "accent_amber": {"L": 0.505, "C": 0.095, "H": 65},
        "accent_clay": {"L": 0.535, "C": 0.060, "H": 58},
        "error": {"L": 0.510, "C": 0.125, "H": 28},
        "warning": {"L": 0.505, "C": 0.118, "H": 68},
        "color4": {"L": 0.455, "C": 0.030, "H": 200},
        "color6": {"L": 0.500, "C": 0.052, "H": 172},
        "color7": {"L": 0.475, "C": 0.014, "H": 60},
        "color9": {"L": 0.560, "C": 0.130, "H": 28},
        "color10": {"L": 0.540, "C": 0.050, "H": 155},
        "color12": {"L": 0.515, "C": 0.030, "H": 200},
        "color13": {"L": 0.585, "C": 0.065, "H": 58},
        "color14": {"L": 0.550, "C": 0.058, "H": 172},
        "color15": {"L": 0.275, "C": 0.011, "H": 60},
    },
    # Residual gold sky — warmer / lighter than night umber
    "dusk": {
        "background": {"L": 0.275, "C": 0.016, "H": 58},
        "foreground": {"L": 0.905, "C": 0.022, "H": 78},
        "selection": {"L": 0.355, "C": 0.020, "H": 58},
        "comment": {"L": 0.625, "C": 0.022, "H": 70},
        "accent_sage": {"L": 0.680, "C": 0.042, "H": 164},
        "accent_amber": {"L": 0.765, "C": 0.098, "H": 78},
        "accent_clay": {"L": 0.685, "C": 0.060, "H": 62},
        "error": {"L": 0.660, "C": 0.118, "H": 28},
        "warning": {"L": 0.760, "C": 0.112, "H": 72},
        "color4": {"L": 0.640, "C": 0.028, "H": 205},
        "color6": {"L": 0.700, "C": 0.045, "H": 172},
        "color7": {"L": 0.905, "C": 0.022, "H": 78},
        "color9": {"L": 0.700, "C": 0.122, "H": 28},
        "color10": {"L": 0.720, "C": 0.048, "H": 155},
        "color12": {"L": 0.680, "C": 0.030, "H": 205},
        "color13": {"L": 0.720, "C": 0.065, "H": 60},
        "color14": {"L": 0.730, "C": 0.050, "H": 172},
        "color15": {"L": 0.915, "C": 0.018, "H": 80},
    },
    # Evening lamp — committed dark SoT (slightly lifted from deepest night)
    "evening": {
        "background": {"L": 0.220, "C": 0.008, "H": 67},
        "foreground": {"L": 0.910, "C": 0.018, "H": 81},
        "selection": {"L": 0.300, "C": 0.012, "H": 67},
        "comment": {"L": 0.610, "C": 0.018, "H": 74},
        "accent_sage": {"L": 0.660, "C": 0.039, "H": 164},
        "accent_amber": {"L": 0.740, "C": 0.087, "H": 80},
        "accent_clay": {"L": 0.660, "C": 0.054, "H": 67},
        "error": {"L": 0.640, "C": 0.109, "H": 29},
        "warning": {"L": 0.740, "C": 0.107, "H": 73},
        "color4": {"L": 0.630, "C": 0.032, "H": 205},
        "color6": {"L": 0.690, "C": 0.042, "H": 172},
        "color7": {"L": 0.910, "C": 0.018, "H": 81},
        "color9": {"L": 0.680, "C": 0.115, "H": 29},
        "color10": {"L": 0.700, "C": 0.045, "H": 155},
        "color12": {"L": 0.670, "C": 0.028, "H": 205},
        "color13": {"L": 0.710, "C": 0.060, "H": 65},
        "color14": {"L": 0.720, "C": 0.048, "H": 172},
        "color15": {"L": 0.920, "C": 0.016, "H": 81},
    },
    # Deepest warm night — committed eye-comfort-dark anchors
    "night": {
        "background": {"L": 0.200, "C": 0.005, "H": 67},
        "foreground": {"L": 0.910, "C": 0.018, "H": 81},
        "selection": {"L": 0.290, "C": 0.012, "H": 67},
        "comment": {"L": 0.610, "C": 0.018, "H": 74},
        "accent_sage": {"L": 0.660, "C": 0.039, "H": 164},
        "accent_amber": {"L": 0.740, "C": 0.087, "H": 80},
        "accent_clay": {"L": 0.660, "C": 0.054, "H": 67},
        "error": {"L": 0.640, "C": 0.109, "H": 29},
        "warning": {"L": 0.740, "C": 0.107, "H": 73},
        "color4": {"L": 0.620, "C": 0.032, "H": 205},
        "color6": {"L": 0.680, "C": 0.042, "H": 172},
        "color7": {"L": 0.910, "C": 0.018, "H": 81},
        "color9": {"L": 0.680, "C": 0.115, "H": 29},
        "color10": {"L": 0.700, "C": 0.045, "H": 155},
        "color12": {"L": 0.660, "C": 0.028, "H": 205},
        "color13": {"L": 0.700, "C": 0.060, "H": 65},
        "color14": {"L": 0.710, "C": 0.048, "H": 172},
        "color15": {"L": 0.920, "C": 0.016, "H": 81},
    },
}

# Hex locks for identity packages (must match colors.toml)
HEX_LOCKS: Dict[Phase, Dict[str, str]] = {
    "midday": {
        "background": "#F5F0E8",
        "foreground": "#2A2622",
        "selection": "#E0D9CE",
        "comment": "#6E665C",
        "accent_sage": "#4A6B5C",
        "accent_amber": "#8A6030",
        "accent_clay": "#8B6B4E",
        "error": "#B54A40",
        "warning": "#8B6020",
    },
    "night": {
        "background": "#181614",
        "foreground": "#E6DFD3",
        "selection": "#2F2924",
        "comment": "#8A8278",
        "accent_sage": "#7D9A8C",
        "accent_amber": "#C9A66B",
        "accent_clay": "#A88B6E",
        "error": "#C47064",
        "warning": "#D4A05A",
    },
}

# Omarchy package per phase (4 packages cover the arc)
PHASE_THEME: Dict[Phase, str] = {
    "dawn": "eye-comfort-dawn",
    "morning": "eye-comfort-light",
    "midday": "eye-comfort-light",
    "afternoon": "eye-comfort-light",
    "dusk": "eye-comfort-dusk",
    "evening": "eye-comfort-dark",
    "night": "eye-comfort-dark",
}

# Display CCT hints (hyprsunset companion; theme already warm-biased)
PHASE_CCT_K: Dict[Phase, int] = {
    "dawn": 5200,
    "morning": 5600,
    "midday": 6200,
    "afternoon": 5400,
    "dusk": 4200,
    "evening": 3800,
    "night": 3400,
}

# Wallpaper preference within package backgrounds/
PHASE_WALLPAPER_HINT: Dict[Phase, str] = {
    "dawn": "1-parchment-dunes.jpg",
    "morning": "1-parchment-dunes.jpg",
    "midday": "2-cream-botanical.jpg",
    "afternoon": "2-cream-botanical.jpg",
    "dusk": "2-sage-amber-ribbons.jpg",
    "evening": "1-journals-tea.jpg",
    "night": "0-signature-lantern.jpg",
}

# One-line scene (delight): printed on apply; never blocks the task
PHASE_SCENE: Dict[Phase, str] = {
    "dawn": "peach linen · first light",
    "morning": "soft cream · clear desk",
    "midday": "day paper · long focus",
    "afternoon": "warm paper · amber lean",
    "dusk": "residual gold · lamp just on",
    "evening": "journals & tea · evening lamp",
    "night": "lantern umber · deep night",
}


def is_dark_phase(phase: Phase) -> bool:
    return phase in ("dusk", "evening", "night")


def _adjust_oklch(
    L: float,
    C: float,
    H: float,
    *,
    role: str,
    ambient: Ambient,
    intensity: Intensity,
    high_contrast: bool,
    dark: bool,
) -> OklchColor:
    is_surface = role in ("background", "selection")
    is_ink = role in ("foreground", "comment", "color15", "color7")

    # Outdoor: reduce wash on surfaces; deepen ink for sun glare
    if ambient == "outdoor":
        if is_surface:
            if dark:
                L = max(0.14, L - 0.015)
                C = max(0.0, C - 0.004)
            else:
                L = max(0.88, L - 0.020)  # less washed cream under sun
                C = max(0.0, C - 0.006)
        elif is_ink:
            if dark:
                L = min(0.96, L + 0.02)
            else:
                L = max(0.18, L - 0.03)
    elif ambient == "indoor":
        if is_surface:
            if dark:
                L = min(0.35, L + 0.01)
                C = C + 0.003
            else:
                L = min(0.97, L + 0.005)
                C = C + 0.002

    if high_contrast or intensity == "crisp":
        if is_ink:
            if dark:
                L = min(0.96, L + 0.03)
            else:
                L = max(0.16, L - 0.04)
        elif is_surface:
            if dark:
                L = max(0.12, L - 0.025)
            else:
                L = min(0.98, L + 0.01)
        C = min(0.16, C + 0.006)
    elif intensity == "soft":
        # Soft = gentler contrast, still ≥4.5 after repair
        if is_ink:
            if dark:
                L = max(0.82, L - 0.02)
            else:
                L = min(0.38, L + 0.025)
        elif is_surface:
            if dark:
                L = min(0.30, L + 0.02)
            else:
                L = max(0.92, L - 0.008)
        C = max(0.0, C - 0.004)

    return {"L": L, "C": max(0.0, C), "H": H % 360.0}


def roles_for_phase(
    phase: Phase,
    *,
    ambient: Ambient = "auto",
    intensity: Intensity = "balanced",
    high_contrast: bool = False,
) -> Dict[str, str]:
    """Return role→hex for a phase after ambient/intensity adjustments."""
    amb: Ambient = ambient if ambient in ("indoor", "outdoor") else "indoor"
    dark = is_dark_phase(phase)
    base = _PHASE_OKLCH[phase]
    roles: Dict[str, str] = {}

    # Hex-lock identity packages when balanced indoor (preserve committed SoT)
    use_lock = (
        phase in HEX_LOCKS
        and intensity == "balanced"
        and not high_contrast
        and amb == "indoor"
    )

    for key, okl in base.items():
        if use_lock and key in HEX_LOCKS[phase]:
            roles[key] = HEX_LOCKS[phase][key]
            continue
        adj = _adjust_oklch(
            okl["L"],
            okl["C"],
            okl["H"],
            role=key,
            ambient=amb,
            intensity=intensity,
            high_contrast=high_contrast,
            dark=dark,
        )
        roles[key] = oklch_to_hex(adj["L"], adj["C"], adj["H"])

    # Guarantee WCAG AA body contrast; nudge ink if soft outdoor edge cases
    cr = contrast_ratio(roles["foreground"], roles["background"])
    if cr < 4.5:
        fg_L, fg_C, fg_H = hex_to_oklch(roles["foreground"])
        step = 0.02 if dark else -0.02
        for _ in range(12):
            fg_L = min(0.98, max(0.12, fg_L + step))
            roles["foreground"] = oklch_to_hex(fg_L, fg_C, fg_H)
            if contrast_ratio(roles["foreground"], roles["background"]) >= 4.5:
                break

    # Warm-dark invariant: background R channel must exceed B
    if dark:
        bg = roles["background"]
        h = bg.lstrip("#")
        r, g, b = int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)
        if r <= b:
            L, C, H = hex_to_oklch(bg)
            # Pull hue toward warm umber (≈67°) and ensure R>B
            roles["background"] = oklch_to_hex(L, max(C, 0.008), 67.0)
            hh = roles["background"].lstrip("#")
            rr, bb = int(hh[0:2], 16), int(hh[4:6], 16)
            if rr <= bb:
                # Last resort: bump red channel
                roles["background"] = f"#{min(255, b + 8):02X}{g:02X}{b:02X}"

    return roles


def validate_roles(roles: Dict[str, str], *, dark: bool) -> list[str]:
    fails: list[str] = []
    bg, fg = roles["background"], roles["foreground"]
    if bg.upper() in ("#000000", "#FFFFFF") or fg.upper() in ("#000000", "#FFFFFF"):
        fails.append("pure black/white not allowed for bg/fg")
    cr = contrast_ratio(fg, bg)
    if cr < 4.5:
        fails.append(f"fg/bg contrast {cr:.2f} < 4.5")
    # Warm dark: R > B
    if dark:
        h = bg.lstrip("#")
        r, b = int(h[0:2], 16), int(h[4:6], 16)
        if r <= b:
            fails.append("dark bg not warm (R should exceed B)")
    return fails


def css_custom_properties(roles: Dict[str, str], phase: Phase) -> str:
    """OKLCH CSS custom properties for design-system / docs consumers."""
    lines = [f"  /* eye-comfort phase: {phase} */"]
    for key, hexv in roles.items():
        L, C, H = hex_to_oklch(hexv)
        css_name = key.replace("_", "-")
        lines.append(f"  --ec-{css_name}: oklch({L:.3f} {C:.3f} {H:.1f});")
        lines.append(f"  --ec-{css_name}-hex: {hexv};")
    return ":root {\n" + "\n".join(lines) + "\n}\n"
