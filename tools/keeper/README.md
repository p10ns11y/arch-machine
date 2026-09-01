# keeper

**Location:** `tools/keeper` (first-class product next to `archy` / `groxy`).  
**Install hook:** security expand builds and installs the binary  
(`modules/security/install.sh --agent-expand` → `~/.local/bin/keeper`).

Local vault for a few **high-value** secrets (MFA packs, break-glass tokens).  
Not a password manager for every site key.

---

## Mental model (30 seconds)

**Any 2 of 3 unlock:**

| Slot | What | Daily role |
|------|------|------------|
| **Remember** | 1 passphrase | Human factor for `get` / `put` |
| **Store offline** | 1 escrow file | USB / other house — **not only under `$HOME`** for real recovery |
| **Free** | This device | Automatic fingerprint; laptop alone must not open the vault |
| **Optional** | YubiKey | Strong path; **never enough alone** |

| Status field | Means |
|--------------|--------|
| `healthy` / `drillProven` | You once proved recover **without** passphrase |
| | It does **not** leave the vault open |

Default: **k=2 of n=3**. Knowledge factor is **not** in the default path.  
Deeper: [docs/OPERATOR-MODEL.md](docs/OPERATOR-MODEL.md) · [docs/SECRETS-EVERYDAY.md](../../docs/SECRETS-EVERYDAY.md)

```text
                    ┌─ passphrase + device ──────── get / put (daily)
  root reconstruct ─┼─ offline escrow + device ──── get-escrow / put-escrow / recover
                    └─ passphrase + escrow ──────── new machine (then rebind)
```

---

## Install (once per machine)

```bash
# Preferred — release build + ~/.local/bin/keeper
./modules/security/install.sh --agent-expand

# Manual
cd /path/to/arch-machine/tools/keeper
cargo test && cargo build --release
install -m 755 target/release/keeper ~/.local/bin/keeper
# ensure ~/.local/bin is on PATH
command -v keeper && keeper --help
```

Prefer the installed `keeper` over `cargo run`.

---

## Before real secrets (rules)

1. Complete **§ Practice flow** first — never put live MFA into a broken setup.
2. Real escrow must leave this laptop (USB / other house). `$HOME`-only is theater.
3. No secrets on argv (`--value` hits shell history). Use prompts or `--file` mode `600`.
4. Never set `KEEPER_YUBI_MOCK_SECRET` on a vault with real secrets.
5. After **`enroll-yubikey`**, **`rebind`**, or **`passwd-reset`**, escrow is **rewritten** — copy the **new** file offline.
6. Lose **two** of {passphrase, offline escrow, this machine} → unrecoverable by design.

---

# Flow A — Practice (safe, do this first)

**Goal:** Prove init → store → read with passphrase → read **without** passphrase → recover drill → optional loop.  
**Paths:** throwaway under `$HOME/tmp` (escrow under `$HOME` is OK for practice only).

### A1. Interactive (recommended)

```bash
keeper loop --practice
```

What happens:

1. Warning if escrow is under `$HOME` (expected in practice).
2. **Passphrase** (not echoed) ×2 — remember it or write it down for this session only.
3. **Init** vault (`k=2 n=3`, PQ seal).
4. **Secret name** + **secret value** (not echoed).
5. Auto-check: get (passphrase+device), get via escrow (no passphrase), recover → `healthy=true`.
6. Prompt: **Enter command loop?** → `Y`

### A2. Loop after onboard (practice)

First word is the command; optional name after:

```text
keeper> list
recoverykeyvaluetest

keeper> get-escrow recoverykeyvaluetest
# prints secret — NO passphrase (offline escrow + this device)

keeper> get recoverykeyvaluetest
Passphrase: ****
# prints secret — needs the passphrase you set at init

keeper> help
keeper> quit
```

| Want | Type in loop |
|------|----------------|
| Names only | `list` |
| Read **without** passphrase | `get-escrow NAME` |
| Read with passphrase | `get NAME` |
| Store another secret | `put NAME` |
| Store **without** passphrase | `put-escrow NAME` |
| Change passphrase (know old) | `passwd` |
| Forgot passphrase | `passwd-reset` then `recover` |
| Health | `status` |
| Leave | `quit` |

**Common mistakes**

| Typed | Problem | Use instead |
|-------|---------|-------------|
| `get --escrow` | not a loop command | `get-escrow NAME` |
| `put --escrow` | not a loop command | `put-escrow NAME` |
| `get NAME` with wrong passphrase | wrap fails | retype carefully, or `get-escrow NAME`, or `passwd-reset` |
| Expecting `healthy` to skip passphrase | design | healthy ≠ open session |

### A3. Scripted practice (CI / automation)

