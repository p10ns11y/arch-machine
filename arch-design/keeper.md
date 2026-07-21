# Keeper — architecture design (arch-machine)

**Audience:** operators · implementers · agents  
**Contract:** [THREAT-MODEL](../tools/keeper/docs/THREAT-MODEL.md) · [RECOVERY-CEREMONY](../tools/keeper/docs/RECOVERY-CEREMONY.md) · [LOCATION](../tools/keeper/docs/LOCATION.md)  
**Backlog:** [coming-next-keeper.md](./coming-next-keeper.md) · parent [coming-next.md](./coming-next.md)  
**Method:** stellar-roadmap · evidence columns · diagrams over prose  

*Last updated: 2026-07-21 · PATH install · rebind · interactive loop*

---

## 0. Mission

Hold high-value secrets under **any 2 of 3** (passphrase · offline · device): **one** secret to remember, **one** file offline, device free — survive passphrase loss without a second knowledge password or IP theater.

**Shipped default:** k=2 n=3. Knowledge factor is **not** required. Optional YubiKey expands to any-2-of-4.

---

## 0b. Thrive picture (hull bay in the security module)

```mermaid
flowchart TB
  subgraph weather["Cosmic weather"]
    W1[device loss]
    W2[PQ transition]
    W3[agent ops surface]
  end
  subgraph kernel["Keeper kernel — root & seal"]
    K1[Shamir k=2 n=3]
    K2[hybrid ML-KEM-768 + AES-GCM]
    K3[effective_threshold floor]
  end
  subgraph bridge["Operator bridge"]
    B1[CLI ceremony]
    B2[Grok /arch-expand security]
    B3[agent-expand prep]
  end
  subgraph boundary["Hard boundary"]
    X1[no ISP IP trust]
    X2[no secrets on argv]
    X3[confirmation not root KDF]
  end
  weather --> kernel
  kernel --> bridge
  boundary --> kernel
  bridge --> OUT[Human judgment before recover]
```

| Role | What it is | Why it still wins in 2036 |
|------|------------|---------------------------|
| **Kernel** | Threshold root + PQ-sealed blobs on disk | Survives host loss + classical crypto break |
| **Bridge** | CLI + thin Grok expand (not gum TUI) | Agent ops without theater confirmations |
| **Boundary** | IP ban, k floor, offline escrow | Trust stays out-of-band |

**Design bet:** root reconstruction is always threshold crypto; UX factors only **release shares**.

---

## 1. Scorecard (current)

```mermaid
flowchart LR
  subgraph shipped["Shipped"]
    S1[init put get status]
    S2[recover drill no-passphrase]
    S3[PQ seal]
    S4[k floor]
    S5[PATH install expand]
    S6[rebind]
    S7[interactive loop]
  end
  subgraph open["Next altitude"]
    O1[fprintd factor]
    O2[trusted places]
  end
  shipped --> open
```

| Area | Grade | One line | Evidence |
|------|-------|----------|----------|
| Shamir k=2 n=3 (default) | A | any 2 of P/O/D; optional n=4 Yubi | `crypto.rs`, `ceremony.rs`, tests |
| Confirmation ≠ root | A | Factors gate share open only | `factors.rs`, THREAT-MODEL |
| No-passphrase drill | A | offline+device | `ceremony.rs`, README |
| PQ hybrid seal | A | ML-KEM-768 + AES-GCM + HKDF | `crypto.rs`, sealed blobs |
| meta.k downgrade | A | `effective_threshold` floors k | unit tests |
| ISP IP trust | A | weight 0; reject | `factors.rs`, LOCATION.md |
| Grok expand + PATH | A | `--agent-expand` release install `~/.local/bin/keeper` | `modules/security/install.sh` |
| Device rebind | A | P+O reconstruct; reseal device; old fp fails | `rebind_device`, tests |
| Interactive loop | A | non-echo prompts; no argv secrets | `interactive.rs`, CLI `loop` |
| CI cargo | A | `keeper` job in workflows | `.github/workflows/ci.yml` |
| fprintd / GPS | — | deferred | THREAT-MODEL out of scope |

**Plain rule:** If disk can lower k, or confirmation alone opens secrets, the design is broken.

---

## 2. System map (today)

```mermaid
flowchart TB
  subgraph cli["CLI — tools/keeper"]
    Init[init]
    Put[put]
    Get[get]
    Status[status]
    Recover[recover / drill]
  end
  subgraph crypto["Crypto plane"]
    Shamir[Shamir shares k=2]
    Scrypt[scrypt wraps]
    DevSeal[device HKDF seal]
    PQ[ML-KEM-768 encaps]
    AEAD[AES-256-GCM]
  end
  subgraph disk["Store root KEEPER_ROOT"]
    Meta[meta.json]
    PassW[passphrase wrap]
    DevB[device share blob]
    PQek[pq encapsulation key]
    PQdk[pq dk wrap]
    Canary[canary sealed]
    Secs[secrets/*.sealed]
  end
  subgraph outband["Out of band"]
    Escrow[offline escrow share file]
  end
  Init --> Shamir
  Shamir --> PassW
  Shamir --> DevB
  Shamir --> Escrow
  Put --> PQ
  PQ --> AEAD
  AEAD --> Secs
  Recover --> Escrow
  Recover --> DevB
  Recover --> Canary
  Status --> Meta
  Status --> Canary
```

