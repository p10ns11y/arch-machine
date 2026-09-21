# Mesh verb design: `copy_escrow_blob`

**Status:** design only — not implemented in mesh yet.  
**Keeper CLI today:** `keeper custody distribute` (local/ssh).

## Purpose

Allowlisted fleet verb to copy **opaque escrow bytes** peer↔peer without passphrase, without vault ciphertext dump, without silent offline drip.

## Verb contract

| Field | Value |
|-------|-------|
| Name | `copy_escrow_blob` |
| Payload | `{ "ownerAlias": "grok-bot", "escrowSha256": "…", "bytesB64": "…" }` |
| Allowed aliases | `laptop-1`, `laptop-2`, `mac-mini`, `grok-bot` |
| Dest on holder | `~/keeper-escrow/peers/<ownerAlias>/keeper-escrow.json` (600 / 700) |

## Hard gates (mirror keeper laws 8–10)

1. **Opaque only** — payload must parse as `ShareJson` `{id,data}`; reject passphrase wraps, sealed secrets, or extra JSON fields.
2. **Reachability + HITL** — mesh broker refuses delivery unless source and target are both online **or** operator issued a one-shot HITL token for that transfer (no background queue to offline peers).
3. **Not unlock** — receiving peer stores escrow for recovery custody only; named secrets on the holder still need a second factor (owner vault + device, or passphrase + escrow on vault host).

## Explicit denylists

- `KEEPER_PASSPHRASE` / `KEEPER_PASSPHRASE_FILE` — never in verb payload or side channels
- `passphrase.wrap.json`, `secrets/*.sealed.json`, vault root tarball
- Full vault sync (separate verb / future design if ever needed)

## Broker flow (sketch)

```text
source peer                mesh broker                 target peer
    │                           │                           │
    │  copy_escrow_blob req     │                           │
    ├──────────────────────────►│  reachability both ends?  │
    │                           │  or HITL token valid?     │
    │                           ├──────────────────────────►│ write peers/<alias>/…
    │                           │◄──────────────────────────┤ ack + sha256
    │◄──────────────────────────┤ result                    │
```

## Drift signal (future)

Fleet Desk fact: compare custody map holders vs on-disk peer files + sha256. Keeper `custody distribute --verify-complete` is the local pre-mesh equivalent.

## Implementation notes

- Reuse `tools/keeper/src/custody.rs` validation (`read_opaque_escrow`, `assert_no_passphrase_co_ship`, alias allowlist).
- Mesh plugin lives outside arch-machine (`~/.config/omarchy/plugins/mesh/`); wire via thin RPC that shells to `keeper custody distribute` or in-process library call.
- Stub acceptable: broker returns `501 not implemented` with this doc link until transport lands.

## Related

- `tools/keeper/docs/KEEPER-ESCROW-CUSTODY.md` — custody map + CLI
- `arch-design/coming-next-keeper.md` — SN-KEEP backlog
