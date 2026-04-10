# Encrypted Vault Guide: gocryptfs

This guide explains how the encrypted vault system works in arch-machine, including setup, usage, and security considerations.

## Overview

The encrypted vault uses [gocryptfs](https://github.com/rfjakob/gocryptfs) to provide transparent encryption for sensitive files. It creates two directories:

- **Encrypted storage** (`~/.securevaultenc`): Contains encrypted data
- **Mount point** (`~/securevault`): Decrypted access point for files

Files placed in the mount point are automatically encrypted and stored in the encrypted directory.

## How It Works

### Encryption Flow

```
User writes file → Mount point (~/securevault) → gocryptfs encryption → Encrypted storage (~/.securevaultenc)
```

### Decryption Flow

```
User reads file ← Mount point (~/securevault) ← gocryptfs decryption ← Encrypted storage (~/.securevaultenc)
```

### Technical Details

1. **File-based Encryption**: Each file is encrypted individually with AES-256-GCM
2. **Transparent Operation**: Encryption/decryption happens automatically when files are accessed
3. **FUSE Integration**: Uses Filesystem in Userspace for seamless integration
4. **Password Protection**: Master password protects the encryption keys

## Setup and Usage

### Initial Setup

```bash
# Using the installer (recommended)
./install.sh --setup-vault

# Or with custom locations
./install.sh --setup-vault ~/.myvault ~/.vault

# Direct function call
source lib/logger.sh
source modules/security/install.sh
setup_encrypted_vault ~/.myvault ~/.vault
```

The setup process:
1. Creates encrypted directory (if doesn't exist)
2. Initializes gocryptfs vault with password
3. Creates mount point directory
4. Mounts the vault for immediate use

### Reading Files

Once mounted, reading files works like any normal filesystem:

```bash
# List files in vault
ls ~/securevault/

# Read a file
cat ~/securevault/secret.txt

# Edit a file
nano ~/securevault/document.md

# Copy files to/from vault
cp ~/securevault/important.doc ~/backup/
cp ~/work/secrets.txt ~/securevault/
```

### Writing Files

Writing works transparently:

```bash
# Create new file
echo "sensitive data" > ~/securevault/secrets.txt

# Copy files into vault
cp ~/documents/private.key ~/securevault/

# Use any application
code ~/securevault/project.md
```

## Mounting and Unmounting

### Manual Mounting

If the vault isn't auto-mounted:

```bash
# Mount vault
gocryptfs ~/.securevaultenc ~/securevault

# You'll be prompted for the password
```

### Unmounting

```bash
# Unmount vault
fusermount -u ~/securevault

# Or use umount (less reliable)
umount ~/securevault
```

### Checking Mount Status

```bash
# Check if vault is mounted
mountpoint -q ~/securevault && echo "Vault is mounted" || echo "Vault is not mounted"

# List all FUSE mounts
mount | grep fuse
```

## Security Features

### Encryption Details

- **Algorithm**: AES-256-GCM (Galois/Counter Mode)
- **Key Derivation**: scrypt (configurable strength)
- **File Format**: gocryptfs reverse mode (compatible with other tools)
- **Metadata**: Filename encryption prevents directory browsing

### Password Protection

- Master password required for mounting
- Password is used to derive encryption keys
- No password = no access to files
- Strong password recommended (20+ characters)

### Access Control

- Vault only accessible when mounted
- Mounted vault appears as normal directory
- Standard filesystem permissions apply
- Root access doesn't bypass encryption

## Backup and Recovery

### Backup Strategy

```bash
# Backup encrypted data (recommended)
cp -r ~/.securevaultenc ~/backup/vault-backup/

# NEVER backup the mount point - it's not encrypted
# cp -r ~/securevault ~/backup/  # DON'T DO THIS
```

### Recovery Process

```bash
# Restore encrypted data
cp -r ~/backup/vault-backup ~/.securevaultenc

# Mount the restored vault
gocryptfs ~/.securevaultenc ~/securevault
```

### Emergency Access

If you forget the password:
- **There is no recovery** - encryption is secure
- Only option is to restore from backup (with correct password)
- Consider using a password manager for vault passwords

## Advanced Usage

### Custom Mount Options

```bash
# Mount with specific options
gocryptfs -o allow_other ~/.securevaultenc ~/securevault
```

### Multiple Vaults

```bash
# Work vault
setup_encrypted_vault ~/.work-enc ~/work-vault

# Personal vault
setup_encrypted_vault ~/.personal-enc ~/personal-vault
```

### Integration with Applications

```bash
# Use with password manager
PASSWORD_STORE_DIR=~/securevault/passwords pass init

# Store SSH keys
cp ~/.ssh/id_rsa ~/securevault/ssh-backup/

# Database files
mysqldump mydb > ~/securevault/database.sql
```

## Troubleshooting

### Common Issues

**"fusermount: failed to unmount: Device or resource busy"**
```bash
# Close all files/processes using the vault
lsof ~/securevault/
# Kill processes if necessary
kill -9 <pid>
# Try unmount again
fusermount -u ~/securevault
```

**"gocryptfs: mountpoint is not empty"**
```bash
# Mount point must be empty
rm -rf ~/securevault/*
fusermount -u ~/securevault 2>/dev/null || true
gocryptfs ~/.securevaultenc ~/securevault
```

**Permission Denied**
```bash
# Ensure you own the directories
sudo chown -R $USER:$USER ~/.securevaultenc ~/securevault
```

### Performance Considerations

- FUSE overhead: ~10-20% performance impact
- Memory usage: Minimal additional RAM
- CPU usage: AES encryption/decryption load
- Suitable for most desktop workloads

## Integration with arch-machine

### Profile Configuration

Enable vault in security profile:

```yaml
# config/profiles/security-dev.yaml
customizations:
  security:
    encrypted_storage: true
```

### Automatic Mounting

Future enhancement may include:
- Auto-mount on login (with password prompt)
- Systemd user service for mounting
- PAM integration for seamless access

## Best Practices

### Security
1. Use strong, unique passwords
2. Regularly backup encrypted data (not mount point)
3. Unmount when not in use
4. Don't store password in plaintext
5. Consider plausible deniability needs

### Usage
1. Test backup/restore procedures
2. Document vault locations and passwords securely
3. Use descriptive filenames within vault
4. Keep vault size manageable
5. Consider compression for large files

### Maintenance
1. Monitor disk space usage
2. Update gocryptfs regularly
3. Test mounting periodically
4. Keep multiple backups
5. Document recovery procedures

## Technical Reference

### File Structure
```
~/.securevaultenc/
├── gocryptfs.conf    # Configuration file
├── gocryptfs.diriv   # Directory IV file
└── [encrypted files] # AES-256-GCM encrypted content
```

### Mount Process
1. Verify encrypted directory exists
2. Read configuration files
3. Prompt for password
4. Derive encryption keys via scrypt
5. Mount FUSE filesystem
6. Provide transparent access

### Encryption Details
- **Block size**: 4096 bytes
- **IV generation**: HKDF-SHA256 per file
- **Filename encryption**: EME with AES
- **DirIV**: Unique IV per directory
- **GCM authentication**: Prevents tampering

This vault system provides strong, transparent encryption while maintaining usability for everyday file operations.</content>
<parameter name="filePath">VAULT-GUIDE.md