# arch-machine

Modular bootstrap and maintenance system for Arch Linux workstations focused on ML/AI development and security hardening.

## Overview

This repository provides a comprehensive system for setting up and maintaining Arch Linux workstations for:

- **ML/AI Development**: ROCm-accelerated PyTorch, Python tooling, and development environments
- **Security Hardening**: Kubernetes-based local fortress with runtime monitoring
- **Automated Maintenance**: Weekly updates, security audits, and system health monitoring

## Key Features

- **Modular Installation**: Choose from different profiles (minimal, ml-dev, security-dev)
- **Automated Maintenance**: Weekly system updates, security scans, and health checks
- **Backup & Recovery**: Automatic configuration backups with rollback capabilities
- **Comprehensive Logging**: Detailed logs and reports for all operations
- **Migration Support**: Seamless transition from existing installations

## Prerequisites

- **Arch Linux** (primary target)
- **Internet access** for downloads
- **sudo privileges** for system operations
- **yq** or **jq** for YAML/JSON processing (auto-installed if missing)

## Quick Start

### Installation

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

### Post-Installation Setup

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

## Usage

### Maintenance Scripts

Run maintenance tasks individually:

```bash
# Check for updates without installing
maintenance/check-updates.sh

# Apply available updates
maintenance/apply-updates.sh

# Run security audit
maintenance/security-audit.sh

# Setup automated maintenance
maintenance/systemd-setup.sh setup
```

### Automated Maintenance

The system includes automated weekly maintenance that runs every Monday at 2:00 AM:

#### What It Does
- **System Updates**: Pacman package updates and tool updates
- **Security Scans**: Rootkit detection, file permission checks, service validation
- **Health Monitoring**: Disk space, service status, and system health
- **Cleanup**: Package cache cleanup and log rotation
- **Reporting**: Detailed reports with recommendations

#### Maintenance Reports
Reports are saved in `logs/reports/` with information about updates applied, security issues found, system health metrics, and recommended actions.

### Backup and Recovery

The system automatically creates backups before major operations:

```bash
# Create manual backup
maintenance/backup.sh create

# List backups
maintenance/backup.sh list

# Restore specific backup
maintenance/backup.sh restore <backup-name>

# Clean old backups (keep 5 most recent)
maintenance/backup.sh clean 5
```

### Utility Functions

#### Encrypted Vault Setup

Create and manage encrypted storage vaults using gocryptfs:

```bash
# Setup default vault (~/.securevaultenc → ~/securevault)
./install.sh --setup-vault

# Setup custom vault locations
./install.sh --setup-vault ~/.myvault ~/.vault

# Or call the function directly (requires logger)
source lib/logger.sh
source modules/security/install.sh
setup_encrypted_vault ~/.workvault ~/.work
```

The vault setup function accepts two optional arguments:
- `encrypted_dir`: Directory for encrypted data (default: `~/.securevaultenc`)
- `mount_point`: Mount point for decrypted access (default: `~/securevault`)

For detailed usage, security considerations, and troubleshooting, see [`VAULT-GUIDE.md`](VAULT-GUIDE.md).

##### Quick Vault Usage

```bash
# Mount vault (if not auto-mounted)
gocryptfs ~/.securevaultenc ~/securevault

# Use like normal directory
echo "secret data" > ~/securevault/file.txt
cat ~/securevault/file.txt

# Unmount when done
fusermount -u ~/securevault
```

## Project Structure

```
arch-machine/
├── config/
│   ├── tools.yaml              # Tool definitions and versions
│   └── profiles/               # Installation profiles
├── modules/                    # Installation modules
│   ├── system/                 # System packages and services
│   ├── development/            # Development tools (mise, uv, etc.)
│   ├── ml-ai/                  # ML/AI tools and environments
│   └── security/               # Security tools (k3s, Cilium, etc.)
├── maintenance/                # Maintenance and automation
│   ├── weekly-check.sh         # Weekly maintenance script
│   ├── check-updates.sh        # Update checking
│   ├── apply-updates.sh        # Update application
│   ├── security-audit.sh       # Security scanning
│   ├── backup.sh               # Backup and rollback
│   ├── notify.sh               # Notification system
│   ├── systemd-setup.sh        # Systemd timer setup
│   └── cron-setup.sh           # Cron job setup
├── lib/                        # Shared libraries
│   ├── logger.sh               # Logging functions
│   ├── installer.sh            # Installation functions
│   └── validator.sh            # Validation functions
├── systemd/                    # Systemd units
├── logs/                       # Log files and reports
├── install.sh                  # Main installer
├── migrate.sh                  # Migration helper
└── README.md
```

## Configuration

### Profile Customization

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

### Custom Profiles

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

### Tool Configuration

Modify `config/tools.yaml` to change tool versions or add new tools.

The vault setup function accepts two optional arguments:
- `encrypted_dir`: Directory for encrypted data (default: `~/.securevaultenc`)
- `mount_point`: Mount point for decrypted access (default: `~/securevault`)

For detailed usage, security considerations, and troubleshooting, see [`VAULT-GUIDE.md`](VAULT-GUIDE.md).

#### Quick Vault Usage

