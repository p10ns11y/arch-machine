from pathlib import Path

from patch_waybar import ensure_center, ensure_css, ensure_object

STOCK = """{
  "modules-center": ["clock", "custom/weather"],
  "clock": {
    "format": "{:%H:%M}"
  }
}
"""

USER = """{
  "modules-center": ["custom/focus-now", "clock"],
  "custom/focus-now": {
    "exec": "focus-now chip"
  }
}
"""


def test_stock_omarchy_inserts_after_clock():
    out = ensure_object(ensure_center(STOCK))
    assert '"clock", "custom/mission-map"' in out
    assert '"custom/mission-map":' in out
    assert out.count("custom/mission-map") >= 2


def test_user_config_inserts_after_focus_now():
    out = ensure_object(ensure_center(USER))
    assert '"custom/focus-now", "custom/mission-map"' in out
    assert '"custom/mission-map":' in out


def test_idempotent():
    once = ensure_object(ensure_center(STOCK))
    twice = ensure_object(ensure_center(once))
    assert once == twice


def test_css_once(tmp_path: Path):
    extra = "#custom-mission-map { color: #95d5b2; }\n"
    one = ensure_css("body {}\n", extra)
    two = ensure_css(one, extra)
    assert one == two
    assert one.count("#custom-mission-map") == 1
