# Regression: first boot after shutdown fails (UWSM × graphical-session)

**Status:** fixed in units (keep this doc + skill + unit tests).  
**Date found:** 2026-07-16 · **Host pattern:** Framework 13 AMD, SDDM autologin → UWSM → Hyprland (Omarchy), `loginctl` Linger=yes.

## Symptom

With or without AC power:

1. **Normal shutdown** → next cold boot: desktop **fails** the first time (blank / no Hyprland / immediate hard-power).
2. **Hard power button** off → start again: **second** boot works.
3. Independent of plugged-in vs battery.

Journal fingerprint on the failed boot:

```text
Reached target Current graphical user session
Starting Apply eye-comfort Tamil Nadu ...
uwsm: A compositor or graphical-session* target is already active!
sddm-helper exited with 1
```

## Root cause

Three factors combined:

| Factor | Role |
|--------|------|
| `Linger=yes` | User systemd manager starts at boot / early login, not only after a compositor exists. |
| `Persistent=true` on eye-comfort **user timers** | After long downtime, the timer fires **catch-up** as soon as the user manager is up. |
| Service had `Wants=graphical-session.target` | **Pulls and activates** `graphical-session.target` without a compositor. |

Sequence on the failed first boot:

1. User manager starts → timers.target → eye-comfort timer fires.
2. Oneshot service `Wants=graphical-session.target` → target becomes **active** with no Hyprland.
3. SDDM starts `uwsm start … hyprland.desktop`.
4. UWSM refuses: session target already active → no compositor.
5. User hard-powers. Second boot often works because the Persistent catch-up was already consumed; next `OnCalendar` is later, so UWSM wins the race.

**Not the cause:** theme palettes, Ghostty/nvim colors, AC/battery, NVIDIA suspend (host is amdgpu). Theme **content** is user-session-only; the **unit dependency** was the bug.

## Fix

Shipped units (`units/eye-comfort-theme.service`, `units/eye-comfort-tn.service`):

- **Keep** `After=graphical-session.target` (ordering only when both start).
- **Do not** use `Wants=` / `Requires=` / `BindsTo=` on `graphical-session.target` (or compositor targets) from timer-driven oneshots under Linger + Persistent.

Deploy:

```bash
./modules/productivity/eye-comfort/install.sh --with-tn-timer   # or --with-timer
# or: copy units → ~/.config/systemd/user/ && systemctl --user daemon-reload
```

## Closed-loop tests

```bash
python3 modules/productivity/eye-comfort/lib/test_timer_mutex.py
# must include: test_services_do_not_pull_graphical_session
```

Audit units (any path):

```bash
rg -n '^(Wants|Requires|BindsTo)=.*graphical-session' \
  modules/productivity/eye-comfort/units \
  ~/.config/systemd/user
```

Expect **no** matches on shipped services.

## Re-verify after cold boot

After a **normal** shutdown and one cold start (should succeed post-fix):

```bash
# On the boot that just came up, or previous if diagnosing a fail:
journalctl -b -1 --no-pager | rg -i 'uwsm|graphical-session|eye-comfort|sddm-helper exited|already active'
```

**Pass:** `Reached target Current graphical user session` only **after** UWSM/Hyprland start lines; no `already active!` before compositor.

**Fail (old bug):** eye-comfort / `Reached target Current graphical user session` **before** `uwsm` start, then `already active!` and `sddm-helper exited with 1`.

## Agent prevention

Use skill **`session-unit-order`**:

- Repo: `.agents/skills/session-unit-order/`
- User: `~/skills/session-unit-order` → same tree (symlink)

Load when editing user systemd units, eye-comfort timers, UWSM/Hyprland session startup, or diagnosing first-boot-after-shutdown login failures.
