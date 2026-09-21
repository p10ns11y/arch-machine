"""Calendar plugin registry — resolve eye-comfort-theme MODE via calendar id.

Adding a culture = new schedule + palette modules + packages; CLI/waybar stay generic.
"""
from __future__ import annotations

import json
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Callable, Dict, Literal, Optional

CalendarId = Literal["circadian", "tamil_nadu", "sweden", "america_1776", "india"]

DEFAULT_CALENDAR: CalendarId = "circadian"
DEFAULT_STATE_DIR = Path.home() / ".config" / "eye-comfort"


@dataclass(frozen=True)
class CalendarMeta:
    id: CalendarId
    label: str
    cli_aliases: tuple[str, ...]
    enabled: bool
    later_label: Optional[str] = None


CALENDAR_CATALOG: tuple[CalendarMeta, ...] = (
    CalendarMeta("tamil_nadu", "Tamil Nadu", ("tn", "tamil", "tamil-nadu"), True),
    CalendarMeta("sweden", "Sweden", ("se", "sweden"), True),
    CalendarMeta(
        "america_1776",
        "America",
        ("us", "america", "america_1776"),
        False,
        later_label="later",
    ),
    CalendarMeta("circadian", "Circadian", ("circadian",), True),
    CalendarMeta("india", "India", ("in", "india"), False, later_label="later"),
)


@dataclass
class CalendarApplyResult:
    calendar: CalendarId
    payload: Dict[str, Any]
    theme: str
    roles: Dict[str, str]
    phase: str
    wallpaper_hint: str
    scene: str
    contrast_fg_bg: float


def _meta_for(calendar_id: str) -> Optional[CalendarMeta]:
    for meta in CALENDAR_CATALOG:
        if meta.id == calendar_id:
            return meta
    return None


def is_calendar_enabled(calendar_id: str) -> bool:
    meta = _meta_for(calendar_id)
    return bool(meta and meta.enabled)


