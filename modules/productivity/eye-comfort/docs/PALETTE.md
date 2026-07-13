# Eye-comfort palette — source of truth

Vision-science dark/light themes for Omarchy (`eye-comfort-dark`, `eye-comfort-light`).  
Hosts: Ghostty, Helix, Yazi; OS surfaces via Omarchy templates from `colors.toml`.

**Principles (binding):** perceptual uniformity (OKLCH thinking), smart contrast (no pure black/white), warm dark for night (less blue / melatonin-friendly), balanced luminance, low–medium saturation except Error/Warning, semantic color only.

**Schedule (default circadian):** light **07:00–17:59** local, dark **18:00–06:59**. Override: `eye-comfort-theme day|night|auto` or `HOUR=…`.

**Fonts:** Ghostty uses `JetBrainsMono Nerd Font` @ 10 with ligatures; Omarchy system font is often `CaskaydiaMono Nerd Font`. Keep monospaced code surfaces on one family per host; sizes stay local to Ghostty (theme files do not override font).

**Hardware CCT:** optional `hyprsunset` night profile (~4000K after ~20:00) is a display-level companion — see `hyprsunset.conf` comments. Theme colors already bias warm; do not stack extreme red without an easy off path.

---

## Dark Mode (`eye-comfort-dark`)

Warm off-black UI for long evening sessions. Background R > B (warmer than cool blue-blacks such as ethereal `#060B1E`).

| Role | Hex | OKLCH (approx) | Vision justification |
|------|-----|----------------|----------------------|
| **Background** | `#181614` | L≈0.20 C≈0.005 H≈67° | Slightly warm off-black; avoids pure `#000` veiling glare / high local contrast; low blue content supports evening melatonin. |
| **Foreground** | `#E6DFD3` | L≈0.91 C≈0.018 H≈81° | Soft warm parchment; avoids pure `#FFF` halation; contrast ≈ **13.6:1** on bg (well above WCAG AA 4.5:1). |
| **Selection** | `#2F2924` (bg) / `#E6DFD3` (fg) | L≈0.29 surface | Elevated warm surface, not inverted harsh flash; keeps fg luminance stable so pupils need less readjustment. |
| **Comment** | `#8A8278` (ANSI 8) | L≈0.61 C≈0.018 H≈74° | Recedes via lower L + low chroma; still ≥ ~4.5:1 on bg for readable secondary text. |
| **Accent sage** | `#7D9A8C` (ANSI 2 / accent) | L≈0.66 C≈0.039 H≈164° | Low–medium sat green-teal for structure (strings/keywords path); restful, not neon. |
| **Accent amber** | `#C9A66B` (ANSI 3 / cursor) | L≈0.74 C≈0.087 H≈80° | Warm gold for types/cursor — natural “attention” without high blue. |
| **Accent clay** | `#A88B6E` (ANSI 5) | L≈0.66 C≈0.054 H≈67° | Earthy third accent for keyword/special roles; harmony with bg hue family. |
| **Error** | `#C47064` (ANSI 1) | L≈0.64 C≈0.109 H≈29° | Higher saturation reserved for critical semantics; still warm-red, not pure RGB red. |
| **Warning** | `#D4A05A` (ANSI 11 family / bright amber) | L≈0.74 C≈0.107 H≈73° | Higher sat amber for caution; distinct from clay/sage without cool blue. |

**ANSI extras:** `color4`/`#7A8F98` muted slate (low-blue “blue” slot); brights are modest lifts of the same hues.

---

## Light Mode (`eye-comfort-light`)

Soft cream day mode for indoor daylight hours (not pure white).

| Role | Hex | OKLCH (approx) | Vision justification |
|------|-----|----------------|----------------------|
| **Background** | `#F5F0E8` | L≈0.96 C≈0.012 H≈80° | Soft cream off-white; lowers glare vs `#FFFFFF` under bright indoor/day ambient. |
| **Foreground** | `#2A2622` | L≈0.27 C≈0.009 H≈67° | Warm charcoal; contrast ≈ **13.2:1** on cream. |
| **Selection** | `#E0D9CE` / `#2A2622` | L≈0.89 surface | Gentle paper elevation; fg stays dark for stable reading. |
| **Comment** | `#6E665C` (ANSI 8) | L≈0.53-ish muted | Secondary text; ≈ **5.0:1** on bg. |
| **Accent sage** | `#4A6B5C` | mid L, C≈0.045 | Darker sage so accents stay readable on light paper. |
| **Accent amber** | `#8A6030` | mid L, warm | Types/constants; deeper than dark-mode amber for light bg contrast. |
| **Accent clay** | `#8B6B4E` | mid L | Keyword/special harmony. |
| **Error** | `#B54A40` | higher C | Semantic critical on cream. |
| **Warning** | `#8B6020` | higher C amber | Semantic caution; deeper than decorative gold. |

---

## Role → ANSI map (both modes)

| Role | Field |
|------|--------|
| Background / Foreground | `background` / `foreground` |
| Selection | `selection_background` / `selection_foreground` |
| Comment | `color8` |
| Accent sage | `accent`, `color2` |
| Accent amber | `cursor` (dark), `color3` |
| Accent clay | `color5` |
| Error | `color1` |
| Warning | `color3`/`color11` (dark amber family; light uses deeper `color3`/`color11`) |

---

## Apply

```bash
omarchy-theme-set eye-comfort-dark
omarchy-theme-set eye-comfort-light
eye-comfort-theme          # auto by local hour
eye-comfort-theme day      # force light
eye-comfort-theme night    # force dark
HOUR=22 eye-comfort-theme  # injectable clock (test)
```

Optional hourly timer (not enabled by default):

```bash
systemctl --user enable --now eye-comfort-theme.timer
systemctl --user status eye-comfort-theme.timer
```

## Helix warning mapping

Omarchy’s stock Helix template only defines `color0`–`color8`. These themes extend the palette through `color15` and map **`warning` / `diagnostic.warning` → `color11`** so the SoT warning hex is used (dark `#D4A05A`, light `#8B6020`). Error remains **`color1`**.
## Wallpapers

Artist-matched 16:9 backgrounds ship under each theme’s `backgrounds/`:

**Dark:** candle still-life · sage/amber ribbons · mist valley ink wash  
**Light:** parchment geometric dunes · cream botanical stationery  

Cycle: `omarchy theme bg next` (or `omarchy-theme-bg-next`).  
Helix is optional; nvim is wired via each theme’s `neovim.lua` (soft gruvbox, warm overrides on dark).

Design context: [PRODUCT.md](./PRODUCT.md) · [DESIGN.md](./DESIGN.md)
