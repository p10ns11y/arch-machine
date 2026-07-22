# Overlay — arch-machine stellar roadmap

**Pairs with:** [stellar-roadmap](../skills/stellar-roadmap/SKILL.md)

**Doc:** `arch-design/coming-next.md` · **Keeper:** `arch-design/coming-next-keeper.md` · **Index:** `docs/INDEX.md`  
**Soft-obsolete:** `arch-design/soft-obsolete-candidates.md`

## Fused one-liner

archy + shell backends + profile installer + evidence → self-remediating guardian. Grok transports (serve/stdio/inject) are sibling surfaces.

## Scorecard skeleton (2026-07 soft pass)

| Area | Grade | Evidence |
|------|-------|----------|
| archy control plane | B+ | `tools/archy`, cargo tests |
| archy on thin PATH | D | SN-ARCHY-1 open |
| Grok agent transports | A- | `docs/groxy.md`, ontology |
| Thin-first install | A- | `install.sh --thin` |
| Shell backends | A- | `maintenance/*.sh` |
| Profile validation | B | local harness; CI stub |
| Evidence extract | A- | extract-evidence + logs |
| Remediation apply | C | policy A-; applicator stub |
| Keeper | A | `tools/keeper` |
| CI | B | cargo hard; shell soft |
| Agent skills | A- | skills-lock + `.agents/` |

## SN priority template

1. **SN-1** Dogfood — lint + validate-profiles + cargo tests  
2. **SN-ARCHY-1** Thin ships `archy` on PATH  
3. Wire CI `make validate-profiles` (finish SN-3)  
4. Inventory/actuate UX in archy  
5. SN-GO-THIN demote Go shim  

## Verify

```bash
make lint && make validate-profiles
cargo test --manifest-path tools/archy/Cargo.toml
./install.sh --thin --validate
```
