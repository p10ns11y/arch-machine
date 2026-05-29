# arch-machine

<img src="tinfoil.jpg" alt="tinfoil" width="140" style="display: block; margin: auto;">


Profile-based bootstrap and maintenance system for Arch Linux workstations focused on ML/AI development and security hardening.

For a more entertaining introduction, see [FUNREADME.md](FUNREADME.md) – where security meets humor.

## Prerequisites

- **Arch Linux** (primary target)
- **Internet access** for downloads
- **sudo privileges** for system operations
- **yq** or **jq** for YAML/JSON processing (auto-installed if missing)

## Safety Note

The security-dev profile includes security hardening and scans. Review [Safety & Requirements](docs/SECURITY.md) before choosing profiles.

## Quick Start

```bash
# Clone the repository
git clone <repository-url>
cd arch-machine

# Make scripts executable
chmod +x install.sh migrate.sh

# Install using ml-dev profile (recommended)
./install.sh --profile ml-dev

# Or for security-focused setup
./install.sh --profile security-dev

# Post-installation setup
maintenance/systemd-setup.sh setup
```

## Installation Profiles

### `minimal`
Basic development tools (git, python, node, rust) and essential system packages.

### `ml-dev` (Recommended)
Everything in `minimal` plus ROCm GPU acceleration, ML/AI environments, and data science packages.

Pre-configured Conda environments:
- **ai_amd**: AI/ML environment with PyTorch, ROCm GPU support, JupyterLab, and essential data science packages (numpy, pandas, scikit-learn, xgboost, etc.)
- **xai_exp**: Experimental AI environment with similar packages optimized for latest Python versions

### `security-dev`
Everything in `minimal` plus Kubernetes security hardening, runtime monitoring, and encrypted storage.

See [Installation Guide](docs/INSTALLATION.md) for detailed profile information and customization options.

## Adapting for Other Distributions

#### Ubuntu/Debian
```bash
# Replace pacman with apt
sed -i 's/pacman -S/apt install/g' modules/system/install.sh

# Update package names
# arch-package → debian-package equivalents
# Example: reflector → apt update
```

#### Fedora/RHEL/CentOS
```bash
# Replace pacman with dnf/yum
sed -i 's/pacman -S/dnf install/g' modules/system/install.sh

# Update service management
# systemctl → systemctl (same, but check init system)
```

#### General Adaptation Steps
1. **Update Package Manager**: Replace `pacman` calls with your distro's package manager
2. **Service Management**: Verify systemd compatibility (most modern distros use it)
3. **Package Names**: Update package names to match your distribution
4. **Paths**: Check `/usr/local/bin`, `/etc/systemd/system` availability
5. **Dependencies**: Ensure `yq`, `jq`, `curl`, `git` are available

#### Testing on Other Distros
```bash
# Test package manager detection
./install.sh --validate

# Dry run installation
./install.sh --profile minimal --dry-run

# Check for missing packages
grep "pacman -S" modules/system/install.sh
```

## Maintenance

The system includes automated weekly maintenance for system updates, security scans, and health monitoring.

- **Automated**: Runs weekly via systemd timers
- **Manual**: Individual maintenance scripts in `maintenance/`
- **Evidence Extraction**: Generates AI-optimized evidence bundles from logs

See [Maintenance Guide](docs/MAINTENANCE.md) for complete maintenance documentation.

## Interactive TUI (New in 2026 Sentinel)

Launch the beautiful gum-powered vigilant control center:

```bash
tinfoil tui          # after system install (or go run bin/tinfoil.go tui in dev)
./install.sh --tui   # during setup
```

Flows include:
- 🔍 Full security audit (live vulns, SBOM, Lynis...)
- 🧹 Policy-guided remediation (ruthless audit → kill, with multiple confirms)
- 📦 Profile installer with live yq-powered module toggles + dry-run
- 📜 Evidence extraction, maintenance, log browser (fzf)
- Humorous self-aware tone: "The Sentinel sees your choices, citizen"

Zero extra deps beyond what's already in the fortress. Pure shell + gum.

## Key Features

- **Modular Installation**: Choose from different profiles
- **Automated Maintenance**: Weekly system updates and security scans
- **Backup & Recovery**: Configuration backups with rollback
- **Log Evidence Extraction**: Token-efficient AI agent integration
- **Migration Support**: Seamless transition from existing setups

## Project Structure

```
arch-machine/
├── config/                 # Tool definitions and profiles
├── modules/                # Installation modules
├── maintenance/            # Maintenance and automation
├── lib/                    # Shared libraries
├── systemd/                # Systemd units
├── logs/                   # Log files and reports
└── docs/                   # Detailed documentation
```

## Documentation

- [Safety & Requirements](docs/SECURITY.md) - Important safety information and system requirements
- [Installation Guide](docs/INSTALLATION.md) - Detailed setup and profiles
- [Maintenance Guide](docs/MAINTENANCE.md) - System maintenance and automation
- [Evidence Extraction](docs/EVIDENCE.md) - AI-optimized log processing (legacy content in EVIDENCE-EXTRACTION.md during transition)
- [Backup Guide](docs/BACKUP.md) - Backup and recovery procedures
- [Troubleshooting](docs/TROUBLESHOOTING.md) - Common issues and solutions
- [Development](docs/DEVELOPMENT.md) - Contributing and development guide
- [Author's Motto](AUTHORS-MOTTO.md) - Project philosophy and design decisions

## Verification

After installation, verify your setup:

```bash
# Run comprehensive validation
./install.sh --validate

# Check maintenance status
maintenance/systemd-setup.sh status

# View recent logs
tail logs/installer.log
```

## License

See LICENSE file for details.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

Please ensure all changes include appropriate logging and error handling.