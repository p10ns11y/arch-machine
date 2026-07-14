"""Waybar / notify payloads for eye-comfort (TN + circadian).

Compact bar text; rich tooltip acts as the lightweight “extra widget”.
Reads last apply from state.json when present; live-resolves clock fields.

Waybar tooltips accept Pango markup — hierarchy lives there, not in the bar chip.
"""
from __future__ import annotations

import json
import re
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, List, Optional

from tamil_schedule import (
    JAAMAMS_PER_DAY,
    NAZHIGAI_MINUTES,
    NAZHIGAIS_PER_SIRU,
    PERUM_LABEL,
    SIRU_LABEL,
    TINAI_META,
    resolve_tamil,
)

# Soft amber / muted ink from DESIGN.md dark tokens (readable on warm dark tooltips)
_PANGO_ACCENT = "#C9A66B"
_PANGO_MUTED = "#8A8278"
_PANGO_SOFT = "#A89F94"
_STRIP_PANGO = re.compile(r"</?[^>]+>")

_TINAI_SOURCE_LABEL = {
    "flag": "apply",
    "geo": "geo",
    "default": "default",
}


def default_state_path() -> Path:
    return Path.home() / ".config" / "eye-comfort" / "state.json"


def load_state(path: Optional[Path] = None) -> Dict[str, Any]:
    p = path or default_state_path()
    if not p.is_file():
        return {}
    try:
        data = json.loads(p.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return {}
    return data if isinstance(data, dict) else {}


def _is_tn(state: Dict[str, Any]) -> bool:
    if state.get("calendar") == "tamil_nadu":
        return True
    theme = str(state.get("theme") or "")
    return theme.startswith("eye-comfort-tn-")


def _pango_esc(text: str) -> str:
    return (
        str(text)
        .replace("&", "&amp;")
        .replace("<", "&lt;")
        .replace(">", "&gt;")
    )


def _plain_from_pango(markup: str) -> str:
    """Drop Pango tags for notify-send / CLI; keep newlines and wording."""
    return (
        _STRIP_PANGO.sub("", markup)
        .replace("&amp;", "&")
        .replace("&lt;", "<")
        .replace("&gt;", ">")
    )


def _muted(text: str) -> str:
    return f'<span foreground="{_PANGO_MUTED}">{text}</span>'


def _soft(text: str) -> str:
    return f'<span foreground="{_PANGO_SOFT}">{text}</span>'


def _accent_b(text: str) -> str:
    return f'<span foreground="{_PANGO_ACCENT}"><b>{text}</b></span>'


def _date_line(now: datetime) -> str:
    """Civil date + ISO week — never glued to tinai/siru."""
    week = now.isocalendar()[1]
    return f"{now.day} {now.strftime('%B')}  ·  week {week}  ·  {now.year}"


def _title_tinai(name: str) -> str:
    """DESIGN-TN romanization: Tinai (not Thinai); Title Case display."""
    return name[:1].upper() + name[1:] if name else name


def _jaamam_part_sense(part: Any) -> str:
    if part.full:
        return "full watch · 3 h"
    mins = int(round(part.nazhigai * NAZHIGAI_MINUTES))
    amount = (
        f"{int(round(part.nazhigai))}"
        if abs(part.nazhigai - round(part.nazhigai)) < 1e-9
        else f"{part.nazhigai:g}"
    )
    return f"{amount} nazhigai · ≈{mins} min in this Siru"


def _jaamam_heart_lines(tn: Any) -> List[str]:
    """Living clock heart — current watch + Siru split narrative."""
    jam = tn.jaamam
    lines = [
        _accent_b("Jaamam"),
        f"  Watching <b>{jam.current}</b> of {JAAMAMS_PER_DAY}",
        f"  {_soft('Split')}  ·  {_pango_esc(jam.label)}",
        _soft("  This Siru holds —"),
    ]
    for part in jam.parts:
        sense = _pango_esc(_jaamam_part_sense(part))
        name = f"Jaamam {part.index}"
        if part.index == jam.current:
            lines.append(f"    <b>{_pango_esc(name)}</b>  —  {sense}")
        else:
            lines.append(f"    {_muted(_pango_esc(name))}  —  {sense}")
    return lines


def _nazhigai_heart_lines(tn: Any) -> List[str]:
    """Nazhigai as elapsed pulse inside the current Siru."""
    n = tn.nazhigai
    into_min = n * NAZHIGAI_MINUTES
    siru_title = _pango_esc(_title_tinai(tn.siru))
    return [
        _accent_b("Nazhigai"),
        f"  Nazhigai <b>{n}</b>  ·  step of {NAZHIGAIS_PER_SIRU} into {siru_title}",
        _soft(
            f"  ≈ {into_min} min elapsed"
            f"  ·  {n} × {NAZHIGAI_MINUTES} min into this Siru"
        ),
    ]


def tn_tooltip_markup(tn: Any, now: datetime) -> str:
    """Pango tooltip: date → Tinai → Pozhuthu → Jaamam/Nazhigai heart → Theme."""
    meta = TINAI_META[tn.tinai]
    date = _pango_esc(_date_line(now))
    landscape = _pango_esc(meta["landscape"].title())
    flower = _pango_esc(meta["flower"])
    tinai_name = _pango_esc(_title_tinai(tn.tinai))
    tinai_src = _pango_esc(
        _TINAI_SOURCE_LABEL.get(tn.tinai_source, tn.tinai_source)
    )
    perum_label = _pango_esc(PERUM_LABEL[tn.perum])
    siru_label = _pango_esc(SIRU_LABEL[tn.siru])
    theme = _pango_esc(tn.theme)

    lines: List[str] = [
        "",
        _accent_b(date),
        "",
        "<b>Tinai</b>",
        f"  {landscape}  —  {flower}  ·  {tinai_name} ({tinai_src})",
        "",
        "<b>Pozhuthu</b>",
        f"  {_muted('Perum')}  {perum_label}",
        f"  {_muted('Siru')}   {siru_label}",
        "",
    ]
    lines.extend(_jaamam_heart_lines(tn))
    lines.append("")
    lines.extend(_nazhigai_heart_lines(tn))
    lines.extend(
        [
            "",
            _muted("Theme"),
            f"  {_muted(theme)}",
            "",
        ]
    )
    return "\n".join(lines)


def tn_waybar_payload(
    *,
    state: Optional[Dict[str, Any]] = None,
    now: Optional[datetime] = None,
) -> Dict[str, Any]:
    """Live TN bar + tooltip (tinai from last apply when available)."""
    st = state if state is not None else load_state()
    now = now or datetime.now()
    kwargs: Dict[str, Any] = {"hour": now.hour, "minute": now.minute}
    tinai = st.get("tinai")
    if isinstance(tinai, str) and tinai.strip():
        kwargs["tinai"] = tinai
    lat, lon = st.get("latitude"), st.get("longitude")
    if lat is not None and lon is not None:
        try:
            kwargs["latitude"] = float(lat)
            kwargs["longitude"] = float(lon)
        except (TypeError, ValueError):
            pass

    tn = resolve_tamil(**kwargs)
    text = f"{tn.tinai} · {tn.siru} · n{tn.nazhigai}"
    tooltip = tn_tooltip_markup(tn, now)
    return {
        "text": text,
        "tooltip": tooltip,
        "class": f"eye-comfort-tn eye-comfort-{tn.siru}",
        "alt": "tn",
        "percentage": tn.nazhigai * 10,
    }


def circadian_waybar_payload(
    state: Dict[str, Any], now: Optional[datetime] = None
) -> Dict[str, Any]:
    now = now or datetime.now()
    phase = str(state.get("phase") or "unknown")
    theme = str(state.get("theme") or "eye-comfort")
    scene = str(state.get("scene") or "")
    text = f"{phase}"
    date = _pango_esc(_date_line(now))
    scene_e = _pango_esc(scene) if scene else ""
    theme_e = _pango_esc(theme)
    phase_e = _pango_esc(phase)
    lines = [
        "",
        _accent_b(date),
        "",
        f"<b>{phase_e}</b>",
    ]
    if scene_e:
        lines.append(f"  {_muted(scene_e)}")
    if state.get("cct_k") is not None:
        lines.append(
            f"  {_muted('Cct')}       ≈{_pango_esc(state['cct_k'])}K"
        )
    lines.extend(
        [
            "",
            _muted("Theme"),
            f"  {_muted(theme_e)}",
            "",
        ]
    )
    return {
        "text": text,
        "tooltip": "\n".join(lines),
        "class": f"eye-comfort eye-comfort-{phase}",
        "alt": "circadian",
    }


def waybar_payload(
    *,
    state_path: Optional[Path] = None,
    now: Optional[datetime] = None,
    force_tn: bool = False,
) -> Dict[str, Any]:
    st = load_state(state_path)
    if force_tn or _is_tn(st) or not st:
        try:
            return tn_waybar_payload(state=st, now=now)
        except (ValueError, RuntimeError) as e:
            return {
                "text": "eye-comfort?",
                "tooltip": f"eye-comfort waybar error: {_pango_esc(e)}",
                "class": "eye-comfort-error",
                "alt": "error",
            }
    return circadian_waybar_payload(st, now=now)


def status_text(*, state_path: Optional[Path] = None, now: Optional[datetime] = None) -> str:
    """Human one-liner + scene for `eye-comfort-theme status` (plain text)."""
    payload = waybar_payload(state_path=state_path, now=now)
    return f"{payload['text']}\n{_plain_from_pango(payload['tooltip'])}"


def notify_body(*, state_path: Optional[Path] = None, now: Optional[datetime] = None) -> str:
    """Body for notify-send (plain; click action / second widget surface)."""
    return _plain_from_pango(waybar_payload(state_path=state_path, now=now)["tooltip"])
