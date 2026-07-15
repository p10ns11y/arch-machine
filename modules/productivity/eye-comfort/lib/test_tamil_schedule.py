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
    nazhigai_ordinal,
    nazhigai_running_copy,
    parse_siru,
    parse_tinai,
    perum_for_date,
    resolve_tamil,
    siru_for_hour,
    wallpaper_fallback_names,
)
from waybar_status import (
    _PANGO_DARK,
    _PANGO_LIGHT,
    activate_pango_surface,
    surface_is_light,
    tn_waybar_payload,
    waybar_payload,
)


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
    # UI ordinals are 1-based; index 1 ≈ 24 min → Running Nāḻikai 2
    assert nazhigai_ordinal(0) == 1
    assert nazhigai_ordinal(1) == 2
    assert nazhigai_ordinal(9) == 10
    assert "Running Nāḻikai 1 (first 24 minutes of this Ciṟu)" in nazhigai_running_copy(0)
    assert (
        nazhigai_running_copy(1)
        == "Running Nāḻikai 2 (after 24 minutes, first nāḻikai over)"
    )
    assert (
        nazhigai_running_copy(2)
        == "Running Nāḻikai 3 (after 48 minutes, first 2 nāḻikai over)"
    )


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
    assert d.label == "jāmam 1 (full) + jāmam 2 (2.5 nāḻikai)"
    d2 = jaamam_detail_for("nanpagal", 5)
    assert d2.current == 4
    assert "jāmam 3 (2.5 nāḻikai) + jāmam 4 (full)" == d2.label


def test_iso_display_helpers():
    from tamil_schedule import (
        TINAI_ISO,
        SIRU_ISO,
        PERUM_ISO,
        tinai_display,
        siru_display,
        perum_display,
    )

    assert TINAI_ISO["kurinji"] == "kuṟiñci"
    assert TINAI_ISO["marutham"] == "marutam"
    assert TINAI_ISO["neythal"] == "neytal"
    assert TINAI_ISO["palai"] == "pālai"
    assert SIRU_ISO["yaamam"] == "yāmam"
    assert SIRU_ISO["erpaadu"] == "eṟpāṭu"
    assert SIRU_ISO["nanpagal"] == "naṇpakal"
    assert PERUM_ISO["ila_venil"] == "iḷavēṉil"
    assert PERUM_ISO["munpani"] == "muṉpaṉi"
    assert tinai_display("marutham") == "Marutam"
    assert siru_display("yaamam") == "Yāmam"
    assert perum_display("kar") == "Kār"


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
    assert "jāmam 5 (full) + jāmam 6 (2.5 nāḻikai)" in s.scene

    s2 = resolve_tamil(hour=23, minute=0, latitude=11.0, longitude=76.5)
    assert s2.siru == "yaamam"
    assert s2.tinai == "kurinji"
    assert s2.theme == TINAI_THEME["kurinji"]
    assert "jāmam 7 (2.5 nāḻikai) + jāmam 8 (full)" in s2.scene

    s3 = resolve_tamil(siru="maalai", nazhigai=3, tinai="mullai")
    assert s3.siru == "maalai" and s3.nazhigai == 3
    assert "Running Nāḻikai 4 (after 72 minutes, first 3 nāḻikai over)" in s3.scene
    assert "jāmam 6 (5 nāḻikai) + jāmam 7 (5 nāḻikai)" in s3.scene

    s5 = resolve_tamil(siru="nanpagal", nazhigai=5, tinai="marutham")
    assert "Running Nāḻikai 6 (after 120 minutes, first 5 nāḻikai over)" in s5.scene
    assert "jāmam 3 (2.5 nāḻikai) + jāmam 4 (full)" in s5.scene


