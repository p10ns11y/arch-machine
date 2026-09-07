# Host / Omarchy edits — personal tweaks (cluster heading)

What this module writes. **Never** edit `/usr/share/omarchy/` or `~/.local/share/omarchy/`.

## Omarchy 4+ (Quickshell)

| Path | How | Why |
|------|-----|-----|
| `~/.local/bin/mm-lifeos-graph` | symlink to plugins `mission-map/scripts/` | Nightly + manual heading rewrite |
| `~/.local/bin/mm-waybar` | symlink | Bar chip JSON + open kanithanj.ai |
| `~/.local/bin/kanithanj.ai` | download GitHub `collab-finder` **v2** if missing | Heading cockpit |
| `~/.config/systemd/user/mission-map-graph.{service,timer}` | copy | 20:00 local refresh |
| `~/.config/omarchy/shell.json` | insert command modules | focus-now + mission-map (left); eye-comfort (center after weather); move system-update to right |
| `~/.local/share/applications/kanithanj.ai.desktop` | copy | Walker |
| `~/.local/lib/personal-tweaks/patch_shell_bar.py` | copy | Idempotent shell.json layout |
| `~/.local/lib/personal-tweaks/apply-shell-bar.sh` | copy | Re-apply after `omarchy refresh shell` |
| `~/.config/omarchy/hooks/theme-set.d/92-heading-chip.sh` | copy | Re-apply chips after theme-set |
| `~/.config/omarchy/hooks/post-update.d/92-heading-chip.sh` | copy | Re-apply after `omarchy update` |
| `~/.local/share/personal-tweaks/shell-bar-backups/` | snapshot before every apply | Timestamped + `last-good` `shell.json` |

**Not written:** `~/.grok/mission-maps/` (live JSON, contacts, `_private.Mission`). That is local SoT.

`omarchy refresh shell` still copies stock config. The hooks +
`~/.local/lib/personal-tweaks/apply-shell-bar.sh` put the chips back without a
full `--yes` reinstall. Each apply snapshots first.

```bash
~/.local/lib/personal-tweaks/apply-shell-bar.sh
omarchy restart shell   # not refresh
```

## Legacy Omarchy ≤3 (Waybar)

Still installed under `~/.local/lib/personal-tweaks/` for archaeology / old hosts
(`apply-waybar.sh`, `patch_waybar.py`, `backup-waybar.sh`, `mission-map.css`).
Hooks no longer call them on Omarchy 4+.
