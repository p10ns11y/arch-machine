# Coming next — arch-machine keeper

**Audience:** You · implementer · agents  
**Style:** Short words. Diagrams over prose. Optimism grounded in evidence.  
**Contract:** [keeper architecture](./keeper.md) · [THREAT-MODEL](../modules/security/keeper/docs/THREAT-MODEL.md)  
**Method:** [stellar-roadmap](../.agents/skills/stellar-roadmap/SKILL.md) · collab-finder blueprint style  
**Parent backlog:** [coming-next.md](./coming-next.md)

*Last updated: 2026-07-18 · PR #28 on sentinel*

---

## 0. Mission (one sentence)

Make **threshold multi-factor secrets** the default local vault for MFA/recovery material — drill-proven, PQ-sealed, agent-operable without gum theater.

---

## 0b. Ten-year thrive picture (2026–2036)

```mermaid
flowchart TB
  subgraph kernelY["Kernel — ship computer"]
    K1[threshold root k-of-n]
    K2[hybrid PQ seal]
    K3[policy floor on disk]
  end
  subgraph bridgeY["Command bridge"]
    B1[CLI + PATH install]
    B2[Grok /arch-expand]
    B3[optional fprintd / places]
  end
  subgraph weather["Cosmic weather"]
    W1[device churn]
    W2[PQ migration]
    W3[agent unattended ops]
  end
  weather --> kernelY
  kernelY --> bridgeY
  bridgeY --> OUT[Human escrow custody]
```

| Horizon | Outcome | Signal |
|---------|---------|--------|
| 2026 | Keeper MVP on `sentinel`; drill dogfood monthly | PR #28 merged; `cargo test` green |
| 2028 | PATH binary + CI; optional fprintd share | install target; workflow job |
| 2030 | Trusted places + multi-host re-bind ceremony | LOCATION.md phases shipped |
| 2036 | Agent-native vault ops under policy caps | expand + recover without gum TUI |

**Design bet:** threshold + offline escrow forever; biometric/GPS only as **share release**, never as root.

---

## 1. Scorecard — what landed (PR #28)

```mermaid
flowchart LR
  subgraph shipped["Shipped A"]
    A1[init put get]
    A2[recover drill]
    A3[PQ hybrid]
    A4[k floor]
    A5[IP ban]
  end
  subgraph next["Open B/C"]
    B1[PATH install]
    B2[CI cargo]
    B3[fprintd]
    B4[places]
  end
  shipped --> next
```

| Area | Grade | One line | Evidence |
|------|-------|----------|----------|
| Ceremony CLI | A | init/put/get/status/recover | `src/ceremony.rs`, `cli.rs` |
| Threshold | A | k=3 n=4 enforced | `crypto.rs`, tests |
| PQ seal | A | ML-KEM-768 + AES-GCM | `crypto.rs` |
| Downgrade resist | A | effective_threshold | unit tests |
| Docs | A- | threat + ceremony + location | `docs/*` |
| Agent expand | B+ | `--agent-expand` cargo check | `modules/security/install.sh` |
| Install UX | C | cargo only | README |
| CI | C | not in vigil CI yet | workflows |
| Extra factors | — | fprintd/GPS deferred | THREAT-MODEL |

**Plain rule:** Healthy status means the offline drill already worked once.

---

## 2. System map (today)

See [keeper.md §2](./keeper.md) — CLI → crypto plane → `KEEPER_ROOT` + escrow file.

---

## 3. Precedence: reconstruct paths

```mermaid
stateDiagram-v2
  [*] --> Uninitialized
  Uninitialized --> Initialized: init
  Initialized --> DrillPending: put secrets before drill
  DrillPending --> Healthy: recover offline+device+knowledge
  Healthy --> Healthy: get with passphrase+device+knowledge
  Healthy --> DrillPending: optional re-drill
```

| Path | Shares | Opens |
|------|--------|-------|
| Daily | passphrase + device + knowledge | secrets |
| Drill/recover | offline + device + knowledge | canary → healthy |

---

## 4. Musk five-step — backlog

