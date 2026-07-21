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

## New machine / reimage (`rebind`)

1. Restore vault directory onto the new host.
2. Present **passphrase + offline escrow** (old device fingerprint is gone).
3. Run `keeper rebind --escrow PATH` — reconstructs root, re-splits, seals **device** share to the **new** fingerprint, rewrites escrow.
4. Copy the **new** escrow offline; old USB copy is obsolete.
5. `keeper recover --escrow PATH` once → healthy on the new binding.
6. Old device binding no longer opens with passphrase (or escrow) as if still current.

Until rebind, passphrase+offline still reconstruct root (unlock for migration), but daily passphrase+device fails on the new fingerprint.

## Rules

- Confirmation **releases a share**; it never KDFs the root alone.
- Public ISP IP / GeoIP confirmations are **rejected**.
- Healthy ≠ unlocked session; get still needs P or escrow (or strong Yubi path).
- Prefer `keeper loop` so secrets never appear on argv / shell history.
