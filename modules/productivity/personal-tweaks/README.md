# Personal tweaks — heading cluster (Omarchy 4+)

Restore **this operator’s** shell bar chips (focus-now, mission-map, eye-comfort),
20:00 mission-map timer, and **kanithanj.ai** launch on a new Arch/Omarchy box.

Omarchy 4 replaced Waybar with Quickshell (`omarchy-shell`). Chips are
`type: command` modules in `~/.config/omarchy/shell.json` (Waybar-style JSON from
existing CLIs). Do **not** reinstall Waybar.

```bash
# from arch-machine checkout
./modules/productivity/personal-tweaks/install.sh --yes
omarchy restart shell
```

Needs: `focus-now` and `eye-comfort-theme` on PATH; `~/Work/personal/plugins`
(or `PLUGINS_ROOT`) with `mission-map`; network for the v2 binary if
`kanithanj.ai` is not on PATH yet.

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
# legacy Waybar patcher (Omarchy ≤3):
cd lib && python3 test_patch_waybar.py
```

Live mission JSON is **not** in this module (correct).

See [HOST-EDITS.md](HOST-EDITS.md).
