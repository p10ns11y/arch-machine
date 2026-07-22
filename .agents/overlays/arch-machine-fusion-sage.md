# Overlay — arch-machine fusion

**Pairs with:** [fusion-sage](../skills/fusion-sage/SKILL.md) · **Ontology:** [../ontology/INDEX.md](../ontology/INDEX.md)

## Fused loop

```text
archy (Eagle+sats) → maintenance/*.sh / install.sh → evidence bundles
        ↑ TEA Msg/Cmd                              │
        └──────── logs/evidence-bundle-*.{json,toon} ┘
groxy: inject|acp · keeper: threshold vault · plugin↔archy cycle
```

**Iron peak:** Eagle thin + offline jobs + evidence schema — compounds a decade.

## Aggregates

| Aggregate | Sources | Stable API |
|-----------|---------|------------|
| **ControlPlane** | `tools/archy/`, eagle skill | Msg → Eagle → Cmd → satellite |
| **ProfileEngine** | `install.sh`, `lib/installer.sh`, profiles | `--profile --thin --validate --dry-run` |
| **ModuleBay** | `modules/*/install.sh` | `install_<name>()` · `docs/MODULES.md` |
| **EvidenceLoop** | `lib/evidence.sh`, extract-evidence | `logs/evidence-bundle-*.{json,toon}` |
| **RemediationPolicy** | `policies/security-remediation.md` | audit→fix dry-run first |
| **Groxy** | `tools/groxy/`, `bin/groxy` | inject notify · acp serve |
| **Keeper** | `tools/keeper/` | `--agent-expand` install |

## Surplus (Q>1)

1. Derive profile docs from one registry (cut duplicate tables)
2. Pin evidence schema node agents may trust
3. Ontology drift check before merge on control/install edges

## Expand

`expand control` · `expand install` · `expand evidence` · `expand remote` · `expand vault`
