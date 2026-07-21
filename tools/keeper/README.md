# keeper

**Location:** `tools/keeper` (first-class product next to `archy` / `groxy`).  
Security module expand still **builds and installs** the binary (`modules/security/install.sh --agent-expand`).

Local vault for a few **high-value** secrets (MFA packs, break-glass tokens).  
Not a password manager for every site key.

**Recommended entry:** `keeper` or `keeper loop` — interactive onboard that never puts secrets on argv or shell history.

**Rule of three (any 2 unlock):**

| You | What | Rule |
|-----|------|------|
| **Remember** | 1 passphrase | Only human secret. Prefer a password manager *entry*, not a sticky note. |
| **Store offline** | 1 escrow file | Must leave this laptop (USB / other house). A file that only lives in `$HOME` is **not** recovery. |
| **Free** | This device | Automatic. Stolen laptop alone must not open the vault. |
| **Optional strong** | YubiKey | Extra share. **Never** enough alone. |

Secrets open only when you run `get` with enough factors.  
`status` saying `healthy` only means “you once proved recover works” — it does **not** leave the vault open.

Default protocol: **k=2 of n=3** (passphrase · offline · device). Knowledge factor is **not** part of the default path.  
Deeper model: [docs/OPERATOR-MODEL.md](docs/OPERATOR-MODEL.md) · everyday API-key hygiene: [docs/SECRETS-EVERYDAY.md](../../docs/SECRETS-EVERYDAY.md)

---

## Before you touch real secrets

1. **Practice first** with `keeper loop --practice` (or throwaway dirs) — not `~/.local/share/keeper` with real MFA codes.
2. **Never** put the live escrow file only under `~/` and forget a USB copy.
3. **Never** put real secrets on the shell command line (`--value '…'` lands in history). Prefer interactive prompts or `--file` with mode `600`.
4. **Never** set `KEEPER_YUBI_MOCK_SECRET` when storing real secrets (fake key for tests/CI only).
5. After **`enroll-yubikey`** or **`rebind`**, the escrow file is **rewritten**. Copy the **new** escrow offline again.
6. If you lose **two** of {passphrase, offline escrow, this machine}, recovery is impossible. That is intentional.

---

## 0. Install (once per machine)

```bash
# From security module expand (builds tools/keeper release + installs ~/.local/bin/keeper):
./modules/security/install.sh --agent-expand

# Or manual:
cd /path/to/arch-machine/tools/keeper
cargo test
cargo build --release
install -m 755 target/release/keeper ~/.local/bin/keeper
# ensure ~/.local/bin is on PATH
command -v keeper && keeper --help

# Or from repo root:
# cargo test --manifest-path tools/keeper/Cargo.toml
# cargo build --release --manifest-path tools/keeper/Cargo.toml
```

After install, prefer `keeper` over `cargo run`.

---

## 1. Practice path (safe — do this first)

### 1a. Interactive (recommended)

```bash
keeper loop --practice
# prompts (not echoed): passphrase ×2, secret name, secret value
# walks: init → put → get → get-via-escrow → recover → status healthy
# then optional command menu (status / get / put / recover / rebind / quit)
```

Secrets are entered only at prompts. Nothing lands in shell history.

### 1b. Scripted practice (automation / CI-shaped)

```bash
cd /path/to/arch-machine/tools/keeper

export KEEPER_ROOT="$HOME/tmp/keeper-practice-vault"
export KEEPER_PASSPHRASE='practice-only-not-real'
mkdir -p "$HOME/tmp"
ESCROW="$HOME/tmp/keeper-practice-escrow.json"
rm -rf "$KEEPER_ROOT" "$ESCROW"

keeper init --escrow "$ESCROW"
printf 'demo-secret\n' > "$HOME/tmp/keeper-practice-secret.txt"
chmod 600 "$HOME/tmp/keeper-practice-secret.txt"
keeper put demo --file "$HOME/tmp/keeper-practice-secret.txt"
keeper get demo
# expect: demo-secret

unset KEEPER_PASSPHRASE
keeper get demo --escrow "$ESCROW"
# expect: demo-secret

keeper recover --escrow "$ESCROW"
keeper status
# expect: "healthy": true, "drillProven": true

rm -rf "$KEEPER_ROOT" "$ESCROW" "$HOME/tmp/keeper-practice-secret.txt"
unset KEEPER_ROOT KEEPER_PASSPHRASE
```

