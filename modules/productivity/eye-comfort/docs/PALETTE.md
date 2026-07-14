# Eye-comfort palette — source of truth

Vision-science circadian themes for Omarchy (`eye-comfort-dawn`, `eye-comfort-light`, `eye-comfort-dusk`, `eye-comfort-dark`).  
Hosts: Ghostty, nvim, Yazi; OS surfaces via Omarchy templates from `colors.toml`.

**Principles (binding):** perceptual uniformity (OKLCH), smart contrast (no pure black/white), warm dark for night (less blue / melatonin-friendly), balanced luminance, low–medium saturation except Error/Warning, semantic color only.

**Schedule:** seven phases — dawn · morning · midday · afternoon · dusk · evening · night.  
Fixed local windows (no `--lat`): dawn 05–07, morning 07–10, midday 10–14, afternoon 14–17, dusk 17–19, evening 19–22, night 22–05.  
With `--lat`, boundaries track approximate sunrise/sunset. Override: `eye-comfort-theme --phase …` or `--hour`.

**Fonts:** Ghostty uses `JetBrainsMono Nerd Font` @ 10 with ligatures; Omarchy system font is often `CaskaydiaMono Nerd Font`.

**Hardware CCT:** optional `hyprsunset` companion — phase CCT hints in `state.json` (`cct_k`). Theme colors already bias warm; do not stack extreme red without an easy off path.

**Tokens:** OKLCH CSS mirrors in `tokens/phases.css`; live resolve via `eye-comfort-theme --css`.

---

## Packages ↔ phases

| Package | Phases | Scene |
|---------|--------|-------|
| `eye-comfort-dawn` | dawn | Peach-linen first light |
| `eye-comfort-light` | morning, midday, afternoon | Soft cream day (midday hex-locked) |
| `eye-comfort-dusk` | dusk | Residual-gold transitional dark |
| `eye-comfort-dark` | evening, night | Warm umber lamp / deepest night (night hex-locked) |

Live apply re-renders role hexes into the active package so morning ≠ midday ≠ afternoon within `eye-comfort-light`.

---

## Dark Mode (`eye-comfort-dark` / night)

Warm off-black UI for long evening sessions. Background R > B (warmer than cool blue-blacks such as ethereal `#060B1E`).

| Role | Hex | OKLCH (approx) | Vision justification |
|------|-----|----------------|----------------------|
| **Background** | `#181614` | L≈0.20 C≈0.005 H≈67° | Slightly warm off-black; avoids pure `#000` veiling glare; low blue supports evening melatonin. |
| **Foreground** | `#E6DFD3` | L≈0.91 C≈0.018 H≈81° | Soft warm parchment; contrast ≈ **13.6:1** on bg. |
| **Selection** | `#2F2924` | L≈0.29 | Elevated warm surface. |
| **Comment** | `#8A8278` | L≈0.61 | Secondary ≥ ~4.5:1. |
| **Accent sage** | `#7D9A8C` | L≈0.66 C≈0.039 H≈164° | Restful structure. |
| **Accent amber** | `#C9A66B` | L≈0.74 C≈0.087 H≈80° | Attention / cursor. |
| **Accent clay** | `#A88B6E` | L≈0.66 C≈0.054 H≈67° | Tertiary harmony. |
| **Error** | `#C47064` | L≈0.64 C≈0.109 H≈29° | Semantic critical. |
| **Warning** | `#D4A05A` | L≈0.74 C≈0.107 H≈73° | Semantic caution. |

---

## Light Mode (`eye-comfort-light` / midday)

Soft cream day mode for indoor daylight hours (not pure white).

| Role | Hex | OKLCH (approx) | Vision justification |
|------|-----|----------------|----------------------|
| **Background** | `#F5F0E8` | L≈0.96 C≈0.012 H≈80° | Soft cream; lowers glare vs `#FFFFFF`. |
| **Foreground** | `#2A2622` | L≈0.27 C≈0.009 H≈67° | Warm charcoal; ≈ **13.2:1**. |
| **Selection** | `#E0D9CE` | L≈0.89 | Gentle paper elevation. |
| **Comment** | `#6E665C` | mid | Secondary ≈ **5.0:1**. |
| **Accent sage** | `#4A6B5C` | mid | Darker sage on paper. |
| **Accent amber** | `#8A6030` | mid | Types/constants. |
| **Accent clay** | `#8B6B4E` | mid | Keyword harmony. |
| **Error** | `#B54A40` | higher C | Critical on cream. |
| **Warning** | `#8B6020` | higher C | Caution. |

---

## Dawn (`eye-comfort-dawn`)

Peach-linen first light — lower glare than noon cream, rose-peach hue (~52°), still ≥4.5:1 body contrast. Generated from OKLCH SoT (`lib/palette.py`); see `themes/eye-comfort-dawn/colors.toml`.

## Dusk (`eye-comfort-dusk`)

Residual-gold transitional dark — lighter L than night umber (~0.275), warmer amber accents for the lamp-just-on window. See `themes/eye-comfort-dusk/colors.toml`.

---

## Ambient & intensity

| Flag | Effect |
|------|--------|
| `--indoor` | Slightly warmer surfaces (default for evening/night auto) |
| `--outdoor` | Less washed day paper; deeper ink for sun glare |
| `--intensity soft` | Gentler contrast (still ≥4.5:1) |
| `--intensity crisp` / `--high-contrast` | Stronger ink / surface separation |
| `--no-dynamic` | Collapse to light vs dark packages only |

---

## Role → ANSI map (all packages)

| Role | Field |
|------|--------|
| Background / Foreground | `background` / `foreground` |
| Selection | `selection_background` / `selection_foreground` |
| Comment | `color8` |
| Accent sage | `accent`, `color2` |
| Accent amber | `cursor` (all packages — attention focal), `color3` |
| Success-adjacent | `accent_sage`, `color2`, `color10` |
| Accent clay | `color5` |
| Error | `color1` |
| Warning | `color11` |
| Warm slate (not cyber blue) | `color4`, `color12` |
| Soft teal | `color6`, `color14` |

---

## Apply

```bash
omarchy-theme-set eye-comfort-dark
omarchy-theme-set eye-comfort-light
omarchy-theme-set eye-comfort-dawn
omarchy-theme-set eye-comfort-dusk
eye-comfort-theme                    # auto by local hour
eye-comfort-theme --phase evening --indoor
eye-comfort-theme auto --lat 28.6
HOUR=22 eye-comfort-theme --dry-run
eye-comfort-theme --help
```

Optional hourly timer:

```bash
systemctl --user enable --now eye-comfort-theme.timer
```

Design context: [PRODUCT.md](./PRODUCT.md) · [DESIGN.md](./DESIGN.md)
