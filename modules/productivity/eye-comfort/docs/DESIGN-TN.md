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

**Perum** (approx Gregorian mid-month): Iḷavēṉil mid-Apr→Jun · Mutuvēṉil →Aug ·
Kār →Oct · Kuḷir →Dec · Muṉpaṉi →Feb · Piṉpaṉi →Apr.

**Ciṟu:** 02–06 viṭiyal · 06–10 kālai · 10–14 naṇpakal · 14–18 eṟpāṭu ·
18–22 mālai · 22–02 yāmam.

**Jāmam / cāmam (design grid):** 8 × 3 h watches from the viṭiyal epoch (02:00),
not live astronomy. Each Ciṟu (4 h ≈ 10 Nāḻikai) overlaps the 3 h grid as
**7.5+2.5**, **5+5**, or **2.5+7.5** Nāḻikai (1 Nāḻikai ≈ 24 min; ISO 15919 display —
API field remains `nazhigai`). Scene lines use the term **jāmam** (API `jaamam`;
synonym of **cāmam** / saamam; distinct from Ciṟu *Yāmam*). Example:
`Viṭiyal · jāmam 1 (full) + jāmam 2 (2.5 nāḻikai) · Running Nāḻikai …`.

Bar / tooltip Title Case ISO tiṇai and ciṟu (`Marutam · Yāmam · N3`). Tiṇai line is
landscape gloss + tiṇai once (`Plains — Marutam`), not a flower/id echo.

## ISO 15919 glossary (display)

API / CLI / package ids stay ASCII (`tinai`, `kurinji`, `nazhigai`, `jaamam`, …).
User-facing copy uses ISO 15919:

| Role | Tamil | API id | ISO 15919 |
|------|-------|--------|-----------|
| Landscape class | திணை | `tinai` | tiṇai |
| Season class | பெரும்(பொழுது) | `perum` | perum (poḻutu) |
| Day-part class | சிறு(பொழுது) | `siru` | ciṟu (poḻutu) |
| Time unit | நாழிகை | `nazhigai` | nāḻikai |
| 3 h watch | ஜாமம் / சாமம் | `jaamam` | jāmam / cāmam |
| Mountains | குறிஞ்சி | `kurinji` | kuṟiñci |
| Forest | முல்லை | `mullai` | mullai |
| Plains | மருதம் | `marutham` | marutam |
| Seashore | நெய்தல் | `neythal` | neytal |
| Wasteland | பாலை | `palai` | pālai |
| Early summer | இளவேனில் | `ila_venil` | iḷavēṉil |
| Harsh summer | முதுவேனில் | `mudhu_venil` | mutuvēṉil |
| Monsoon | கார் | `kar` | kār |
| Cool | குளிர் | `kulir` | kuḷir |
| Early dew | முன்பனி | `munpani` | muṉpaṉi |
| Late dew | பின்பனி | `pinpani` | piṉpaṉi |
| Dawn | விடியல் / வைகறை | `vidiyal` | viṭiyal / vaikaṟai |
| Morning | காலை | `kaalai` | kālai |
| Midday | நண்பகல் | `nanpagal` | naṇpakal |
| Afternoon | எற்பாடு | `erpaadu` | eṟpāṭu |
| Evening | மாலை | `maalai` | mālai |
| Night (ciṟu) | யாமம் | `yaamam` | yāmam |
| Stage matter | கருப்பொருள் | (docs) | karupporuḷ |
| Mood matter | உரிப்பொருள் | (docs) | uripporuḷ |

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
