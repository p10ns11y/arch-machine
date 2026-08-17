# Omarchy + arch-machine

**Omarchy** is the host desktop (Hyprland, Walker, themes, `omarchy` CLI).  
**arch-machine / tinfoil / archy** is the sentinel (profiles, inventory, audit, evidence).

They cooperate; they do not fork each other.

## Day-1 on an Omarchy machine

1. Thin sentinel only (no heavy ML profile unless you asked):
   ```bash
   ./install.sh --thin
   # or: tinfoil install --thin  (if already on PATH)
   ```
2. See what Omarchy already owns vs what you added:
   ```bash
   tinfoil inventory --json | jq .summary.ownership
   # arch_machine / omarchy_baseline / user_explicit
   ```
3. Omarchy desktop status (read-only):
   ```bash
   tinfoil omarchy
   # or: ./maintenance/omarchy-status.sh --json
   ```
4. Search arch-machine catalog (tools.yaml + profiles):
   ```bash
   tinfoil search docker
   tinfoil search rocm --json
   ```
5. Prefer Omarchy for interactive package taste:
   ```bash
   omarchy pkg install          # fuzzy TUI
   omarchy pkg add <pkg>        # silent if present
   omarchy pkg present jq git   # probe
   ```
6. Consent-gated actuate plan (arch-machine; dry-run default):
   ```bash
   tinfoil pkg --update jq
   tinfoil pkg --remove some-toy --dry-run
   # real remove needs --yes --i-accept-risk; refuse-list blocks base/linux/…
   ```

## Ownership model (SN-OM-1)

| Tag | Meaning |
|-----|---------|
| `omarchy-baseline` | In `config/baselines/omarchy.yaml` or live `$OMARCHY_PATH/install/omarchy-*.packages` |
| `arch-machine` | Named in `config/tools.yaml` (profile-managed) |
| `user-explicit` | Explicit pacman install, neither baseline nor tools.yaml |

Priority when tagging: **arch-machine > omarchy-baseline > user-explicit**.

## Command map (safe vs mutating)

Full table: [omarchy-commands.md](./omarchy-commands.md).

### Read-only (safe for agents / archy jobs)

| Command | Use |
|---------|-----|
| `omarchy version` / `version branch` / `version channel` | Identify host channel |
| `omarchy theme current` / `theme list` | Theme state |
| `omarchy update available` | Is Omarchy behind? |
| `omarchy pkg present <pkgs…>` | Presence probe |
| `omarchy pkg missing <pkgs…>` | Inverse probe |
| `omarchy battery status` | Laptop status (if present) |
| `omarchy debug --print` | Diagnostics (may be long) |

### Mutating (human consent; not auto-run from archy)

| Command | Use |
|---------|-----|
| `omarchy pkg add` / `pkg drop` / `pkg install` / `pkg remove` | Package taste |
| `omarchy update` / `update perform` | Full system + Omarchy update |
| `omarchy theme set` | Apply theme (eye-comfort uses this path) |
| `omarchy refresh *` | Reset configs from Omarchy defaults |
| `omarchy setup *` | DNS, fingerprint, FIDO2, … |

## archy control plane

`archy` menu includes **Omarchy status** → runs `maintenance/omarchy-status.sh` and streams stdio.

Mutating Omarchy package/theme flows stay in Omarchy’s own TUI/`omarchy menu` until multi-select actuate lands.

## Paths

| What | Where |
|------|--------|
| Omarchy install root | `$OMARCHY_PATH` or `~/.local/share/omarchy` |
| Package lists (baseline) | `$OMARCHY_PATH/install/omarchy-base.packages` |
| CLI binaries | `$OMARCHY_PATH/bin/omarchy-*` |
| arch-machine baseline snapshot | `config/baselines/omarchy.yaml` |
| Full command reference | `docs/omarchy-commands.md` |
| Personal heading / kanithanj.ai / 20:00 timer | `modules/productivity/personal-tweaks/` (`install.sh --yes`) |
