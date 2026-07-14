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
from typing import Any, Dict, Optional

from tamil_schedule import (
    NAZHIGAI_MINUTES,
    PERUM_LABEL,
    SIRU_LABEL,
    TINAI_META,
    resolve_tamil,
)

# Soft amber / muted ink from DESIGN.md dark tokens (readable on warm dark tooltips)
_PANGO_ACCENT = "#C9A66B"
_PANGO_MUTED = "#8A8278"
_STRIP_PANGO = re.compile(r"</?[^>]+>")


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


def _date_line(now: datetime) -> str:
    """Civil date + ISO week — never glued to tinai/siru."""
    week = now.isocalendar()[1]
    return f"{now.day} {now.strftime('%B')}  ·  week {week}  ·  {now.year}"


def _nazhigai_full(nazhigai: int) -> str:
    into_min = nazhigai * NAZHIGAI_MINUTES
    return (
        f"nazhigai {nazhigai} "
        f"(≈{nazhigai}×{NAZHIGAI_MINUTES} min ≈ {into_min} min into this siru)"
    )


def tn_tooltip_markup(tn: Any, now: datetime) -> str:
    """Multi-line Pango tooltip: date → scene → labeled fields (breathing room)."""
    meta = TINAI_META[tn.tinai]
    perum_words = tn.perum.replace("_", " ")
    date = _pango_esc(_date_line(now))
    landscape = _pango_esc(meta["landscape"])
    flower = _pango_esc(meta["flower"])
    siru = _pango_esc(tn.siru)
    jam_label = _pango_esc(tn.jaamam.label)
    nazh = _pango_esc(_nazhigai_full(tn.nazhigai))
    perum_short = _pango_esc(perum_words)
    tinai = _pango_esc(tn.tinai)
    tinai_src = _pango_esc(tn.tinai_source)
    siru_label = _pango_esc(SIRU_LABEL[tn.siru])
    perum_label = _pango_esc(PERUM_LABEL[tn.perum])
    theme = _pango_esc(tn.theme)
    jam_now = tn.jaamam.current

    # Leading/trailing blank lines + CSS padding give edge breathing room.
    return "\n".join(
        [
            "",
            f'<span foreground="{_PANGO_ACCENT}"><b>{date}</b></span>',
            "",
            f"<b>{landscape}</b>  —  {flower}  ·  {siru}",
            f'<span foreground="{_PANGO_MUTED}">{jam_label}</span>',
            f'<span foreground="{_PANGO_MUTED}">{nazh}</span>',
            f'<span foreground="{_PANGO_MUTED}">{perum_short}</span>',
            "",
            f'<span foreground="{_PANGO_MUTED}">tinai</span>     {tinai} ({tinai_src})',
            f'<span foreground="{_PANGO_MUTED}">siru</span>      {siru_label}',
            f'<span foreground="{_PANGO_MUTED}">jaamam</span>    now {jam_now}',
            f"             {jam_label}",
            f'<span foreground="{_PANGO_MUTED}">nazhigai</span>  {nazh}',
            f'<span foreground="{_PANGO_MUTED}">perum</span>     {perum_label}',
            f'<span foreground="{_PANGO_MUTED}">theme</span>     {theme}',
            "",
        ]
    )


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
        f'<span foreground="{_PANGO_ACCENT}"><b>{date}</b></span>',
        "",
        f"<b>{phase_e}</b>",
    ]
    if scene_e:
        lines.append(f'<span foreground="{_PANGO_MUTED}">{scene_e}</span>')
    if state.get("cct_k") is not None:
        lines.append(
            f'<span foreground="{_PANGO_MUTED}">cct</span>       '
            f'≈{_pango_esc(state["cct_k"])}K'
        )
    lines.extend(
        [
            f'<span foreground="{_PANGO_MUTED}">theme</span>     {theme_e}',
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
