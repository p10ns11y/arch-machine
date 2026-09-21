# Keeper escrow custody map

**SoT for who holds whose offline escrow.** Not the vault ciphertext. Not passphrases.

## Law

1. **Any 2 of 3** — passphrase / offline escrow / device.
2. Escrow must not live only next to the only vault that needs it.
3. **USB PENDING** stays the operator offline copy (`escrow-PENDING-copy-to-usb.json` habit).
4. **Mesh peers** may hold each other's escrow so one saves the other — this map says who.
5. **Never** ship `KEEPER_PASSPHRASE` / passphrase file on the same path/channel as escrow.
6. Host aliases on any public surface: `laptop-1`, `laptop-2`, `mac-mini`, `grok-bot`.
7. Escrow custody ≠ vault sync. Holding peer escrow does not open peer secrets without that peer's vault (or a restore + `rebind`).
8. **Non-leaky peer storage:** a holder who can read disk on the peer machine must still see only **encrypted / opaque escrow bytes** — never plaintext secret values, never the vault passphrase file.
9. **Distribute gate:** mesh/scripted escrow copy runs only when **both endpoints are alive** (owner + holder reachable) **or** the operator explicitly approves a one-shot copy (`--hitl-approve-offline`). No silent background drip of escrow to offline or unattended peers.
10. Peer escrow alone must not unlock named secrets; unlock still needs a second factor (owner device share after restore/rebind, or passphrase + escrow on a machine that holds the vault).

## On-disk layout (per holder)

For vault owner `X`, a peer `Y` stores:

```text
~/keeper-escrow/peers/<alias-of-X>/keeper-escrow.json   # mode 600, dir 700
```

Owner keeps:

```text
~/keeper-escrow/keeper-escrow.json                      # working copy
~/.local/share/keeper/escrow-PENDING-copy-to-usb.json   # loop default / USB staging
```

Passphrase file stays **only** on machines the operator chooses for daily unlock — never in `peers/`.

## CLI: `keeper custody distribute`

Push opaque escrow bytes to peer holders (no passphrase, no vault dump):

```bash
keeper custody distribute \
  --escrow ~/keeper-escrow/keeper-escrow.json \
  --owner-alias grok-bot \
  --holder laptop-1=local:/home/operator \
  --holder mac-mini=ssh:operator@mac-mini
```

| Flag | Purpose |
|------|---------|
| `--escrow PATH` | Owner escrow file (ShareJson only) |
| `--owner-alias` | Vault owner (`laptop-1` \| `laptop-2` \| `mac-mini` \| `grok-bot`) |
| `--holder alias=local:HOME` | Same-machine or test staging |
| `--holder alias=ssh:USER@HOST` | Remote copy via ssh |
| `--map PATH` | Optional JSON custody map (merges holders for owner) |
| `--hitl-approve-offline` | One-shot operator approval when reachability check fails |
| `--verify-complete` | Post-rebind checklist: exit non-zero if any holder missing/mismatch |

After `rebind` / `enroll-yubikey` / `passwd-reset`, escrow is rewritten — **re-distribute to every holder** in this map (`--verify-complete`).

## Custody map JSON (optional)

```json
{
  "owners": {
    "grok-bot": {
      "holders": [
        { "alias": "laptop-1", "transport": "ssh", "target": "operator@laptop-1" },
        { "alias": "mac-mini", "transport": "ssh", "target": "operator@mac-mini" }
      ]
    }
  }
}
```

## Ops checklist (when a vault changes)

1. Update PENDING + `~/keeper-escrow/keeper-escrow.json` on owner.
2. `keeper custody distribute` to each holder in the row above.
3. Confirm holders list in this file (date + who got a copy).
4. Do **not** echo escrow JSON or passphrase into chat / public git.

## Related

- `tools/keeper/docs/MESH-ESCROW-VERB.md` — future mesh allowlist design
- `tools/keeper/README.md` — operator flows
- `arch-design/keeper.md` — architecture
