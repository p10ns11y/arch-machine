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

## Quick Start

### First-Time Installation

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

## Configuration

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

## Legacy Scripts

The original scripts are still available for backward compatibility:
- `basic_setup.sh`: Basic ML/AI development setup
- `secure-fortress-phase0-simple.sh`: Security hardening setup

These are now considered legacy and may be removed in future versions.

## Requirements

- **Arch Linux** (primary target)
- **Internet access** for downloads
- **sudo privileges** for system operations
- **yq** or **jq** for YAML/JSON processing (auto-installed if missing)

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