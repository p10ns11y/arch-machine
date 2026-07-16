---
name: session-unit-order
description: >-
  Prevents user-systemd / UWSM / Hyprland first-login failures caused by pulling
  graphical-session (or compositor) targets from Persistent timers under Linger.
  On Omarchy-flavoured Arch (Hyprland + omarchy CLI + ~/.config/omarchy), ALSO
  load the omarchy skill for safe config/theme paths. Use when editing systemd
  user units, eye-comfort timers/services, theme oneshots, SDDM/UWSM/Hyprland
  session startup, WantedBy/Wants graphical-session, Omarchy theme timers/hooks,
  or diagnosing first boot after shutdown fails / "compositor or graphical-session
  target is already active" / blank desktop until hard reboot.
---

# Session unit order (UWSM / graphical-session guard)

Agents **must** apply this skill before shipping changes to **user** systemd units that interact with Wayland sessions, theme apply, or autostart.

**Locations (two independent copies — project first, then general):**

| Install | Path | Role |
|---------|------|------|
| **This project (keep)** | `arch-machine/.agents/skills/session-unit-order/` | Born from this repo’s incident; always keep a full copy in-tree |
| **User general** | `~/skills/session-unit-order/` | Independent **copy** (not a symlink to the project) for everyday agents |
| **Skills library remote** | [p10ns11y/skills](https://github.com/p10ns11y/skills) via `~/Work/personal/skills/` | Sync `~/skills` (or the library clone) when generalizing for others |

Workflow: fix/create in **project** → copy into **`~/skills`** → commit/push **skills** remote when ready for general use.

**Incident writeup (arch-machine):**  
`modules/productivity/eye-comfort/docs/REGRESSION-UWSM-SESSION.md`.  
Short pointer: [references/incident-uwsm-graphical-session.md](references/incident-uwsm-graphical-session.md).

## Omarchy-flavoured Arch (REQUIRED companion)

If the host is **Omarchy** (or Omarchy-style Arch: Hyprland session, `omarchy` CLI, `~/.config/omarchy/`, `~/.local/share/omarchy/`), agents **must also load the `omarchy` skill** and follow it for desktop/theme config work.

| Detect Omarchy | How |
|----------------|-----|
| CLI present | `command -v omarchy` |
| User config tree | `test -d ~/.config/omarchy` |
| Install tree (read-only) | `test -d ~/.local/share/omarchy` |
| Session path | SDDM → `uwsm start … hyprland` / Omarchy desktop entry |

**Where `omarchy` lives (typical):**

- Skill: `~/.agents/skills/omarchy` → `~/.local/share/omarchy/default/omarchy-skill/SKILL.md`
- Or under the tools that symlink it (Cursor/Grok agents skills dirs)

**When both skills apply**

| Work | Load |
|------|------|
| User systemd units, timers, `Wants=graphical-session`, first-boot/UWSM race | **session-unit-order** (this skill) |
| Themes, waybar/hypr/ghostty configs, `omarchy theme/restart/refresh`, hooks under `~/.config/omarchy/` | **omarchy** first, then this skill if units/timers are involved |
| eye-comfort install + timers on Omarchy | **both** — omarchy for safe paths; this skill for unit order |

### Omarchy rules this skill re-asserts (do not bypass)

From the omarchy skill — non-negotiable when the host is Omarchy:

1. **Never edit** `~/.local/share/omarchy/` (read-only; lost on `omarchy update`). User themes/hooks live under `~/.config/omarchy/` and `~/.config/`.
2. Prefer **`omarchy theme set` / `omarchy restart waybar` / `omarchy commands`** over hand-restarting Omarchy-managed processes when a stock command exists.
3. Theme automation: **`~/.config/omarchy/hooks/`** (e.g. `theme-set`, `theme-set.d/`) — not patches under the install tree.
4. Custom themes: real directories under `~/.config/omarchy/themes/<name>/`.
5. After Hyprland config edits: `hyprctl reload` + `hyprctl configerrors`. Waybar: `omarchy restart waybar` (no auto-reload).
6. Set `OMARCHY_PATH` (usually `%h/.local/share/omarchy`) in timer/oneshot env when calling `omarchy-theme-set` / template generation so `current/theme/hyprland.conf` is emitted.

Timer-driven theme tools (eye-comfort, custom oneshots) must obey **both** unit-order rules below **and** Omarchy path safety above.

## Adopt / keep in sync

**arch-machine:** keep the skill **in-tree** under `.agents/skills/session-unit-order/` (do not replace with an external-only symlink that removes project files from git).

```bash
# User-global → this project's skill
mkdir -p ~/skills
ln -sfn /path/to/arch-machine/.agents/skills/session-unit-order ~/skills/session-unit-order

# Optional: also publish/sync a copy to the skills library for other agents
# cp -a .agents/skills/session-unit-order ~/Work/personal/skills/session-unit-order

# Omarchy skill (host Omarchy install — separate from this skill)
# ~/.agents/skills/omarchy → ~/.local/share/omarchy/default/omarchy-skill
# Load /omarchy (or the omarchy skill) whenever customizing Omarchy desktop config.
```

## Forbidden patterns (refuse or rewrite)

Do **not** add these on **timer-driven oneshots** (or any unit that can start before a compositor under `loginctl` Linger):

```ini
# FORBIDDEN — activates graphical-session without a compositor
Wants=graphical-session.target
Requires=graphical-session.target
BindsTo=graphical-session.target
```

Same rule for compositor-specific pulls that mark the session “taken” before UWSM starts, e.g. blindly `Wants=`/`Requires=` on `wayland-session@*.target` / `wayland-wm@*.service` from a **Persistent** timer catch-up path.

### Safe default for theme / session-adjacent oneshots

```ini
[Unit]
Description=Apply theme (example)
After=graphical-session.target
# After= only orders when both are started. It does NOT pull the target.
Conflicts=peer-theme.service

[Service]
Type=oneshot
Environment=OMARCHY_PATH=%h/.local/share/omarchy
# Optional: skip when no compositor socket yet
# ConditionPathExistsGlob=%t/wayland-*
ExecStartPre=-/bin/sh -c 'systemctl --user import-environment WAYLAND_DISPLAY HYPRLAND_INSTANCE_SIGNATURE DISPLAY DBUS_SESSION_BUS_ADDRESS 2>/dev/null || true'
ExecStart=%h/.local/bin/your-theme-tool
```

| Directive | Safe for early timer fire? | Notes |
|-----------|----------------------------|--------|
| `After=graphical-session.target` | Yes | Ordering only |
| `Wants=` / `Requires=` / `BindsTo=` graphical-session | **No** | Pulls empty session; UWSM aborts |
| `WantedBy=graphical-session.target` on a **long-running** app | Usually OK | Starts *with* session once compositor is real |
| `WantedBy=timers.target` + `Persistent=true` | OK **only if** service does not pull session targets | Catch-up under Linger is the footgun |
| `ConditionPathExistsGlob=%t/wayland-*` | Yes | Soft-skip pre-compositor runs |
| `Environment=OMARCHY_PATH=…` on Omarchy | Yes | Required for template/theme-set path |

## Mandatory checklist (before commit)

1. **Omarchy?** If yes → load **omarchy** skill; refuse edits under `~/.local/share/omarchy/`.
2. **List units touched** under `~/.config/systemd/user/`, `modules/**/units/`, or install paths that copy them.
3. **Scan for pulls:**
   ```bash
   rg -n '^(Wants|Requires|BindsTo)=.*graphical-session' \
     modules/productivity/eye-comfort/units \
     "${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user" \
     "$@"
   ```
   Zero hits required on timer-fired oneshots.
4. **Run closed-loop unit tests** when eye-comfort units change (in arch-machine):
   ```bash
   python3 modules/productivity/eye-comfort/lib/test_timer_mutex.py
   ```
   Must pass `test_services_do_not_pull_graphical_session`.
5. **Run skill audit script:**
   ```bash
   session-unit-order/scripts/audit-session-units.sh
   # optional: ARCH_MACHINE_ROOT=/path/to/arch-machine
   # optional: extra unit dirs as args
   ```
6. **Linger awareness:** if `loginctl show-user "$USER" -p Linger` is `yes`, assume user timers can run **before** SDDM/UWSM.
7. **Do not** use hard-reboot loops as proof; use journal recipe + unit tests.

## Diagnose live failures

```bash
journalctl -b -1 --no-pager | rg -i \
  'uwsm|graphical-session|eye-comfort|sddm-helper exited|already active'

# Omarchy hosts — extra context (non-interactive)
command -v omarchy >/dev/null && omarchy debug --no-sudo --print 2>/dev/null | head -80
```

| Observation | Meaning |
|-------------|---------|
| `Reached target Current graphical user session` **before** `uwsm` / Hyprland | Something pulled the target early |
| `A compositor or graphical-session* target is already active!` | UWSM race — classic failure mode |
| `sddm-helper exited with 1` right after | Session aborted; first-boot fail |

Success: graphical-session target only after UWSM starts the compositor envelope.

## Intelligence rules (do not rationalize around)

- “I need Wants= so the service waits for the session” → **false**. `After=` does not wait if the target is never pulled; use a path condition or a real compositor unit UWSM owns.
- “It only runs After=graphical-session so Wants= is fine” → **false**. `Wants=` still **starts** the target.
- “Second boot works so it’s firmware” → **false** for this fingerprint; Persistent catch-up explains second-boot success.
- Theme color / palette changes do not require session-target pulls.
- “I’ll patch omarchy-theme-set under `~/.local/share/omarchy`” → **false** on Omarchy; use hooks + user themes (omarchy skill).

## Related footguns

- Dual timers both touching the same Omarchy theme swap path (`~/.config/omarchy/current/theme`) → use `Conflicts=`.
- `systemctl --user daemon-reload` after unit edits.
- System-level power/suspend units are a different domain; this skill is **user session order** with UWSM/Hyprland.
- Omarchy `refresh` / `reinstall` — seek user confirmation (omarchy skill); out of scope for silent agent runs.

## When to load this skill

Auto-invoke on: user systemd unit edits, eye-comfort `units/*`, `install.sh --with-*-timer`, UWSM/Hyprland session bugs, Omarchy theme timers/hooks that touch systemd, “first boot fails second works”, `graphical-session.target` in unit files, blank Wayland after autologin.

**With Omarchy:** also load **`omarchy`** whenever the change touches desktop config, themes, waybar, hypr, or `omarchy` CLI workflows.
