# Overlay — arch-machine decision hooks

**Pairs with:** [higher-order-decision-architect](../skills/higher-order-decision-architect/SKILL.md)

## Zones

| Zone | Invariant | Pre-mortem |
|------|-----------|------------|
| Eagle / satellites | Thin Eagle; satellites own jobs; offline exit | Spaghetti update; Eagle shells out |
| Installer / modules | Idempotent `install_*`; dry-run first | Breaks live Arch; pacman hook fights |
| Profiles | `includes[]` ↔ `install_<module>` exists | CI green, machine red |
| Remediation | Policy + confirm; no silent destroy | `rm -rf` without audit trail |
| Evidence | No secrets in bundles | Schema drift breaks agents |
| Thin PATH | archy on thin; tinfoil optional | Heavy deps on `--thin` |
| Groxy | inject + acp only | Ambient chat as control plane |

## Chain (template)

| Order | Effect | Watch |
|-------|--------|-------|
| 1st | New module in profile | `make validate-profiles` |
| 2nd | Heavier weekly maintenance | timer CPU/disk |
| 3rd | Evidence field rename | agent parse fail |

## Prefer

Dry-run + evidence before apply · thin blast radius · module isolation · Msg/Cmd over ad-hoc scripts

## Refuse / build

| Refuse | Build |
|--------|-------|
| Silent destructive maintenance | Confirm + policy step log |
| Eagle builds shell strings | Satellite owns command |
| Duplicate root `*-simple.sh` | Canonical `maintenance/` + setups |
| Hand am-* to users | Plugin slash / archy only |
