# keeper

Local vault for a few **high-value** secrets (MFA packs, break-glass tokens).  
Not a password manager for every site key.

**Rule of three (any 2 unlock):**

| You | What | Rule |
|-----|------|------|
| **Remember** | 1 passphrase | Only human secret. Prefer a password manager *entry*, not a sticky note. |
| **Store offline** | 1 escrow file | Must leave this laptop (USB / other house). A file that only lives in `$HOME` is **not** recovery. |
| **Free** | This device | Automatic. Stolen laptop alone must not open the vault. |
| **Optional strong** | YubiKey | Extra share. **Never** enough alone. |

Secrets open only when you run `get` with enough factors.  
`status` saying `healthy` only means “you once proved recover works” — it does **not** leave the vault open.

Deeper model: [docs/OPERATOR-MODEL.md](docs/OPERATOR-MODEL.md) · everyday API-key hygiene: [docs/SECRETS-EVERYDAY.md](../../../docs/SECRETS-EVERYDAY.md)

---

## Before you touch real secrets

Read this list once. Skipping it is how people lock themselves out or leave recovery on the same disk.

1. **Practice first** with a throwaway vault under `/tmp` or a throwaway directory — not `~/.local/share/keeper` with real MFA codes.
2. **Never** put the live escrow file only under `~/` and forget a USB copy.
3. **Never** put real secrets on the shell command line (`--value '…'` lands in history). Use `--file` with mode `600`.
4. **Never** set `KEEPER_YUBI_MOCK_SECRET` when storing real secrets (that is a fake key for tests/CI only).
5. After **`enroll-yubikey`**, the escrow file is **rewritten**. Copy the **new** escrow offline again; throw away the old USB copy.
6. If you lose **two** of {passphrase, offline escrow, this machine}, recovery is impossible. That is intentional.

---

## 0. Build (once per machine)

```bash
cd /path/to/arch-machine/modules/security/keeper
cargo test
cargo build --release
# optional convenience:
# install -m 755 target/release/keeper ~/.local/bin/keeper
```

Below, either use `cargo run --quiet --` from this directory, or `keeper` if installed.

---

## 1. Practice path (safe — do this first)

Uses throwaway dirs and a demo secret. No USB required for learning.

```bash
cd /path/to/arch-machine/modules/security/keeper

export KEEPER_ROOT="$HOME/tmp/keeper-practice-vault"
export KEEPER_PASSPHRASE='practice-only-not-real'
mkdir -p "$HOME/tmp"
ESCROW="$HOME/tmp/keeper-practice-escrow.json"
rm -rf "$KEEPER_ROOT" "$ESCROW"

cargo run --quiet -- init --escrow "$ESCROW"
printf 'demo-secret\n' > "$HOME/tmp/keeper-practice-secret.txt"
chmod 600 "$HOME/tmp/keeper-practice-secret.txt"
cargo run --quiet -- put demo --file "$HOME/tmp/keeper-practice-secret.txt"
cargo run --quiet -- get demo
# expect: demo-secret

# Prove “forgot passphrase” on the same machine:
unset KEEPER_PASSPHRASE
cargo run --quiet -- get demo --escrow "$ESCROW"
# expect: demo-secret

cargo run --quiet -- recover --escrow "$ESCROW"
cargo run --quiet -- status
# expect: "healthy": true, "drillProven": true

# cleanup practice
rm -rf "$KEEPER_ROOT" "$ESCROW" "$HOME/tmp/keeper-practice-secret.txt"
unset KEEPER_ROOT KEEPER_PASSPHRASE
```

If any step fails, stop. Do **not** move real secrets into a broken setup.

---

## 2. Real vault (only after practice works)

### 2a. Paths you choose once

```bash
cd /path/to/arch-machine/modules/security/keeper

# Durable vault on this machine (default if unset: ~/.local/share/keeper)
export KEEPER_ROOT="${KEEPER_ROOT:-$HOME/.local/share/keeper}"

# Passphrase: use env for this session, or:
# export KEEPER_PASSPHRASE_FILE="$HOME/.config/keeper/passphrase"
# (file mode 600; do not commit it)

# Escrow must be a path you will COPY OFF the machine (USB mount preferred).
# Example while USB is mounted:
# ESCROW=/run/media/$USER/USBSTICK/keeper-escrow.json
ESCROW="${ESCROW:?set ESCROW to a path on removable media}"
```

If `ESCROW` is still under `$HOME` only, you do not have offline recovery.

### 2b. Init (once)

```bash
# Refuse accidental second init
if [ -f "$KEEPER_ROOT/meta.json" ]; then
  echo "Vault already exists at $KEEPER_ROOT — aborting init."
  exit 1
fi

test -n "${KEEPER_PASSPHRASE:-}${KEEPER_PASSPHRASE_FILE:-}" || {
  echo "Set KEEPER_PASSPHRASE or KEEPER_PASSPHRASE_FILE first."
  exit 1
}

cargo run --quiet -- init --escrow "$ESCROW"
# Immediately: copy escrow to a second offline place if USB is your only copy.
# Then unmount USB and verify the file is not the only copy on the laptop disk.
```

