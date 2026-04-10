#!/usr/bin/env bash
# Backup and rollback system for configuration files

set -euo pipefail

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$SCRIPT_DIR/lib"
BACKUP_DIR="${BACKUP_DIR:-$SCRIPT_DIR/backups/$(date +%Y%m%d-%H%M%S)}"

# Load libraries
if [[ -f "$LIB_DIR/logger.sh" ]]; then
    source "$LIB_DIR/logger.sh"
else
    echo "ERROR: Logger library not found: $LIB_DIR/logger.sh"
    exit 1
fi

if [[ -f "$LIB_DIR/installer.sh" ]]; then
    source "$LIB_DIR/installer.sh"
else
    echo "ERROR: Installer library not found: $LIB_DIR/installer.sh"
    exit 1
fi

# Configuration files to backup
CONFIG_FILES=(
    "$HOME/.bashrc"
    "$HOME/.zshrc"
    "$HOME/.profile"
    "$HOME/.bash_profile"
    "/etc/pacman.conf"
    "/etc/makepkg.conf"
    "$HOME/.config/mise/config.toml"
    "$HOME/.config/uv/uv.toml"
)

# Directories to backup
CONFIG_DIRS=(
    "$HOME/.ssh"
    "$HOME/.gnupg"
)

# Create backup
create_backup() {
    log_section "Creating Configuration Backup"

    ensure_dir "$BACKUP_DIR"

    local backup_count=0

    # Backup files
    for file in "${CONFIG_FILES[@]}"; do
        if [[ -f "$file" ]]; then
            local relative_path="${file#/}"
            relative_path="${relative_path//\//_}"
            local backup_file="$BACKUP_DIR/$relative_path"

            ensure_dir "$(dirname "$backup_file")"
            cp "$file" "$backup_file"
            log_debug "Backed up: $file → $backup_file"
            ((backup_count++))
        fi
    done

    # Backup directories
    for dir in "${CONFIG_DIRS[@]}"; do
        if [[ -d "$dir" ]]; then
            local relative_path="${dir#/}"
            relative_path="${relative_path//\//_}"
            local backup_dir="$BACKUP_DIR/${relative_path}_dir"

            cp -r "$dir" "$backup_dir"
            log_debug "Backed up directory: $dir → $backup_dir"
            ((backup_count++))
        fi
    done

    # Create backup manifest
    {
        echo "Backup created: $(date)"
        echo "Backup directory: $BACKUP_DIR"
        echo "Files backed up: $backup_count"
        echo ""
        echo "Files:"
        find "$BACKUP_DIR" -type f | sort
    } > "$BACKUP_DIR/manifest.txt"

    log_success "Backup created with $backup_count items: $BACKUP_DIR"
    echo "$BACKUP_DIR"
}

# List available backups
list_backups() {
    log_section "Available Backups"

    local backup_base="$SCRIPT_DIR/backups"

    if [[ ! -d "$backup_base" ]]; then
        log_info "No backups found"
        return 0
    fi

    echo "Available backups:"
    echo "=================="

    find "$backup_base" -mindepth 1 -maxdepth 1 -type d | sort -r | while read -r backup; do
        local backup_name
        backup_name=$(basename "$backup")
        local manifest="$backup/manifest.txt"

        if [[ -f "$manifest" ]]; then
            local created
            created=$(head -1 "$manifest" | cut -d: -f2-)
            local item_count
            item_count=$(grep "Files backed up:" "$manifest" | cut -d: -f2- | tr -d ' ')
            echo "  $backup_name ($created, $item_count items)"
        else
            echo "  $backup_name (no manifest)"
        fi
    done
}

