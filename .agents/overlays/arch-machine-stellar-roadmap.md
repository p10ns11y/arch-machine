# Overlay — arch-machine stellar roadmap

**Pairs with:** [stellar-roadmap](../skills/stellar-roadmap/SKILL.md)

**Doc:** `arch-design/coming-next.md` · **Keeper:** `arch-design/coming-next-keeper.md` · **Index:** `docs/INDEX.md`

## Fused one-liner

archy + shell backends + profile installer + evidence → self-remediating guardian (repo eats its policy).

## Scorecard (refresh each pass)

| Area | Grade | Evidence |
|------|-------|----------|
| archy control plane | B+ | `tools/archy`, cargo tests |
| archy on thin PATH | D | SN-ARCHY-1 open |
| Thin-first install | A- | `install.sh --thin` |
| Shell backends | A- | `maintenance/*.sh` |
| Profile validation | B | harness + CI |
| Evidence pipeline | A- | extract-evidence + logs |
| Remediation policy | A | `policies/security-remediation.md` |
| groxy / keeper | B | crates + docs |
| CI gate | B+ | `.github/workflows/ci.yml` |

## SN order (template)

1. **SN-1** Dogfood — lint + validate-profiles + archy tests  
2. **SN-ARCHY-1** Thin ships `archy` on PATH  
3. Inventory/actuate UX in archy  
4. Demote Go shim  
5. Freeze gum features  

## Verify

```bash
make lint && make validate-profiles
cargo test --manifest-path tools/archy/Cargo.toml
./install.sh --thin --validate
```