def load_state(state_dir: Optional[Path] = None) -> Dict[str, Any]:
    p = (state_dir or DEFAULT_STATE_DIR) / "state.json"
    if not p.is_file():
        return {}
    try:
        data = json.loads(p.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return {}
    return data if isinstance(data, dict) else {}


def calendar_from_state(state_dir: Optional[Path] = None) -> CalendarId:
    """Last applied calendar in state.json; no TZ→geo guess."""
    cal = str(load_state(state_dir).get("calendar") or "").strip()
    if cal in {m.id for m in CALENDAR_CATALOG}:
        return cal  # type: ignore[return-value]
    return DEFAULT_CALENDAR


def mode_to_calendar(mode: str, *, state_dir: Optional[Path] = None) -> CalendarId:
    """Map CLI positional MODE to registry calendar id."""
    m = (mode or "auto").strip().lower()
    if m in ("auto", ""):
        return calendar_from_state(state_dir)
    for meta in CALENDAR_CATALOG:
        if m == meta.id or m in meta.cli_aliases:
            return meta.id  # type: ignore[return-value]
    # Circadian phase aliases — not a cultural calendar overlay.
    return DEFAULT_CALENDAR


def is_cultural_calendar(calendar_id: str) -> bool:
    return calendar_id in ("tamil_nadu", "sweden", "india", "america_1776")


def is_cultural_mode(mode: str) -> bool:
    m = (mode or "").strip().lower()
    for meta in CALENDAR_CATALOG:
        if meta.id == m or m in meta.cli_aliases:
            return meta.id != "circadian"
    return False


def apply_calendar(
    calendar_id: CalendarId,
    *,
    hour: Optional[int] = None,
    minute: int = 0,
    latitude: Optional[float] = None,
    longitude: Optional[float] = None,
    ambient: str = "auto",
    intensity: str = "balanced",
    high_contrast: bool = False,
    reduced_motion: bool = False,
    no_dynamic: bool = False,
    # TN overrides
    tinai: Optional[str] = None,
    perum: Optional[str] = None,
    siru: Optional[str] = None,
    nazhigai: Optional[int] = None,
    # SE overrides
    realm: Optional[str] = None,
    arstid: Optional[str] = None,
    mikrosteg: Optional[int] = None,
    # Circadian
    mode: str = "auto",
) -> CalendarApplyResult:
    meta = _meta_for(calendar_id)
    if meta is None:
        raise ValueError(f"unknown calendar {calendar_id!r}")
    if not meta.enabled:
        label = meta.later_label or "later"
        raise ValueError(f"calendar {calendar_id!r} is not available ({label})")

    if calendar_id == "tamil_nadu":
        return _apply_tamil_nadu(
            hour=hour,
            minute=minute,
            latitude=latitude,
            longitude=longitude,
            ambient=ambient,
            intensity=intensity,
            high_contrast=high_contrast,
            tinai=tinai,
            perum=perum,
            siru=siru,
            nazhigai=nazhigai,
        )
    if calendar_id == "sweden":
        return _apply_sweden(
            hour=hour,
            minute=minute,
            latitude=latitude,
            ambient=ambient,
            intensity=intensity,
            high_contrast=high_contrast,
            realm=realm,
            arstid=arstid,
            mikrosteg=mikrosteg,
        )
    return _apply_circadian(
        mode=mode,
        hour=hour,
        minute=minute,
        latitude=latitude,
        ambient=ambient,
        intensity=intensity,
        high_contrast=high_contrast,
        reduced_motion=reduced_motion,
        no_dynamic=no_dynamic,
    )


def _apply_tamil_nadu(**kwargs: Any) -> CalendarApplyResult:
    from oklch import contrast_ratio as cr
    from tamil_palette import roles_for_tamil
    from tamil_schedule import resolve_tamil, state_to_dict as tn_state_to_dict

    resolve_kw: Dict[str, Any] = {}
    for key in ("hour", "minute", "latitude", "longitude", "tinai", "perum", "siru", "nazhigai"):
        if kwargs.get(key) is not None:
            resolve_kw[key] = kwargs[key]

    state = resolve_tamil(**resolve_kw)
    amb = kwargs.get("ambient") or "auto"
    amb = amb if amb in ("indoor", "outdoor") else "indoor"
    intensity = kwargs.get("intensity") or "balanced"
    roles = roles_for_tamil(
        state.tinai,
        state.siru,
        nazhigai=state.nazhigai,
        ambient=amb,  # type: ignore[arg-type]
        intensity=intensity,  # type: ignore[arg-type]
        high_contrast=bool(kwargs.get("high_contrast")),
    )
    payload = tn_state_to_dict(state)
    payload["roles"] = roles
    payload["contrast_fg_bg"] = round(cr(roles["foreground"], roles["background"]), 2)
    payload["ambient"] = amb
    payload["intensity"] = intensity
    payload["calendar"] = "tamil_nadu"
    return CalendarApplyResult(
        calendar="tamil_nadu",
        payload=payload,
        theme=state.theme,
        roles=roles,
        phase=state.phase,
        wallpaper_hint=state.wallpaper_hint,
        scene=state.scene,
        contrast_fg_bg=payload["contrast_fg_bg"],
    )


def _apply_sweden(**kwargs: Any) -> CalendarApplyResult:
    from oklch import contrast_ratio as cr
    from sweden_palette import roles_for_sweden
    from sweden_schedule import resolve_sweden, state_to_dict as se_state_to_dict

    resolve_kw: Dict[str, Any] = {}
    for key in ("hour", "minute", "latitude", "realm", "arstid", "mikrosteg"):
        if kwargs.get(key) is not None:
            resolve_kw[key] = kwargs[key]

    state = resolve_sweden(**resolve_kw)
    amb = kwargs.get("ambient") or "auto"
    amb = amb if amb in ("indoor", "outdoor") else "indoor"
    intensity = kwargs.get("intensity") or "balanced"
    roles = roles_for_sweden(
        state.realm,
        state.phase,
        mikrosteg=state.mikrosteg,
        ambient=amb,  # type: ignore[arg-type]
        intensity=intensity,  # type: ignore[arg-type]
        high_contrast=bool(kwargs.get("high_contrast")),
    )
    payload = se_state_to_dict(state)
    payload["roles"] = roles
    payload["contrast_fg_bg"] = round(cr(roles["foreground"], roles["background"]), 2)
    payload["ambient"] = amb
    payload["intensity"] = intensity
    payload["calendar"] = "sweden"
    return CalendarApplyResult(
        calendar="sweden",
        payload=payload,
        theme=state.theme,
        roles=roles,
        phase=state.phase,
        wallpaper_hint=state.wallpaper_hint,
        scene=state.scene,
        contrast_fg_bg=payload["contrast_fg_bg"],
    )


def _apply_circadian(**kwargs: Any) -> CalendarApplyResult:
    from schedule import resolve, state_to_dict

    mode = kwargs.get("mode") or "auto"
    resolve_kw: Dict[str, Any] = {
        "mode": mode,
        "ambient": kwargs.get("ambient") or "auto",
        "intensity": kwargs.get("intensity") or "balanced",
        "high_contrast": bool(kwargs.get("high_contrast")),
        "reduced_motion": bool(kwargs.get("reduced_motion")),
        "no_dynamic": bool(kwargs.get("no_dynamic")),
    }
    if kwargs.get("hour") is not None:
        resolve_kw["hour"] = kwargs["hour"]
    if kwargs.get("minute") is not None:
        resolve_kw["minute"] = kwargs["minute"]
    if kwargs.get("latitude") is not None:
        resolve_kw["latitude"] = kwargs["latitude"]

    state = resolve(**resolve_kw)
    payload = state_to_dict(state)
    payload["calendar"] = "circadian"
    return CalendarApplyResult(
        calendar="circadian",
        payload=payload,
        theme=state.theme,
        roles=state.roles,
        phase=state.phase,
        wallpaper_hint=state.wallpaper_hint,
        scene=state.scene,
        contrast_fg_bg=state.contrast_fg_bg,
    )


def set_calendar_in_state(
    calendar_id: CalendarId,
    *,
    state_dir: Optional[Path] = None,
    latitude: Optional[float] = None,
) -> Path:
    """Persist calendar choice without applying a theme (panel switcher preflight)."""
    sd = state_dir or DEFAULT_STATE_DIR
    sd.mkdir(parents=True, exist_ok=True)
    path = sd / "state.json"
    data = load_state(sd)
    data["calendar"] = calendar_id
    if latitude is not None:
        data["latitude"] = latitude
    path.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
    return path
