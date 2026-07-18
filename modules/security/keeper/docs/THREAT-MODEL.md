# Threat model — arch-machine keeper

## Purpose

Local-first secrets holder with **threshold recovery (any 2 of 3: passphrase, offline, device)**. Confirmation signals gate **share release**; they are **not** the root key. Default path has **one** human secret + **one** offline file (see OPERATOR-MODEL.md).

## Adversaries

| Adversary | Capability | Keeper response |
|-----------|------------|-----------------|
| Curious roommate | Physical brief access, no offline share | Needs k=3 factors; passphrase wrap resists offline guess (scrypt) |
| Stolen laptop | Full disk, data root, no offline escrow | Device alone insufficient (**k=2**); need passphrase or offline escrow |
| Disk tamperer | Rewrites `meta.json` (e.g. lower `k` to 1) | **`effective_threshold` floors k at protocol `DEFAULT_K=2`** — disk cannot unlock with one factor |
| Remote malware | Reads files, may keylog | Offline share out-of-band; no secrets on argv; agent-safe logging |
| Network observer | Sees public IP / traffic | **Public ISP IP is not a trust signal** (see LOCATION.md) |

## Invariants

1. **Confirmation ≠ key material.** Machine-id, MAC, package inventory, public IP, and GeoIP never derive the root.
2. **Root `R` = Shamir reconstruct(k of n shares).** Default: **k=2, n=3** (passphrase, offline escrow, device-bound).
3. **No-passphrase drill/recover:** **offline + device** opens canary / secrets via `--escrow`; status non-healthy until drill once.
4. **Policy floor:** reconstruction uses `effective_threshold(meta.k, meta.n) = max(meta.k, DEFAULT_K=2)` — unauthenticated disk metadata cannot unlock with a single factor.
5. **No secrets on argv** in happy-path docs; tests may use env `KEEPER_PASSPHRASE` / `KEEPER_KNOWLEDGE` / files.
6. **Implementation language:** Rust (`modules/security/keeper` crate).
7. **Hybrid PQ sealed secrets:** **ML-KEM-768 + AES-256-GCM via HKDF-SHA256** (FIPS 203 KEM). Threshold root/share wrap remains classical.
8. **Breaking change:** pre-PQ classical-only sealed blobs (v1) and pre-multifactor layouts are rejected / not supported.

## Out of scope (deferred)

- fprintd hardware path, GPS companion / trusted places enrollment (specified in LOCATION / RECOVERY-CEREMONY as future factors)
- Cloud sync, browser autofill
- Recovering legacy `~/.securevaultenc` without known password/master key