**Paths:** crate `tools/keeper/` · `keeper loop` interactive UX · agent expand installs PATH binary via `modules/security/install.sh --agent-expand`.

---

## 3. Ceremony data-flow

### Daily unlock (passphrase path)

```mermaid
sequenceDiagram
  participant Op as Operator
  participant CLI as keeper CLI
  participant Disk as KEEPER_ROOT
  participant Shamir as reconstruct
  Op->>CLI: get name (passphrase prompt or env)
  CLI->>Disk: open passphrase wrap
  CLI->>Disk: open device share
  CLI->>Shamir: k=2 shares
  Shamir->>CLI: root R
  CLI->>Disk: unwrap PQ dk + open sealed secret
  CLI->>Op: secret (stdout only when intentional)
```

### Recover / mandatory drill (no passphrase)

```mermaid
sequenceDiagram
  participant Op as Operator
  participant CLI as keeper CLI
  participant Esc as offline escrow
  participant Disk as KEEPER_ROOT
  participant Shamir as reconstruct
  Op->>CLI: recover --escrow path
  CLI->>Esc: load offline share
  CLI->>Disk: device share
  CLI->>Shamir: offline + device
  Shamir->>CLI: root R
  CLI->>Disk: open canary (prove drill)
  CLI->>Disk: status becomes healthy
```

| Layer | Owns | Must not |
|-------|------|----------|
| `factors` | share seals, fingerprint, IP reject | derive root from confirmations |
| `crypto` | Shamir, scrypt, PQ hybrid | lower k from untrusted meta alone |
| `ceremony` | init/put/get/recover/rebind/status | skip drill gate for healthy |
| `interactive` | non-echo onboard loop | put secrets on argv |
| `store` | JSON/blob paths | put secrets on argv in docs |

---

## 4. Factor topology

```mermaid
flowchart LR
  R[Root R]
  S1[share passphrase]
  S2[share offline]
  S3[share device]
  S4[share yubi optional]
  R --- S1
  R --- S2
  R --- S3
  R -.-> S4
  S1 --> Daily[daily: P+D]
  S2 --> Drill[drill: O+D]
  S3 --> Daily
  S3 --> Drill
  S4 --> Strong[strong: Y+D]
```

| Role | Seal | Typical release |
|------|------|-----------------|
| passphrase | scrypt wrap | daily |
| offline | plaintext escrow file (operator custody) | recover / rebind |
| device | HKDF(machine fingerprint) | daily + recover |
| yubikey (optional) | HMAC-SHA1 challenge-response | strong get; never alone |

---

## 5. Fit in arch-machine + Grok TUI

```mermaid
flowchart LR
  subgraph thin["Thin core"]
    Tinfoil[tinfoil --thin]
  end
  subgraph expand["Consent expand"]
    AM[Grok /arch-expand security --yes]
    Hook[install.sh --agent-expand]
    Cargo[cargo build --release + install PATH]
  end
  subgraph full["Full profile — later"]
    Prof[install.sh --profile security-dev]
  end
  thin --> expand
  expand --> Hook
  Hook --> Cargo
  Prof -.->|sudo k3s etc| full
```

Agent surface prefers **Grok plugin** over `tinfoil tui` for expand. Expand installs `keeper` to `~/.local/bin`. Full k3s remains profile path (never default thin). Primary secure UX is **CLI interactive loop** (not Waybar/archy panel).

---

## 6. Module layout

```
tools/keeper/
  Cargo.toml
  README.md
  docs/
    THREAT-MODEL.md
    RECOVERY-CEREMONY.md
    LOCATION.md
  src/
    main.rs cli.rs lib.rs
    ceremony.rs crypto.rs factors.rs store.rs
  tests/
```

---

## 7. Invariants (bind agents)

1. **Confirmation ≠ root KDF**  
2. **k floor = DEFAULT_K (3)** even if disk says lower  
3. **Public ISP IP / GeoIP weight = 0**  
4. **Healthy requires proven no-passphrase drill**  
5. **No secrets on argv** in happy-path operator docs  
6. **Classical-only pre-PQ blobs rejected**  

---

## 13. References

| Source | Use |
|--------|-----|
| `tools/keeper/README.md` | Operator quick start |
| `tools/keeper/docs/*` | Threat, ceremony, location ban |
| `arch-design/coming-next-keeper.md` | SN-KEEP-* backlog |
| `Work/personal/plugins/arch-machine` | Grok agent-as-TUI expand |
| collab-finder batch-2 blueprints | Card format |

---

**Plain rule:** Escrow lives out-of-band; the laptop alone must never be enough.
