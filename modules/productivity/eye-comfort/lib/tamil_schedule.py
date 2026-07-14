"""Tamil Nadu cultural schedule for eye-comfort — Perum × Siru × Tinai × Nazhigai.

Eye comfort remains primary: this module only resolves *which* package and
micro-tint to apply. Palettes stay warm OKLCH / WCAG AA via tamil_palette.

Not a rewrite of the solar circadian schedule — additive cultural overlay.
"""
from __future__ import annotations

from dataclasses import asdict, dataclass
from datetime import date, datetime
from typing import Any, Dict, Literal, Optional, Sequence

Tinai = Literal["kurinji", "mullai", "marutham", "neythal", "palai"]
Perum = Literal[
    "ila_venil",
    "mudhu_venil",
    "kar",
    "kulir",
    "munpani",
    "pinpani",
]
Siru = Literal["vidiyal", "kaalai", "nanpagal", "erpaadu", "maalai", "yaamam"]

TINAI: Sequence[Tinai] = (
    "kurinji",
    "mullai",
    "marutham",
    "neythal",
    "palai",
)
PERUM: Sequence[Perum] = (
    "ila_venil",
    "mudhu_venil",
    "kar",
    "kulir",
    "munpani",
    "pinpani",
)
SIRU: Sequence[Siru] = (
    "vidiyal",
    "kaalai",
    "nanpagal",
    "erpaadu",
    "maalai",
    "yaamam",
)

# 1 Nazhigai ≈ 24 minutes; 60 Nazhigais per civil day; 10 per Siru (~4 h)
NAZHIGAI_MINUTES = 24
NAZHIGAIS_PER_SIRU = 10

# Package identity = landscape (tinai). Siru live-renders luminance inside it.
TINAI_THEME: Dict[Tinai, str] = {
    "kurinji": "eye-comfort-tn-kurinji",
    "mullai": "eye-comfort-tn-mullai",
    "marutham": "eye-comfort-tn-marutham",
    "neythal": "eye-comfort-tn-neythal",
    "palai": "eye-comfort-tn-palai",
}

# Table: characteristic Siru / Perum / Uri Porul (for hints + docs, not cosplay)
TINAI_META: Dict[Tinai, Dict[str, str]] = {
    "kurinji": {
        "landscape": "mountains",
        "flower": "kurinji",
        "siru": "yaamam",
        "perum": "munpani",
        "deity": "Murugan",
        "uri_porul": "union/joy",
    },
    "mullai": {
        "landscape": "forest",
        "flower": "jasmine",
        "siru": "maalai",
        "perum": "kar",
        "deity": "Mayon",
        "uri_porul": "waiting",
    },
    "marutham": {
        "landscape": "plains",
        "flower": "marutham",
        "siru": "vidiyal",
        "perum": "various",
        "deity": "Indra",
        "uri_porul": "quarrel",
    },
    "neythal": {
        "landscape": "seashore",
        "flower": "water lily",
        "siru": "erpaadu",
        "perum": "various",
        "deity": "Varuna",
        "uri_porul": "pining",
    },
    "palai": {
        "landscape": "wasteland",
        "flower": "palai",
        "siru": "nanpagal",
        "perum": "mudhu_venil",
        "deity": "Kotravai",
        "uri_porul": "separation/endurance",
    },
}

# Display names (Tamil + roman)
PERUM_LABEL: Dict[Perum, str] = {
    "ila_venil": "இளவேனில் Ila Venil — Early/Light Summer",
    "mudhu_venil": "முதுவேனில் Mudhu Venil — Late/Harsh Summer",
    "kar": "கார் Kār — Rainy/Monsoon",
    "kulir": "குளிர்/கூதிர் Kulir — Cool/Autumn",
    "munpani": "முன்பனி Munpani — Early Dew/Winter",
    "pinpani": "பின்பனி Pinpani — Late Dew/Late Winter",
}
SIRU_LABEL: Dict[Siru, str] = {
    "vidiyal": "வைகறை/விடியல் Vidiyal — Dawn ~2–6",
    "kaalai": "காலை Kaalai — Morning ~6–10",
    "nanpagal": "நண்பகல் Nan Pagal — Midday ~10–14",
    "erpaadu": "எற்பாடு Erpaadu — Afternoon→Dusk ~14–18",
    "maalai": "மாலை Maalai — Evening ~18–22",
    "yaamam": "யாமம் Yaamam — Night ~22–2",
}

