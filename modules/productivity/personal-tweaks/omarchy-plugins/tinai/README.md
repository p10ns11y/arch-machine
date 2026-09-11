# Omarchy Tiṇai (2.0)

**BarWidget + Panel** views (heading-style split). Chip: landscape icon + waybar
text (e.g. `󰔏 Marutam · Naṇpakal · N3`). Panel: structured Tamil time —
DATE / TIṆAI / POḺUTU / JĀMAM / NĀḺIKAI — plus **Notify**. No raw tooltip dump.

```bash
rsync -a --delete ./ ~/.config/omarchy/plugins/tinai/
omarchy plugin validate ~/.config/omarchy/plugins/tinai
omarchy restart shell   # never refresh
```

Requires `~/.local/bin/eye-comfort-theme` and
`~/.local/lib/eye-comfort/waybar/tn-status.sh`.

Clicks: left toggle · right notify · middle refresh. Enter in panel = notify.
