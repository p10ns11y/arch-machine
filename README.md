# arch-machine

Modular bootstrap and maintenance system for Arch Linux workstations focused on ML/AI development and security hardening.

## Prerequisites

- **Arch Linux** (primary target)
- **Internet access** for downloads
- **sudo privileges** for system operations
- **yq** or **jq** for YAML/JSON processing (auto-installed if missing)

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

### `security-dev`
Everything in `minimal` plus Kubernetes security hardening, runtime monitoring, and encrypted storage.

See [Installation Guide](INSTALLATION.md) for detailed profile information and customization options.

## Maintenance

The system includes automated weekly maintenance for system updates, security scans, and health monitoring.

- **Automated**: Runs weekly via systemd timers
- **Manual**: Individual maintenance scripts in `maintenance/`
- **Evidence Extraction**: Generates AI-optimized evidence bundles from logs

See [Maintenance Guide](MAINTENANCE.md) for complete maintenance documentation.

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

- [Installation Guide](docs/INSTALLATION.md) - Detailed setup and profiles
- [Maintenance Guide](docs/MAINTENANCE.md) - System maintenance and automation
- [Evidence Extraction](EVIDENCE-EXTRACTION.md) - AI-optimized log processing
- [Backup Guide](docs/BACKUP.md) - Backup and recovery procedures
- [Troubleshooting](docs/TROUBLESHOOTING.md) - Common issues and solutions
- [Development](docs/DEVELOPMENT.md) - Contributing and development guide

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