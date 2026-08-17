# Personal tweaks — heading cluster (Omarchy)

Restore **this operator’s** waybar chip, 20:00 mission-map timer, and **kanithanj.ai** launch on a new Arch/Omarchy box.

```bash
# from arch-machine checkout
./modules/productivity/personal-tweaks/install.sh --yes
omarchy restart waybar
```

Needs: `~/Work/personal/plugins` (or `PLUGINS_ROOT`) with `mission-map`, network for the v2 binary if `kanithanj.ai` is not on PATH yet.

See [HOST-EDITS.md](HOST-EDITS.md).
