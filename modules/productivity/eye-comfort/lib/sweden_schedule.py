"""Sweden cultural schedule — Årstid × Dagsindelning × realm × mikrosteg.

Solar `--lat` first-class (Stockholm ~59.3 default). Season + light only — no weather.
"""
from __future__ import annotations

from dataclasses import asdict, dataclass
from datetime import date, datetime
from typing import Any, Dict, Literal, Optional, Sequence

from palette import Phase
from schedule import phase_for_hour, phase_for_solar

# Stockholm desk default — explicit CLI flag; never inferred from TZ.
DEFAULT_LATITUDE = 59.3

Arstid = Literal["vinter", "var", "sommar", "host"]
Realm = Literal["asgard", "midgard", "jotunheim", "vanaheim", "nifl"]

ARSTID: Sequence[Arstid] = ("vinter", "var", "sommar", "host")
REALM: Sequence[Realm] = ("asgard", "midgard", "jotunheim", "vanaheim", "nifl")

ARSTID_DISPLAY: Dict[Arstid, str] = {
    "vinter": "Vinter",
    "var": "Vår",
    "sommar": "Sommar",
    "host": "Höst",
}

REALM_DISPLAY: Dict[Realm, str] = {
    "asgard": "Asgard",
    "midgard": "Midgard",
    "jotunheim": "Jotunheim",
    "vanaheim": "Vanaheim",
    "nifl": "Niflheim",
}

REALM_MYTH_LABEL: Dict[Realm, str] = {
    "asgard": "sky hall — calm long light",
    "midgard": "meadow — everyday ground",
    "jotunheim": "fells — shortening days",
    "vanaheim": "forest — spring warmth",
    "nifl": "mist winter — low sun",
}

REALM_THEME: Dict[Realm, str] = {
    "asgard": "eye-comfort-se-asgard",
    "midgard": "eye-comfort-se-midgard",
    "jotunheim": "eye-comfort-se-jotunheim",
    "vanaheim": "eye-comfort-se-vanaheim",
    "nifl": "eye-comfort-se-nifl",
}

# Årstid → default realm (saga hue lean; seasons live-render inside package)
ARSTID_REALM: Dict[Arstid, Realm] = {
    "vinter": "nifl",
    "var": "vanaheim",
    "sommar": "asgard",
    "host": "jotunheim",
}

# Shoulder weeks use midgard meadow baseline
MIDGARD_WEEKS = (
    (2, 15, 3, 14),  # late Feb – mid Mar
    (8, 15, 9, 14),  # late Aug – mid Sep
)

PHASE_DISPLAY: Dict[Phase, str] = {
    "dawn": "Gryning",
    "morning": "Förmiddag",
    "midday": "Middag",
    "afternoon": "Eftermiddag",
    "dusk": "Skymning",
    "evening": "Kväll",
    "night": "Natt",
}

# One-line solar hint only (work / rest / outdoor) — not coaching.
SOLAR_HINT: Dict[Phase, str] = {
    "dawn": "outdoor",
    "morning": "work",
    "midday": "outdoor",
    "afternoon": "work",
    "dusk": "rest",
    "evening": "rest",
    "night": "rest",
}

MIKROSTEG_PER_PHASE = 6


@dataclass(frozen=True)
class SwedenState:
    arstid: Arstid
    realm: Realm
    phase: Phase
    mikrosteg: int  # 0–5 within current dagsindelning
    theme: str
    hour: int
    minute: int
    latitude: float
    wallpaper_hint: str
    scene: str
    solar_hint: str
    source: str  # "auto" | "forced"
    realm_source: str  # "flag" | "arstid" | "shoulder"


def parse_arstid(name: str) -> Arstid:
    n = name.strip().lower().replace("å", "a").replace("ä", "a").replace("ö", "o")
    aliases = {
        "vinter": "vinter",
        "winter": "vinter",
        "var": "var",
        "vaar": "var",
        "spring": "var",
        "sommar": "sommar",
        "summer": "sommar",
        "host": "host",
        "hosten": "host",
        "autumn": "host",
        "fall": "host",
    }
    n = aliases.get(n, n)
    if n not in ARSTID:
        raise ValueError(f"unknown arstid {name!r}; use one of: {', '.join(ARSTID)}")
    return n  # type: ignore[return-value]


def parse_realm(name: str) -> Realm:
    n = name.strip().lower().replace("-", "_")
    aliases = {
        "asgard": "asgard",
        "midgard": "midgard",
        "jotunheim": "jotunheim",
        "jotun": "jotunheim",
        "vanaheim": "vanaheim",
        "vanir": "vanaheim",
        "nifl": "nifl",
        "niflheim": "nifl",
    }
    n = aliases.get(n, n)
    if n not in REALM:
        raise ValueError(f"unknown realm {name!r}; use one of: {', '.join(REALM)}")
    return n  # type: ignore[return-value]


def _in_midgard_shoulder(on: date) -> bool:
    m, d = on.month, on.day
    for sm, sd, em, ed in MIDGARD_WEEKS:
        if (m == sm and d >= sd) or (m > sm and m < em) or (m == em and d <= ed):
            return True
    return False


def arstid_for_date(on: date) -> Arstid:
    """Nordic year structure (desk calendar, not agriculture)."""
    m, day = on.month, on.day
    if m in (12, 1, 2) or (m == 11 and day >= 15):
        return "vinter"
    if m in (3, 4, 5):
        return "var"
    if m in (6, 7, 8):
        return "sommar"
    return "host"


