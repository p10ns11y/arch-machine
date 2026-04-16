# Backup and Recovery Guide

## Automatic Backups

The system automatically creates backups before major operations:
- Installation of new profiles
- Major system updates
- Configuration changes

## Manual Backup Operations

```bash
# Create a new backup
maintenance/backup.sh create

# List available backups
maintenance/backup.sh list

# Restore from a specific backup
maintenance/backup.sh restore 20260416-153000

# Clean old backups (keep last 5)
maintenance/backup.sh clean 5
```

## Backup Contents

Backups include:
- Configuration files (`config/`)
- Profile settings
- Tool configurations
- System state information

## Recovery Procedures

### Full System Restore
```bash
# List available backups
maintenance/backup.sh list

# Restore to a previous state
maintenance/backup.sh restore <backup-name>

# Verify system state
./install.sh --validate
```

### Configuration Rollback
```bash
# Restore only configuration files
maintenance/backup.sh restore <backup-name> --config-only
```

## Best Practices

- **Regular Backups**: Create backups before major changes
- **Test Restores**: Periodically test backup restoration
- **Offsite Storage**: Consider copying backups to external storage
- **Retention Policy**: Keep multiple backup generations

## Troubleshooting

### Backup Creation Fails
- Check disk space: `df -h`
- Verify permissions: `ls -la maintenance/backup.sh`
- Check logs: `tail logs/maintenance.log`

### Restore Fails
- Ensure backup integrity: `maintenance/backup.sh verify <backup-name>`
- Check system state: `./install.sh --validate`
- Review logs for specific errors