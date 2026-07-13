#!/usr/bin/env python3
"""Tests for eye-comfort schedule + palette gates (drives real schedule.py)."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from schedule import (
    DARK_ROLES,
    DARK_THEME,
    LIGHT_ROLES,
    LIGHT_THEME,
    contrast_ratio,
    is_warm_dark_bg,
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


def test_contrast_and_warm():
    assert contrast_ratio(DARK_ROLES["foreground"], DARK_ROLES["background"]) >= 4.5
    assert contrast_ratio(LIGHT_ROLES["foreground"], LIGHT_ROLES["background"]) >= 4.5
    assert is_warm_dark_bg(DARK_ROLES["background"])
    assert not is_warm_dark_bg("#060B1E")  # ethereal cool reference
    assert validate_palette(DARK_ROLES, dark=True) == []
    assert validate_palette(LIGHT_ROLES, dark=False) == []
    assert DARK_ROLES["background"].upper() not in ("#000000", "#FFFFFF")
    assert LIGHT_ROLES["background"].upper() not in ("#000000", "#FFFFFF")


if __name__ == "__main__":
    test_hour_day_night()
    test_mode()
    test_contrast_and_warm()
    print("test_schedule.py: OK")
