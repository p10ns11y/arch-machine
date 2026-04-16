## ⚠️ Safety & Requirements

### System Requirements
- **Operating System**: Arch Linux (primary), other Linux distributions may work with modifications
- **Architecture**: x86_64 (AMD64)
- **RAM**: Minimum 8GB, recommended 16GB+
- **Storage**: 20GB+ free space for installations and logs
- **Network**: Stable internet connection for package downloads

### Safety Measures
**Note: This tool installer may access and investigate installed packages for compatibility checks and security scans (virus scans only in security-dev profile). Other profiles are standard tool installations - don't panic!**

Basic precautions (recommended for any system changes):

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
- Installs development tools, packages, and environments based on selected profile
- Configures basic system settings and user environments
- Sets up automated maintenance (optional)
- Security hardening and virus scans only apply to security-dev profile

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