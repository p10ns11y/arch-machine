"""Circadian schedule + resolve API for eye-comfort themes (testable, no display)."""
from __future__ import annotations

import math
from dataclasses import asdict, dataclass
from datetime import date, datetime, time
from typing import Any, Dict, Optional, Sequence

from palette import (
    PHASE_CCT_K,
    PHASE_THEME,
    PHASE_WALLPAPER_HINT,
    Ambient,
    Intensity,
    Phase,
    is_dark_phase,
    roles_for_phase,
    validate_roles,
)

# Back-compat aliases (tests + older call sites)
DARK_THEME = "eye-comfort-dark"
LIGHT_THEME = "eye-comfort-light"
LIGHT_START_HOUR = 7
DARK_START_HOUR = 18

PHASES: Sequence[Phase] = (
    "dawn",
    "morning",
    "midday",
    "afternoon",
    "dusk",
    "evening",
    "night",
)

# Fixed local-hour windows when latitude is unset (Northern-hemisphere desk default)
# [start_hour, end_hour) — night wraps midnight
_FIXED_WINDOWS: Dict[Phase, tuple[int, int]] = {
    "dawn": (5, 7),
    "morning": (7, 10),
    "midday": (10, 14),
    "afternoon": (14, 17),
    "dusk": (17, 19),
    "evening": (19, 22),
    "night": (22, 5),  # wraps
}


@dataclass(frozen=True)
class CircadianState:
    phase: Phase
    theme: str
    hour: int
    minute: int
    ambient: Ambient
    intensity: Intensity
    high_contrast: bool
    reduced_motion: bool
    no_dynamic: bool
    latitude: Optional[float]
    cct_k: int
    wallpaper_hint: str
    roles: Dict[str, str]
    contrast_fg_bg: float
    source: str  # "solar" | "fixed" | "forced"


def theme_for_hour(hour: int) -> str:
    """Legacy binary map: light [7,18), else dark."""
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
    if m in ("dawn",):
        return "eye-comfort-dawn"
    if m in ("dusk",):
        return "eye-comfort-dusk"
    raise ValueError(f"unknown mode {mode!r}; use day|night|dawn|dusk|auto|<phase>")


def phase_for_hour(hour: int, minute: int = 0) -> Phase:
    """Fixed-window phase for local clock (no solar)."""
    if not isinstance(hour, int) or hour < 0 or hour > 23:
        raise ValueError(f"hour must be int 0–23, got {hour!r}")
    if not isinstance(minute, int) or minute < 0 or minute > 59:
        raise ValueError(f"minute must be int 0–59, got {minute!r}")
    t = hour + minute / 60.0
    for phase, (start, end) in _FIXED_WINDOWS.items():
        if start < end:
            if start <= t < end:
                return phase
        else:  # wraps (night)
            if t >= start or t < end:
                return phase
    return "night"


def _day_of_year(d: date) -> int:
    return d.timetuple().tm_yday


def approx_sunrise_sunset(
    latitude: float,
    on: date,
) -> tuple[time, time]:
    """Approximate local solar sunrise/sunset (no tz; fractional day hours).

    NOAA-style day-length approximation. Good enough for circadian theme
    boundaries; not for navigation.
    """
    if latitude < -66.0 or latitude > 66.0:
        # Polar: fall back to mid-latitude day length shape
        latitude = max(-66.0, min(66.0, latitude))
    n = _day_of_year(on)
    # Solar declination (radians)
    decl = 23.44 * math.pi / 180.0 * math.sin(2 * math.pi * (284 + n) / 365.0)
    lat_r = latitude * math.pi / 180.0
    # Hour angle
    cos_ha = -math.tan(lat_r) * math.tan(decl)
    cos_ha = max(-1.0, min(1.0, cos_ha))
    ha = math.acos(cos_ha)  # radians from noon
    hours_from_noon = ha * 12.0 / math.pi
    sunrise_h = 12.0 - hours_from_noon
    sunset_h = 12.0 + hours_from_noon

    def to_time(h: float) -> time:
        h = h % 24.0
        hh = int(h)
        mm = int(round((h - hh) * 60)) % 60
        if mm == 60:
            hh = (hh + 1) % 24
            mm = 0
        return time(hh, mm)

    return to_time(sunrise_h), to_time(sunset_h)


def _hm(t: time) -> float:
    return t.hour + t.minute / 60.0


def phase_for_solar(
    hour: int,
    minute: int,
    latitude: float,
    on: Optional[date] = None,
) -> Phase:
    """Map clock to phase using approximate sunrise/sunset at latitude."""
    on = on or date.today()
    sunrise, sunset = approx_sunrise_sunset(latitude, on)
    sr, ss = _hm(sunrise), _hm(sunset)
    day_len = max(0.5, ss - sr)
    t = hour + minute / 60.0

    dawn_start = (sr - 0.75) % 24
    morning_end = sr + day_len * 0.22
    midday_end = sr + day_len * 0.55
    afternoon_end = ss - 0.75
    dusk_end = (ss + 0.6) % 24
    evening_end = (ss + 3.0) % 24

    def in_span(start: float, end: float) -> bool:
        if start <= end:
            return start <= t < end
        return t >= start or t < end

    if in_span(dawn_start, sr):
        return "dawn"
    if in_span(sr, morning_end):
        return "morning"
    if in_span(morning_end, midday_end):
        return "midday"
    if in_span(midday_end, afternoon_end):
        return "afternoon"
    if in_span(afternoon_end, dusk_end):
        return "dusk"
    if in_span(dusk_end, evening_end):
        return "evening"
    return "night"


