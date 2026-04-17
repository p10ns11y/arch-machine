# Wave 1: Core Stabilization (P0)

## Scope
- Stabilize installer correctness and profile/module plumbing.
- Ensure YAML parsing consistency, module loading reliability, and profile validation coverage.
- Confirm dry-run truthfulness and baseline behavior for `minimal`, `ml-dev`, and `security-dev`.

## Suggested Task Allocation
- Task `P0-1`: YAML parsing and profile validation hardening -> `Virtinel`
- Task `P0-2`: module loading and error handling determinism -> `Trusinel`
- Task `P0-3`: dry-run parity and baseline matrix verification -> `Guardwell`

## Exit Criteria
- Installer core paths are deterministic and validated.
- Dry-run output matches execution plan behavior.
- Baseline profile matrix passes pre-security hardening checks.