| Step | Question | Verdict |
|------|----------|---------|
| 1 Question | Why no PATH install? | Dogfood friction blocks monthly drill |
| 2 Delete | Classical-only seal path | Already rejected — keep dead |
| 3 Simplify | One `keeper` binary install | `cargo install --path` or module install hook |
| 4 Accelerate | CI `cargo test` | Catch GF/PQ regressions on PR |
| 5 Automate | Calendar reminder for drill | later; human escrow first |

---

## 5. Trajectory forces

| Force | P(horizon) | Effect | Response |
|-------|------------|--------|----------|
| PQ urgency | high 2026–28 | classical AEAD break risk | hybrid seal already on |
| Agent unattended | med | env passphrase leakage | files + TTY; no argv secrets |
| Device reimage | high | fingerprint change | re-bind ceremony (SN-KEEP-3) |
| Biometric hype | med | fake 1FA theater | fprintd as share only |

**Acceleration trigger:** after monthly personal drill succeeds twice on production MFA blob.

---

## 6. Trajectory guardrails

```mermaid
flowchart TD
  subgraph avoid["Refuse — drag"]
    R1[ISP IP as trust]
    R2[confirmation derives root]
    R3[meta.k downgrade]
    R4[skip drill for healthy]
  end
  subgraph build["Build toward 2036"]
    B1[escrow custody UX]
    B2[PATH + CI]
    B3[optional hardware factors]
    B4[Grok expand rails]
  end
```

| Refuse | Build |
|--------|-------|
| Public IP / GeoIP trust | LOCATION.md ban + weight 0 |
| k&lt;3 via disk edit | effective_threshold floor |
| Auto-full security-dev | Grok expand module only |
| Legacy vault undelete myth | new keeper init |

---

## 7. Blueprint cards

### SN-KEEP-1 · Dogfood recover drill (no new code)

**Problem:** Ceremony only real if operator runs recover without passphrase on a live escrow.

```mermaid
flowchart LR
  init[init + escrow offsite] --> put[put mfa test]
  put --> recover[recover --escrow]
  recover --> status[status healthy]
```

| File | Work |
|------|------|
| `modules/security/keeper/README.md` | already documents path |
| operator escrow path | store offline share off-laptop |

**Done when:** `status` reports healthy after no-passphrase recover; canary open.

**Verify:**
```bash
cd modules/security/keeper
export KEEPER_ROOT=/tmp/keeper-dogfood KEEPER_PASSPHRASE=… KEEPER_KNOWLEDGE=…
cargo run --quiet -- init --escrow /tmp/keeper-escrow.json
cargo run --quiet -- put demo --value 'x'
# unset passphrase
cargo run --quiet -- recover --escrow /tmp/keeper-escrow.json
cargo run --quiet -- status   # healthy
```

### SN-KEEP-2 · CI cargo test job

**Problem:** Shamir/PQ regressions only caught locally.

```mermaid
flowchart LR
  pr[PR to sentinel] --> ci[GitHub Actions]
  ci --> test[cargo test --manifest-path modules/security/keeper/Cargo.toml]
```

| File | Work |
|------|------|
| `.github/workflows/ci.yml` | add `keeper` job (stable Rust) |
| `modules/security/keeper/` | keep tests offline/no network |

**Done when:** CI red if `cargo test` fails on keeper.

**Verify:** open PR with deliberate test fail → job fails; revert.

### SN-KEEP-3 · Install to PATH (`~/.local/bin/keeper`)

**Problem:** `cargo run` friction kills dogfood.

```mermaid
flowchart LR
  expand[agent-expand / install] --> build[cargo build --release]
  build --> bin["~/.local/bin/keeper"]
```

| File | Work |
|------|------|
| `modules/security/install.sh` | `--agent-expand` optional install release binary |
| `modules/security/keeper/README.md` | PATH install section |

**Done when:** `command -v keeper` after expand/install; `keeper status` works.

**Verify:** expand security --yes on clean env; `keeper --help`

### SN-KEEP-4 · Device re-bind ceremony

**Problem:** Reimage / new machine breaks device share without guided re-seal.