def parse_phase(name: str) -> Phase:
    n = name.strip().lower()
    aliases = {
        "day": "midday",
        "light": "midday",
        "dark": "night",
    }
    n = aliases.get(n, n)
    if n not in PHASES:
        raise ValueError(
            f"unknown phase {name!r}; use one of: {', '.join(PHASES)} "
            f"(aliases: day|light→midday, dark→night)"
        )
    return n  # type: ignore[return-value]


def collapse_dynamic(phase: Phase) -> Phase:
    """--no-dynamic: only light vs dark packages."""
    return "night" if is_dark_phase(phase) else "midday"


def infer_ambient(ambient: Ambient, phase: Phase) -> Ambient:
    if ambient != "auto":
        return ambient
    # Heuristic: midday/afternoon lean outdoor glare; night/evening indoor lamp
    if phase in ("midday", "afternoon"):
        return "outdoor"
    return "indoor"


def resolve(
    *,
    mode: str = "auto",
    hour: Optional[int] = None,
    minute: int = 0,
    latitude: Optional[float] = None,
    ambient: Ambient = "auto",
    intensity: Intensity = "balanced",
    high_contrast: bool = False,
    reduced_motion: bool = False,
    no_dynamic: bool = False,
    now: Optional[datetime] = None,
) -> CircadianState:
    """Resolve full circadian state from flags/params."""
    now = now or datetime.now()
    if hour is None:
        hour = now.hour
        minute = now.minute
    if not (0 <= hour <= 23):
        raise ValueError(f"hour must be 0–23, got {hour}")
    if not (0 <= minute <= 59):
        raise ValueError(f"minute must be 0–59, got {minute}")
    if latitude is not None and not (-90.0 <= latitude <= 90.0):
        raise ValueError(f"latitude must be -90..90, got {latitude}")
    if intensity not in ("soft", "balanced", "crisp"):
        raise ValueError(f"intensity must be soft|balanced|crisp, got {intensity!r}")
    if ambient not in ("auto", "indoor", "outdoor"):
        raise ValueError(f"ambient must be auto|indoor|outdoor, got {ambient!r}")

    m = mode.strip().lower()
    source = "fixed"
    if m in ("auto", ""):
        if latitude is not None:
            phase = phase_for_solar(hour, minute, latitude, on=now.date())
            source = "solar"
        else:
            phase = phase_for_hour(hour, minute)
            source = "fixed"
    else:
        phase = parse_phase(m)
        source = "forced"

    if no_dynamic:
        phase = collapse_dynamic(phase)

    amb = infer_ambient(ambient, phase)
    roles = roles_for_phase(
        phase,
        ambient=amb,
        intensity=intensity,
        high_contrast=high_contrast,
    )
    fails = validate_roles(roles, dark=is_dark_phase(phase))
    if fails:
        # Soften to balanced indoor if validation fails after extreme flags
        roles = roles_for_phase(phase, ambient="indoor", intensity="balanced", high_contrast=False)
        fails = validate_roles(roles, dark=is_dark_phase(phase))
        if fails:
            raise RuntimeError(f"palette validation failed for {phase}: {fails}")

    from oklch import contrast_ratio as cr

    return CircadianState(
        phase=phase,
        theme=PHASE_THEME[phase],
        hour=hour,
        minute=minute,
        ambient=amb,
        intensity=intensity,
        high_contrast=high_contrast,
        reduced_motion=reduced_motion,
        no_dynamic=no_dynamic,
        latitude=latitude,
        cct_k=PHASE_CCT_K[phase],
        wallpaper_hint=PHASE_WALLPAPER_HINT[phase],
        roles=roles,
        contrast_fg_bg=round(cr(roles["foreground"], roles["background"]), 2),
        source=source,
    )


def state_to_dict(state: CircadianState) -> Dict[str, Any]:
    d = asdict(state)
    return d


# --- legacy palette exports (tests) ---
from palette import HEX_LOCKS  # noqa: E402

DARK_ROLES = {
    "background": HEX_LOCKS["night"]["background"],
    "foreground": HEX_LOCKS["night"]["foreground"],
    "selection": HEX_LOCKS["night"]["selection"],
    "comment": HEX_LOCKS["night"]["comment"],
    "accent_sage": HEX_LOCKS["night"]["accent_sage"],
    "accent_amber": HEX_LOCKS["night"]["accent_amber"],
    "accent_clay": HEX_LOCKS["night"]["accent_clay"],
    "error": HEX_LOCKS["night"]["error"],
    "warning": HEX_LOCKS["night"]["warning"],
}
LIGHT_ROLES = {
    "background": HEX_LOCKS["midday"]["background"],
    "foreground": HEX_LOCKS["midday"]["foreground"],
    "selection": HEX_LOCKS["midday"]["selection"],
    "comment": HEX_LOCKS["midday"]["comment"],
    "accent_sage": HEX_LOCKS["midday"]["accent_sage"],
    "accent_amber": HEX_LOCKS["midday"]["accent_amber"],
    "accent_clay": HEX_LOCKS["midday"]["accent_clay"],
    "error": HEX_LOCKS["midday"]["error"],
    "warning": HEX_LOCKS["midday"]["warning"],
}


def srgb_to_linear(c: float) -> float:
    c = c / 255.0
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def relative_luminance(hex_color: str) -> float:
    from oklch import relative_luminance_hex

    return relative_luminance_hex(hex_color)


def contrast_ratio(fg: str, bg: str) -> float:
    from oklch import contrast_ratio as cr

    return cr(fg, bg)


def is_warm_dark_bg(hex_color: str) -> bool:
    h = hex_color.lstrip("#")
    r, b = int(h[0:2], 16), int(h[4:6], 16)
    return r > b


def validate_palette(roles: dict[str, str], *, dark: bool) -> list[str]:
    return validate_roles(roles, dark=dark)