```bash
export KEEPER_ROOT="$HOME/tmp/keeper-practice-vault"
export KEEPER_PASSPHRASE='practice-only-not-real'
mkdir -p "$HOME/tmp"
ESCROW="$HOME/tmp/keeper-practice-escrow.json"
rm -rf "$KEEPER_ROOT" "$ESCROW"

keeper init --escrow "$ESCROW"
printf 'demo-secret\n' > "$HOME/tmp/keeper-practice-secret.txt"
chmod 600 "$HOME/tmp/keeper-practice-secret.txt"
keeper put demo --file "$HOME/tmp/keeper-practice-secret.txt"
keeper get demo                                    # passphrase path
unset KEEPER_PASSPHRASE
keeper get demo --escrow "$ESCROW"                 # no passphrase
keeper put-escrow demo --file "$HOME/tmp/keeper-practice-secret.txt" --escrow "$ESCROW"  # no passphrase
keeper recover --escrow "$ESCROW"
keeper status                                      # healthy + drillProven

rm -rf "$KEEPER_ROOT" "$ESCROW" "$HOME/tmp/keeper-practice-secret.txt"
unset KEEPER_ROOT KEEPER_PASSPHRASE
```

If any step fails, stop. Do **not** move real secrets into a broken setup.

### A4. Cleanup practice vault

```bash
rm -rf "$HOME/tmp/keeper-practice-vault" "$HOME/tmp/keeper-practice-escrow.json"
```

---

# Flow B — Real vault (only after practice works end-to-end)

**Goal:** Durable vault on this machine + escrow **off** the machine + one no-passphrase drill before real MFA.

### B1. Choose paths once

```bash
export KEEPER_ROOT="${KEEPER_ROOT:-$HOME/.local/share/keeper}"

# Escrow MUST be removable / off-box for real recovery
# ESCROW=/run/media/$USER/USBSTICK/keeper-escrow.json
ESCROW="${ESCROW:?set ESCROW to a path on removable media}"
```

| | Practice | Real |
|--|----------|------|
| `KEEPER_ROOT` | `~/tmp/keeper-practice-vault` | `~/.local/share/keeper` (default) |
| Escrow | may be under `$HOME` | **USB / other house** |
| Passphrase | throwaway | strong; password manager entry OK |
| Secrets | junk only | MFA / break-glass only |

### B2. Init (once)

**Interactive (preferred):**

```bash
# USB mounted; ESCROW points at the stick
keeper loop --escrow "$ESCROW"
# same wizard as practice, but refuse to treat $HOME-only escrow lightly
```

**CLI:**

```bash
if [ -f "$KEEPER_ROOT/meta.json" ]; then
  echo "Vault already exists at $KEEPER_ROOT — aborting init."
  exit 1
fi
# set passphrase via prompt (TTY) or KEEPER_PASSPHRASE / KEEPER_PASSPHRASE_FILE
keeper init --escrow "$ESCROW"
# Immediately: second offline copy of escrow if possible; unmount USB
```

### B3. Store and daily read

```bash
# Interactive (no secrets on argv)
keeper put mfa
keeper get mfa

# Or file:
umask 077
# write secret to a 600 file, then:
keeper put mfa --file /path/to/600-file
shred -u /path/to/600-file 2>/dev/null || rm -f /path/to/600-file
```

**Loop on an existing real vault:**

```bash
keeper loop --escrow "$ESCROW" --menu-only
# or: keeper   (if vault exists, skips full init)
keeper> list
keeper> get mfa
keeper> get-escrow mfa    # USB mounted
```

### B4. Mandatory recover drill (before you trust the vault)

```bash
# Prefer a shell without KEEPER_PASSPHRASE set
unset KEEPER_PASSPHRASE
# remount USB so ESCROW is readable
keeper recover --escrow "$ESCROW"
keeper status
# need: "healthy": true, "drillProven": true
```

Until recover works **without** the passphrase, treat the vault as unproven.

### B5. Day-to-day cheat sheet

| Situation | What to run |
|-----------|-------------|
| Daily unlock | `keeper get NAME` or loop `get NAME` |
| Forgot passphrase, same PC, USB present | `keeper get NAME --escrow USB` or loop `get-escrow NAME` |
| Store without passphrase, same PC, USB present | `keeper put-escrow NAME --escrow USB --file PATH` or loop `put-escrow NAME` |
| Change passphrase (you know the old one) | `keeper passwd` or loop `passwd` — **secrets kept, escrow unchanged** |
| Forgot passphrase, same PC, USB present | `keeper passwd-reset --escrow USB` or loop `passwd-reset` — **secrets kept, escrow rewritten** |
| New machine / reimage | restore vault files → `rebind --escrow` → copy new escrow → `recover` → `get` |
| Lost passphrase **and** escrow | secrets are gone |

### B6. New machine / reimage

```bash
# Vault files restored on NEW host; USB with escrow present
keeper rebind --escrow "$ESCROW"   # passphrase + offline; reseals device
# copy NEW escrow offline again
keeper recover --escrow "$ESCROW"
keeper get mfa
```

