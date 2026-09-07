"""Waybar / notify / Omarchy-shell payloads for eye-comfort (TN + circadian).

Compact bar text; rich tooltip acts as the lightweight “extra widget”.
Reads last apply from state.json when present; live-resolves clock fields.

Waybar GTK tooltips accept Pango markup. Omarchy 4 Quickshell command-module
tooltips are plain text — tags render literally — so default is auto: Pango
only while a `waybar` process is running (override with EYE_COMFORT_TOOLTIP).
"""
from __future__ import annotations

import json
import os
import re
import shutil
import subprocess
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, List, Optional

from tamil_schedule import (
    JAAMAM_DISPLAY_TITLE,
    JAAMAMS_PER_DAY,
    NAZHIGAI_DISPLAY,
    NAZHIGAI_DISPLAY_TITLE,
    NAZHIGAI_MINUTES,
    NAZHIGAIS_PER_SIRU,
    PERUM_DISPLAY_TITLE,
    PERUM_LABEL,
    POZHUTU_DISPLAY_TITLE,
    SIRU_DISPLAY_TITLE,
    SIRU_LABEL,
    TINAI_DISPLAY_TITLE,
    TINAI_META,
    nazhigai_ordinal,
    resolve_tamil,
    siru_display,
    tinai_display,
)

# Tooltip Pango spans — DESIGN.md locks. Dark tokens wash out on cream paper
# (~2:1); pick palette from surface (roles.background / light.mode).
_PANGO_DARK = {
    "accent": "#C9A66B",  # dark-amber on umber
    "muted": "#8A8278",
    "soft": "#A89F94",
}
_PANGO_LIGHT = {
    "accent": "#885920",  # light-amber on cream ≥5:1
    "muted": "#72685E",  # comment ink ≥4.5:1
    "soft": "#6E665C",
}
_ACTIVE_PANGO = dict(_PANGO_DARK)
_STRIP_PANGO = re.compile(r"</?[^>]+>")
_LIGHT_MODE_PATH = Path.home() / ".config" / "omarchy" / "current" / "theme" / "light.mode"


def default_state_path() -> Path:
    return Path.home() / ".config" / "eye-comfort" / "state.json"


def _hex_rel_luminance(hex_color: str) -> Optional[float]:
    """sRGB relative luminance, or None if not a #RRGGBB color."""
    h = hex_color.strip().lstrip("#")
    if len(h) != 6:
        return None
    try:
        r, g, b = (int(h[i : i + 2], 16) / 255.0 for i in (0, 2, 4))
    except ValueError:
        return None

    def lin(c: float) -> float:
        return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4

    R, G, B = lin(r), lin(g), lin(b)
    return 0.2126 * R + 0.7152 * G + 0.0722 * B


def surface_is_light(state: Optional[Dict[str, Any]] = None) -> bool:
    """True when tooltip/bar paper is day cream (not umber night).

    Prefer live roles.background from state.json; fall back to Omarchy light.mode.
    """
    st = state if state is not None else {}
    roles = st.get("roles")
    if isinstance(roles, dict):
        bg = roles.get("background")
        if isinstance(bg, str):
            L = _hex_rel_luminance(bg)
            if L is not None:
                # Midpoint: cream ~0.9, umber night ~0.05
                return L >= 0.45
    try:
        if _LIGHT_MODE_PATH.is_file():
            return True
    except OSError:
        pass
    return False


def activate_pango_surface(state: Optional[Dict[str, Any]] = None) -> Dict[str, str]:
    """Select light/dark span colors for the next tooltip build; return active map."""
    global _ACTIVE_PANGO
    _ACTIVE_PANGO = dict(_PANGO_LIGHT if surface_is_light(state) else _PANGO_DARK)
    return dict(_ACTIVE_PANGO)


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
    """Drop Pango tags for notify-send / CLI / Quickshell; keep newlines and wording."""
    return (
        _STRIP_PANGO.sub("", markup)
        .replace("&amp;", "&")
        .replace("&lt;", "<")
        .replace("&gt;", ">")
    )


def wants_pango_tooltip() -> bool:
    """True when the bar host parses Pango (Waybar); False for Omarchy shell."""
    env = (os.environ.get("EYE_COMFORT_TOOLTIP") or "").strip().lower()
    if env in ("plain", "text", "none", "0", "false", "no"):
        return False
    if env in ("pango", "markup", "waybar", "1", "true", "yes"):
        return True
    pgrep = shutil.which("pgrep")
    if not pgrep:
        return False
    try:
        completed = subprocess.run(
            [pgrep, "-x", "waybar"],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            check=False,
        )
        return completed.returncode == 0
    except OSError:
        return False


