# Design System — Eye Comfort

Visual system for Omarchy themes `eye-comfort-{dawn,light,dusk,dark}` with seven circadian phases.  
Strategic context: [PRODUCT.md](./PRODUCT.md) · Token lock: [PALETTE.md](./PALETTE.md)

## Theme

| Mode | Scene | Strategy |
|------|--------|----------|
| Dawn | First light through linen | Restrained: peach-rose paper + warm charcoal |
| Light / day phases | Soft day paper | Restrained: cream + warm charcoal + sage/amber |
| Dusk | Residual gold sky | Restrained: lifted warm dark + amber attention |
| Dark / night | Evening lamp / umber room | Restrained: warm off-black + parchment ink |

**Color strategy:** Restrained (product). Accent ≤10% for structure/attention; semantic error/warning only at higher chroma.

**Scene sentence:** Single operator at a Linux desk under mixed indoor lamp and window light — chrome disappears into long coding sessions; luminance follows the sun without spectacle.

## Colors

See [PALETTE.md](./PALETTE.md) for locked hex + OKLCH. Phase refinements live in `lib/palette.py`; CSS mirrors in `tokens/phases.css`.

### Identity locks (balanced indoor)

| Package | bg | fg |
|---------|----|----|
| light (midday) | `#F5F0E8` | `#2A2622` |
| dark (night) | `#181614` | `#E6DFD3` |

Dawn/dusk are transitional siblings — same family, not a second brand.

## Typography

- **Code terminal:** JetBrainsMono Nerd Font, size 10, ligatures on, cell-height +3
- **Omarchy UI font:** CaskaydiaMono Nerd Font (system)
- Product (code): one monospace family per host; no display fonts in UI chrome

## Motion

- Desktop theme swaps are instant (product tool).
- `--reduced-motion` writes `motion: reduce` to `~/.config/eye-comfort/state.json` for companions (Hyprland animations, etc.).
- No decorative page-load choreography.

## Components / hosts

| Host | Source |
|------|--------|
| Omarchy templates | `colors.toml` → generated surfaces |
| Ghostty | theme `ghostty.conf` only |
| nvim | `neovim.lua` → soft gruvbox + SoT overrides |
| Yazi | flavors `eye-comfort-{dark,light}` (dawn→light, dusk→dark) |
| Wallpaper | shared: dawn←light, dusk←dark backgrounds |
| CSS tokens | `tokens/phases.css` / `eye-comfort-theme --css` |

## Layout (wallpaper)

- Prefer calm lower third / soft gradient fields
- Keep upper 30–40% quieter for floating terminals
- Avoid high-frequency noise behind text-heavy windows
- 16:9 primary; fill mode via swaybg

## Do / Don't

**Do:** warm R>B darks; OKLCH phase tokens; semantic error/warning only; ≥4.5:1 body contrast.  
**Don't:** cool blue night BGs; pure #000/#FFF; dual Ghostty palettes; busy wall art; cream SaaS marketing as decoration; purple cyber defaults.

## Polish notes (impeccable)

- Four packages cover seven phases; live render keeps morning/afternoon/evening distinct.
- Outdoor ambient deepens ink; soft intensity gentles contrast without breaking AA.
- Wallpapers graded to SoT; dawn/dusk share day/night sets via install symlinks.
- Helix optional / not required.

## Wallpaper set

**Dark / dusk:** lantern · journals-tea · sage-amber ribbons · mist valley  
**Light / dawn:** parchment dunes · cream botanical  

Cycle: `omarchy theme bg next`. Personality: subtle sophistication, not spectacle.
