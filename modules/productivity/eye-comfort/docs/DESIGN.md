# Design System — Eye Comfort

Visual system for Omarchy themes `eye-comfort-dark` and `eye-comfort-light`.  
Strategic context: [PRODUCT.md](./PRODUCT.md) · Token lock: [PALETTE.md](./PALETTE.md)

## Theme

| Mode | Scene | Strategy |
|------|--------|----------|
| Dark | Evening lamp / umber room | Restrained: warm off-black + parchment ink + sage/amber accents |
| Light | Soft day paper | Restrained: cream paper + warm charcoal + deeper sage/amber |

## Colors

### Dark (`eye-comfort-dark`)

| Token | Hex | Role |
|-------|-----|------|
| `bg` | `#181614` | Surface base |
| `surface` | `#2F2924` | Selection / elevated |
| `fg` | `#E6DFD3` | Primary text |
| `muted` | `#8A8278` | Comments / secondary |
| `accent` | `#7D9A8C` | Sage structure |
| `warm` | `#C9A66B` | Amber attention / cursor |
| `clay` | `#A88B6E` | Tertiary accent |
| `error` | `#C47064` | Critical |
| `warning` | `#D4A05A` | Caution (`color11`) |

### Light (`eye-comfort-light`)

| Token | Hex | Role |
|-------|-----|------|
| `bg` | `#F5F0E8` | Cream paper |
| `surface` | `#E0D9CE` | Selection |
| `fg` | `#2A2622` | Warm charcoal |
| `muted` | `#6E665C` | Comments |
| `accent` | `#4A6B5C` | Sage |
| `warm` | `#8A6030` | Amber |
| `clay` | `#8B6B4E` | Tertiary |
| `error` | `#B54A40` | Critical |
| `warning` | `#8B6020` | Caution |

## Typography

- **Code terminal:** JetBrainsMono Nerd Font, size 10, ligatures on, cell-height +3
- **Omarchy UI font:** CaskaydiaMono Nerd Font (system)
- Product (code): one monospace family per host; no display fonts in UI chrome

## Components / hosts

| Host | Source |
|------|--------|
| Omarchy templates | `colors.toml` → generated surfaces |
| Ghostty | theme `ghostty.conf` only (no local palette fight) |
| nvim | `neovim.lua` → soft gruvbox + dark SoT overrides |
| Yazi | flavors `eye-comfort-{dark,light}` |
| Wallpaper | `backgrounds/*.jpg` — stage, not hero |

## Layout (wallpaper)

- Prefer calm lower third / soft gradient fields
- Keep upper 30–40% quieter for floating terminals
- Avoid high-frequency noise behind text-heavy windows
- 16:9 primary; fill mode via swaybg

## Do / Don't

**Do:** warm R>B darks; OKLCH-aware spacing of accents; semantic error/warning only.  
**Don't:** cool blue night BGs; pure #000/#FFF; dual Ghostty palettes; busy wall art fighting the HUD.

## Polish notes (impeccable)

- Wallpapers graded to SoT tokens; subject mass kept off the upper field for floating windows.
- Ghostty: theme file owns color; local config owns font + `background-opacity = 0.96` (stage, not wash).
- nvim soft gruvbox; dark palette_overrides lock `dark0`/`light1` to SoT.
- Helix optional / not required.

## Wallpaper set (quieter + delight)

**Dark** (`eye-comfort-dark/backgrounds/`):
| File | Role |
|------|------|
| `0-signature-lantern.jpg` | **Delight** — single paper lantern on vast umber; discovery when desk is clear |
| `1-journals-tea.jpg` | Quieter journals-tea vignette (lower-left) |
| `2-sage-amber-ribbons.jpg` | Quieter ribbon band (bottom third only) |
| `3-mist-valley-ink.jpg` | Quieter night ink landscape |

**Light**: `1-parchment-dunes.jpg`, `2-cream-botanical.jpg` (quieter edge botanicals).

Cycle: `omarchy theme bg next`. Personality: subtle sophistication, not spectacle.

