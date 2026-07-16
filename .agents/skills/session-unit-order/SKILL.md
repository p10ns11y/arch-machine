---
name: session-unit-order
description: >-
  Prevents user-systemd / UWSM / Hyprland first-login failures caused by pulling
  graphical-session (or compositor) targets from Persistent timers under Linger.
  Use when editing systemd user units, eye-comfort timers/services, theme
  oneshots, SDDM/UWSM/Hyprland session startup, WantedBy/Wants graphical-session,
  or diagnosing first boot after shutdown fails / "compositor or graphical-session
  target is already active" / blank desktop until hard reboot.
---

# Session unit order (UWSM / graphical-session guard)

Agents **must** apply this skill before shipping changes to **user** systemd units that interact with Wayland sessions, theme apply, or autostart.

**Canonical tree:** repo `.agents/skills/session-unit-order/`  
**User mirror:** `~/skills/session-unit-order` → same path (symlink).  
**Incident writeup:** `modules/productivity/eye-comfort/docs/REGRESSION-UWSM-SESSION.md`

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
# Avoid concurrent races with peer timers via Conflicts= if needed.
Conflicts=peer-theme.service

[Service]
Type=oneshot
# Optional: skip when no compositor socket yet (catch-up fires early)
# ConditionPathExistsGlob=%t/wayland-*
ExecStart=%h/.local/bin/your-theme-tool
```

| Directive | Safe for early timer fire? | Notes |
|-----------|----------------------------|--------|
| `After=graphical-session.target` | Yes | Ordering only |
| `Wants=` / `Requires=` / `BindsTo=` graphical-session | **No** | Pulls empty session; UWSM aborts |
| `WantedBy=graphical-session.target` on a **long-running** app | Usually OK | Starts *with* session once compositor is real |
| `WantedBy=timers.target` + `Persistent=true` | OK **only if** service does not pull session targets | Catch-up under Linger is the footgun |
| `ConditionPathExistsGlob=%t/wayland-*` | Yes | Soft-skip pre-compositor runs |

## Mandatory checklist (before commit)

1. **List units touched** under `~/.config/systemd/user/`, `modules/**/units/`, or install paths that copy them.
2. **Scan for pulls:**
   ```bash
   rg -n '^(Wants|Requires|BindsTo)=.*graphical-session' \
     modules/productivity/eye-comfort/units \
     "${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user" \
     "$@"
   ```
   Zero hits required on timer-fired oneshots.
3. **Run closed-loop unit tests** when eye-comfort units change:
   ```bash
   python3 modules/productivity/eye-comfort/lib/test_timer_mutex.py
   ```
   Must pass `test_services_do_not_pull_graphical_session`.
4. **Run skill audit script** (same tree):
   ```bash
   .agents/skills/session-unit-order/scripts/audit-session-units.sh
   ```
5. **Linger awareness:** if `loginctl show-user "$USER" -p Linger` is `yes`, assume user timers can run **before** SDDM/UWSM. Design units accordingly.
6. **Do not “fix” blank first-login by hard-rebooting in a loop** as proof; use journal recipe below + unit tests.

## Diagnose live failures

```bash
journalctl -b -1 --no-pager | rg -i \
  'uwsm|graphical-session|eye-comfort|sddm-helper exited|already active'
```

| Observation | Meaning |
|-------------|---------|
| `Reached target Current graphical user session` **before** `uwsm` / Hyprland | Something pulled the target early (check `Wants=` on timer services) |
| `A compositor or graphical-session* target is already active!` | UWSM race — classic failure mode |
| `sddm-helper exited with 1` right after | Session aborted; matches first-boot fail |

Success: graphical-session target only after UWSM starts the compositor envelope.

## Intelligence rules (do not rationalize around)

- “I need Wants= so the service waits for the session” → **false**. `After=` does not wait if the target is never pulled; use a path condition or bind to a real compositor unit that UWSM owns, not a bare target pull from a Persistent timer.
- “It only runs After=graphical-session so Wants= is fine” → **false**. `Wants=` still **starts** the target.
- “Second boot works so it’s firmware” → **false** for this fingerprint; Persistent catch-up explains second-boot success.
- Theme color / eye-comfort palette changes do not require session-target pulls. Keep units order-safe independently of palettes.

## Related footguns

- Dual timers both touching the same theme swap path → use `Conflicts=` (see eye-comfort timer mutex tests).
- `systemctl --user daemon-reload` after unit edits; install scripts should copy units then enable **one** of mutually exclusive timers.
- System-level (`/etc/systemd/system`) power/suspend units are a **different** domain; this skill is about **user session order** with UWSM/Hyprland.

## When to load this skill

Auto-invoke on: user systemd unit edits, eye-comfort `units/*`, `install.sh --with-*-timer`, UWSM/Hyprland session bugs, “first boot fails second works”, `graphical-session.target` in unit files, blank Wayland after autologin.