### 2c. Store and read (no secrets on argv)

```bash
# Write secret into a temp file, not the command line
umask 077
printf '%s' 'PASTE_OR_TYPE_SECRET_HERE' > /tmp/keeper-in.txt   # or use your editor
chmod 600 /tmp/keeper-in.txt

cargo run --quiet -- put mfa --file /tmp/keeper-in.txt
shred -u /tmp/keeper-in.txt 2>/dev/null || rm -f /tmp/keeper-in.txt

cargo run --quiet -- get mfa
# prints the secret to stdout — redirect only to a 600 file if needed
```

### 2d. Mandatory recover drill (before you trust the vault)

```bash
# Prefer: open a new terminal that does NOT have KEEPER_PASSPHRASE set
unset KEEPER_PASSPHRASE
# remount USB if needed so ESCROW is readable
cargo run --quiet -- recover --escrow "$ESCROW"
cargo run --quiet -- status
# healthy + drillProven must be true
```

Until this works **without** the passphrase, treat the vault as unproven.

### 2e. Day-to-day

```bash
export KEEPER_ROOT=…          # if not default
export KEEPER_PASSPHRASE=…    # or PASSPHRASE_FILE
cargo run --quiet -- get mfa
cargo run --quiet -- put other --file /path/to/600-file
```

Forgot passphrase, same machine, USB present:

```bash
unset KEEPER_PASSPHRASE
cargo run --quiet -- get mfa --escrow "$ESCROW"
```

---

## 3. Optional: YubiKey (strong path)

**Do this only after §1 practice and §2 drill succeed.**

Requirements for **live** key:

- YubiKey with **HMAC-SHA1 challenge-response** programmed on a slot (default slot **2**)
- `ykchalresp` on PATH (`yubikey-personalization` / distro equivalent)
- You will touch the key when prompted by the tool

### 3a. Enroll (rewrites escrow — copy USB again)

```bash
export KEEPER_ROOT=…
export KEEPER_PASSPHRASE=…
# ESCROW must be the path you will keep offline AFTER enroll
cargo run --quiet -- enroll-yubikey --escrow "$ESCROW"
# Copy NEW escrow off-machine. Destroy previous escrow copies.
```

### 3b. Strong get (no passphrase; needs key + this machine)

```bash
unset KEEPER_PASSPHRASE
cargo run --quiet -- get mfa --yubi
```

### 3c. Prove YubiKey alone cannot open (must succeed as rejection)

```bash
cargo run --quiet -- yubi-probe
# expect: "soloYubiRejected": true
# if this ever opens the vault alone, stop using the vault and report a bug
```

### 3d. Tests / CI only — mock backend

```bash
# NEVER set this for a vault that holds real secrets
export KEEPER_YUBI_MOCK_SECRET='ci-only-fake-seed'
cargo run --quiet -- enroll-yubikey --escrow "$ESCROW"
cargo run --quiet -- get mfa --yubi
```

---

## 4. Command cheat sheet

| Goal | Command |
|------|---------|
| Create vault | `init --escrow PATH` |
| Store secret | `put NAME --file PATH` (prefer over `--value`) |
| Daily read | `get NAME` |
| Forgot passphrase | `get NAME --escrow PATH` |
| Prove recover | `recover --escrow PATH` then `status` |
| Add YubiKey | `enroll-yubikey --escrow PATH` |
| Strong read | `get NAME --yubi` |
| Solo-Yubi safety check | `yubi-probe` |

Environment:

| Variable | Meaning |
|----------|---------|
| `KEEPER_ROOT` | Vault directory (default `~/.local/share/keeper`) |
| `KEEPER_PASSPHRASE` | Session passphrase (not stored on disk as plaintext) |
| `KEEPER_PASSPHRASE_FILE` | Passphrase from file instead of env |
| `KEEPER_YUBI_MOCK_SECRET` | **Test-only** fake YubiKey — do not use with real secrets |

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

---

## 6. Stop conditions (do not “push through”)

| Situation | Action |
|-----------|--------|
| `init` says vault already exists | Do not force; use existing vault or a new `KEEPER_ROOT` |
| `recover` fails | Do not delete vault; fix escrow path / passphrase / machine |
| Escrow only exists under `$HOME` | Copy offline before storing anything you care about |
| Lost passphrase **and** escrow | Secrets are gone — no vendor backdoor |
| `yubi-probe` does not reject solo open | Stop; file a bug; do not trust that build |

---

## 7. More docs

| Doc | Use |
|-----|-----|
| [OPERATOR-MODEL.md](docs/OPERATOR-MODEL.md) | Remember / store / free / loss matrix |
| [THREAT-MODEL.md](docs/THREAT-MODEL.md) | Adversaries and invariants |
| [RECOVERY-CEREMONY.md](docs/RECOVERY-CEREMONY.md) | Ceremony steps |
| [LOCATION.md](docs/LOCATION.md) | Why IP is not trust |
| [arch-design/keeper.md](../../../arch-design/keeper.md) | Architecture |

---

**Plain rule:** Practice once with junk data. One passphrase, one offline escrow, machine free. Prove recover before real secrets. YubiKey is optional muscle, never the only key.
