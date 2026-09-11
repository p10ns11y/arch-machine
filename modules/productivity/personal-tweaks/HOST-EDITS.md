# Host / Omarchy edits — personal tweaks (cluster heading)

What this module writes. **Never** edit `/usr/share/omarchy/` or `~/.local/share/omarchy/`.

## Omarchy 4+ (Quickshell plugins)

| Path | How | Why |
|------|-----|-----|
| `~/.config/omarchy/plugins/heading/` | rsync from `omarchy-plugins/heading/` | Bar widget: focus slot + mission apply |
| `~/.config/omarchy/plugins/tinai/` | rsync from `omarchy-plugins/tinai/` | Bar widget: eye-comfort Tamil calendar |
| `~/.local/bin/focus-now` | copy `bin/focus-now` | Slot CLI + Omarchy menu picker (used by heading) |
| `~/.config/focus-now/live.json` | seed once if missing | Live slot SoT (default CSH); never overwrite |
| `~/.config/hypr/bindings.lua` | idempotent marker block | Super+Ctrl+semicolon → `focus-now picker` |
| `~/.local/bin/mm-lifeos-graph` | symlink to plugins `mission-map/scripts/` | Nightly + manual heading rewrite |
| `~/.local/bin/mm-bar-json` | copy | Mission JSON for heading panel |
| `~/.local/lib/personal-tweaks/mm_bar_json.py` | copy | Tooltip wrap for Quickshell NoWrap |
| `~/.local/bin/mm-waybar` | symlink | Underlying mission JSON (still used by mm-bar-json) |
| `~/.local/bin/kanithanj.ai` | download GitHub `collab-finder` **v2** if missing | Heading cockpit |
| `~/.config/systemd/user/mission-map-graph.{service,timer}` | copy | 20:00 local refresh |
| `~/.config/omarchy/shell.json` | plugin refs `{id:heading}` / `{id:tinai}` | Zoning; strips legacy command chips |
| `~/.local/share/applications/kanithanj.ai.desktop` | copy | Launcher entry |
| `~/.local/lib/personal-tweaks/patch_shell_bar.py` | copy | Idempotent shell.json layout |
| `~/.local/lib/personal-tweaks/install_omarchy_plugins.sh` | copy | rsync + validate + enable |
| `~/.local/lib/personal-tweaks/ensure_focus_now_bind.py` | copy | Hypr bind helper |
| `~/.local/lib/personal-tweaks/apply-shell-bar.sh` | copy | Re-apply after stock shell reset |
| `~/.config/omarchy/hooks/theme-set.d/92-heading-chip.sh` | copy | Re-apply layout after theme-set |
| `~/.config/omarchy/hooks/post-update.d/92-heading-chip.sh` | copy | Re-apply after `omarchy update` |
| `~/.local/share/personal-tweaks/shell-bar-backups/` | snapshot before every apply | Timestamped + `last-good` `shell.json` |

**Not written:** `~/.grok/mission-maps/` (live JSON, contacts, `_private.Mission`). That is local SoT.
**Not owned here:** `~/.config/omarchy/plugins/mesh/` (separate mesh product plugin).

Prefer plugins over command chips. **Never** `omarchy refresh shell` — use
`omarchy restart shell`. If stock config is restored, hooks +
`~/.local/lib/personal-tweaks/apply-shell-bar.sh` put heading/tinai back.

```bash
~/.local/lib/personal-tweaks/install_omarchy_plugins.sh
~/.local/lib/personal-tweaks/apply-shell-bar.sh
omarchy restart shell   # not refresh
```

## Legacy Omarchy ≤3 (Waybar)

Still installed under `~/.local/lib/personal-tweaks/` for archaeology / old hosts
(`apply-waybar.sh`, `patch_waybar.py`, `backup-waybar.sh`, `mission-map.css`).
Hooks no longer call them on Omarchy 4+.