If any step fails, stop. Do **not** move real secrets into a broken setup.

---

## 2. Real vault (only after practice works)

### 2a. Paths you choose once

```bash
export KEEPER_ROOT="${KEEPER_ROOT:-$HOME/.local/share/keeper}"
# Prefer: keeper loop   (prompts for passphrase; no env required)
# Or session: export KEEPER_PASSPHRASE_FILE="$HOME/.config/keeper/passphrase"  # mode 600

# Escrow must be a path you will COPY OFF the machine (USB mount preferred).
# ESCROW=/run/media/$USER/USBSTICK/keeper-escrow.json
ESCROW="${ESCROW:?set ESCROW to a path on removable media}"
```

If `ESCROW` is still under `$HOME` only, you do not have offline recovery.

### 2b. Init (once) — or just `keeper loop`

```bash
if [ -f "$KEEPER_ROOT/meta.json" ]; then
  echo "Vault already exists at $KEEPER_ROOT — aborting init."
  exit 1
fi
keeper init --escrow "$ESCROW"
# Immediately: copy escrow to a second offline place if USB is your only copy.
```

### 2c. Store and read (no secrets on argv)

```bash
# Interactive (preferred):
keeper put mfa
# prompts for passphrase (if not in env) and secret value (non-echo)

# Or file:
umask 077
printf '%s' 'PASTE_OR_TYPE_SECRET_HERE' > /tmp/keeper-in.txt
chmod 600 /tmp/keeper-in.txt
keeper put mfa --file /tmp/keeper-in.txt
shred -u /tmp/keeper-in.txt 2>/dev/null || rm -f /tmp/keeper-in.txt

keeper get mfa
```

`--value` still works for tests but prints a **history warning** — do not use for real secrets.

### 2d. Mandatory recover drill (before you trust the vault)

```bash
unset KEEPER_PASSPHRASE
keeper recover --escrow "$ESCROW"
keeper status
# healthy + drillProven must be true
```

Until this works **without** the passphrase, treat the vault as unproven.

### 2e. New machine / reimage — `rebind`

After copying vault files to a new host (or after reimage that changes machine fingerprint):

```bash
# On the NEW machine, with vault files restored and escrow present:
keeper rebind --escrow "$ESCROW"
# needs passphrase + offline escrow; reseals device share to this machine
# escrow is rewritten — copy NEW escrow offline again
keeper recover --escrow "$ESCROW"   # drill once on new binding
keeper get mfa                     # passphrase + new device
```

Old device binding no longer opens secrets with passphrase (or escrow) as if still current.

---

## 3. Optional: YubiKey (strong path)

**Do this only after §1 practice and §2 drill succeed.**

Requirements for **live** key:

- YubiKey with **HMAC-SHA1 challenge-response** programmed on a slot (default slot **2**)
- `ykchalresp` on PATH
- You will touch the key when prompted

```bash
keeper enroll-yubikey --escrow "$ESCROW"
# Copy NEW escrow off-machine. Destroy previous escrow copies.
unset KEEPER_PASSPHRASE
keeper get mfa --yubi
keeper yubi-probe   # expect soloYubiRejected
```

`KEEPER_YUBI_MOCK_SECRET` is **tests/CI only** — refused when the vault already has named secrets.

---

## 4. Command cheat sheet