# Fixed Siru windows [start_hour, end_hour) — yaamam wraps midnight
_SIRU_WINDOWS: Dict[Siru, tuple[int, int]] = {
    "vidiyal": (2, 6),
    "kaalai": (6, 10),
    "nanpagal": (10, 14),
    "erpaadu": (14, 18),
    "maalai": (18, 22),
    "yaamam": (22, 2),
}

# Map Siru → eye-comfort circadian phase (luminance family; for render dark/light)
SIRU_TO_PHASE: Dict[Siru, str] = {
    "vidiyal": "dawn",
    "kaalai": "morning",
    "nanpagal": "midday",
    "erpaadu": "afternoon",
    "maalai": "dusk",
    "yaamam": "night",
}


@dataclass(frozen=True)
class TamilState:
    tinai: Tinai
    perum: Perum
    siru: Siru
    nazhigai: int  # 0–9 within current Siru
    theme: str
    phase: str  # circadian mirror for hosts/render
    hour: int
    minute: int
    latitude: Optional[float]
    longitude: Optional[float]
    wallpaper_hint: str
    scene: str
    source: str  # "auto" | "forced"
    tinai_source: str  # "flag" | "geo" | "default"


def parse_tinai(name: str) -> Tinai:
    n = name.strip().lower().replace("-", "_")
    aliases = {
        "kurinci": "kurinji",
        "kurinji": "kurinji",
        "mullai": "mullai",
        "marutam": "marutham",
        "marutham": "marutham",
        "neytal": "neythal",
        "neythal": "neythal",
        "paalai": "palai",
        "palai": "palai",
    }
    n = aliases.get(n, n)
    if n not in TINAI:
        raise ValueError(
            f"unknown tinai {name!r}; use one of: {', '.join(TINAI)}"
        )
    return n  # type: ignore[return-value]


def parse_perum(name: str) -> Perum:
    n = name.strip().lower().replace("-", "_").replace(" ", "_")
    aliases = {
        "ila_venil": "ila_venil",
        "ilavenil": "ila_venil",
        "early_summer": "ila_venil",
        "mudhu_venil": "mudhu_venil",
        "mudhuvenil": "mudhu_venil",
        "late_summer": "mudhu_venil",
        "kar": "kar",
        "kaar": "kar",
        "monsoon": "kar",
        "kulir": "kulir",
        "koodhir": "kulir",
        "kudir": "kulir",
        "autumn": "kulir",
        "munpani": "munpani",
        "early_winter": "munpani",
        "pinpani": "pinpani",
        "late_winter": "pinpani",
    }
    n = aliases.get(n, n)
    if n not in PERUM:
        raise ValueError(
            f"unknown perum {name!r}; use one of: {', '.join(PERUM)}"
        )
    return n  # type: ignore[return-value]


def parse_siru(name: str) -> Siru:
    n = name.strip().lower().replace("-", "_").replace(" ", "_")
    aliases = {
        "vidiyal": "vidiyal",
        "vaikarai": "vidiyal",
        "dawn": "vidiyal",
        "kaalai": "kaalai",
        "kalai": "kaalai",
        "morning": "kaalai",
        "nanpagal": "nanpagal",
        "nan_pagal": "nanpagal",
        "midday": "nanpagal",
        "erpaadu": "erpaadu",
        "erpadu": "erpaadu",
        "afternoon": "erpaadu",
        "maalai": "maalai",
        "malai": "maalai",
        "evening": "maalai",
        "yaamam": "yaamam",
        "yamam": "yaamam",
        "night": "yaamam",
    }
    n = aliases.get(n, n)
    if n not in SIRU:
        raise ValueError(
            f"unknown siru {name!r}; use one of: {', '.join(SIRU)}"
        )
    return n  # type: ignore[return-value]


def _month_day(d: date) -> tuple[int, int]:
    return d.month, d.day