```mermaid
sequenceDiagram
  participant Op
  participant Old as old device share
  participant New as new fingerprint
  participant CLI
  Op->>CLI: rebind --escrow
  CLI->>CLI: reconstruct via offline+knowledge(+passphrase)
  CLI->>New: seal device share for new fp
  CLI->>CLI: invalidate old device blob
```

| File | Work |
|------|------|
| `src/ceremony.rs` | `rebind` command |
| `docs/RECOVERY-CEREMONY.md` | rebind section |
| tests | rebind roundtrip |

**Done when:** after rebind, daily path works on new host; old device blob fails open.

**Verify:** unit test with two fingerprints.

### SN-KEEP-5 · Optional fprintd share release (not root)

**Problem:** Hardware confirm is useful UX; must not become 1FA root.

| File | Work |
|------|------|
| `src/factors.rs` | fprintd confirmation → release existing share slot or n+1 policy |
| THREAT-MODEL | document non-root role |

**Done when:** fprintd absent → graceful skip; present → may replace knowledge **only if** k still ≥3 with offline.

**Verify:** tests with mock confirmation; no path where fprint alone opens secrets.

### SN-KEEP-6 · Trusted places enrollment (GPS companion)

**Problem:** LOCATION.md specifies places; not implemented.

| File | Work |
|------|------|
| `docs/LOCATION.md` | already bans IP |
| `src/factors.rs` | place confirmation when companion present |
| companion app/spec | out of crate initially |

**Done when:** place confirm weight documented; IP still weight 0.

**Verify:** unit tests reject IP-shaped confirmations.

---

## 8. Scope lock

| In | Out |
|----|-----|
| Local disk vault + escrow file | Cloud sync / autofill |
| Grok expand prep | Full k3s via expand |
| Hybrid PQ seal | Classical-only v1 recovery |
| Rebind + CI + PATH | Browser extension |

---

## 9. Gantt (suggested)

```mermaid
gantt
  title keeper sprint order
  dateFormat YYYY-MM-DD
  section Gate
  SN-KEEP-1 Dogfood drill     :k1, 2026-07-18, 3d
  section Ship
  SN-KEEP-2 CI cargo          :k2, after k1, 3d
  SN-KEEP-3 PATH install      :k3, after k1, 5d
  section Altitude
  SN-KEEP-4 Device rebind     :k4, after k3, 8d
  SN-KEEP-5 fprintd optional  :k5, after k4, 10d
  SN-KEEP-6 Trusted places    :k6, after k5, 14d
```

---

## 10. Monitoring signals

- PR #28 not merged while CI green → merge friction
- `cargo test` local red → block expand
- Operator never ran recover → status stuck drill-pending (expected)
- Escrow only on laptop → custody failure (process, not code)

---

## 11. Done log

| Item | Evidence |
|------|----------|
| Multi-factor keeper MVP | PR #28 `de7faf2` |
| Threshold floor / meta.k | PR #28 `2612f3f` |
| Grok plugin TUI docs | PR #28 `1ed01fe` |
| Module `--agent-expand` | PR #28 `e9c264a` |
| Rebase on sentinel #25 | force-push `e9c264a` |
| Grok plugin package | `p10ns11y/plugins` arch-machine |

---

## 12. File touch mindmap

```mermaid
mindmap
  root((keeper))
    src
      ceremony
      crypto
      factors
      store
      cli
    docs
      THREAT-MODEL
      RECOVERY-CEREMONY
      LOCATION
    arch-design
      keeper.md
      coming-next-keeper.md
    expand
      security install.sh
      Grok am-expand
```

---

## 13. References

| Source | Use |
|--------|-----|
| [keeper.md](./keeper.md) | Architecture + mermaid system map |
| [coming-next.md](./coming-next.md) | Global arch-machine backlog |
| [plugins/arch-machine](https://github.com/p10ns11y/plugins) | Agent-as-TUI |
| collab-finder [batch-2-blueprints](https://github.com/p10ns11y/collab-finder/blob/main/reports/batch-2-engineering-blueprints.md) | Card format |
| FIPS 203 ML-KEM | PQ KEM choice |

---

**Plain rule:** Offline escrow off the machine — or the threshold is theater.
