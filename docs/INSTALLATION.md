# Installation Guide

## First-Time Installation

```bash
# Clone the repository
git clone <repository-url>
cd arch-machine

# Make scripts executable
chmod +x install.sh migrate.sh

# Run migration if you have existing setup (optional)
./migrate.sh

# Install using ml-dev profile (recommended)
./install.sh --profile ml-dev

# For security-focused setup
./install.sh --profile security-dev

# For minimal development setup
./install.sh --profile minimal

# List available profiles
./install.sh --list-profiles

# Show detailed profile information
./install.sh --show-profile ml-dev

# Validate system readiness
./install.sh --validate
```

## Post-Installation Setup

```bash
# Log out and back in for group changes
# Set up automated maintenance
maintenance/systemd-setup.sh setup

# Or use cron if systemd is not available
maintenance/cron-setup.sh setup
```

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

These provide one-shot installation but lack the modular, profile-based approach of the new system.