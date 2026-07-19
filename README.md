# arch-machine

<img src="tinfoil.jpg" alt="arch-machine" width="140" style="display: block; margin: auto;">

Arch Linux workstation toolkit steered by **`archy`** (Ratatui entry + loop): thin install first, then optional YAML profiles for ML/AI and security hardening. Shell backends (`maintenance/`, `install.sh`) do the work; evidence bundles close the loop. Omarchy-friendly inventory and package plans.

[![CI](https://github.com/p10ns11y/arch-machine/actions/workflows/ci.yml/badge.svg)](https://github.com/p10ns11y/arch-machine/actions/workflows/ci.yml)

For lore and humor, see [FUNREADME.md](FUNREADME.md). Safety details: [SAFETY.md](SAFETY.md). Roadmap: [arch-design/coming-next.md](arch-design/coming-next.md).

## What you can use this for

| Goal | Path |
|------|------|
| Interactive control plane | `archy` (or `make archy` from this repo) |
| Full ML/AI workstation | `./install.sh --profile ml-dev` |
| Security-focused workstation | `./install.sh --profile security-dev` |
| Light base tools only | `./install.sh --profile minimal` |
| Inventory / ownership | `./maintenance/inventory.sh --json` (also in archy menu) |
| Omarchy host status | `./maintenance/omarchy-status.sh` |
| Search tools & profiles | `./maintenance/catalog.sh docker` |
| Package change plan (dry-run) | `./maintenance/package-actuate.sh --update jq` |
| Security audit | `./maintenance/security-audit.sh` |
| Evidence bundles | `./maintenance/extract-evidence.sh` |
| Weekly updates + scans | `maintenance/systemd-setup.sh setup` |

Primary target: **Arch Linux** (including Omarchy). Not a multi-distro installer.

## Prerequisites

- Arch Linux, network, `sudo`, `git`
- **Rust / cargo** for `archy` (main controller)
- `yq` or `jq` when needed (often auto-installed)

Review [SAFETY.md](SAFETY.md) before `security-dev`.

## Install

### A — Thin runtime + control plane (recommended first)

```bash
git clone https://github.com/p10ns11y/arch-machine.git
cd arch-machine
chmod +x install.sh

./install.sh
# same as: ./install.sh --thin

# Main controller (until SN-ARCHY-1 ships archy on PATH from thin install):
make archy
TINFOIL_ROOT="$PWD" ./crates/archy/target/debug/archy
```

`./install.sh --thin` installs the shared runtime under `/usr/share/tinfoil/` (backends + profiles). Day-1 interaction is **`archy`**, not the optional Go shim.

### B — Full workstation profile

```bash
./install.sh --list-profiles
./install.sh --show-profile ml-dev
./install.sh --profile ml-dev --dry-run
./install.sh --profile minimal|ml-dev|security-dev
```

After a full profile:

```bash
# Log out/in if groups changed (docker, ROCm, …)
maintenance/systemd-setup.sh setup
```

### Flags

| Flag | Meaning |
|------|---------|
| (none) / `--thin` | Thin runtime (default) |
| `--profile NAME` | Full profile install |
| `--dry-run` | Full-profile preview (pair with `--profile`) |
| `--validate` | Readiness checks only |
| `--tui` | Launch control plane (archy if present, else gum legacy) |

## Usage by job

### Control plane

```bash
make archy
TINFOIL_ROOT="$PWD" ./crates/archy/target/debug/archy
# after SN-ARCHY-1 / when on PATH:
archy
```

Keys: ↑↓ select · Enter run · `g` Grok split · `G` fullscreen Grok · `?` help · `q` quit.  
Details: [crates/archy/README.md](crates/archy/README.md).

### Backends (scripts archy steers)

```bash
./maintenance/inventory.sh --json
./maintenance/omarchy-status.sh
./maintenance/catalog.sh docker
./maintenance/package-actuate.sh --update jq    # dry-run default
./maintenance/security-audit.sh
./maintenance/extract-evidence.sh --dry-run
```

Omarchy playbook: [docs/omarchy.md](docs/omarchy.md).

### Profiles

- **minimal** — git, mise (python/node/rust), essentials
- **ml-dev** — + ROCm, conda (`ai_amd`, `xai_exp`), data science
- **security-dev** — + vault, k8s/security tooling, scanners

See [docs/INSTALLATION.md](docs/INSTALLATION.md) · [docs/MODULES.md](docs/MODULES.md).

## Verify

```bash
./install.sh --validate
make validate-profiles
make archy
./crates/archy/target/debug/archy --print-root
./maintenance/extract-evidence.sh --dry-run
```

## Project layout

```
arch-machine/
├── crates/archy/           # MAIN controller — Ratatui entry + loop
├── maintenance/            # shell backends (iron peak)
├── install.sh              # thin default; --profile for full
├── config/profiles/        # minimal | ml-dev | security-dev
├── modules/                # system, development, ml_ai, security, …
├── lib/                    # installer, evidence, gum TUI (legacy)
├── bin/tinfoil.go          # optional thin dispatcher (not the product)
└── docs/                   # start at docs/INDEX.md
```

## Documentation

- [arch-design/coming-next.md](arch-design/coming-next.md) — backlog (archy-first)
- [docs/INDEX.md](docs/INDEX.md) · [SAFETY.md](SAFETY.md)
- [docs/INSTALLATION.md](docs/INSTALLATION.md) · [docs/MAINTENANCE.md](docs/MAINTENANCE.md)
- [docs/omarchy.md](docs/omarchy.md) · [docs/BACKUP.md](docs/BACKUP.md) · [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)
- [AUTHORS-MOTTO.md](AUTHORS-MOTTO.md)

## License

See [LICENSE](LICENSE).

## Contributing

1. Fork and branch  
2. Prefer new capability in `maintenance/*.sh`, surfaces in `crates/archy`  
3. Verify with the commands above (`make lint` when touching shell/docs)  
4. Open a pull request  

See [docs/CONTRIBUTING.md](docs/CONTRIBUTING.md).
