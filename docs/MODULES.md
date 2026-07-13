# Module authoring contract

Each capability under `modules/<area>/<name>/` (or `modules/<area>/install.sh` for bundled areas) must expose an idempotent `install_<name>()` (or area entrypoint) that supports `--dry-run` / `--validate` when wired through the root installer.

## Profile / ModuleBay wiring

- **Profile-wired modules** appear in `config/profiles/*.yaml` `includes` and are invoked by `install.sh --profile …`.
- **Standalone modules** ship their own `install.sh` and are **not** pulled in by profiles until explicitly wired.

### eye-comfort (standalone-only)

[`modules/productivity/eye-comfort`](../modules/productivity/eye-comfort/) is **standalone-only** for now: install via its own `./install.sh` (or after merge, the same path on `sentinel`). It is **not** listed in profile YAML and has no `install_eye_comfort` hook in `modules/productivity/install.sh`. Optional ModuleBay / profile wire is a follow-up (SN-EC-1).

See also [docs/eye-comfort.md](eye-comfort.md).

## Checklist for new modules

1. Idempotent install; dry-run safe.
2. Document in `docs/` + module README.
3. Either profile-wire **or** state standalone-only here (and in the module README).
4. Prefer evidence hooks where the module touches maintenance surfaces.
