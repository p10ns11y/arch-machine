# Host / Omarchy edits — personal tweaks (cluster heading)

What this module writes. **Never** edit `~/.local/share/omarchy/`.

| Path | How | Why |
|------|-----|-----|
| `~/.local/bin/mm-lifeos-graph` | symlink to plugins `mission-map/scripts/` | Nightly + manual heading rewrite |
| `~/.local/bin/mm-waybar` | symlink | Waybar chip + open kanithanj.ai |
| `~/.local/bin/kanithanj.ai` | download GitHub `collab-finder` **v2** if missing | Heading cockpit |
| `~/.config/systemd/user/mission-map-graph.{service,timer}` | copy | 20:00 local refresh |
| `~/.config/waybar/config.jsonc` | insert `custom/mission-map` if absent | Chip after focus-now |
| `~/.config/waybar/style.css` | append CSS; rewrite TN include to a relative path | Chip colors; Waybar cannot load `file://` CSS |
| `~/.config/waybar/eye-comfort/eye-comfort.css` | copy if missing | Local TN stylesheet next to `style.css` |
| `~/.local/share/applications/kanithanj.ai.desktop` | copy | Walker |
| `~/.local/lib/personal-tweaks/patch_waybar.py` | copy | Idempotent insert (stock bar has no focus-now) |
| `~/.local/lib/personal-tweaks/apply-waybar.sh` | copy | Re-apply after `omarchy refresh waybar` |
| `~/.local/lib/personal-tweaks/backup-waybar.sh` | copy | Snapshot / list / restore |
| `~/.local/lib/personal-tweaks/mission-map.css` | copy | CSS source for apply (not `../waybar/` from `~/.local/lib`) |
| `~/.config/omarchy/hooks/theme-set.d/92-heading-chip.sh` | copy | Re-apply chip after theme-set |
| `~/.config/omarchy/hooks/post-update.d/92-heading-chip.sh` | copy | Re-apply after `omarchy update` |
| `~/.local/share/personal-tweaks/waybar-backups/` | snapshot before every apply | Timestamped copies + `last-good` of `config.jsonc` + `style.css` |

**Not written:** `~/.grok/mission-maps/` (live JSON, contacts, `_private.Mission`). That is local SoT and may contain process detail — rsync it yourself if you want a new box to inherit the heading.

`omarchy refresh waybar` still copies stock config. The hooks + `~/.local/lib/personal-tweaks/apply-waybar.sh` put the chip back without a full `--yes` reinstall. Each apply snapshots first.

```bash
~/.local/lib/personal-tweaks/backup-waybar.sh                 # snapshot now
~/.local/lib/personal-tweaks/backup-waybar.sh --list
~/.local/lib/personal-tweaks/backup-waybar.sh --restore last-good
omarchy restart waybar   # not refresh
```