| Goal | Command |
|------|---------|
| **Secure onboard + menu** | `keeper` / `keeper loop` / `keeper loop --practice` |
| Create vault | `init --escrow PATH` |
| Store secret | `put NAME` (prompt) or `put NAME --file PATH` |
| Daily read | `get NAME` (passphrase + device) |
| No passphrase (same machine) | `get NAME --escrow PATH` · loop: **`get-escrow NAME`** |
| Prove recover | `recover --escrow PATH` then `status` |
| Change passphrase (know old) | `passwd` · loop: **`passwd`** — secrets + escrow stay |
| Forgot passphrase | `passwd-reset --escrow PATH` · loop: **`passwd-reset`** — rewrites escrow |
| New machine | `rebind --escrow PATH` then `recover` |
| Add YubiKey | `enroll-yubikey --escrow PATH` |
| Strong read | `get NAME --yubi` |
| Solo-Yubi safety check | `yubi-probe` |

### Loop quick reference

```text
keeper> list
keeper> get mfa              # prompts passphrase
keeper> get-escrow mfa       # NO passphrase (needs offline escrow file)
keeper> passwd               # change passphrase; secrets kept
keeper> passwd-reset         # forgot P; escrow+device → new P (copy new escrow)
keeper> help
```

Environment:

| Variable | Meaning |
|----------|---------|
| `KEEPER_ROOT` | Vault directory (default `~/.local/share/keeper`) |
| `KEEPER_PASSPHRASE` | Session passphrase (automation; prefer prompt / file) |
| `KEEPER_PASSPHRASE_FILE` | Passphrase from file instead of env |
| `KEEPER_INSTALL_BIN` | Override install dir for `--agent-expand` (default `~/.local/bin`) |
| `KEEPER_YUBI_MOCK_SECRET` | **Test-only** fake YubiKey |
| `KEEPER_ALLOW_YUBI_MOCK` | Set `1` only in CI |

---

## 5. What is sealed where

| Piece | How it is protected |
|-------|---------------------|
| Share (passphrase) | scrypt wrap on disk under `KEEPER_ROOT` |
| Share (offline) | Plaintext **only** in your escrow file — you move it offline |
| Share (device) | Sealed to this machine’s fingerprint |
| Share (YubiKey, optional) | Sealed under HMAC-SHA1 challenge-response |
| Named secrets | Hybrid PQ: ML-KEM-768 + AES-GCM after root is reconstructed |

Passphrase is never written into the vault as plaintext.  
Public ISP IP is never a factor.

**Honest keylog note:** Non-echo TTY prompts and no-argv prevent *shell history* and shoulder-surfing of argv. A compromised kernel/userland keylogger can still steal typed secrets; optional YubiKey raises the bar. There is no perfect desktop immunity.

---

## 6. Stop conditions (do not “push through”)

| Situation | Action |
|-----------|--------|
| `init` says vault already exists | Do not force; use existing vault or a new `KEEPER_ROOT` |
| `recover` fails | Do not delete vault; fix escrow path / passphrase / machine |
| Escrow only exists under `$HOME` | Copy offline before storing anything you care about |
| Lost passphrase **and** escrow | Secrets are gone — no vendor backdoor |
| `yubi-probe` does not reject solo open | Stop; file a bug; do not trust that build |
| Reimaged without rebind | Use `rebind --escrow` with passphrase + offline share |

---

## 7. More docs

| Doc | Use |
|-----|-----|
| [OPERATOR-MODEL.md](docs/OPERATOR-MODEL.md) | Remember / store / free / loss matrix |
| [THREAT-MODEL.md](docs/THREAT-MODEL.md) | Adversaries and invariants |
| [RECOVERY-CEREMONY.md](docs/RECOVERY-CEREMONY.md) | Ceremony steps |
| [LOCATION.md](docs/LOCATION.md) | Why IP is not trust |
| [arch-design/keeper.md](../../arch-design/keeper.md) | Architecture |

---

**Plain rule:** Practice once with junk data. One passphrase, one offline escrow, machine free. Prove recover before real secrets. Prefer `keeper loop`. YubiKey is optional muscle, never the only key.
