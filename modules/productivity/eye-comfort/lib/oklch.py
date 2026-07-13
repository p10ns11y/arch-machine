"""Minimal OKLCH ↔ sRGB helpers (stdlib only) for eye-comfort tokens."""
from __future__ import annotations

import math
from typing import Tuple


def _clamp01(x: float) -> float:
    return 0.0 if x < 0.0 else 1.0 if x > 1.0 else x


def srgb_channel_to_linear(c: float) -> float:
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def linear_to_srgb_channel(c: float) -> float:
    c = _clamp01(c)
    return 12.92 * c if c <= 0.0031308 else 1.055 * (c ** (1.0 / 2.4)) - 0.055


def hex_to_srgb(hex_color: str) -> Tuple[float, float, float]:
    h = hex_color.lstrip("#")
    if len(h) != 6:
        raise ValueError(f"expected #RRGGBB, got {hex_color!r}")
    r, g, b = int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)
    return r / 255.0, g / 255.0, b / 255.0


def srgb_to_hex(r: float, g: float, b: float) -> str:
    ri = int(round(_clamp01(r) * 255))
    gi = int(round(_clamp01(g) * 255))
    bi = int(round(_clamp01(b) * 255))
    return f"#{ri:02X}{gi:02X}{bi:02X}"


def srgb_to_oklab(r: float, g: float, b: float) -> Tuple[float, float, float]:
    lr, lg, lb = srgb_channel_to_linear(r), srgb_channel_to_linear(g), srgb_channel_to_linear(b)
    l_ = math.pow(0.4122214708 * lr + 0.5363325363 * lg + 0.0514459929 * lb, 1 / 3)
    m_ = math.pow(0.2119034982 * lr + 0.6806995451 * lg + 0.1073969566 * lb, 1 / 3)
    s_ = math.pow(0.0883024619 * lr + 0.2817188376 * lg + 0.6299787005 * lb, 1 / 3)
    L = 0.2104542553 * l_ + 0.7936177850 * m_ - 0.0040720468 * s_
    a = 1.9779984951 * l_ - 2.4285922050 * m_ + 0.4505937099 * s_
    b_ = 0.0259040371 * l_ + 0.7827717662 * m_ - 0.8086757660 * s_
    return L, a, b_


def oklab_to_srgb(L: float, a: float, b_: float) -> Tuple[float, float, float]:
    l_ = L + 0.3963377774 * a + 0.2158037573 * b_
    m_ = L - 0.1055613458 * a - 0.0638541728 * b_
    s_ = L - 0.0894841775 * a - 1.2914855480 * b_
    l, m, s = l_ * l_ * l_, m_ * m_ * m_, s_ * s_ * s_
    lr = +4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s
    lg = -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s
    lb = -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s
    return linear_to_srgb_channel(lr), linear_to_srgb_channel(lg), linear_to_srgb_channel(lb)


def oklab_to_oklch(L: float, a: float, b_: float) -> Tuple[float, float, float]:
    C = math.sqrt(a * a + b_ * b_)
    H = math.degrees(math.atan2(b_, a)) % 360.0
    return L, C, H


def oklch_to_oklab(L: float, C: float, H: float) -> Tuple[float, float, float]:
    hr = math.radians(H)
    return L, C * math.cos(hr), C * math.sin(hr)


def oklch_to_hex(L: float, C: float, H: float) -> str:
    return srgb_to_hex(*oklab_to_srgb(*oklch_to_oklab(L, C, H)))


def hex_to_oklch(hex_color: str) -> Tuple[float, float, float]:
    return oklab_to_oklch(*srgb_to_oklab(*hex_to_srgb(hex_color)))


def relative_luminance_hex(hex_color: str) -> float:
    r, g, b = hex_to_srgb(hex_color)
    R, G, B = srgb_channel_to_linear(r), srgb_channel_to_linear(g), srgb_channel_to_linear(b)
    return 0.2126 * R + 0.7152 * G + 0.0722 * B


def contrast_ratio(fg: str, bg: str) -> float:
    L1, L2 = relative_luminance_hex(fg), relative_luminance_hex(bg)
    lighter, darker = max(L1, L2), min(L1, L2)
    return (lighter + 0.05) / (darker + 0.05)
