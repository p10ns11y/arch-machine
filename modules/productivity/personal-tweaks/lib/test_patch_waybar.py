from pathlib import Path

from patch_waybar import (
    ensure_center,
    ensure_css,
    ensure_eye_comfort_import,
    ensure_object,
    is_valid_jsonc,
    loads_jsonc,
    apply,
    RELATIVE_EYE_IMPORT,
)

STOCK = """{
  "modules-center": ["clock", "custom/weather"],
  "clock": {
    "format": "{:%H:%M}"
  }
}
"""

# Real Omarchy waybar: clock is followed by another key (comma after `}`).
STOCK_TRAILING = """{
  "modules-center": ["clock", "custom/weather"],
  "clock": {
    "format": "{:L%A %H:%M}",
    "tooltip": false
  },
  "custom/weather": {
    "exec": "weather.sh"
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
    loads_jsonc(out)


def test_stock_trailing_comma_stays_valid():
    out = ensure_object(ensure_center(STOCK_TRAILING))
    assert '"clock", "custom/mission-map"' in out
    assert ",\n," not in out
    parsed = loads_jsonc(out)
    assert "custom/mission-map" in parsed
    assert parsed["modules-center"][0:2] == ["clock", "custom/mission-map"]


def test_user_config_inserts_after_focus_now():
    out = ensure_object(ensure_center(USER))
    assert '"custom/focus-now", "custom/mission-map"' in out
    assert '"custom/mission-map":' in out


def test_idempotent():
    once = ensure_object(ensure_center(STOCK))
    twice = ensure_object(ensure_center(once))
    assert once == twice


def test_css_once(tmp_path: Path | None = None):
    extra = "#custom-mission-map { color: #95d5b2; }\n"
    one = ensure_css("body {}\n", extra)
    two = ensure_css(one, extra)
    assert one == two
    assert one.count("#custom-mission-map") == 1


def test_rewrites_file_import():
    raw = '@import "../omarchy/current/theme/waybar.css";\n@import url("file:///home/u/.local/lib/eye-comfort/waybar/eye-comfort.css");\n'
    out = ensure_eye_comfort_import(raw)
    assert RELATIVE_EYE_IMPORT in out
    assert "file://" not in out
    assert out.count("eye-comfort.css") == 1


def test_apply_backs_up_and_writes(tmp_path: Path):
    cfg = tmp_path / "config.jsonc"
    css = tmp_path / "style.css"
    src = tmp_path / "mission-map.css"
    backups = tmp_path / "backups"
    cfg.write_text(STOCK_TRAILING, encoding="utf-8")
    css.write_text('@import "../omarchy/current/theme/waybar.css";\n', encoding="utf-8")
    src.write_text("#custom-mission-map { color: #95d5b2; }\n", encoding="utf-8")
    notes = apply(cfg, css, src, backup_root=backups)
    assert any(n.startswith("backup ") for n in notes)
    assert (backups / "last-good" / "config.jsonc").is_file()
    stamped = [p for p in backups.iterdir() if p.is_dir() and p.name != "last-good"]
    assert stamped
    assert is_valid_jsonc(cfg.read_text(encoding="utf-8"))
    assert "custom/mission-map" in cfg.read_text(encoding="utf-8")
    assert RELATIVE_EYE_IMPORT in css.read_text(encoding="utf-8")


if __name__ == "__main__":
    import tempfile

    test_stock_omarchy_inserts_after_clock()
    test_stock_trailing_comma_stays_valid()
    test_user_config_inserts_after_focus_now()
    test_idempotent()
    test_css_once()
    test_rewrites_file_import()
    with tempfile.TemporaryDirectory() as d:
        test_apply_backs_up_and_writes(Path(d))
    print("patcher tests ok")
