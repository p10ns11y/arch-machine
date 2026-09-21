#!/usr/bin/env python3
"""Tests for Sweden schedule + palette gates (SN-EC-SE)."""
from __future__ import annotations

import json
import sys
from datetime import date, datetime
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from calendar_registry import apply_calendar, calendar_from_state, mode_to_calendar
from oklch import contrast_ratio as cr_ok
from palette import is_dark_phase, validate_roles
from sweden_palette import roles_for_sweden
from sweden_schedule import (
    ARSTID,
    DEFAULT_LATITUDE,
    REALM,
    REALM_THEME,
    SOLAR_HINT,
    arstid_for_date,
    parse_realm,
    resolve_sweden,
)
from waybar_status import se_waybar_payload, waybar_payload


def test_arstid_windows():
    assert arstid_for_date(date(2026, 1, 15)) == "vinter"
    assert arstid_for_date(date(2026, 4, 1)) == "var"
    assert arstid_for_date(date(2026, 7, 1)) == "sommar"
    assert arstid_for_date(date(2026, 10, 1)) == "host"


def test_resolve_sweden_defaults():
    s = resolve_sweden(hour=14, minute=0, now=datetime(2026, 7, 14, 14, 0))
    assert s.arstid == "sommar"
    assert s.realm == "asgard"
    assert s.latitude == DEFAULT_LATITUDE
    assert s.theme == REALM_THEME["asgard"]
    assert s.solar_hint in SOLAR_HINT.values()


def test_se_json_cli_shape():
    r = apply_calendar("sweden", hour=14, minute=0, latitude=59.3)
    assert r.calendar == "sweden"
    assert r.payload["calendar"] == "sweden"
    assert r.contrast_fg_bg >= 4.5
    json.dumps(r.payload)


def test_midsummer_lat_honesty():
    """June 21 ~59.3°N — short night; phase may stay dusk/evening not deep night."""
    s = resolve_sweden(
        hour=23,
        minute=30,
        latitude=59.3,
        now=datetime(2026, 6, 21, 23, 30),
    )
    assert s.phase in ("dusk", "evening", "night")


def test_winter_lat_honesty():
    s = resolve_sweden(
        hour=12,
        minute=0,
        latitude=59.3,
        now=datetime(2026, 12, 21, 12, 0),
    )
    assert s.arstid == "vinter"
    assert s.realm in ("nifl", "midgard")


def test_all_realm_phase_contrast():
    for realm in REALM:
        for phase in (
            "dawn",
            "morning",
            "midday",
            "afternoon",
            "dusk",
            "evening",
            "night",
        ):
            for mik in (0, 2, 5):
                roles = roles_for_sweden(
                    realm,
                    phase,  # type: ignore[arg-type]
                    mikrosteg=mik,
                    ambient="indoor",
                    intensity="balanced",
                )
                dark = is_dark_phase(phase)  # type: ignore[arg-type]
                fails = validate_roles(roles, dark=dark)
                assert fails == [], f"{realm} {phase} m{mik}: {fails}"
                assert cr_ok(roles["foreground"], roles["background"]) >= 4.5


def test_waybar_se_payload():
    p = se_waybar_payload(
        state={"calendar": "sweden", "latitude": 59.3},
        now=datetime(2026, 7, 14, 14, 0),
        plain_tooltip=True,
    )
    assert "Sommar" in p["text"]
    assert "Eftermiddag" in p["text"] or "Middag" in p["text"]
    assert p["alt"] == "se"
    assert "Solar" in p["tooltip"]
    assert "work" in p["tooltip"] or "outdoor" in p["tooltip"]
    # No weather / coaching copy
    assert "weather" not in p["tooltip"].lower()
    assert "career" not in p["tooltip"].lower()


def test_calendar_registry_mode():
    assert mode_to_calendar("se") == "sweden"
    assert mode_to_calendar("tn") == "tamil_nadu"
    assert calendar_from_state(Path("/nonexistent")) == "circadian"


def test_parse_realm():
    assert parse_realm("niflheim") == "nifl"
    assert parse_realm("vanir") == "vanaheim"


def test_america_stub_disabled():
    try:
        apply_calendar("america_1776")
        assert False, "expected ValueError"
    except ValueError as e:
        assert "later" in str(e).lower()


if __name__ == "__main__":
    test_arstid_windows()
    test_resolve_sweden_defaults()
    test_se_json_cli_shape()
    test_midsummer_lat_honesty()
    test_winter_lat_honesty()
    test_all_realm_phase_contrast()
    test_waybar_se_payload()
    test_calendar_registry_mode()
    test_parse_realm()
    test_america_stub_disabled()
    print("test_sweden_schedule.py: OK")
