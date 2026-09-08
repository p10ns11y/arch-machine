# Personal tweaks — heading cluster (Omarchy 4+)

Restore **this operator’s** shell bar chips (focus-now, mission-map, eye-comfort),
slot picker, 20:00 mission-map timer, and **kanithanj.ai** launch on a new
Arch/Omarchy box.

Omarchy 4 replaced Waybar with Quickshell (`omarchy-shell`). Chips are
`type: command` modules in `~/.config/omarchy/shell.json` (Waybar-style JSON from
existing CLIs). Do **not** reinstall Waybar. Walker is gone — focus-now uses
`omarchy-menu-select`.

```bash
# from arch-machine checkout
./modules/productivity/personal-tweaks/install.sh --yes
omarchy restart shell
hyprctl reload   # if focus-now bind was new
```

Installs `~/.local/bin/focus-now` (Season / CSH / SON / DBT) and Super+Ctrl+semicolon
in `~/.config/hypr/bindings.lua`. Needs: `eye-comfort-theme` on PATH; `mission-map`
under `~/dev/agentic-reactor/plugins` (fallback `~/Work/personal/plugins`, or
`PLUGINS_ROOT`); network for the v2 binary if `kanithanj.ai` is not on PATH yet.

After `omarchy refresh shell`, the theme-set / post-update hooks call
`apply-shell-bar.sh`. You can also run that script alone.
**Use `omarchy restart shell` to reload; `refresh` resets to stock.**

Every apply snapshots `shell.json` to
`~/.local/share/personal-tweaks/shell-bar-backups/` (timestamp + `last-good`).

Bar zoning (avoids tooltip collision with `omarchy.indicators`):

| Section | Chips |
|---------|--------|
| left (after workspaces) | `focus-now`, `mission-map` |
| center (after weather) | `eye-comfort` |
| right (after tray) | `omarchy.system-update` moved out of center |

```bash
cd lib && python3 test_patch_shell_bar.py
cd lib && python3 test_focus_now.py
cd lib && python3 test_ensure_focus_now_bind.py
# legacy Waybar patcher (Omarchy ≤3):
cd lib && python3 test_patch_waybar.py
```

Live mission JSON is **not** in this module (correct).

See [HOST-EDITS.md](HOST-EDITS.md).
