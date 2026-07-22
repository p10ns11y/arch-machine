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

# STEP 2 (when ready): Full profile install via the same installer or from TUI
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

## Legacy Scripts

The original standalone scripts are still available for backward compatibility:

- **`basic_setup.sh`**: Comprehensive ML/AI development setup
- **`secure-fortress-phase0-simple.sh`**: Security hardening setup

These provide one-shot installation but lack the profile-based approach of the new system.

## The tinfoil CLI (optional shim — interim)

> **Product surface:** **`archy`** (`tools/archy`) is the main interactive control plane.  
> Until **SN-ARCHY-1** ships `archy` on PATH from thin install, day-1 from a checkout is:
>
> ```bash
> make archy
> TINFOIL_ROOT="$PWD" ./tools/archy/target/debug/archy
> ```
>
> `tinfoil` remains the **thin Go dispatcher** installed by default `./install.sh` / `--thin` today.  
> `tinfoil tui` / `./install.sh --tui` fall through to **gum** (`lib/tui/`) — legacy bridge (SN-2 freeze), not the product.

`tinfoil` is the lightweight sentinel/guardian **CLI shim**. By default `./install.sh` (or `--thin`) still installs this binary first.

### Installation details (current thin path)
- Binary: `/usr/local/bin/tinfoil`
- Supporting runtime: `/usr/share/tinfoil/`  
  (contains `bin/tinfoil.go`, `lib/`, `config/profiles/`, `maintenance/`, `modules/`, `install.sh`, etc.)

### Basic usage after thin install (shim)

```bash
tinfoil                  # Full system audit (global investigator mode)
tinfoil tui              # Legacy: prefers archy if on PATH, else gum TUI
tinfoil .                # Audit current directory
tinfoil /some/path       # Audit any folder
```

Prefer running **archy** from the checkout (or future PATH install) for the real menu → NEXT loop. See [archy.md](archy.md).

For development (before any install):

```bash
make archy
TINFOIL_ROOT="$PWD" ./tools/archy/target/debug/archy
# legacy gum:
# ./install.sh --tui
# go run bin/tinfoil.go tui
```

After the thin CLI is installed you can still do full workstation bootstrap with:

```bash
./install.sh --profile ml-dev
```

Name humor: [tinfoil-name-explained.md](../tinfoil-name-explained.md) (legacy entry doc — points here + archy). Architecture: [INDEX.md](INDEX.md).
