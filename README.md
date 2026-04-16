# arch-machine

Modular bootstrap and maintenance system for Arch Linux workstations focused on ML/AI development and security hardening.

## Prerequisites

- **Arch Linux** (primary target)
- **Internet access** for downloads
- **sudo privileges** for system operations
- **yq** or **jq** for YAML/JSON processing (auto-installed if missing)

## ⚠️ Safety & Requirements

### System Requirements
- **Operating System**: Arch Linux (primary), other Linux distributions may work with modifications
- **Architecture**: x86_64 (AMD64)
- **RAM**: Minimum 8GB, recommended 16GB+
- **Storage**: 20GB+ free space for installations and logs
- **Network**: Stable internet connection for package downloads

### Safety Measures
**⚠️ IMPORTANT: This project modifies your system extensively. Take these precautions:**

1. **Create Backups**: Backup your system before installation
   ```bash
   # Create system backup
   maintenance/backup.sh create
   ```

2. **Test in Virtual Machine**: Test installations in a VM first

3. **Review Configurations**: Check `config/tools.yaml` and profile settings before installation

4. **Monitor Installation**: Watch logs during installation
   ```bash
   tail -f logs/installer.log
   ```

5. **Have Recovery Options**: Ensure you can restore from backups or reinstall if needed

### What This Project Does
- **Package Installation**: Installs system packages, development tools, and security software
- **System Configuration**: Modifies system settings, services, and configurations
- **User Environment**: Sets up development environments, Python/Node/Rust toolchains
- **Security Hardening**: Configures firewalls, monitoring tools, and security policies
- **Automated Maintenance**: Sets up cron jobs and systemd timers for ongoing maintenance

### Adapting for Other Distributions

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

### Support & Compatibility
- **Primary Support**: Arch Linux
- **Community Support**: Other Arch-based distros (Manjaro, EndeavourOS)
- **Experimental**: Debian/Ubuntu/Fedora with modifications
- **Not Supported**: macOS, Windows (WSL may work with extensive modifications)

See [Author's Motto](/AUTHORS-MOTTO.md) for detailed reasoning behind our distribution focus and adaptation philosophy.

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
- [Author's Motto](/AUTHORS-MOTTO.md) - Project philosophy and design decisions

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