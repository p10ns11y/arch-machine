# keeper — simple threshold secrets (Rust)

**Any 2 of enrolled factors:** passphrase · offline escrow · device · optional **YubiKey (strong)**.  
Hybrid **ML-KEM-768** sealed secrets. No second “knowledge” password. **YubiKey alone never opens.**

> **Mental model:** [docs/OPERATOR-MODEL.md](docs/OPERATOR-MODEL.md)  
> **Dev hygiene (API keys / multi-tool):** [`docs/SECRETS-EVERYDAY.md`](../../../docs/SECRETS-EVERYDAY.md)  
> Architecture: [`arch-design/keeper.md`](../../../arch-design/keeper.md)

## One card

| | |
|--|--|
| **Remember** | ONE passphrase |
| **Store offline** | ONE escrow file (USB / other house) |
| **Free** | Device fingerprint (automatic) |
| **Strong (optional)** | YubiKey HMAC-SHA1 slot — share release only |

```text
Daily:     passphrase + device
Strong:    YubiKey + device     →  get NAME --yubi
Forgot P:  escrow + device      →  get NAME --escrow file
New PC:    passphrase + escrow (+ vault files)
```

## Build & test

```bash
cd modules/security/keeper
cargo test
cargo build --release
```

## Quick start

```bash
export KEEPER_PASSPHRASE='strong-passphrase'   # only secret you remember
export KEEPER_ROOT=~/.local/share/keeper

cargo run --quiet -- init --escrow ~/keeper-escrow.share.json
# COPY escrow OFF this laptop, then:

cargo run --quiet -- put mfa --value '…'
cargo run --quiet -- get mfa
# forgot passphrase?
cargo run --quiet -- get mfa --escrow ~/keeper-escrow.share.json
# prove drill once:
cargo run --quiet -- recover --escrow ~/keeper-escrow.share.json
cargo run --quiet -- status   # healthy + remember/store/free card

# optional strong hardware (live: ykchalresp; CI: mock secret)
# cargo run --quiet -- enroll-yubikey --escrow ~/keeper-escrow.share.json
# cargo run --quiet -- get mfa --yubi
# cargo run --quiet -- yubi-probe   # must report soloYubiRejected
# export KEEPER_YUBI_MOCK_SECRET='ci-only'  # mock HMAC backend
```

## What is encrypted where

| Blob | Sealed by |
|------|-----------|
| Share 1 | scrypt(passphrase) |
| Share 2 | plaintext file **you** take offline |
| Share 3 | HKDF(device fingerprint) |
| Secrets / canary | ML-KEM-768 + AES-GCM (root after 2 shares) |

Passphrase is **never** stored. Healthy = “you proved escrow recover once”; it does **not** leave the vault unlocked without P or escrow.

## Docs

- [OPERATOR-MODEL.md](docs/OPERATOR-MODEL.md) — forgetfulness bounds  
- [THREAT-MODEL.md](docs/THREAT-MODEL.md)  
- [RECOVERY-CEREMONY.md](docs/RECOVERY-CEREMONY.md)  
- [LOCATION.md](docs/LOCATION.md) — IP trust banned  
- Backlog: [`arch-design/coming-next-keeper.md`](../../../arch-design/coming-next-keeper.md)
