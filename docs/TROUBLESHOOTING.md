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

1. **Check Logs**: All operations log to `logs/` directory
2. **Validation**: Run `./install.sh --validate` for system checks
3. **Backup First**: Create backup before troubleshooting
4. **Issue Reports**: Include relevant log snippets and system information

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