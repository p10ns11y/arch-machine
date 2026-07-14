---
name: Eye Comfort Tamil Nadu
description: Tinai landscape packages + Perum/Siru schedule on the eye-comfort OKLCH bar
colors:
  marutham-bg: "#F5F0E8"
  neythal-lean: "warm sand + water-lily teal H≈190"
  kurinji-night: "mountain mist dusk — warm dark"
  palai-midday: "dry ochre heat paper"
  mullai-evening: "jasmine forest dusk"
typography:
  terminal:
    fontFamily: "JetBrainsMono Nerd Font"
    fontSize: "10"
---

# Design System — Eye Comfort · Tamil Nadu

Additive overlay on [DESIGN.md](./DESIGN.md). Product slice: [PRODUCT-TN.md](./PRODUCT-TN.md).

## Theme

| Package | Tinai | Landscape | Canonical Siru (baked) | Scene |
|---------|-------|-----------|------------------------|--------|
| `eye-comfort-tn-kurinji` | Kurinji | mountains | yaamam | mist ridges · night union |
| `eye-comfort-tn-mullai` | Mullai | forest | maalai | jasmine dusk · waiting |
| `eye-comfort-tn-marutham` | Marutham | plains | vidiyal | fertile dawn · plains |
| `eye-comfort-tn-neythal` | Neythal | seashore | erpaadu | sand · afternoon pining |
| `eye-comfort-tn-palai` | Palai | wasteland | nanpagal | dry ochre · endurance |

**Why tinai packages (not 6 seasonal packages):** landscape identity is stable;
Perum/Siru change luminance and hints the way morning≠midday already does inside
`eye-comfort-light`. Five packages keep Omarchy theme lists sane.

**Color strategy:** Restrained. Tinai shifts accent/bg hue leans ≤35–60% blend
toward landscape targets; never cool cyber blue (H≈230°) or SaaS cream as décor.

**Scene sentence:** Operator at a desk whose light follows Tamil Siru while
chrome stays museum-quiet — coastal Chennai afternoon or Nilgiri night, same AA ink.

## Colors

Base roles from circadian Siru→phase map:

| Siru | Phase mirror |
|------|----------------|
| vidiyal | dawn |
| kaalai | morning |
| nanpagal | midday |
| erpaadu | afternoon |
| maalai | dusk |
| yaamam | night |

Tinai then retargets sage/amber/clay/ANSI slate accents; Nazhigai 0–9 nudges
background L by ~±0.006. Validate: `PYTHONPATH=lib python3 lib/test_tamil_schedule.py`.

## Typography

Identical to parent (JetBrainsMono 10 / CaskaydiaMono system).

## Motion

Instant theme swaps. Nazhigai timer (~24 min) only soft-tints — no page choreography.
`--reduced-motion` still recorded in `state.json`.

## Components / hosts

Same render path (`colors.toml`, Ghostty, nvim). Yazi uses an install-only dual map (`eye-comfort-dark` / `eye-comfort-light`); no apply rematch — reopen after light↔dark if contrast looks wrong.
CLI: `eye-comfort-theme tn …` · `status` / `waybar`. State key `calendar: tamil_nadu`.
Opt-in Waybar: `waybar/module.jsonc` → `custom/eye-comfort` (bar + Pango tooltip + notify); CSS `waybar/eye-comfort.css` for chip gap + tooltip padding.

## Layout (wallpaper)

See each `themes/eye-comfort-tn-*/backgrounds/README.md`:

- Filename: `{tinai}-{siru}-{a|b}.jpg` (a = Nazhigai 0–4, b = 5–9)
- Karu Porul (14 elements) as composition hints, not mandatory icons
- Upper 30–40% quiet for floating terminals; calm lower third
- v1 may be README-only (no invented binary noise)

## Schedule & harden

**Perum** (approx Gregorian mid-month): Ila Venil mid-Apr→Jun · Mudhu Venil →Aug ·
Kār →Oct · Kulir →Dec · Munpani →Feb · Pinpani →Apr.

**Siru:** 02–06 vidiyal · 06–10 kaalai · 10–14 nanpagal · 14–18 erpaadu ·
18–22 maalai · 22–02 yaamam.

**Jaamam / saamam (design grid):** 8 × 3 h watches from the vidiyal epoch (02:00),
not live astronomy. Each Siru (4 h ≈ 10 Nazhigai) overlaps the 3 h grid as
**7.5+2.5**, **5+5**, or **2.5+7.5** Nāḻikai (1 Nāḻikai ≈ 24 min; ISO 15919 display —
API field remains `nazhigai`). Scene lines use the term **jaamam** (synonym of
saamam; distinct from Siru *Yaamam*). Example:
`Vidiyal · jaamam 1 (full) + jaamam 2 (2.5 nāḻikai) · Running Nāḻikai …`.

Bar / tooltip Title Case tinai and siru (`Marutham · Yaamam · N3`). Tinai line is
landscape gloss + tinai once (`Plains — Marutham`), not a flower/id echo.

**Tinai geo (v1 heuristic):**

| Cue | Tinai |
|-----|-------|
| lon ≳ 79.55°, TN lat band | neythal |
| lon ≲ 77.35° hills / Nilgiris | kurinji |
| Coimbatore foothills belt | mullai |
| dry interior + Mudhu Venil | palai |
| else / missing coords | marutham |

**Timers:** optional `--with-tn-timer` installs `eye-comfort-tn.timer`
(`OnCalendar=*:0/24`) calling `eye-comfort-theme tn`. Mutually exclusive with
the hourly circadian timer — `install.sh` disables the other on enable so they
cannot race `omarchy-theme-set`’s `current/theme` swap. Switcher keeps
OMARCHY_PATH + waybar restore (same harden as PR live-reload).

**Edge cases:** invalid tinai/siru/nazhigai → exit 2; missing theme dir → exit 1;
missing wallpaper hint → warn skip (no crash); extreme ambient softens via base
palette repair then light tinai blend.

## Do / Don't

**Do:** AA first; tinai via `--tinai` or simple geo; soft Nazhigai; document Karu Porul.  
**Don't:** fork cool cyber seas; decorate with temple chrome; 30 Omarchy packages;
edit `~/.local/share/omarchy/`.