def perum_for_date(on: date) -> Perum:
    """Approximate Gregorian windows for the six Perum Pozhuthugal (~mid-month).

    Traditional Tamil calendar boundaries vary by almanac; these mid-month
    Gregorian spans are good enough for desk theme season, not agriculture.
    """
    m, day = _month_day(on)
    # (month, day) inclusive ranges; pinpani wraps year
    # Ila Venil: Mid-Apr–Mid-Jun
    if (m == 4 and day >= 15) or m == 5 or (m == 6 and day < 15):
        return "ila_venil"
    # Mudhu Venil: Mid-Jun–Mid-Aug
    if (m == 6 and day >= 15) or m == 7 or (m == 8 and day < 15):
        return "mudhu_venil"
    # Kār: Mid-Aug–Mid-Oct
    if (m == 8 and day >= 15) or m == 9 or (m == 10 and day < 15):
        return "kar"
    # Kulir: Mid-Oct–Mid-Dec
    if (m == 10 and day >= 15) or m == 11 or (m == 12 and day < 15):
        return "kulir"
    # Munpani: Mid-Dec–Mid-Feb
    if (m == 12 and day >= 15) or m == 1 or (m == 2 and day < 15):
        return "munpani"
    # Pinpani: Mid-Feb–Mid-Apr
    return "pinpani"


def siru_for_hour(hour: int, minute: int = 0) -> Siru:
    if not isinstance(hour, int) or hour < 0 or hour > 23:
        raise ValueError(f"hour must be int 0–23, got {hour!r}")
    if not isinstance(minute, int) or minute < 0 or minute > 59:
        raise ValueError(f"minute must be int 0–59, got {minute!r}")
    t = hour + minute / 60.0
    for siru, (start, end) in _SIRU_WINDOWS.items():
        if start < end:
            if start <= t < end:
                return siru
        else:  # wraps (yaamam)
            if t >= start or t < end:
                return siru
    return "yaamam"


