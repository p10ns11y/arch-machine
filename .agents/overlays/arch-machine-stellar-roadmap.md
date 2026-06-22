# Overlay — arch-machine stellar roadmap scout

**Pairs with:** [stellar-roadmap](../skills/stellar-roadmap/SKILL.md)

**Canonical doc:** `arch-design/coming-next.md` · **Boundary:** `policies/security-remediation.md` · **Index:** `docs/INDEX.md`

## Fused abstraction

Sentinel surface + profile installer + maintenance heart + evidence loop → **self-remediating guardian platform** (the repo eats its own policy).

## Scorecard skeleton (refresh on each roadmap pass)

| Area | Grade | Evidence |
|------|-------|----------|
| Thin-first install | A- | `install.sh --thin`, README quick start |
| tinfoil CLI + TUI | B+ | `bin/tinfoil.go`, `lib/tui.sh`, Issue #7 |
| Profile validation | B | `scripts/profile-validation-harness.sh`, CI job |
| Evidence pipeline | A- | `maintenance/extract-evidence.sh`, sample bundles in `logs/` |
| Remediation policy | A | `policies/security-remediation.md`, `apply-remediation.sh` |
| Module contract docs | B | `docs/MODULES.md`, `docs/PROFILES.md` |
| CI gate | B+ | `.github/workflows/ci.yml` |

## SN priority template

1. **SN-1** Dogfood gate — `make lint && make validate-profiles` + thin install validate
2. **SN-2** TUI Elm flows complete (Issue #7) — gum menus wired to maintenance
3. **SN-3** Profile harness real (not CI stub) — every `includes[]` symbol checked
4. **SN-4** Evidence screen in TUI — `tinfoil evidence` parity in Bubble Tea
5. **SN-5** systemd timer dogfood on sentinel branch

## Key paths

`docs/INDEX.md` · `install.sh` · `modules/` · `maintenance/` · `config/profiles/` · `lib/tui/`

## Verify

```bash
make lint
make validate-profiles
go build -o /tmp/tinfoil ./bin/tinfoil.go
./install.sh --thin --validate
```
