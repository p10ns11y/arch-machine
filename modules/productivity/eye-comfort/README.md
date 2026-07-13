# Eye-comfort themes (Omarchy)

Vision-science circadian desktop themes for long coding sessions — warm nights, soft days, transitional dawn/dusk.

## Install

**Standalone-only** — not wired into profile YAML / ModuleBay yet. Install from this directory (see [docs/MODULES.md](../../../docs/MODULES.md)).

```bash
cd modules/productivity/eye-comfort
./install.sh
./install.sh --set auto          # resolve phase from local hour (full switcher)
./install.sh --set dawn          # force dawn via switcher (live render + state.json)
./install.sh --with-timer        # optional hourly systemd user timer
```

All `--set` modes route through `eye-comfort-theme` (not a bare `omarchy-theme-set`), so applied packages get live role render and `~/.config/eye-comfort/state.json`.

Requires: `omarchy-theme-set` on PATH for apply; Python 3 for schedule + OKLCH helpers.

Regenerate committed host files after palette changes:

```bash
PYTHONPATH=lib python3 lib/generate_packages.py
PYTHONPATH=lib python3 lib/test_schedule.py
```

## Layout

| Path | Purpose |
|------|---------|
| `docs/PALETTE.md` | Color SoT + vision justifications |
| `docs/PRODUCT.md` / `DESIGN.md` | Impeccable design context |
| `themes/eye-comfort-{dawn,light,dusk,dark}` | Omarchy packages |
| `tokens/phases.css` | OKLCH CSS custom properties per phase |
| `bin/eye-comfort-theme` | Circadian switcher (flags below) |
| `units/eye-comfort-theme.{service,timer}` | Hourly systemd user timer |
| `lib/{schedule,palette,oklch,render}.py` | Phase math + tokens + host render |
| `yazi/` | File manager flavors (dark/light) |

## Circadian phases

| Phase | Local hours (no `--lat`) | Omarchy package | Feel |
|-------|--------------------------|-----------------|------|
| dawn | 05–07 | `eye-comfort-dawn` | Peach-linen first light |
| morning | 07–10 | `eye-comfort-light` | Soft cream focus |
| midday | 10–14 | `eye-comfort-light` | Day paper (locked SoT) |
| afternoon | 14–17 | `eye-comfort-light` | Warmer amber lean |
| dusk | 17–19 | `eye-comfort-dusk` | Residual gold dark |
| evening | 19–22 | `eye-comfort-dark` | Lamp umber |
| night | 22–05 | `eye-comfort-dark` | Deepest warm night |

With `--lat DEG`, boundaries follow approximate sunrise/sunset for that latitude.

## Flags

```bash
eye-comfort-theme [MODE] [flags]

# MODE: auto | dawn|morning|midday|afternoon|dusk|evening|night
#       aliases: day|light → midday; dark → night

--phase NAME              Force phase (overrides positional MODE)
--hour N / --minute N     Clock override (or HOUR=N)
--lat DEG                 Solar phase boundaries
--indoor | --outdoor      Ambient context (default auto)
--ambient auto|indoor|outdoor
--intensity soft|balanced|crisp   # --comfort is an alias
--high-contrast           Extra ink contrast
--reduced-motion          Record motion=reduce in state.json
--no-dynamic              Collapse to light/dark packages only
--dry-run                 Plan only
--preview / --print-only  Print theme name
--json                    Full CircadianState JSON (no apply)
--css                     Emit OKLCH CSS variables
--no-render               Skip live role write into theme dir
--state-dir DIR           Default: ~/.config/eye-comfort
-h / --help
```

### Examples

```bash
eye-comfort-theme
eye-comfort-theme --phase dusk --indoor --intensity soft
eye-comfort-theme auto --lat 28.6 --outdoor --json
HOUR=22 eye-comfort-theme --dry-run
eye-comfort-theme --css --phase night > /tmp/ec-night.css
```

On apply (not `--json`/`--dry-run`), the switcher live-renders resolved roles into the installed Omarchy theme so morning/afternoon/evening get phase-tuned tokens, then runs `omarchy-theme-set`.

State file: `~/.config/eye-comfort/state.json` (phase, CCT hint, contrast, motion preference).

## Scheduled apply (systemd user timer)

The timer runs `eye-comfort-theme auto` every hour (`OnCalendar=hourly`, `Persistent=true` so it catches up after sleep).

### Enable with install

```bash
./install.sh --with-timer
```

### Enable manually (switcher already installed)

```bash
cp units/eye-comfort-theme.{service,timer} ~/.config/systemd/user/
systemctl --user daemon-reload
systemctl --user enable --now eye-comfort-theme.timer
```

### Check / run once

```bash
systemctl --user status eye-comfort-theme.timer
systemctl --user list-timers eye-comfort-theme.timer
systemctl --user start eye-comfort-theme.service    # apply now
journalctl --user -u eye-comfort-theme.service -n 20
```

### Customize flags

Default `ExecStart` is `%h/.local/bin/eye-comfort-theme auto`. To pass `--lat`, `--indoor`, etc., edit `~/.config/systemd/user/eye-comfort-theme.service`, then:

```bash
systemctl --user daemon-reload
systemctl --user restart eye-comfort-theme.timer
```

Disable later: `systemctl --user disable --now eye-comfort-theme.timer`.

## Live targets

Install copies into:

- `~/.config/omarchy/themes/`
- `~/.local/bin/eye-comfort-theme`
- `~/.local/lib/eye-comfort/`
- `~/.config/systemd/user/eye-comfort-theme.{service,timer}` (with `--with-timer`)

Does **not** commit live `~/.config` (gitignored at repo root).