# Restore from backup
restore_backup() {
    local backup_name="$1"

    if [[ -z "$backup_name" ]]; then
        log_error "Backup name required"
        log_info "Use '$0 list' to see available backups"
        return 1
    fi

    local backup_path="$SCRIPT_DIR/backups/$backup_name"

    if [[ ! -d "$backup_path" ]]; then
        log_error "Backup not found: $backup_path"
        return 1
    fi

    log_section "Restoring from Backup: $backup_name"

    local manifest="$backup_path/manifest.txt"
    if [[ -f "$manifest" ]]; then
        log_info "Backup details:"
        cat "$manifest"
        echo ""
    fi

    # Confirm restoration
    read -p "This will overwrite current configuration files. Continue? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Restoration cancelled"
        return 0
    fi

    # Create backup of current state before restoration
    log_info "Creating backup of current state..."
    local pre_restore_backup
    pre_restore_backup=$(create_backup)
    log_info "Current state backed up to: $pre_restore_backup"

    # Restore files
    local restored_count=0

    find "$backup_path" -name "manifest.txt" -prune -o -type f -print | while read -r backup_file; do
        # Convert backup path back to original path
        local relative_path="${backup_file#$backup_path/}"
        local original_path

        if [[ "$relative_path" == *_dir_* ]]; then
            # Directory backup
            local dir_name="${relative_path%_dir*}"
            dir_name="${dir_name//_//}"
            original_path="/$dir_name"
        else
            # File backup
            original_path="/${relative_path//_//}"
        fi

        # Restore file
        if [[ -f "$backup_file" ]]; then
            ensure_dir "$(dirname "$original_path")"
            cp "$backup_file" "$original_path"
            log_debug "Restored: $backup_file → $original_path"
            ((restored_count++))
        elif [[ -d "$backup_file" ]]; then
            ensure_dir "$(dirname "$original_path")"
            cp -r "$backup_file" "$original_path"
            log_debug "Restored directory: $backup_file → $original_path"
            ((restored_count++))
        fi
    done

    log_success "Restored $restored_count items from backup"
    log_warn "Please log out and back in for changes to take effect"
}

# Clean old backups
clean_backups() {
    local keep_count="${1:-5}"

    log_section "Cleaning Old Backups"

    local backup_base="$SCRIPT_DIR/backups"

    if [[ ! -d "$backup_base" ]]; then
        log_info "No backups to clean"
        return 0
    fi

    local backup_count
    backup_count=$(find "$backup_base" -mindepth 1 -maxdepth 1 -type d | wc -l)

    if [[ $backup_count -le $keep_count ]]; then
        log_info "Only $backup_count backups exist, keeping all (configured to keep $keep_count)"
        return 0
    fi

    local to_remove=$((backup_count - keep_count))
    log_info "Removing $to_remove old backups (keeping $keep_count most recent)"

    # Remove oldest backups
    find "$backup_base" -mindepth 1 -maxdepth 1 -type d -printf '%T@ %p\n' | \
        sort -n | head -n "$to_remove" | cut -d' ' -f2- | \
        while read -r old_backup; do
            rm -rf "$old_backup"
            log_debug "Removed old backup: $(basename "$old_backup")"
        done

    log_success "Backup cleanup completed"
}

# Show usage
show_usage() {
    cat << EOF
Usage: $0 COMMAND [OPTIONS]

Backup and rollback system for configuration files.

COMMANDS:
    create              Create a new backup
    list                List available backups
    restore BACKUP      Restore from specified backup
    clean [COUNT]       Clean old backups (keep COUNT, default 5)
    help                Show this help

EXAMPLES:
    $0 create           # Create backup
    $0 list             # List backups
    $0 restore 20241201-143022  # Restore specific backup
    $0 clean 3          # Keep only 3 most recent backups

BACKUP LOCATION:
    $SCRIPT_DIR/backups/

EOF
}

# Main function
main() {
    case "${1:-help}" in
        create)
            create_backup
            ;;
        list)
            list_backups
            ;;
        restore)
            [[ $# -lt 2 ]] && { log_error "Backup name required"; show_usage; exit 1; }
            restore_backup "$2"
            ;;
        clean)
            clean_backups "${2:-5}"
            ;;
        help|--help|-h)
            show_usage
            ;;
        *)
            log_error "Unknown command: $1"
            show_usage
            exit 1
            ;;
    esac
}

# Run main function
main "$@"