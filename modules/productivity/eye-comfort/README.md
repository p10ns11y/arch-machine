# Eye-comfort themes (Omarchy)

Vision-science light/dark desktop themes for long coding sessions and circadian rhythm.

## Install (any Omarchy / Arch machine)

```bash
cd modules/productivity/eye-comfort
./install.sh
./install.sh --set dark          # apply immediately
./install.sh --set auto          # local hour schedule
./install.sh --with-timer        # optional hourly systemd user timer
```

Requires: `omarchy-theme-set` on PATH for apply; Python 3 for schedule tests.

## Layout

| Path | Purpose |
|------|---------|
| `docs/PALETTE.md` | Color SoT + vision justifications |
| `docs/PRODUCT.md` / `DESIGN.md` | Impeccable design context |
| `themes/eye-comfort-dark` | Night package (wallpapers, colors, ghostty, nvim) |
| `themes/eye-comfort-light` | Day package + `light.mode` |
| `bin/eye-comfort-theme` | Circadian / manual switcher |
| `lib/schedule.py` | Pure hour→theme + contrast helpers (tested) |
| `snippets/ghostty.fragment.conf` | Font/opacity only (palette stays Omarchy) |
| `yazi/` | File manager flavors |

## Schedule

- Light: local 07:00–17:59  
- Dark: 18:00–06:59  
- Override: `HOUR=22 eye-comfort-theme` or `eye-comfort-theme day|night`

## Live targets

Install copies into:

- `~/.config/omarchy/themes/`
- `~/.local/bin/eye-comfort-theme`
- `~/.local/lib/eye-comfort/`

Does **not** commit live `~/.config` (gitignored at repo root).
