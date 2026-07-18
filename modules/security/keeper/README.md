# keeper — multi-factor threshold secrets (Rust)

Local-first secrets holder: **k=3 of n=4** factors, **mandatory no-passphrase drill**, hybrid **ML-KEM-768** sealed secrets.

## Factors (confirmation gates share release — never derive root alone)

| Role | How released |
|------|----------------|
| **passphrase** | `KEEPER_PASSPHRASE` / file |
| **offline** | Escrow file path at drill/recover |
| **device** | Local machine fingerprint (auto on this host) |
| **knowledge** | `KEEPER_KNOWLEDGE` / file |

**Forbidden:** public ISP IP / GeoIP as trust (weight = 0). See `docs/LOCATION.md`.

## Build & test

```bash
cd modules/security/keeper
cargo test
cargo build --release
```

## Quick start

```bash
export KEEPER_PASSPHRASE='strong-passphrase'
export KEEPER_KNOWLEDGE='private knowledge answer'
export KEEPER_ROOT=~/.local/share/keeper

cargo run --quiet -- init --escrow ~/keeper-escrow.share.json
cargo run --quiet -- put mfa --value '...'
cargo run --quiet -- status          # exit 2 until drill
# no passphrase:
cargo run --quiet -- recover --escrow ~/keeper-escrow.share.json
cargo run --quiet -- status          # drill-proven / healthy
```

Daily unlock uses **passphrase + device + knowledge**.  
Recover/drill uses **offline + device + knowledge** (no passphrase).

## Crypto

- Shamir k=3 n=4 over AES GF(256)
- Share seals: scrypt (passphrase/knowledge), HKDF-device fingerprint (device)
- Secrets/canary: **ML-KEM-768 + AES-256-GCM via HKDF-SHA256 (hybrid PQ)**

## Docs

- [THREAT-MODEL.md](docs/THREAT-MODEL.md)
- [RECOVERY-CEREMONY.md](docs/RECOVERY-CEREMONY.md)
- [LOCATION.md](docs/LOCATION.md) — GPS places future; IP trust banned
