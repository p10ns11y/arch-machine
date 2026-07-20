# Overlay — arch-machine stellar roadmap scout

**Pairs with:** [stellar-roadmap](../skills/stellar-roadmap/SKILL.md)

**Canonical doc:** `arch-design/coming-next.md` · **Boundary:** `policies/security-remediation.md` · **Index:** `docs/INDEX.md`

## Fused abstraction

**archy** (entry + loop) + shell backends + profile installer + evidence loop → **self-remediating guardian platform** (the repo eats its own policy). Go shim / gum are legacy bridges.

## Scorecard skeleton (refresh on each roadmap pass)

| Area | Grade | Evidence |
|------|-------|----------|
| archy control plane | B+ | `crates/archy`, `make archy` |
| archy on thin PATH | D | SN-ARCHY-1 open — thin still ships Go shim |
| Thin-first install | A- | `install.sh --thin`, README |
| Shell backends | A- | `maintenance/*.sh` |
| Profile validation | B | `scripts/profile-validation-harness.sh`, CI job |
| Evidence pipeline | A- | `maintenance/extract-evidence.sh`, `logs/` |
| Remediation policy | A | `policies/security-remediation.md` |
| CI gate | B+ | `.github/workflows/ci.yml` |

## SN priority template

1. **SN-ARCHY-1** Thin install ships `/usr/local/bin/archy`
2. **SN-1** Dogfood gate — `make lint && make validate-profiles && make archy`
3. **SN-INV-2** Multi-select actuate UX in archy
4. **SN-GO-THIN** Demote/exit optional Go shim
5. **SN-2** gum freeze (no new features)

## Key paths

`crates/archy/` · `docs/INDEX.md` · `install.sh` · `modules/` · `maintenance/` · `config/profiles/`

## Verify

```bash
make lint
make validate-profiles
make archy
./crates/archy/target/debug/archy --print-root
./install.sh --validate
```