def realm_for_arstid(arstid: Arstid, on: date, *, forced: Optional[Realm] = None) -> tuple[Realm, str]:
    if forced:
        return forced, "flag"
    if _in_midgard_shoulder(on):
        return "midgard", "shoulder"
    return ARSTID_REALM[arstid], "arstid"


def dagsindelning_for_clock(
    hour: int,
    minute: int,
    latitude: float,
    on: date,
) -> tuple[Phase, str]:
    """Map wall clock to circadian phase; solar when lat set."""
    phase = phase_for_solar(hour, minute, latitude, on=on)
    return phase, "solar"


def mikrosteg_in_phase(hour: int, minute: int, phase: Phase, latitude: float, on: date) -> int:
    """Micro-step 0–5 within the current dagsindelning window."""
    # Re-resolve boundaries by scanning hour slices (good enough for bar chip).
    t = hour + minute / 60.0
    boundaries: list[tuple[float, Phase]] = []
    for h in range(24):
        for m in (0, 30):
            ph = (
                phase_for_solar(h, m, latitude, on=on)
                if latitude is not None
                else phase_for_hour(h, m)
            )
            boundaries.append((h + m / 60.0, ph))

    # Find span of current phase containing t
    start = 0.0
    end = 24.0
    for i, (bt, ph) in enumerate(boundaries):
        if ph != phase:
            continue
        start = bt
        # find end where phase changes
        for j in range(i + 1, len(boundaries) + i):
            nt, nph = boundaries[j % len(boundaries)]
            if nph != phase:
                end = nt if nt > start else nt + 24.0
                break
        break

    if end <= start:
        end += 24.0
    pos = t if t >= start else t + 24.0
    span = max(0.25, end - start)
    step = int(min(MIKROSTEG_PER_PHASE - 1, (pos - start) / span * MIKROSTEG_PER_PHASE))
    return max(0, min(MIKROSTEG_PER_PHASE - 1, step))


def wallpaper_hint(realm: Realm, phase: Phase, mikrosteg: int) -> str:
    variant = "a" if mikrosteg < MIKROSTEG_PER_PHASE // 2 else "b"
    return f"{realm}-{phase}-{variant}.jpg"


def scene_line(
    arstid: Arstid,
    realm: Realm,
    phase: Phase,
    mikrosteg: int,
    *,
    solar_hint: str,
) -> str:
    return (
        f"{ARSTID_DISPLAY[arstid]} · {REALM_DISPLAY[realm]} · "
        f"{PHASE_DISPLAY[phase]} · M{mikrosteg + 1} · {solar_hint}"
    )


def resolve_sweden(
    *,
    realm: Optional[str] = None,
    arstid: Optional[str] = None,
    mikrosteg: Optional[int] = None,
    hour: Optional[int] = None,
    minute: int = 0,
    latitude: Optional[float] = None,
    now: Optional[datetime] = None,
) -> SwedenState:
    now = now or datetime.now()
    if hour is None:
        hour = now.hour
        minute = now.minute
    if not (0 <= hour <= 23):
        raise ValueError(f"hour must be 0–23, got {hour}")
    if not (0 <= minute <= 59):
        raise ValueError(f"minute must be 0–59, got {minute}")

    lat = float(latitude if latitude is not None else DEFAULT_LATITUDE)
    if not (-90.0 <= lat <= 90.0):
        raise ValueError(f"latitude must be -90..90, got {lat}")

    on = now.date()
    forced = any(x is not None for x in (realm, arstid, mikrosteg))

    if arstid:
        arstid_v = parse_arstid(arstid)
    else:
        arstid_v = arstid_for_date(on)

    realm_v, realm_src = realm_for_arstid(
        arstid_v,
        on,
        forced=parse_realm(realm) if realm else None,
    )

    phase, _ = dagsindelning_for_clock(hour, minute, lat, on)

    if mikrosteg is not None:
        if not isinstance(mikrosteg, int) or not (0 <= mikrosteg <= MIKROSTEG_PER_PHASE - 1):
            raise ValueError(
                f"mikrosteg must be int 0–{MIKROSTEG_PER_PHASE - 1}, got {mikrosteg!r}"
            )
        mik_v = mikrosteg
    else:
        mik_v = mikrosteg_in_phase(hour, minute, phase, lat, on)

    hint = SOLAR_HINT[phase]
    return SwedenState(
        arstid=arstid_v,
        realm=realm_v,
        phase=phase,
        mikrosteg=mik_v,
        theme=REALM_THEME[realm_v],
        hour=hour,
        minute=minute,
        latitude=lat,
        wallpaper_hint=wallpaper_hint(realm_v, phase, mik_v),
        scene=scene_line(arstid_v, realm_v, phase, mik_v, solar_hint=hint),
        solar_hint=hint,
        source="forced" if forced else "auto",
        realm_source=realm_src,
    )


def state_to_dict(state: SwedenState) -> Dict[str, Any]:
    d = asdict(state)
    d["arstid_label"] = ARSTID_DISPLAY[state.arstid]
    d["realm_label"] = REALM_DISPLAY[state.realm]
    d["realm_myth"] = REALM_MYTH_LABEL[state.realm]
    d["phase_label"] = PHASE_DISPLAY[state.phase]
    d["dagsindelning"] = state.phase
    return d
