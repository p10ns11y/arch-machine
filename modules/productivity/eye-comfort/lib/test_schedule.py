#!/usr/bin/env python3
"""Tests for eye-comfort circadian schedule + palette gates."""
from __future__ import annotations

import sys
from datetime import date
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from oklch import contrast_ratio as cr_ok
from palette import PHASE_THEME, is_dark_phase, roles_for_phase, validate_roles
from schedule import (
    DARK_ROLES,
    DARK_THEME,
    LIGHT_ROLES,
    LIGHT_THEME,
    PHASES,
    approx_sunrise_sunset,
    collapse_dynamic,
    contrast_ratio,
    is_warm_dark_bg,
    parse_phase,
    phase_for_hour,
    phase_for_solar,
    resolve,
    theme_for_hour,
    theme_for_mode,
    validate_palette,
)


def test_hour_day_night():
    assert theme_for_hour(7) == LIGHT_THEME
    assert theme_for_hour(12) == LIGHT_THEME
    assert theme_for_hour(17) == LIGHT_THEME
    assert theme_for_hour(18) == DARK_THEME
    assert theme_for_hour(22) == DARK_THEME
    assert theme_for_hour(0) == DARK_THEME
    assert theme_for_hour(6) == DARK_THEME


def test_mode():
    assert theme_for_mode("day") == LIGHT_THEME
    assert theme_for_mode("night") == DARK_THEME
    assert theme_for_mode("dawn") == "eye-comfort-dawn"
    assert theme_for_mode("dusk") == "eye-comfort-dusk"


def test_phases_fixed():
    assert phase_for_hour(6) == "dawn"
    assert phase_for_hour(8) == "morning"
    assert phase_for_hour(12) == "midday"
    assert phase_for_hour(15) == "afternoon"
    assert phase_for_hour(18) == "dusk"
    assert phase_for_hour(20) == "evening"
    assert phase_for_hour(23) == "night"
    assert phase_for_hour(3) == "night"


def test_solar_rough():
    # Tropics / mid-lat: sunrise before noon, sunset after
    sr, ss = approx_sunrise_sunset(28.6, date(2026, 6, 21))
    assert sr.hour < 8
    assert ss.hour > 17
    # Midday near noon → midday/afternoon
    p = phase_for_solar(12, 0, 28.6, on=date(2026, 6, 21))
    assert p in ("morning", "midday", "afternoon")


def test_resolve_flags():
    s = resolve(mode="auto", hour=6, minute=0, ambient="indoor", intensity="soft")
    assert s.phase == "dawn"
    assert s.theme == "eye-comfort-dawn"
    assert s.contrast_fg_bg >= 4.5

    s2 = resolve(mode="dusk", ambient="outdoor", intensity="crisp", high_contrast=True)
    assert s2.phase == "dusk"
    assert s2.theme == "eye-comfort-dusk"

    s3 = resolve(mode="auto", hour=12, no_dynamic=True)
    assert s3.phase == "midday"
    assert s3.theme == LIGHT_THEME

    s4 = resolve(mode="auto", hour=22, no_dynamic=True)
    assert s4.phase == "night"
    assert collapse_dynamic("dusk") == "night"


def test_all_phases_contrast():
    for phase in ("dawn", "morning", "midday", "afternoon", "dusk", "evening", "night"):
        for amb in ("indoor", "outdoor"):
            for inten in ("soft", "balanced", "crisp"):
                roles = roles_for_phase(phase, ambient=amb, intensity=inten)  # type: ignore[arg-type]
                fails = validate_roles(roles, dark=is_dark_phase(phase))  # type: ignore[arg-type]
                assert fails == [], f"{phase} {amb} {inten}: {fails}"
                assert cr_ok(roles["foreground"], roles["background"]) >= 4.5


def test_contrast_and_warm():
    assert contrast_ratio(DARK_ROLES["foreground"], DARK_ROLES["background"]) >= 4.5
    assert contrast_ratio(LIGHT_ROLES["foreground"], LIGHT_ROLES["background"]) >= 4.5
    assert is_warm_dark_bg(DARK_ROLES["background"])
    assert not is_warm_dark_bg("#060B1E")
    assert validate_palette(DARK_ROLES, dark=True) == []
    assert validate_palette(LIGHT_ROLES, dark=False) == []


def test_parse_and_theme_map():
    assert parse_phase("day") == "midday"
    assert parse_phase("DARK") == "night"
    assert PHASE_THEME["evening"] == DARK_THEME


def test_bad_inputs():
    try:
        theme_for_hour(25)
        assert False
    except ValueError:
        pass
    try:
        resolve(mode="auto", hour=12, latitude=999)
        assert False
    except ValueError:
        pass
    try:
        resolve(mode="auto", intensity="loud")  # type: ignore[arg-type]
        assert False
    except ValueError:
        pass


if __name__ == "__main__":
    test_hour_day_night()
    test_mode()
    test_phases_fixed()
    test_solar_rough()
    test_resolve_flags()
    test_all_phases_contrast()
    test_contrast_and_warm()
    test_parse_and_theme_map()
    test_bad_inputs()
    print("test_schedule.py: OK")
