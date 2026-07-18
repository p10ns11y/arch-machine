# Recovery ceremony — multi-factor keeper

## Init

1. Generate root `R`; Shamir **k=3, n=4**.
2. Enroll factors:
   - **passphrase** — scrypt wrap of share 1  
   - **offline** — share 2 written to operator escrow path  
   - **device** — share 3 sealed to machine fingerprint  
   - **knowledge** — share 4 sealed under knowledge-derived key  
3. Generate ML-KEM-768 keypair; wrap decap seed under `R`; seal canary with hybrid PQ.
4. Status remains **non-healthy** until drill/recover succeeds.

## Daily unlock

`passphrase` + `device` (this machine) + `knowledge` → reconstruct `R` → open hybrid secrets.

## Drill / recover (no primary passphrase)

`offline` escrow file + `device` + `knowledge` → open canary → mark `drillProven`.

## Rules

- Confirmation **releases a share**; it never KDFs the root alone.
- Public ISP IP / GeoIP confirmations are **rejected**.
- Optional future: fprintd, GPS trusted places (see LOCATION.md) as additional sealed shares.
