# Maintenance Guide

## Overview

The system includes automated weekly maintenance that runs every Monday at 2:00 AM:

### What It Does
- **System Updates**: Pacman package updates and tool updates
- **Security Scans**: Rootkit detection, file permission checks, service validation
- **Health Monitoring**: Disk space, service status, and system health
- **Cleanup**: Package cache cleanup and log rotation
- **Reporting**: Detailed reports with recommendations

## Automated Maintenance

### Setup
```bash
# Enable systemd timers
maintenance/systemd-setup.sh setup

# Or use cron jobs
maintenance/cron-setup.sh setup
```

### Status Check
```bash
# Check systemd timer status
maintenance/systemd-setup.sh status

# View recent maintenance logs
tail logs/maintenance.log
```

## Manual Maintenance

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

## Evidence Extraction

Maintenance scripts automatically generate AI-optimized evidence bundles:

- **Format**: JSON bundles with TOON compression
- **Content**: Errors, warnings, blockers, metrics
- **Size**: ~97% reduction vs raw logs
- **Location**: `logs/evidence-bundle-*.json`

### Manual Extraction
```bash
# Extract evidence from latest logs
./maintenance/extract-evidence.sh

# Extract to custom location
./maintenance/extract-evidence.sh -o /path/to/output
```

## Maintenance Reports

Reports are saved in `logs/reports/` with information about:
- Updates applied
- Security issues found
- System health metrics
- Recommended actions

## Backup and Recovery

### Automatic Backups
The system automatically creates backups before major operations.

### Manual Backups
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

## Log Management

### Log Locations
- `logs/installer.log`: Installation logs
- `logs/security-reports/`: Security audit reports
- `logs/evidence-bundle-*.json`: AI evidence bundles
- `logs/reports/`: Maintenance reports

### Log Rotation
Logs are automatically rotated to prevent disk space issues.