# Personal tweaks — heading cluster (Omarchy)

Restore **this operator’s** waybar chip, 20:00 mission-map timer, and **kanithanj.ai** launch on a new Arch/Omarchy box.

```bash
# from arch-machine checkout
./modules/productivity/personal-tweaks/install.sh --yes
omarchy restart waybar
```

Needs: `~/Work/personal/plugins` (or `PLUGINS_ROOT`) with `mission-map`, network for the v2 binary if `kanithanj.ai` is not on PATH yet.

After `omarchy refresh waybar`, the theme-set / post-update hooks call `apply-waybar.sh`. You can also run that script alone. **Use `omarchy restart waybar` to reload; `refresh` resets to stock.**

Every apply snapshots `config.jsonc` + `style.css` to
`~/.local/share/personal-tweaks/waybar-backups/` (timestamp + `last-good`).
Restore without reinstall:

```bash
~/.local/lib/personal-tweaks/backup-waybar.sh --list
~/.local/lib/personal-tweaks/backup-waybar.sh --restore last-good
omarchy restart waybar
```

Live mission JSON is **not** in this module (correct).

```bash
cd lib && python3 test_patch_waybar.py
```

See [HOST-EDITS.md](HOST-EDITS.md).