def nazhigai_in_siru(hour: int, minute: int = 0, siru: Optional[Siru] = None) -> int:
    """Soft Nazhigai step 0–9 within the current (or given) Siru.

    Each Siru ≈ 4 h = 10 × 24 min. Step is floor(minutes_into_siru / 24).
    """
    s = siru or siru_for_hour(hour, minute)
    start, end = _SIRU_WINDOWS[s]
    t_min = hour * 60 + minute
    if start < end:
        start_min = start * 60
        into = t_min - start_min
    else:
        # yaamam 22:00 → 02:00
        start_min = 22 * 60
        if t_min >= start_min:
            into = t_min - start_min
        else:
            into = (24 * 60 - start_min) + t_min
    step = max(0, min(NAZHIGAIS_PER_SIRU - 1, into // NAZHIGAI_MINUTES))
    return int(step)


def nazhigai_of_day(hour: int, minute: int = 0) -> int:
    """Absolute Nazhigai index 0–59 from local midnight (informational)."""
    total = (hour * 60 + minute) // NAZHIGAI_MINUTES
    return max(0, min(59, total))


def infer_tinai(
    latitude: Optional[float],
    longitude: Optional[float],
    *,
    perum: Optional[Perum] = None,
) -> tuple[Tinai, str]:
    """Simple TN coastal / hills / plains / forest / dry heuristic.

    Documented mapping (v1, not GIS):
      - East coast (lon ≳ 79.6° within TN lat band) → neythal
      - Western Ghats / Nilgiris west (lon ≲ 77.3°) → kurinji
      - Coimbatore foothills forest belt → mullai
      - Dry interior + Mudhu Venil → palai
      - Else plains → marutham
    Missing coords → marutham (default fertile plains).
    """
    if latitude is None or longitude is None:
        return "marutham", "default"

    lat, lon = float(latitude), float(longitude)
    if not (-90.0 <= lat <= 90.0 and -180.0 <= lon <= 180.0):
        raise ValueError(f"lat/lon out of range: {lat}, {lon}")

    # Rough Tamil Nadu band (loose; still apply heuristics outside)
    in_tn = 8.0 <= lat <= 13.6 and 76.2 <= lon <= 80.5

    # Neythal — Coromandel / east shore
    if lon >= 79.55 and 8.0 <= lat <= 13.5:
        return "neythal", "geo"

    # Kurinji — Western Ghats / Nilgiris / Palani hills
    if lon <= 77.35 and 9.2 <= lat <= 12.8:
        return "kurinji", "geo"
    if lat >= 11.0 and lon <= 77.05:
        return "kurinji", "geo"

    # Mullai — forested western mid-belt
    if 10.3 <= lat <= 11.8 and 76.9 <= lon <= 77.9:
        return "mullai", "geo"

    # Palai — dry interior, especially harsh summer (Mudhu Venil)
    if 9.4 <= lat <= 11.6 and 77.6 <= lon <= 79.1 and perum == "mudhu_venil":
        return "palai", "geo"

    if in_tn or (8.0 <= lat <= 13.6):
        return "marutham", "geo"
    return "marutham", "default"


def wallpaper_hint(tinai: Tinai, siru: Siru, nazhigai: int) -> str:
    """Filename hint for Karu Porul wallpaper sets (README-driven placeholders OK)."""
    # Soft micro-variation: step 0–4 vs 5–9 pick a/b variant suffix
    variant = "a" if nazhigai < 5 else "b"
    return f"{tinai}-{siru}-{variant}.jpg"


def scene_line(tinai: Tinai, perum: Perum, siru: Siru, nazhigai: int) -> str:
    meta = TINAI_META[tinai]
    return (
        f"{meta['landscape']} · {meta['flower']} · "
        f"{siru} n{nazhigai} · {perum.replace('_', ' ')}"
    )


def resolve_tamil(
    *,
    tinai: Optional[str] = None,
    perum: Optional[str] = None,
    siru: Optional[str] = None,
    nazhigai: Optional[int] = None,
    hour: Optional[int] = None,
    minute: int = 0,
    latitude: Optional[float] = None,
    longitude: Optional[float] = None,
    now: Optional[datetime] = None,
) -> TamilState:
    """Resolve Tamil cultural state for theme apply."""
    now = now or datetime.now()
    if hour is None:
        hour = now.hour
        minute = now.minute
    if not (0 <= hour <= 23):
        raise ValueError(f"hour must be 0–23, got {hour}")
    if not (0 <= minute <= 59):
        raise ValueError(f"minute must be 0–59, got {minute}")
    if latitude is not None and not (-90.0 <= latitude <= 90.0):
        raise ValueError(f"latitude must be -90..90, got {latitude}")
    if longitude is not None and not (-180.0 <= longitude <= 180.0):
        raise ValueError(f"longitude must be -180..180, got {longitude}")

    forced = any(x is not None for x in (tinai, perum, siru, nazhigai))
    on = now.date()

    if perum:
        perum_v = parse_perum(perum)
    else:
        perum_v = perum_for_date(on)

    if siru:
        siru_v = parse_siru(siru)
    else:
        siru_v = siru_for_hour(hour, minute)

    if nazhigai is not None:
        if not isinstance(nazhigai, int) or not (0 <= nazhigai <= 9):
            raise ValueError(f"nazhigai must be int 0–9, got {nazhigai!r}")
        naz_v = nazhigai
    else:
        naz_v = nazhigai_in_siru(hour, minute, siru_v)

    if tinai:
        tinai_v = parse_tinai(tinai)
        tinai_source = "flag"
    else:
        tinai_v, tinai_source = infer_tinai(latitude, longitude, perum=perum_v)

    theme = TINAI_THEME[tinai_v]
    phase = SIRU_TO_PHASE[siru_v]
    return TamilState(
        tinai=tinai_v,
        perum=perum_v,
        siru=siru_v,
        nazhigai=naz_v,
        theme=theme,
        phase=phase,
        hour=hour,
        minute=minute,
        latitude=latitude,
        longitude=longitude,
        wallpaper_hint=wallpaper_hint(tinai_v, siru_v, naz_v),
        scene=scene_line(tinai_v, perum_v, siru_v, naz_v),
        source="forced" if forced else "auto",
        tinai_source=tinai_source,
    )


def state_to_dict(state: TamilState) -> Dict[str, Any]:
    d = asdict(state)
    d["perum_label"] = PERUM_LABEL[state.perum]
    d["siru_label"] = SIRU_LABEL[state.siru]
    d["tinai_meta"] = dict(TINAI_META[state.tinai])
    d["nazhigai_of_day"] = nazhigai_of_day(state.hour, state.minute)
    return d
