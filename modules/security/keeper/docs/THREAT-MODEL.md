# Threat model — arch-machine keeper

## Purpose

Local-first secrets holder with **threshold multi-factor recovery**. Confirmation signals (device, knowledge, GPS/places, fprintd) raise confidence; they are **not** the root key.

## Adversaries

| Adversary | Capability | Keeper response |
|-----------|------------|-----------------|
| Curious roommate | Physical brief access, no offline share | Passphrase + device share need passphrase; rate-limit failures |
| Stolen laptop | Full disk, data root, no offline escrow | Device share alone insufficient (k≥2); passphrase wrap resists offline guess (scrypt/Argon2) |
| Remote malware | Reads files, may keylog | Offline share out-of-band; no secrets on argv; agent-safe logging |
| Network observer | Sees public IP / traffic | **Public ISP IP is not a trust signal** (see LOCATION.md) |

## Invariants

1. **Confirmation ≠ key material.** Machine-id, MAC, package inventory, public IP, and GeoIP never derive the root.
2. **Root `R` = Shamir reconstruct(k of n shares).** Default MVP: k=2, n=3 (passphrase-wrapped, offline escrow, local device share).
3. **Drill-proven health.** Status is non-healthy until a successful drill opens the canary **without** the primary passphrase (offline + device shares).
4. **No secrets on argv** in happy-path docs; tests may use env `KEEPER_PASSPHRASE` / files.
5. **Implementation language:** Rust (`modules/security/keeper` crate). Crypto lives in-process; no Node runtime.
6. **Hybrid PQ sealed secrets:** payloads use **ML-KEM-768 + AES-256-GCM via HKDF-SHA256** (FIPS 203 KEM). Threshold root/share wrap remains classical; harvest-now-decrypt-later resistance is on sealed secret blobs tagged with that algorithm string.
7. **Breaking change:** pre-PQ classical-only sealed blobs (v1) are rejected.

## Out of scope (this MVP)

- fprintd, GPS companion, llm.txt challenges (specified in LOCATION / RECOVERY-CEREMONY as future factors)
- Cloud sync, browser autofill
- Recovering legacy `~/.securevaultenc` without known password/master key
