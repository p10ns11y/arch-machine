"""Waybar / notify payloads for eye-comfort (TN + circadian).

Compact bar text; rich tooltip acts as the lightweight “extra widget”.
Reads last apply from state.json when present; live-resolves clock fields.
"""
from __future__ import annotations

import json
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, Optional

from tamil_schedule import (
    NAZHIGAI_MINUTES,
    PERUM_LABEL,
    SIRU_LABEL,
    resolve_tamil,
)


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
    into_min = tn.nazhigai * NAZHIGAI_MINUTES
    text = f"{tn.tinai} · {tn.siru} · n{tn.nazhigai}"
    tooltip = (
        f"{tn.scene}\n"
        f"\n"
        f"tinai: {tn.tinai} ({tn.tinai_source})\n"
        f"siru: {SIRU_LABEL[tn.siru]}\n"
        f"jaamam now: {tn.jaamam.current} · {tn.jaamam.label}\n"
        f"nazhigai: {tn.nazhigai} (≈{into_min} min into siru)\n"
        f"perum: {PERUM_LABEL[tn.perum]}\n"
        f"theme: {tn.theme}"
    )
    return {
        "text": text,
        "tooltip": tooltip,
        "class": f"eye-comfort-tn eye-comfort-{tn.siru}",
        "alt": "tn",
        "percentage": tn.nazhigai * 10,
    }


def circadian_waybar_payload(state: Dict[str, Any]) -> Dict[str, Any]:
    phase = str(state.get("phase") or "unknown")
    theme = str(state.get("theme") or "eye-comfort")
    scene = str(state.get("scene") or "")
    text = f"{phase}"
    tooltip = scene or f"phase={phase}\ntheme={theme}"
    if state.get("cct_k") is not None:
        tooltip += f"\ncct≈{state['cct_k']}K"
    tooltip += f"\ntheme: {theme}"
    return {
        "text": text,
        "tooltip": tooltip,
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
                "tooltip": f"eye-comfort waybar error: {e}",
                "class": "eye-comfort-error",
                "alt": "error",
            }
    return circadian_waybar_payload(st)


def status_text(*, state_path: Optional[Path] = None, now: Optional[datetime] = None) -> str:
    """Human one-liner + scene for `eye-comfort-theme status`."""
    payload = waybar_payload(state_path=state_path, now=now)
    return f"{payload['text']}\n{payload['tooltip']}"


def notify_body(*, state_path: Optional[Path] = None, now: Optional[datetime] = None) -> str:
    """Body for notify-send (click action / second widget surface)."""
    return waybar_payload(state_path=state_path, now=now)["tooltip"]
