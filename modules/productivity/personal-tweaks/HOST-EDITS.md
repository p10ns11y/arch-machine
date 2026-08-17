# Host / Omarchy edits — personal tweaks (cluster heading)

What this module writes. **Never** edit `~/.local/share/omarchy/`.

| Path | How | Why |
|------|-----|-----|
| `~/.local/bin/mm-lifeos-graph` | symlink to plugins `mission-map/scripts/` | Nightly + manual heading rewrite |
| `~/.local/bin/mm-waybar` | symlink | Waybar chip + open kanithanj.ai |
| `~/.local/bin/kanithanj.ai` | download GitHub `collab-finder` **v2** if missing | Heading cockpit |
| `~/.config/systemd/user/mission-map-graph.{service,timer}` | copy | 20:00 local refresh |
| `~/.config/waybar/config.jsonc` | insert `custom/mission-map` if absent | Chip after focus-now |
| `~/.config/waybar/style.css` | append CSS if absent | Chip colors |
| `~/.local/share/applications/kanithanj.ai.desktop` | copy | Walker |

**Not written:** `~/.grok/mission-maps/` (live JSON, contacts, `_private.Mission`). Sync those separately; they are local SoT and may contain process detail.

`omarchy refresh waybar` wipes user Waybar — re-run this install after a refresh.
