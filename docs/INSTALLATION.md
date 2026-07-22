# Installation Guide

## Safety Information

Basic precautions for installation:

1. Backup your system before installation
2. Test in a virtual machine first
3. Review configurations in `config/`
4. Monitor the installation process
5. Have recovery options ready

See [Safety & Requirements](../SAFETY.md) for detailed information.

## First-Time Installation (Thin Sentinel First — Recommended)

```bash
# Clone the repository
git clone <repository-url>
cd arch-machine

# Make scripts executable
chmod +x install.sh migrate.sh

# Run migration if you have existing setup (optional)
./migrate.sh

# STEP 1 (default / recommended): Thin install — shared runtime for backends
./install.sh
# or explicitly:
./install.sh --thin

# Runtime tree: /usr/share/tinfoil/  (maintenance/, profiles, modules, …)
# Main controller is archy (Ratatui entry + loop). Until thin install ships
# archy on PATH (SN-ARCHY-1), build and run from the checkout:
make archy
TINFOIL_ROOT="$PWD" ./tools/archy/target/debug/archy

# Or call backends directly:
./maintenance/security-audit.sh
./maintenance/inventory.sh --json

# STEP 2 (when ready): Full profile install (same installer; prefer archy menus later)
./install.sh --profile ml-dev     # recommended full ML/AI + ROCm workstation
# or
./install.sh --profile security-dev
# or
./install.sh --profile minimal

# List / inspect profiles (no install performed)
./install.sh --list-profiles
./install.sh --show-profile ml-dev

# Validate system readiness (no changes)
./install.sh --validate
```

## Post-Installation Setup (after full profile)

```bash
# After a full --profile install:
# Log out and back in for group changes (ROCm, docker, etc.)

# Set up automated weekly maintenance + evidence (recommended)
maintenance/systemd-setup.sh setup

# Or cron fallback:
maintenance/cron-setup.sh setup
```

Note: the thin `tinfoil` install alone does not require logout or systemd setup — you get the auditor + TUI immediately. Full maintenance timers are part of the profile + maintenance layer.

## Installation Profiles

### `minimal`
- Basic development tools (git, python, node, rust)
- Essential system packages
- Core development workflow

### `ml-dev` (Recommended)
- Everything in `minimal`
- ROCm GPU acceleration
- ML/AI environments (ai-amd, xAI-exp)
- Data science packages

### `security-dev`
- Everything in `minimal`
- Kubernetes (k3s) with Cilium networking
- Runtime security monitoring (Tetragon)
- Encrypted storage vault
- Vulnerability scanning tools (OSV-Scanner, Grype, Syft, pip-audit, cargo-audit)
- Log processing pipeline (Vector, Toon)

## Profile Customization

Each installation profile can be customized by modifying the corresponding YAML file in `config/profiles/`. For example, to change the Python or Node.js versions installed with mise:

```yaml
customizations:
  development:
    mise:
      versions:
        python: ["3.12", "3.13", "3.14"]
        node: ["20", "lts"]
        rust: ["stable"]
```

Customizations override the default versions specified in `config/tools.yaml`. Use `./install.sh --show-profile <name>` to see current customizations for any profile.

## Custom Profiles

Create custom installation profiles by editing `config/profiles/*.yaml`:

```yaml
name: "custom-profile"
description: "My custom development setup"
includes:
  - system.full
  - development.full
customizations:
  development:
    mise:
      versions:
        python: ["3.12", "3.13"]
```

## Tool Configuration

Modify `config/tools.yaml` to change tool versions or add new tools.

## Legacy one-shots (removed from day-1)

Do **not** start from old root one-shots (`basic_setup.sh`, fortress scripts, etc.). They were killed or superseded; history only in [LEGACY.md](LEGACY.md). Use **profiles** + `./install.sh --profile …`.

## Day-1 controller: archy

**Product surface:** [archy.md](archy.md) (`tools/archy`). Interactive menus → NEXT → maintenance backends.

Until **SN-ARCHY-1** installs `archy` on PATH from thin install:

```bash
make archy
TINFOIL_ROOT="$PWD" ./tools/archy/target/debug/archy
```

Gum `lib/tui/` remains on disk as a frozen bridge (bugfixes only). Do not document it as the product. Code cleanup of gum / Go PATH face is deferred (no app changes in this docs pass).

## Thin shim note (`tinfoil`)

Today `./install.sh` / `--thin` still installs the Go **`tinfoil`** dispatcher to `/usr/local/bin/tinfoil` and runtime under `/usr/share/tinfoil/`. Use it for shim subcommands (audit, inventory, …) if needed. Prefer **archy** for the menu loop.

```bash
tinfoil                  # audit via shim (if installed)
tinfoil .                # audit current directory
./install.sh --profile ml-dev
```

Name humor (optional): [tinfoil-name-explained.md](../tinfoil-name-explained.md). Architecture: [INDEX.md](INDEX.md).
