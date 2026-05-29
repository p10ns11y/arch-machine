# Contributing to Arch Machine

The Vigilant Guardian welcomes contributions that strengthen the evidence self-loop and the platform's ability to apply its own policies to itself.

## Before You Open a PR

1. Run the project's own tools:
   - `./install.sh --thin`
   - `tinfoil` (or `tinfoil tui`)
   - `maintenance/security-audit.sh`
   - `maintenance/extract-evidence.sh`

2. `make lint` (or the individual linters) and `make validate-profiles`.

3. Produce an evidence bundle and reference it in your PR.

## CI Requirements (Phase 4+)

All PRs to `sentinel` must pass the CI workflow (see `.github/workflows/ci.yml`):
- shellcheck
- yamllint
- Go build/vet
- Profile validation harness
- Evidence smoke test
- Markdown lint

See the PR template for the full checklist.

## Adding a Module

See [docs/MODULES.md](MODULES.md).

## Documentation

Update `docs/INDEX.md` and relevant guides when changing behavior or adding features.

Thank you for helping the Sentinel watch itself.
