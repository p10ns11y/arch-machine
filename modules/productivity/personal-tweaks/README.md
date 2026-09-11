# Personal tweaks — heading + tinai (Omarchy 4+)

Restore **this operator’s** Omarchy bar widgets (heading, tinai), focus slot
picker, 20:00 mission-map timer, and **kanithanj.ai** launch on a new
Arch/Omarchy box.

Omarchy 4 replaced Waybar with Quickshell (`omarchy-shell`). Prefer
**bar-widget plugins** under `~/.config/omarchy/plugins/{heading,tinai}/`.
Legacy `type: command` chips (`focus-now`, `mission-map`, `eye-comfort`) are
deprecated and removed on apply. Do **not** reinstall Waybar. Walker is gone —
focus-now uses `omarchy-menu-select`. Mesh stays a separate plugin.

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

**Never run `omarchy refresh shell`** — it resets to stock. Use
`omarchy restart shell` after layout changes. Theme-set / post-update hooks call
`apply-shell-bar.sh` to put plugins back if stock config is restored.

Every apply snapshots `shell.json` to
`~/.local/share/personal-tweaks/shell-bar-backups/` (timestamp + `last-good`).

Bar zoning (avoids tooltip collision with `omarchy.indicators`):

| Section | Widgets |
|---------|---------|
| left (after workspaces) | `heading` (focus + mission apply) |
| center (after weather) | `tinai` (eye-comfort Tamil calendar) |
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