Old device fingerprint no longer opens with passphrase (or escrow) as if still current.

---

## Optional: YubiKey (strong path)

Only after practice + real recover drill succeed.

- HMAC-SHA1 challenge-response on a slot (default **2**)
- `ykchalresp` on PATH

```bash
keeper enroll-yubikey --escrow "$ESCROW"
# Copy NEW escrow offline. Discard previous USB copy.
unset KEEPER_PASSPHRASE
keeper get mfa --yubi
keeper yubi-probe   # must reject solo Yubi
```

`KEEPER_YUBI_MOCK_SECRET` is **tests/CI only**.

---

## Command reference

### Interactive loop (`keeper` / `keeper loop`)

| Command | Meaning |
|---------|---------|
| `help` | Full list |
| `list` | Secret names (no unlock) |
| `get [name]` | Passphrase + device |
| `get-escrow [name]` | Offline + device — **no passphrase** |
| `put [name]` | Store (prompts passphrase + value) |
| `put-escrow [name]` | Store via escrow — **no passphrase** |
| `status` | Health (healthy ≠ open) |
| `recover` | Offline + device drill |
| `rebind` | New machine reseal |
| `passwd` | Change passphrase (know old) |
| `passwd-reset` | Forgot passphrase (escrow + device) |
| `quit` | Exit loop |

### CLI (non-loop)

| Goal | Command |
|------|---------|
| Onboard / loop | `keeper` · `keeper loop` · `keeper loop --practice` |
| Init | `init --escrow PATH` |
| Put | `put NAME` or `put NAME --file PATH` |
| Put (no passphrase) | `put-escrow NAME --escrow PATH` (and `--file`) |
| Get (daily) | `get NAME` |
| Get (no passphrase) | `get NAME --escrow PATH` |
| Recover drill | `recover --escrow PATH` |
| Change passphrase | `passwd` |
| Reset passphrase | `passwd-reset --escrow PATH` |
| Rebind device | `rebind --escrow PATH` |
| Yubi enroll / strong get | `enroll-yubikey --escrow PATH` · `get NAME --yubi` |
| Solo-Yubi check | `yubi-probe` |

### Environment

| Variable | Meaning |
|----------|---------|
| `KEEPER_ROOT` | Vault dir (default `~/.local/share/keeper`) |
| `KEEPER_PASSPHRASE` | Session passphrase (automation; prefer TTY prompt) |
| `KEEPER_PASSPHRASE_FILE` | Passphrase from file (mode `600`) |
| `KEEPER_NEW_PASSPHRASE` | New passphrase for non-TTY `passwd` / `passwd-reset` |
| `KEEPER_INSTALL_BIN` | Install dir for agent-expand (default `~/.local/bin`) |
| `KEEPER_YUBI_MOCK_SECRET` | **Test-only** fake YubiKey |
| `KEEPER_ALLOW_YUBI_MOCK` | Set `1` only in CI |

---

## What is sealed where

| Piece | Protection |
|-------|------------|
| Passphrase share | scrypt wrap under `KEEPER_ROOT` |
| Offline share | Plaintext **only** in your escrow file |
| Device share | Sealed to machine fingerprint |
| YubiKey share (optional) | HMAC-SHA1 challenge-response |
| Named secrets | Hybrid PQ: ML-KEM-768 + AES-GCM after root reconstruct |

Passphrase is never stored as plaintext. Public ISP IP is never a factor.

**Honest keylog note:** Non-echo prompts + no-argv stop history leaks. A compromised desktop keylogger can still steal typed secrets; YubiKey raises the bar. No perfect desktop immunity.

---

## Stop conditions

| Situation | Action |
|-----------|--------|
| `init`: vault already exists | New `KEEPER_ROOT` or use existing vault |
| `recover` fails | Fix escrow path / machine; do not delete vault blindly |
| Escrow only under `$HOME` (real use) | Copy offline before anything you care about |
| Lost passphrase **and** escrow | Secrets gone — no vendor backdoor |
| `yubi-probe` opens solo | Stop; file a bug |
| Reimaged without rebind | `rebind --escrow` then `recover` |

---

## More docs

| Doc | Use |
|-----|-----|
| [OPERATOR-MODEL.md](docs/OPERATOR-MODEL.md) | Loss matrix · remember / store / free |
| [THREAT-MODEL.md](docs/THREAT-MODEL.md) | Adversaries and invariants |
| [RECOVERY-CEREMONY.md](docs/RECOVERY-CEREMONY.md) | Ceremony steps |
| [LOCATION.md](docs/LOCATION.md) | Why IP is not trust |
| [arch-design/keeper.md](../../arch-design/keeper.md) | Architecture |

---

**Plain rule:** Practice with junk first. One passphrase, one offline escrow, machine free. Prove `get-escrow` / `recover` before real MFA. Prefer `keeper loop`. YubiKey is optional muscle, never the only key.
