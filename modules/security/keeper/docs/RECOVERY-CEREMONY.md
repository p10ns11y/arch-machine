# Recovery ceremony — simple any-2-of-3

## Init

1. Generate root `R`; Shamir **k=2, n=3**.
2. Enroll factors:
   - **passphrase** — scrypt wrap of share 1 (remember ONE secret)
   - **offline** — share 2 written to escrow path (store OFF laptop)
   - **device** — share 3 sealed to machine fingerprint (automatic)
3. Generate ML-KEM-768 keypair; wrap decap seed under `R`; seal canary with hybrid PQ.
4. Status remains **non-healthy** until drill/recover succeeds once.

## Daily unlock

`passphrase` + `device` → reconstruct `R` → open hybrid secrets.

## Forgot passphrase / drill

`offline` escrow + `device` → open canary or secrets (`get --escrow`).

## New machine

Vault directory + `passphrase` + `offline` escrow (no device share required for reconstruct).

## Rules

- Confirmation **releases a share**; it never KDFs the root alone.
- Public ISP IP / GeoIP confirmations are **rejected**.
- Healthy ≠ unlocked session; get still needs P or escrow.
