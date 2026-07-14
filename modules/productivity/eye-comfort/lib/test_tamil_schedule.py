#!/usr/bin/env python3
"""Tests for Tamil Nadu schedule + tinai palette gates."""
from __future__ import annotations

import json
import sys
from datetime import date, datetime
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from oklch import contrast_ratio as cr_ok
from palette import is_dark_phase, validate_roles
from tamil_palette import roles_for_tamil
from tamil_schedule import (
    SIRU,
    SIRU_TO_PHASE,
    TINAI,
    TINAI_THEME,
    jaamam_detail_for,
    jaamam_index_at,
    jaamam_split_for_siru,
    infer_tinai,
    nazhigai_in_siru,
    nazhigai_of_day,
    parse_siru,
    parse_tinai,
    perum_for_date,
    resolve_tamil,
    siru_for_hour,
    wallpaper_fallback_names,
)
from waybar_status import tn_waybar_payload, waybar_payload


def test_perum_windows():
    assert perum_for_date(date(2026, 5, 1)) == "ila_venil"
    assert perum_for_date(date(2026, 7, 1)) == "mudhu_venil"
    assert perum_for_date(date(2026, 9, 1)) == "kar"
    assert perum_for_date(date(2026, 11, 1)) == "kulir"
    assert perum_for_date(date(2026, 1, 10)) == "munpani"
    assert perum_for_date(date(2026, 3, 1)) == "pinpani"
    # Boundaries
    assert perum_for_date(date(2026, 4, 15)) == "ila_venil"
    assert perum_for_date(date(2026, 4, 14)) == "pinpani"
    assert perum_for_date(date(2026, 12, 15)) == "munpani"


def test_siru_windows():
    assert siru_for_hour(3) == "vidiyal"
    assert siru_for_hour(7) == "kaalai"
    assert siru_for_hour(12) == "nanpagal"
    assert siru_for_hour(15) == "erpaadu"
    assert siru_for_hour(19) == "maalai"
    assert siru_for_hour(23) == "yaamam"
    assert siru_for_hour(1) == "yaamam"
    assert siru_for_hour(2, 0) == "vidiyal"
    assert siru_for_hour(5, 59) == "vidiyal"
    assert siru_for_hour(6, 0) == "kaalai"


def test_nazhigai_steps():
    # Nan pagal 10:00 → step 0; 10:24 → 1; 13:36 → 9
    assert nazhigai_in_siru(10, 0) == 0
    assert nazhigai_in_siru(10, 24) == 1
    assert nazhigai_in_siru(13, 36) == 9
    # Yaamam wrap: 22:00 → 0; 01:00 → ~7–8
    assert nazhigai_in_siru(22, 0) == 0
    assert nazhigai_in_siru(22, 48) == 2
    n = nazhigai_in_siru(1, 0)
    assert 0 <= n <= 9
    assert nazhigai_of_day(0, 0) == 0
    assert nazhigai_of_day(0, 24) == 1
    assert nazhigai_of_day(23, 59) == 59


def test_jaamam_splits():
    """Siru (4 h) vs jaamam (3 h) from vidiyal epoch → 7.5+2.5 / 5+5 / 2.5+7.5."""
    expected = {
        "vidiyal": [(1, 7.5, True), (2, 2.5, False)],
        "kaalai": [(2, 5.0, False), (3, 5.0, False)],
        "nanpagal": [(3, 2.5, False), (4, 7.5, True)],
        "erpaadu": [(5, 7.5, True), (6, 2.5, False)],
        "maalai": [(6, 5.0, False), (7, 5.0, False)],
        "yaamam": [(7, 2.5, False), (8, 7.5, True)],
    }
    for siru in SIRU:
        parts = jaamam_split_for_siru(siru)
        got = [(p.index, p.nazhigai, p.full) for p in parts]
        assert got == expected[siru], f"{siru}: {got}"
        assert abs(sum(p.nazhigai for p in parts) - 10.0) < 1e-9

    assert jaamam_index_at(2, 0) == 1
    assert jaamam_index_at(5, 0) == 2
    assert jaamam_index_at(12, 0) == 4
    assert jaamam_index_at(1, 59) == 8

    d = jaamam_detail_for("vidiyal", 0)
    assert d.current == 1
    assert d.label == "jaamam 1 (full) + jaamam 2 (2.5 nazhigai)"
    d2 = jaamam_detail_for("nanpagal", 5)
    assert d2.current == 4
    assert "jaamam 3 (2.5 nazhigai) + jaamam 4 (full)" == d2.label


def test_infer_tinai_geo():
    t, src = infer_tinai(13.0, 80.2)  # Chennai coast
    assert t == "neythal"
    assert src == "geo"
    t2, _ = infer_tinai(11.4, 76.7)  # Nilgiris-ish
    assert t2 == "kurinji"
    t3, src3 = infer_tinai(None, None)
    assert t3 == "marutham" and src3 == "default"
    t4, _ = infer_tinai(10.0, 78.1, perum="mudhu_venil")
    assert t4 == "palai"


