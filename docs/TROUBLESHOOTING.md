# Troubleshooting Guide

## Common Issues

### First boot after shutdown fails; second (hard power) works

Eye-comfort / UWSM race: a user oneshot with `Wants=graphical-session.target` plus `Persistent=` timers under Linger can activate the session target before Hyprland. See:

- [REGRESSION-UWSM-SESSION.md](../modules/productivity/eye-comfort/docs/REGRESSION-UWSM-SESSION.md) — symptom, root cause, fix, journal re-verify
- Agent skill: `.agents/skills/session-unit-order/` (also `~/skills/session-unit-order`)

```bash
journalctl -b -1 --no-pager | rg -i 'uwsm|graphical-session|already active|sddm-helper exited'
python3 modules/productivity/eye-comfort/lib/test_timer_mutex.py
```

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

## OS python do not come with package installer such pip/pipx

Recommended way is to use OS package managers to install the python packages.
For development we use non sudo version managers (mise) and 
virtual env managers (uv). In `sudo` mode only OS python can be runnable.
Mise version python need to be configured otherwise to use with `sudo` 
Previlage.

```bash
externally-managed-environment

× This environment is externally managed
╰─> To install Python packages system-wide, try 'pacman -S
    python-xyz', where xyz is the package you are trying to
    install.
    
    If you wish to install a non-Arch-packaged Python package,
    create a virtual environment using 'python -m venv path/to/venv'.
    Then use path/to/venv/bin/python and path/to/venv/bin/pip.
    
    If you wish to install a non-Arch packaged Python application,
    it may be easiest to use 'pipx install xyz', which will manage a
    virtual environment for you. Make sure you have python-pipx
    installed via pacman.

note: If you believe this is a mistake, please contact your Python installation or OS distribution provider. You can override this, at the risk of breaking your Python installation or OS, by passing --break-system-packages.
hint: See PEP 668 for the detailed specification.
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