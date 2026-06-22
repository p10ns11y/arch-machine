# Overlay — arch-machine (bash + Go sentinel)

**Pairs with:** [ai-optimization](../skills/ai-optimization/SKILL.md)

**Repo:** [p10ns11y/arch-machine](https://github.com/p10ns11y/arch-machine) · **Type:** shell-installer · **Boundary:** `policies/security-remediation.md`

## Project snapshot

- **Stack:** Bash installer modules, gum/Bubble Tea TUI shims, Go `tinfoil` CLI, YAML profiles, evidence JSON/TOON
- **Verify:** `make lint`, `make validate-profiles`, `go build ./bin/tinfoil.go`, `./install.sh --validate`
- **CI:** `.github/workflows/ci.yml`

## Relevance scoring

| Signal | Boost | Notes |
|--------|-------|-------|
| `install.sh`, `lib/installer.sh` | +40 | Entry + orchestration |
| `bin/tinfoil.go`, `lib/tui*.sh` | +35 | User-facing sentinel |
| `modules/*/install.sh` | +30 | Profile composition |
| `maintenance/`, `policies/` | +30 | Audit, evidence, remediation |
| `config/profiles/*.yaml` | +25 | Profile edits |
| `docs/INDEX.md`, `docs/MODULES.md` | +20 | Contracts |
| `.grok/`, `logs/`, samples | -50 | Unless debugging evidence/logs |

## Bash compression playbook

- **install modules:** `install_<name>()` signature + dry-run/validate flags + one-line side effects
- **lib/*.sh:** exported functions with signatures; collapse standard `log_*` / `set -euo pipefail` boilerplate
- **maintenance scripts:** entry args, policy step invoked, output artifact path
- **YAML profiles:** `description`, `includes[]`, key package lists — not full duplicate of tools.yaml
- **Go tinfoil:** Cobra subcommands table; Bubble Tea model fields only when editing TUI

## Never compress

- `policies/security-remediation.md` and any destructive `maintenance/apply-*.sh` path
- Full `install_<module>()` when editing that module
- Profile `includes` when adding/removing modules
- `lib/tui/update.sh` message dispatch when fixing TUI flows

## Fusion handoff

Cross-cutting refactors → load [arch-machine-fusion-sage.md](arch-machine-fusion-sage.md) + [arch-design/coming-next.md](../../arch-design/coming-next.md).
