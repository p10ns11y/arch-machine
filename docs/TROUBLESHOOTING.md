# Troubleshooting Guide

## Common Issues

### Permission Denied
```bash
# Make scripts executable
chmod +x install.sh migrate.sh
chmod +x maintenance/*.sh
```

### Missing Dependencies
```bash
# Re-run installation to install missing dependencies
./install.sh --profile <your-profile>
```

### Service Failures
```bash
# Check systemctl status
systemctl status <service-name>

# View service logs
journalctl -u <service-name>
```

### GPU Issues
```bash
# Verify ROCm installation
rocminfo

# Check GPU detection
lspci | grep -i amd
```

### Network Issues
```bash
# Test internet connectivity
ping -c 3 google.com

# Check DNS resolution
nslookup github.com
```

## Installation Issues

### Profile Installation Fails
```bash
# Check system requirements
./install.sh --validate

# View detailed logs
tail -f logs/installer.log

# Try minimal profile first
./install.sh --profile minimal
```

### Tool Installation Fails
```bash
# Check tool logs
tail logs/installer.log | grep -A 10 -B 10 "<tool-name>"

# Manual installation
# Check specific tool documentation
```

## Maintenance Issues

### Automated Maintenance Not Running
```bash
# Check systemd timers
maintenance/systemd-setup.sh status

# Check cron jobs
maintenance/cron-setup.sh status

# Manual run
maintenance/weekly-check.sh
```

### Security Audit Fails
```bash
# Check sudo access
sudo -v

# Run with verbose output
maintenance/security-audit.sh --verbose

# Check tool availability
which lynis clamscan
```

## Recovery Procedures

### Rollback Installation
```bash
# List available backups
maintenance/backup.sh list

# Restore previous state
maintenance/backup.sh restore <backup-name>
```

### Clean Reinstall
```bash
# Remove installed components (careful!)
./install.sh --uninstall

# Fresh installation
./install.sh --profile <your-profile>
```

## Getting Help

### Before Asking for Help
1. **Check the documentation**: README and docs/ contain extensive guidance
2. **Try the basics**: Run validation, check logs, create backups
3. **Test in isolation**: Use `--dry-run` and minimal profiles first
4. **Search existing issues**: Check for similar problems in troubleshooting docs

### When to Seek Help
- **System instability**: If your system becomes unbootable or unstable
- **Data loss**: If backups fail or data becomes inaccessible
- **Security concerns**: If you suspect the installation compromised security
- **Persistent failures**: If basic troubleshooting doesn't resolve issues

### Providing Information
When reporting issues, include:
- **System info**: `uname -a`, distribution version
- **Command run**: Exact command that failed
- **Error output**: Full error messages and logs
- **Environment**: Virtual machine vs bare metal, sudo access
- **Recent changes**: What you modified before the issue

### Community Resources
- **Arch Wiki**: Comprehensive Linux documentation
- **Distribution forums**: Ubuntu forums, Fedora discourse, etc.
- **GitHub Issues**: For project-specific problems
- **Professional support**: For production deployments

## Diagnostic Commands

```bash
# System information
uname -a
lsb_release -a

# Disk space
df -h

# Memory
free -h

# Running processes
ps aux | head -20

# Network
ip addr
ip route
```