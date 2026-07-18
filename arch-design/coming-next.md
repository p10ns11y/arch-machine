# coming-next — arch-machine architecture backlog

**Keeper deep-dive:** [keeper.md](./keeper.md) · [coming-next-keeper.md](./coming-next-keeper.md) (SN-KEEP-*)  
**Grok agent-as-TUI:** [p10ns11y/plugins](https://github.com/p10ns11y/plugins) `arch-machine/` (prefer over gum `tinfoil tui` for ops)

## §0 Mission

Ship and maintain a **thin-first, evidence-always, self-remediating** Arch Linux workstation guardian (`tinfoil`) with profile-driven ML/security modules — and a **threshold multi-factor keeper** for secrets that outlive passphrase loss.

## §0b Ten-year thrive picture

```mermaid
flowchart LR
  subgraph sentinel [SentinelSurface]
    CLI[tinfoil CLI]
    TUI[gum/BubbleTea TUI]
    Grok[Grok plugin slash]
  end
  subgraph engine [ProfileEngine]
    Install[install.sh]
    Profiles[YAML profiles]
  end
  subgraph bays [ModuleBay]
    Mods[modules/install_*]
    Keeper[security/keeper]
  end
  subgraph heart [MaintenanceHeart]
    Audit[security-audit]
    Weekly[weekly-check]
    Remediate[apply-remediation]
  end
  subgraph loop [EvidenceReactor]
    Extract[extract-evidence]
    Bundles[JSON/TOON bundles]
  end
  CLI --> Install
  Grok --> Install
  TUI --> Audit
  Install --> Mods
  Mods --> Keeper
  Mods --> Weekly
  Weekly --> Extract
  Extract --> Bundles
  Bundles --> TUI
  Remediate --> Audit
```

| Horizon | Outcome | Signal |
|---------|---------|--------|
| 2026 | TUI + evidence first-class; keeper MVP; Grok expand | Issue #7; PR #28; profile harness green |
| 2028 | Autonomous weekly sentinel on fleet machines | systemd timer + evidence drift alerts |
| 2030 | Portable profile packs beyond Arch | adapter modules per distro |
| 2036 | Agent-native ops: bundles + keeper under policy | LLM consumes TOON; drill-proven vault |

## §1 Scorecard

| Area | Grade | One line | Evidence |
|------|-------|----------|----------|
| Thin install | A- | Default `--thin` ships sentinel only | `install.sh`, README |
| tinfoil CLI | A | Global binary + subcommands | `bin/tinfoil.go`, merged PR #3 |
| TUI (Elm/gum) | B | Model/View/Update split; flows in progress | `lib/tui/*.sh`, Issue #7 |
| **Grok agent TUI** | **B+** | Slash status/init/audit/expand; fail closed | `plugins/arch-machine`, BOUNDARY.md |
| **Keeper (MFA vault)** | **A-** | k=3 n=4 + PQ seal + drill; PR open | `modules/security/keeper`, PR #28 |
| Profiles | B | YAML compose modules | `config/profiles/*.yaml` |
| Evidence | A- | JSON + TOON bundles | `maintenance/extract-evidence.sh`, `logs/` |
| Remediation policy | A | Repo applies own 6-step policy | `policies/security-remediation.md` |
| CI | B+ | shellcheck, go, yaml, evidence smoke | `.github/workflows/ci.yml` |
| Agent skills | B+ | Symlinked skills + overlays | `AGENTS.md`, `.agents/` |

## §2 System map today

See `docs/INDEX.md` mermaid. Runtime: `/usr/local/bin/tinfoil` + `/usr/share/tinfoil` copy of repo lib/modules/maintenance.

## §4 Musk 5-step on backlog

1. **Question** — CI profile validation still stubbed
2. **Delete** — root duplicate scripts (done per LEGACY)
3. **Simplify** — single module registry from `config/tools.yaml`
4. **Accelerate** — dogfood `make lint` in verification cockpit
5. **Automate** — weekly timer generates evidence without human

## §6 Guardrails

| Refuse | Build |
|--------|-------|
| Heavy install on `--thin` | Explicit `--profile` for ML/security |
| Destructive maintenance without confirm | gum + policy steps |
| Agent edits skill bodies in symlink target | Use `.agents/overlays/` |

## §7 Blueprint cards

### SN-1 · Dogfood verify gate (no new code)

**Problem:** Agents lack a single pre-PR command set.

```mermaid
flowchart LR
  dev[Agent edit] --> lint[make lint]
  lint --> prof[make validate-profiles]
  prof --> go[go build/vet]
  go --> thin[install.sh --thin --validate]
```

| File | Work |
|------|------|
| `AGENTS.md` | document verify block |
| `Makefile` | keep targets stable |

**Done when:** All five commands exit 0 on sentinel branch.

**Verify:** `make lint && make validate-profiles && go build -o /tmp/tinfoil ./bin/tinfoil.go && ./install.sh --thin --validate`

### SN-2 · Complete TUI interactive flows

**Problem:** Issue #7 — menus must drive audit, remediation, evidence without raw shell.

```mermaid
stateDiagram-v2
  [*] --> MainMenu
  MainMenu --> Audit: select
  MainMenu --> Evidence: select
  MainMenu --> Remediation: select
  Audit --> MainMenu: back
  Evidence --> MainMenu: back
  Remediation --> MainMenu: back
```

| File | Work |
|------|------|
| `lib/tui/update.sh` | wire messages to maintenance scripts |
| `lib/tui/view.sh` | gum menus + confirms |
| `lib/tui/model.sh` | state for selected flow |

**Done when:** `tinfoil tui` runs audit + evidence list + remediation dry-run paths.

**Verify:** manual `tinfoil tui`; `shellcheck lib/tui/*.sh`

### SN-3 · Real profile validation harness

**Problem:** CI echoes stub; `includes[]` ↔ `install_<module>` not fully enforced.

| File | Work |
|------|------|
| `scripts/profile-validation-harness.sh` | assert symbols + module dirs |
| `.github/workflows/ci.yml` | fail job on harness failure |

**Done when:** CI fails on broken profile reference.

**Verify:** `make validate-profiles` in CI locally

### SN-4 · Evidence screen in TUI

**Problem:** CLI has `tinfoil evidence`; TUI parity missing.

| File | Work |
|------|------|
| `lib/tui/view.sh` | evidence list/latest UI |
| `bin/tinfoil.go` | shared helpers if needed |

**Done when:** Latest bundle preview visible in TUI.

**Verify:** `tinfoil tui` → Evidence shows `logs/evidence-bundle-*.json` tail

### SN-EC-CAL · Eye-comfort calendar plugin seam

**Problem:** Tamil Nadu calendar is hard-coded in CLI/waybar; Sweden / America 1776 / pan-India overlays cannot ship without forking the switcher.

**Problem context:** `modules/productivity/eye-comfort` — TN pattern works; next cultures need a registry.

```mermaid
flowchart LR
  CLI[eye-comfort-theme MODE] --> Reg[calendar registry]
  Reg --> TN[tamil_nadu]
  Reg --> SE[sweden]
  Reg --> US[america_1776]
  Reg --> IN[india]
  Reg --> Render[live roles + omarchy-theme-set]
  Reg --> Bar[waybar chip generic]
```

| File | Work |
|------|------|
| `bin/eye-comfort-theme` | mode → registry resolve |
| `lib/*_schedule.py` | TN behind interface; no behavior change |
| `lib/waybar_status.py` | bar/tooltip from `state.calendar` |
| `lib/generate_packages.py` | multi-family package lists |

**Done when:** `tn` regression tests green; adding a calendar is new lib + packages only.

**Verify:** `PYTHONPATH=lib python3 lib/test_tamil_schedule.py` (+ future calendar suite)

### SN-EC-IN · Pan-India ṛtu / region overlay

**Problem:** Operators want subcontinental India rhythm, not only Tamil tinai; TN must stay.

| File | Work |
|------|------|
| `docs/PRODUCT-IN.md`, `DESIGN-IN.md` | ṛtu + region packages; TN coexistence |
| `lib/india_{schedule,palette}.py` | calendar + AA leans |
| `themes/eye-comfort-in-*` | ~5 regional packages |
| CLI | `eye-comfort-theme in` · `calendar: india` |

**Done when:** `in --json` AA-clean; TN untouched.

**Verify:** contrast matrix + dry-run apply one `eye-comfort-in-*`

### SN-EC-SE · Sweden seasons + saga/myth overlay

**Problem:** High-latitude light + Nordic year need structure; sagas/gods as restrained identity, not metal kitsch.

| File | Work |
|------|------|
| `docs/PRODUCT-SE.md`, `DESIGN-SE.md` | årstid + saga realms + lat defaults |
| `lib/sweden_{schedule,palette}.py` | solar-first SE |
| `themes/eye-comfort-se-*` | ~5 packages (asgard…nifl or landskap) |
| CLI | `eye-comfort-theme se` · `calendar: sweden` |

**Done when:** lat-honest midsummer/winter documented; AA tests pass.

**Verify:** `se --lat 59.3 --json` day/night extremes; contrast suite

### SN-EC-US · America 1776 + plain + modern/cowboy

**Problem:** Early-republic desk mood + Amish/plain craft + open modern America (cowboy/range, civic if AA) as optional culture mode.

| File | Work |
|------|------|
| `docs/PRODUCT-US.md`, `DESIGN-US.md` | 1776 spine; plain; range/modern welcome |
| `lib/america_{schedule,palette}.py` | seasons + craft leans |
| `themes/eye-comfort-us-*` | parchment, hearth, field, workshop, plain, range |
| CLI | `eye-comfort-theme us` · `calendar: america_1776` |

**Done when:** packages AA-clean; no ban on cowboy/modern when restrained.

**Verify:** contrast matrix; dry-run `us` apply

**Depends:** SN-EC-CAL preferred first; cultures can sequence IN → SE → US.

### SN-KEEP · Keeper follow-ups (see coming-next-keeper.md)

Full cards: [coming-next-keeper.md](./coming-next-keeper.md) · architecture: [keeper.md](./keeper.md)

| Card | Problem (one line) |
|------|--------------------|
| **SN-KEEP-1** | Dogfood no-passphrase recover drill (no new code) |
| **SN-KEEP-2** | CI `cargo test` for keeper crate |
| **SN-KEEP-3** | Install release binary to `~/.local/bin/keeper` |
| **SN-KEEP-4** | Device re-bind after reimage |
| **SN-KEEP-5** | Optional fprintd as share release (not root) |
| **SN-KEEP-6** | Trusted places enrollment (IP still banned) |

```mermaid
flowchart LR
  K1[SN-KEEP-1 dogfood] --> K2[SN-KEEP-2 CI]
  K1 --> K3[SN-KEEP-3 PATH]
  K3 --> K4[SN-KEEP-4 rebind]
  K4 --> K5[SN-KEEP-5 fprintd]
  K5 --> K6[SN-KEEP-6 places]
```

## §9 Gantt (suggested)

```mermaid
gantt
  title arch-machine sprint order
  dateFormat YYYY-MM-DD
  section Gate
  SN-1 Dogfood verify     :sn1, 2026-06-22, 3d
  section Ship
  SN-3 Profile harness    :sn3, after sn1, 5d
  SN-2 TUI flows          :sn2, after sn1, 10d
  SN-4 Evidence TUI       :sn4, after sn2, 5d
  section Keeper
  SN-KEEP-1 dogfood drill :k1, 2026-07-18, 3d
  SN-KEEP-2 CI cargo      :k2, after k1, 3d
  SN-KEEP-3 PATH install  :k3, after k1, 5d
  SN-KEEP-4 rebind        :k4, after k3, 8d
  section EyeComfort culture
  SN-EC-CAL calendar seam :eccal, after sn4, 5d
  SN-EC-IN pan-India      :ecin, after eccal, 8d
  SN-EC-SE Sweden saga    :ecse, after eccal, 8d
  SN-EC-US America 1776   :ecus, after eccal, 8d
```

## §10 Monitoring signals

- CI red on `sentinel` branch
- `logs/evidence-bundle-*.json` age > 7d on active machines
- `tinfoil` version drift vs repo tag

## §11 Done log

| Item | Evidence |
|------|----------|
| tinfoil CLI shipped | PR #3 merge `2504e39` |
| Remediation policy | PR #4 merge `cb088cd` |
| Agent skills wired | `AGENTS.md`, `.agents/skills` symlinks |
| INDEX architecture doc | `docs/INDEX.md` |
| Multi-factor keeper + PQ seal | PR #28 (open) `modules/security/keeper` |
| Grok arch-machine plugin | [p10ns11y/plugins](https://github.com/p10ns11y/plugins) `arch-machine/` |
| Module `--agent-expand` hooks | PR #28 `e9c264a` |
| UWSM graphical-session race | PR #25 merge |

## §13 References

| Source | Use |
|--------|-----|
| `docs/INDEX.md` | System map |
| `arch-design/keeper.md` | Keeper architecture + mermaid |
| `arch-design/coming-next-keeper.md` | SN-KEEP-* backlog |
| `policies/security-remediation.md` | Boundary meta-rule |
| `AGENTS.md` | Agent verify + skills |
| `.agents/overlays/` | Repo-specific skill overlays |
| collab-finder [batch-2-blueprints](https://github.com/p10ns11y/collab-finder/blob/main/reports/batch-2-engineering-blueprints.md) | Card format |
| Skills library | `~/Work/personal/skills` symlinks |

---

**Plain rule:** Thin install, loud evidence, ruthless remediation — the sentinel must pass its own audit before it audits your machine. Offline escrow off-box, or the keeper is theater.