def test_wallpaper_fallback_chain():
    names = wallpaper_fallback_names("marutham-erpaadu-b.jpg")
    assert names[0] == "marutham-erpaadu-b.jpg"
    assert "marutham-erpaadu-a.jpg" in names
    assert "marutham-vidiyal-a.jpg" in names  # characteristic dawn signature
    assert "marutham-default.jpg" in names


def test_resolve_flags():
    s = resolve_tamil(tinai="neythal", hour=15, minute=0)
    assert s.tinai == "neythal"
    assert s.siru == "erpaadu"
    assert s.theme == "eye-comfort-tn-neythal"
    assert s.phase == "afternoon"
    assert 0 <= s.nazhigai <= 9
    assert "neythal-erpaadu" in s.wallpaper_hint
    assert s.jaamam.current == 5
    assert "jaamam 5 (full) + jaamam 6 (2.5 nazhigai)" in s.scene

    s2 = resolve_tamil(hour=23, minute=0, latitude=11.0, longitude=76.5)
    assert s2.siru == "yaamam"
    assert s2.tinai == "kurinji"
    assert s2.theme == TINAI_THEME["kurinji"]
    assert "jaamam 7 (2.5 nazhigai) + jaamam 8 (full)" in s2.scene

    s3 = resolve_tamil(siru="maalai", nazhigai=3, tinai="mullai")
    assert s3.siru == "maalai" and s3.nazhigai == 3
    assert "nazhigai 3 (≈3×24 min ≈ 72 min elapsed)" in s3.scene
    assert "jaamam 6 (5 nazhigai) + jaamam 7 (5 nazhigai)" in s3.scene

    s5 = resolve_tamil(siru="nanpagal", nazhigai=5, tinai="marutham")
    assert "nazhigai 5 (≈5×24 min ≈ 120 min elapsed)" in s5.scene
    assert "jaamam 3 (2.5 nazhigai) + jaamam 4 (full)" in s5.scene


def test_waybar_payload():
    p = tn_waybar_payload(
        state={"tinai": "neythal", "calendar": "tamil_nadu"},
        now=datetime(2026, 7, 14, 15, 0),
    )
    # erpaadu 14:00 → 15:00 = 60 min → nazhigai 2
    assert p["text"] == "neythal · erpaadu · n2"
    tip = p["tooltip"]
    assert "jaamam 5 (full)" in tip
    assert "Nazhigai <b>2</b>" in tip or "nazhigai 2" in tip.lower()
    assert "week 29" in tip  # ISO week; date line separate from tinai
    assert "2026neythal" not in tip.replace(" ", "")
    assert "14 July" in tip
    assert "<b>" in tip  # Pango hierarchy
    assert "Seashore" in tip
    assert "Tinai" in tip and "Pozhuthu" in tip
    assert "Jaamam" in tip and "Nazhigai" in tip
    assert "Perum" in tip and "Siru" in tip  # grouped under Pozhuthu
    assert tip.index("Pozhuthu") < tip.index("Jaamam") < tip.index("Nazhigai")
    # JSON-serializable for waybar
    json.dumps(p)
    p2 = waybar_payload(
        state_path=Path("/nonexistent/state.json"),
        now=datetime(2026, 7, 14, 10, 0),
    )
    assert " · " in p2["text"]
    assert p2["alt"] in ("tn", "error")


def test_parse_aliases():
    assert parse_tinai("neytal") == "neythal"
    assert parse_siru("yamam") == "yaamam"
    assert parse_siru("dawn") == "vidiyal"


def test_all_tinai_siru_contrast():
    for tinai in TINAI:
        for siru, phase in SIRU_TO_PHASE.items():
            for naz in (0, 4, 9):
                roles = roles_for_tamil(
                    tinai, siru, nazhigai=naz, ambient="indoor", intensity="balanced"
                )
                dark = is_dark_phase(phase)  # type: ignore[arg-type]
                fails = validate_roles(roles, dark=dark)
                assert fails == [], f"{tinai} {siru} n{naz}: {fails}"
                assert cr_ok(roles["foreground"], roles["background"]) >= 4.5


def test_bad_inputs():
    try:
        resolve_tamil(nazhigai=12)
        assert False
    except ValueError:
        pass
    try:
        resolve_tamil(tinai="atlantis")
        assert False
    except ValueError:
        pass
    try:
        siru_for_hour(25)
        assert False
    except ValueError:
        pass


if __name__ == "__main__":
    test_perum_windows()
    test_siru_windows()
    test_nazhigai_steps()
    test_jaamam_splits()
    test_infer_tinai_geo()
    test_wallpaper_fallback_chain()
    test_resolve_flags()
    test_waybar_payload()
    test_parse_aliases()
    test_all_tinai_siru_contrast()
    test_bad_inputs()
    print("test_tamil_schedule.py: OK")