def finalize_tooltip(markup: str, *, plain: Optional[bool] = None) -> str:
    """Return tooltip text for the active bar host."""
    use_plain = wants_pango_tooltip() is False if plain is None else plain
    if not use_plain:
        return markup
    return _plain_from_pango(markup).lstrip("\n")


def _visible_width(markup: str) -> int:
    """Plain-text length of one Pango line (for optical layout)."""
    return len(_plain_from_pango(markup))


def _center_first_content_line(lines: List[str]) -> List[str]:
    """Pad the first non-empty line so it sits under the widest body line.

    Waybar GTK tooltips are one Label (no per-line CSS). Do not use
    text-align / line-height in tooltip CSS — GTK rejects some props and
    aborts Waybar. Leading spaces only center the date; body stays left.
    """
    widths = [_visible_width(ln) for ln in lines if ln.strip()]
    if not widths:
        return lines
    target = max(widths)
    out = list(lines)
    for i, ln in enumerate(out):
        if not ln.strip():
            continue
        pad = max(0, (target - _visible_width(ln)) // 2)
        if pad:
            out[i] = (" " * pad) + ln
        break
    return out


def _muted(text: str) -> str:
    return f'<span foreground="{_ACTIVE_PANGO["muted"]}">{text}</span>'


def _soft(text: str) -> str:
    return f'<span foreground="{_ACTIVE_PANGO["soft"]}">{text}</span>'


def _accent_b(text: str) -> str:
    # Avoid nested <b> + missing Medium face: weight 700 when available, else Regular
    return (
        f'<span foreground="{_ACTIVE_PANGO["accent"]}" '
        f'font_weight="700">{text}</span>'
    )


def _date_line(now: datetime) -> str:
    """Civil date + ISO week — never glued to tinai/siru."""
    week = now.isocalendar()[1]
    return f"{now.day} {now.strftime('%B')}  ·  week {week}  ·  {now.year}"


def _jaamam_part_sense(part: Any) -> str:
    if part.full:
        return "full watch · 3 h"
    mins = int(round(part.nazhigai * NAZHIGAI_MINUTES))
    amount = (
        f"{int(round(part.nazhigai))}"
        if abs(part.nazhigai - round(part.nazhigai)) < 1e-9
        else f"{part.nazhigai:g}"
    )
    return (
        f"{amount} {NAZHIGAI_DISPLAY} · ≈{mins} min in this {SIRU_DISPLAY_TITLE}"
    )


def _jaamam_heart_lines(tn: Any) -> List[str]:
    """Living clock heart — current watch + Ciṟu split narrative (Pango)."""
    jam = tn.jaamam
    lines = [
        _accent_b(JAAMAM_DISPLAY_TITLE),
        f"  Watching <b>{jam.current}</b> of {JAAMAMS_PER_DAY}",
        f"  {_soft('Split')}  ·  {_pango_esc(jam.label)}",
        _soft(f"  This {SIRU_DISPLAY_TITLE} holds —"),
    ]
    for part in jam.parts:
        sense = _pango_esc(_jaamam_part_sense(part))
        name = f"{JAAMAM_DISPLAY_TITLE} {part.index}"
        if part.index == jam.current:
            lines.append(f"    <b>{_pango_esc(name)}</b>  —  {sense}")
        else:
            lines.append(f"    {_muted(_pango_esc(name))}  —  {sense}")
    return lines


def _nazhigai_heart_lines(tn: Any) -> List[str]:
    """Nāḻikai as elapsed pulse inside the current Ciṟu (Pango; 1-based ordinal)."""
    index = tn.nazhigai  # 0-based storage
    ordinal = nazhigai_ordinal(index)
    into_min = index * NAZHIGAI_MINUTES
    siru_title = _pango_esc(siru_display(tn.siru))
    unit = NAZHIGAI_DISPLAY
    if ordinal == 1:
        detail = f"first {NAZHIGAI_MINUTES} minutes of this {SIRU_DISPLAY_TITLE}"
    elif ordinal == 2:
        detail = f"after {into_min} minutes, first {unit} over"
    else:
        detail = f"after {into_min} minutes, first {ordinal - 1} {unit} over"
    return [
        _accent_b(NAZHIGAI_DISPLAY_TITLE),
        (
            f"  Running {NAZHIGAI_DISPLAY_TITLE} <b>{ordinal}</b>"
            f"  ·  {ordinal} of {NAZHIGAIS_PER_SIRU} into {siru_title}"
        ),
        _soft(f"  {_pango_esc(detail)}"),
    ]


def _char_columns(char: str) -> int:
    """Monospace cells for one code point. Tamil fallback glyphs run wide in Qt."""
    import unicodedata

    if unicodedata.combining(char):
        return 0
    code = ord(char)
    if 0x0B80 <= code <= 0x0BFF:
        return 2
    east = unicodedata.east_asian_width(char)
    return 2 if east in ("F", "W") else 1


def _display_width(text: str) -> int:
    """Columns for layout; skip combining marks; Tamil and East-Asian wide = 2."""
    return sum(_char_columns(char) for char in text)


# Quickshell Text.AlignHCenter ignores trailing Unicode whitespace (QTextOption).
# Braille blank is a symbol, so it keeps line width and the block stays flush-left.
_QT_PAD = "\u2800"
_FIBONACCI = (1, 2, 3, 5, 8, 13, 21, 34, 55, 89)
_GAP_MINOR = 1
_GAP_CADENCE = 2


def _fib_ceil(columns: int) -> int:
    """Next Fibonacci width ≥ columns (circadian tip band)."""
    for fib in _FIBONACCI:
        if fib >= columns:
            return fib
    return columns


def _pad_right(text: str, width: int, fill: str = " ") -> str:
    extra = max(0, width - _display_width(text))
    return text + (fill * extra)


def _gaps(count: int) -> List[str]:
    return [""] * count


def _detail(text: str) -> str:
    return f"  {text}"


def _justify_block(lines: List[str], band: int) -> List[str]:
    """Pad every non-empty line to `band` so AlignHCenter keeps a flush left edge."""
    out: List[str] = []
    for line in lines:
        if not line:
            out.append("")
        else:
            out.append(_pad_right(line, band, _QT_PAD))
    return out


def _rule(band: int) -> str:
    return "─" * band


# Landscape glyphs — 5-line motifs, stretched to the copy column height.
_TINAI_ASCII: Dict[str, tuple[str, ...]] = {
    "kurinji": (  # mountains
        "   /\\    /\\",
        "  /  \\  /  \\",
        " /    \\/    \\",
        "/      \\      \\",
        "‾‾‾‾‾‾‾‾‾‾‾‾‾‾",
    ),
    "mullai": (  # forest
        "  Y  Y  Y  Y",
        " /|\\/|\\/|\\/|\\",
        " /|\\/|\\/|\\/|\\",
        " /|\\/|\\/|\\/|\\",
        "‾‾‾‾‾‾‾‾‾‾‾‾‾",
    ),
    "marutham": (  # plains / fields
        "·  ·  ·  ·  ·",
        "~~~~~~~~~~~~~",
        "=============",
        "~~~~~~~~~~~~~",
        "_____________",
    ),
    "neythal": (  # seashore
        "   ~    ~",
        " ~~  ~~  ~~",
        "~  ~~  ~~  ~",
        " ~~  ~~  ~~",
        "~~~~~~~~~~~~",
    ),
    "palai": (  # wasteland / dune
        "    .",
        " .     .",
        "    .",
        "~=~=~=~=~=~",
        "~~~~~~~~~~~",
    ),
}


def _tinai_ascii(tinai: str) -> List[str]:
    motif = list(_TINAI_ASCII.get(tinai) or _TINAI_ASCII["marutham"])
    width = max(_display_width(line) for line in motif)
    return [_pad_right(line, width) for line in motif]


def _latin_gloss(label: str) -> str:
    """Latin-only form of a Perum/Ciṟu label (tests / fallback)."""
    stripped = "".join(
        char for char in label if not (0x0B80 <= ord(char) <= 0x0BFF)
    )
    return " ".join(stripped.split())


def _flow_gloss(label: str) -> str:
    """Keep Tamil + Latin; soften arrows, tildes, and time-range glue."""
    text = " ".join(label.split())
    text = text.replace("→", " into ")
    text = text.replace("~", "")
    text = text.replace("/", " / ")
    text = " ".join(text.split())
    return re.sub(r"\s+(\d{1,2}–\d{1,2})$", r", \1", text)


def _field(label: str, value: str, label_width: int) -> str:
    """Labeled detail in the text column (internal spaces; Qt counts those)."""
    return f"{_pad_right(label, label_width)}  {value}"


def _nazhigai_amount(part: Any) -> str:
    if abs(part.nazhigai - round(part.nazhigai)) < 1e-9:
        return f"{int(round(part.nazhigai))}"
    return f"{part.nazhigai:g}"


def _count_words(count: int) -> str:
    words = {
        1: "one",
        2: "two",
        3: "three",
        4: "four",
        5: "five",
        6: "six",
        7: "seven",
        8: "eight",
        9: "nine",
        10: "ten",
    }
    return words.get(count, str(count))


def _jaamam_sentences(jam: Any) -> List[str]:
    sentences = [f"Watching {jam.current} of {JAAMAMS_PER_DAY}."]
    for part in jam.parts:
        if part.full:
            sentences.append(f"Jāmam {part.index} is a full watch (3 hours).")
            continue
        amount = _nazhigai_amount(part)
        minutes = int(round(part.nazhigai * NAZHIGAI_MINUTES))
        sentences.append(
            f"Jāmam {part.index} holds {amount} {NAZHIGAI_DISPLAY} "
            f"(about {minutes} minutes in this {SIRU_DISPLAY_TITLE})."
        )
    return sentences


def _nazhigai_sentences(tn: Any) -> List[str]:
    ordinal = nazhigai_ordinal(tn.nazhigai)
    siru_title = siru_display(tn.siru)
    elapsed_minutes = tn.nazhigai * NAZHIGAI_MINUTES
    sentences = [f"{ordinal} of {NAZHIGAIS_PER_SIRU} into {siru_title}."]
    if ordinal == 1:
        sentences.append(
            f"The first {NAZHIGAI_MINUTES} minutes of this {SIRU_DISPLAY_TITLE}."
        )
    elif ordinal == 2:
        sentences.append(
            f"After {elapsed_minutes} minutes, the first {NAZHIGAI_DISPLAY} is over."
        )
    else:
        finished = ordinal - 1
        verb = "is" if finished == 1 else "are"
        sentences.append(
            f"After {elapsed_minutes} minutes, the first "
            f"{_count_words(finished)} {NAZHIGAI_DISPLAY} {verb} over."
        )
    return sentences


def tn_tooltip_plain(
    tn: Any, now: datetime, *, state: Optional[Dict[str, Any]] = None
) -> str:
    """Plain tooltip: landscape motif on top, calendar sentences below."""
    del state
    meta = TINAI_META[tn.tinai]
    landscape = meta["landscape"].title()
    tinai_name = tinai_display(tn.tinai)
    jam = tn.jaamam
    date = _date_line(now)
    field_width = max(
        _display_width(PERUM_DISPLAY_TITLE),
        _display_width(SIRU_DISPLAY_TITLE),
    )

    copy: List[str] = [
        TINAI_DISPLAY_TITLE,
        f"  {landscape} — {tinai_name}",
        "",
        POZHUTU_DISPLAY_TITLE,
        f"  {_field(PERUM_DISPLAY_TITLE, _flow_gloss(PERUM_LABEL[tn.perum]), field_width)}",
        f"  {_field(SIRU_DISPLAY_TITLE, _flow_gloss(SIRU_LABEL[tn.siru]), field_width)}",
        "",
        JAAMAM_DISPLAY_TITLE,
        *[f"  {sentence}" for sentence in _jaamam_sentences(jam)],
        "",
        NAZHIGAI_DISPLAY_TITLE,
        *[f"  {sentence}" for sentence in _nazhigai_sentences(tn)],
    ]
    copy_width = max(
        (_display_width(line) for line in copy if line.strip()),
        default=0,
    )
    even_copy = [
        "" if not line.strip() else _pad_right(line, copy_width, _QT_PAD)
        for line in copy
    ]
    art = _tinai_ascii(str(tn.tinai))
    theme_line = f"Theme  {tn.theme}"

    composed: List[str] = [
        date,
        _rule(copy_width),
        *art,
        "",
        *even_copy,
        _rule(copy_width),
        theme_line,
    ]
    return "\n".join(composed)




def tn_tooltip_markup(
    tn: Any, now: datetime, *, state: Optional[Dict[str, Any]] = None
) -> str:
    """Pango tooltip: date → Tiṇai → Poḻutu → Jāmam/Nāḻikai heart → Theme."""
    activate_pango_surface(state)
    meta = TINAI_META[tn.tinai]
    date = _pango_esc(_date_line(now))
    landscape = _pango_esc(meta["landscape"].title())
    tinai_name = _pango_esc(tinai_display(tn.tinai))
    perum_label = _pango_esc(PERUM_LABEL[tn.perum])
    siru_label = _pango_esc(SIRU_LABEL[tn.siru])
    theme = _pango_esc(tn.theme)

    lines: List[str] = [
        "",
        _accent_b(date),
        "",
        f"<b>{TINAI_DISPLAY_TITLE}</b>",
        # Landscape gloss + tiṇai once (no flower echo, no tinai_source leak).
        f"  {landscape}  —  {tinai_name}",
        "",
        f"<b>{POZHUTU_DISPLAY_TITLE}</b>",
        f"  {_muted(PERUM_DISPLAY_TITLE)}  {perum_label}",
        f"  {_muted(SIRU_DISPLAY_TITLE)}   {siru_label}",
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
    return "\n".join(_center_first_content_line(lines))


def circadian_tooltip_plain(
    state: Dict[str, Any], now: datetime
) -> str:
    """Plain circadian tooltip — same Fibonacci band + φ rhythm as TN."""
    phase = str(state.get("phase") or "unknown")
    theme = str(state.get("theme") or "eye-comfort")
    scene = str(state.get("scene") or "")
    date = _date_line(now)
    body = ["Phase", _detail(phase)]
    if scene:
        body.append(_detail(scene))
    if state.get("cct_k") is not None:
        body.append(_detail(f"≈{state['cct_k']}K"))
    theme_block = ["Theme", _detail(theme)]
    measure = [date, *body, *theme_block]
    band = _fib_ceil(max(_display_width(line) for line in measure if line.strip()))
    composed = [
        date,
        *_gaps(_GAP_MINOR),
        _rule(band),
        *_gaps(_GAP_MINOR),
        *body,
        *_gaps(_GAP_CADENCE),
        _rule(band),
        *_gaps(_GAP_MINOR),
        *theme_block,
    ]
    return "\n".join(_justify_block(composed, band))



def tn_waybar_payload(
    *,
    state: Optional[Dict[str, Any]] = None,
    now: Optional[datetime] = None,
    plain_tooltip: Optional[bool] = None,
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
    # Compact bar: ISO 15919 Title Case · N{ordinal} (1-based). Storage stays 0-based.
    text = (
        f"{tinai_display(tn.tinai)} · {siru_display(tn.siru)} · "
        f"N{nazhigai_ordinal(tn.nazhigai)}"
    )
    use_plain = wants_pango_tooltip() is False if plain_tooltip is None else plain_tooltip
    if use_plain:
        tooltip = tn_tooltip_plain(tn, now, state=st)
    else:
        tooltip = tn_tooltip_markup(tn, now, state=st)
    return {
        "text": text,
        "tooltip": tooltip,
        "class": f"eye-comfort-tn eye-comfort-{tn.siru}",
        "alt": "tn",
        "percentage": tn.nazhigai * 10,
    }


def circadian_waybar_payload(
    state: Dict[str, Any],
    now: Optional[datetime] = None,
    *,
    plain_tooltip: Optional[bool] = None,
) -> Dict[str, Any]:
    now = now or datetime.now()
    phase = str(state.get("phase") or "unknown")
    theme = str(state.get("theme") or "eye-comfort")
    scene = str(state.get("scene") or "")
    text = f"{phase}"
    use_plain = wants_pango_tooltip() is False if plain_tooltip is None else plain_tooltip
    if use_plain:
        tooltip = circadian_tooltip_plain(state, now)
    else:
        activate_pango_surface(state)
        date = _pango_esc(_date_line(now))
        scene_e = _pango_esc(scene) if scene else ""
        theme_e = _pango_esc(theme)
        phase_e = _pango_esc(phase)
        lines = [
            "",
            _accent_b(date),
            "",
            f'<span font_weight="700">{phase_e}</span>',
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
        tooltip = "\n".join(_center_first_content_line(lines))
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
    plain_tooltip: Optional[bool] = None,
) -> Dict[str, Any]:
    st = load_state(state_path)
    if force_tn or _is_tn(st) or not st:
        try:
            return tn_waybar_payload(
                state=st, now=now, plain_tooltip=plain_tooltip
            )
        except (ValueError, RuntimeError) as e:
            err_markup = f"eye-comfort waybar error: {_pango_esc(e)}"
            return {
                "text": "eye-comfort?",
                "tooltip": finalize_tooltip(err_markup, plain=plain_tooltip),
                "class": "eye-comfort-error",
                "alt": "error",
            }
    return circadian_waybar_payload(
        st, now=now, plain_tooltip=plain_tooltip
    )


def status_text(*, state_path: Optional[Path] = None, now: Optional[datetime] = None) -> str:
    """Human one-liner + scene for `eye-comfort-theme status` (plain text)."""
    payload = waybar_payload(state_path=state_path, now=now)
    # lstrip drops optical date pad + leading blank lines from the tooltip.
    return f"{payload['text']}\n{_plain_from_pango(payload['tooltip']).lstrip()}"


def notify_body(*, state_path: Optional[Path] = None, now: Optional[datetime] = None) -> str:
    """Body for notify-send (plain; click action / second widget surface)."""
    return _plain_from_pango(waybar_payload(state_path=state_path, now=now)["tooltip"]).lstrip()
