# Contributing to Arch Machine

The Vigilant Guardian welcomes contributions that strengthen the evidence self-loop and the platform's ability to apply its own policies to itself.

## Before You Open a PR

1. Prefer the live control plane from a checkout:
   ```bash
   make archy
   TINFOIL_ROOT="$PWD" ./tools/archy/target/debug/archy
   ```
   Or call backends: `./maintenance/security-audit.sh`, `./maintenance/extract-evidence.sh`.
2. `make lint` and `make validate-profiles`.
3. Cargo where you touched Rust:
   ```bash
   cargo test --manifest-path tools/archy/Cargo.toml
   cargo test --manifest-path tools/groxy/Cargo.toml
   cargo test --manifest-path tools/keeper/Cargo.toml
   ```
4. Produce an evidence bundle (or `--dry-run`) and reference it in your PR when relevant.

Full gate list: root [AGENTS.md](../AGENTS.md). Cockpit VERIFY is a subset — see `.agents/verification/`.

## CI

See `.github/workflows/ci.yml`. Today **hard**: archy/groxy/keeper cargo (+ eye-comfort gates). Shell/profile/evidence jobs may still be advisory (`|| true`). Do not assume every AGENTS.md check is CI-blocking yet.

## Adding a Module

See [docs/MODULES.md](MODULES.md).

## Documentation

Update `docs/INDEX.md` and relevant guides when changing behavior. Evolution inventory: [arch-design/soft-obsolete-candidates.md](../arch-design/soft-obsolete-candidates.md).

Thank you for helping the Sentinel watch itself.
