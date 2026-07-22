# Overlay — arch-machine token budget

**Pairs with:** [ai-optimization](../skills/ai-optimization/SKILL.md)  
**Boundary:** `policies/security-remediation.md` · **Ontology:** [../ontology/INDEX.md](../ontology/INDEX.md)

## Stack

Rust archy + bash installer/modules/maintenance + YAML profiles + evidence JSON/TOON. Go `tinfoil` = thin legacy shim.

## Relevance

| Signal | Boost |
|--------|-------|
| `tools/archy/**` | +40 |
| `install.sh`, `lib/installer.sh` | +40 |
| `modules/*/install.sh` | +30 |
| `maintenance/`, `policies/` | +30 |
| `config/profiles/*.yaml` | +25 |
| `tools/groxy/**`, `tools/keeper/**` | +25 |
| `docs/archy.md`, `docs/INDEX.md`, `docs/MODULES.md` | +20 |
| `bin/tinfoil.go`, `lib/tui/**` | +15 (legacy) |
| `.grok/`, sample logs | −50 unless debugging |

## Compress

| Kind | Keep |
|------|------|
| archy | Msg/Cmd/Eagle signatures; satellite job table |
| install modules | `install_<name>()` + dry-run/validate flags |
| lib/*.sh | exported fns; drop `log_*` boilerplate |
| profiles | `description`, `includes[]`, key pkgs |
| maintenance | args → policy step → artifact path |

## Never compress

- `policies/security-remediation.md`
- `install_<module>()` under edit
- Profile `includes[]` on composition change
- Eagle Msg/Cmd when routing
- Evidence fields agents parse

## Handoff

Cross-cut → [arch-machine-fusion-sage.md](arch-machine-fusion-sage.md) · Ontology subgraph by intent.