```bash
# Mount vault (if not auto-mounted)
gocryptfs ~/.securevaultenc ~/securevault

# Use like normal directory
echo "secret data" > ~/securevault/file.txt
cat ~/securevault/file.txt

# Unmount when done
fusermount -u ~/securevault
```

### Standalone Installers

For legacy or specific use cases, standalone installer scripts are available:

```bash
# Basic ML/AI development setup
./basic_setup.sh

# Security hardening setup (legacy)
./secure-fortress-phase0-simple.sh

# Migration from existing setups
./migrate.sh
```

### Maintenance Scripts

Run maintenance tasks individually:

```bash
# Check for updates without installing
maintenance/check-updates.sh

# Apply available updates
maintenance/apply-updates.sh

# Run security audit
maintenance/security-audit.sh

# Setup automated maintenance
maintenance/systemd-setup.sh setup
```

## Project Structure

```
arch-machine/
├── config/
│   ├── tools.yaml              # Tool definitions and versions
│   └── profiles/               # Installation profiles
├── modules/                    # Installation modules
│   ├── system/                 # System packages and services
│   ├── development/            # Development tools (mise, uv, etc.)
│   ├── ml-ai/                  # ML/AI tools and environments
│   └── security/               # Security tools (k3s, Cilium, etc.)
├── maintenance/                # Maintenance and automation
│   ├── weekly-check.sh         # Weekly maintenance script
│   ├── check-updates.sh        # Update checking
│   ├── apply-updates.sh        # Update application
│   ├── security-audit.sh       # Security scanning
│   ├── backup.sh               # Backup and rollback
│   ├── notify.sh               # Notification system
│   ├── systemd-setup.sh        # Systemd timer setup
│   └── cron-setup.sh           # Cron job setup
├── lib/                        # Shared libraries
│   ├── logger.sh               # Logging functions
│   ├── installer.sh            # Installation functions
│   └── validator.sh            # Validation functions
├── systemd/                    # Systemd units
├── logs/                       # Log files and reports
├── install.sh                  # Main installer
├── migrate.sh                  # Migration helper
└── README.md
```

## Maintenance System

The system includes automated weekly maintenance that runs every Monday at 2:00 AM:

### What It Does
- **System Updates**: Pacman package updates and tool updates
- **Security Scans**: Rootkit detection, file permission checks, service validation
- **Health Monitoring**: Disk space, service status, and system health
- **Cleanup**: Package cache cleanup and log rotation
- **Reporting**: Detailed reports with recommendations

### Maintenance Reports
Reports are saved in `logs/reports/` with information about:
- Updates applied
- Security issues found
- System health metrics
- Recommended actions

### Manual Maintenance
```bash
# Check for updates without installing
maintenance/check-updates.sh

# Apply available updates
maintenance/apply-updates.sh

# Run security audit
maintenance/security-audit.sh

# Create backup
maintenance/backup.sh create

# List available backups
maintenance/backup.sh list

# Restore from backup
maintenance/backup.sh restore 20241201-143022
```

## Backup and Recovery

The system automatically creates backups before major operations:

```bash
# Create manual backup
maintenance/backup.sh create

# List backups
maintenance/backup.sh list

# Restore specific backup
maintenance/backup.sh restore <backup-name>

# Clean old backups (keep 5 most recent)
maintenance/backup.sh clean 5
```

## Legacy Scripts

The original standalone scripts are still available for backward compatibility or specific use cases:

- **`basic_setup.sh`**: Comprehensive ML/AI development setup including hardware detection, ROCm/NVIDIA GPU setup, Conda/Mamba environment management, development tools (VS Code, Docker), and system diagnostics.

- **`secure-fortress-phase0-simple.sh`**: Security hardening setup including system updates, base development tools, mise version manager, Kubernetes (k3s), Cilium networking, Tetragon runtime security monitoring, encrypted vault setup with gocryptfs, and SSH/GPG key management.

These legacy scripts provide one-shot installation but lack the modular, profile-based approach of the new system. They are considered legacy and may be removed in future versions.

## Verification

After installation, verify your setup:

```bash
# Run comprehensive validation
./install.sh --profile <your-profile> --validate

# Check maintenance status
maintenance/systemd-setup.sh status

# View recent logs
tail logs/installer.log
```

## Troubleshooting

### Common Issues

1. **Permission Denied**: Ensure scripts are executable (`chmod +x *.sh`)
2. **Missing Dependencies**: Run `./install.sh` again - it will install missing dependencies
3. **Service Failures**: Check systemctl status and logs
4. **GPU Issues**: Verify ROCm installation with `rocminfo`

### Getting Help

1. Check logs in `logs/` directory
2. Run validation: `./install.sh --validate`
3. Review maintenance reports in `logs/reports/`
4. Use backup system to rollback if needed

## Development

### Adding New Tools
1. Add tool definition to `config/tools.yaml`
2. Create installation module in `modules/`
3. Update profile configurations
4. Test with dry run: `./install.sh --dry-run`

### Testing
```bash
# Dry run installation
./install.sh --profile ml-dev --dry-run

# Test maintenance scripts
maintenance/weekly-check.sh --dry-run
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