# Overlay — arch-machine decision hooks

**Pairs with:** [higher-order-decision-architect](../skills/higher-order-decision-architect/SKILL.md)

## Material decision zones

| Zone | Invariants | Pre-mortem trigger |
|------|------------|-------------------|
| **Installer / modules** | Idempotent `install_*`; `--dry-run` before mutate | Breaks existing Arch installs; pacman hook conflicts |
| **TUI destructive flows** | Security Remediation Policy; confirm in gum | Silent `rm -rf` or branch cleanup without audit trail |
| **Profile YAML** | `includes[]` ↔ `install_<module>` symbol exists | Profile validates in CI but fails on real machine |
| **tinfoil packaging** | Thin default; `/usr/share/tinfoil` runtime | Heavy deps pulled on `--thin`; PATH shadowing |
| **Evidence contracts** | Token-efficient bundles; no secrets in logs | Schema drift breaks agent consumers |

## Consequence chain (template)

| Order | Effect | Watch signal |
|-------|--------|--------------|
| 1st | New module in `ml-dev` profile | `make validate-profiles` |
| 2nd | Weekly timer runs heavier maintenance | systemd unit CPU/disk logs |
| 3rd | Evidence schema change breaks LLM tooling | `tinfoil evidence latest` parse errors |

## Antifragility preferences

- Prefer **dry-run + evidence bundle** before apply-remediation
- Prefer **thin install path** as default blast-radius bound
- Prefer **module isolation** over monolithic install scripts

## Refuse vs build

| Refuse | Build toward |
|--------|--------------|
| Hand-edit signer/policy JSON (N/A here) | Kit-managed policy patterns for future autonomous hooks |
| Silent destructive maintenance | gum confirm + policy step logging |
| Duplicate root-level `*-simple.sh` | Canonical `setups/` + `maintenance/` layout |