def test_waybar_payload():
    p = tn_waybar_payload(
        state={"tinai": "neythal", "calendar": "tamil_nadu"},
        now=datetime(2026, 7, 14, 15, 0),
    )
    # erpaadu 14:00 → 15:00 = 60 min → index 2 → ordinal 3
    assert p["text"] == "Neytal · Eṟpāṭu · N3"
    tip = p["tooltip"]
    assert "jāmam 5 (full)" in tip
    assert "Running Nāḻikai <b>3</b>" in tip
    assert "first 2 nāḻikai over" in tip
    assert "week 29" in tip  # ISO week; date line separate from tinai
    assert "2026neythal" not in tip.replace(" ", "")
    assert "14 July" in tip
    # Date line optically centered vs longest body line (leading spaces before Pango)
    date_ln = next(ln for ln in tip.splitlines() if "14 July" in ln)
    assert date_ln.startswith(" ")
    assert date_ln.lstrip().startswith("<span")
    assert "<b>" in tip or 'font_weight="700"' in tip  # Pango hierarchy
    assert "Seashore" in tip
    assert "Seashore  —  Neytal" in tip
    assert "(apply)" not in tip
    assert "water lily" not in tip  # no flower echo on Tiṇai line
    assert "Tiṇai" in tip and "Poḻutu" in tip
    assert "Jāmam" in tip and "Nāḻikai" in tip
    assert "Perum" in tip and "Ciṟu" in tip  # grouped under Poḻutu
    assert tip.index("Poḻutu") < tip.index("Jāmam") < tip.index("Nāḻikai")
    # JSON-serializable for waybar
    json.dumps(p)
    p2 = waybar_payload(
        state_path=Path("/nonexistent/state.json"),
        now=datetime(2026, 7, 14, 10, 0),
    )
    assert " · " in p2["text"]
    assert p2["alt"] in ("tn", "error")

    # Screenshot case: index 1 → bar N2, first nāḻikai over
    p3 = tn_waybar_payload(
        state={"tinai": "marutham", "calendar": "tamil_nadu"},
        now=datetime(2026, 7, 14, 22, 24),
    )
    assert p3["text"] == "Marutam · Yāmam · N2"
    assert "Running Nāḻikai <b>2</b>" in p3["tooltip"]
    assert "first nāḻikai over" in p3["tooltip"]
    assert "Nāḻikai <b>1</b>" not in p3["tooltip"]
    assert "Plains  —  Marutam" in p3["tooltip"]
    assert "marutham · Marutham" not in p3["tooltip"]
    assert "marutam · Marutam" not in p3["tooltip"]

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


def test_tooltip_pango_adapts_to_light_surface():
    """Cream paper must not use dark-only gold spans (~2:1 wash)."""
    light_state = {
        "tinai": "marutham",
        "calendar": "tamil_nadu",
        "roles": {"background": "#FCF0E2", "foreground": "#2C2622"},
    }
    dark_state = {
        "tinai": "marutham",
        "calendar": "tamil_nadu",
        "roles": {"background": "#322A23", "foreground": "#E8DED0"},
    }
    assert surface_is_light(light_state) is True
    assert surface_is_light(dark_state) is False
    assert activate_pango_surface(light_state)["accent"] == _PANGO_LIGHT["accent"]
    assert activate_pango_surface(dark_state)["accent"] == _PANGO_DARK["accent"]

    tip_l = tn_waybar_payload(
        state=light_state, now=datetime(2026, 7, 15, 17, 55)
    )["tooltip"]
    tip_d = tn_waybar_payload(
        state=dark_state, now=datetime(2026, 7, 15, 22, 0)
    )["tooltip"]
    assert _PANGO_LIGHT["accent"] in tip_l
    assert _PANGO_LIGHT["muted"] in tip_l
    assert _PANGO_DARK["accent"] not in tip_l
    assert _PANGO_DARK["accent"] in tip_d
    assert _PANGO_LIGHT["accent"] not in tip_d


if __name__ == "__main__":
    test_perum_windows()
    test_siru_windows()
    test_nazhigai_steps()
    test_jaamam_splits()
    test_iso_display_helpers()
    test_infer_tinai_geo()
    test_wallpaper_fallback_chain()
    test_resolve_flags()
    test_waybar_payload()
    test_parse_aliases()
    test_all_tinai_siru_contrast()
    test_bad_inputs()
    test_tooltip_pango_adapts_to_light_surface()
    print("test_tamil_schedule.py: OK")
