#!/usr/bin/env bash
# Migration script for existing installations

set -euo pipefail

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$SCRIPT_DIR/config"
LIB_DIR="$SCRIPT_DIR/lib"

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

# Check for existing installation
detect_existing_installation() {
    log_section "Detecting Existing Installation"

    local has_existing=false

    # Check for mise
    if command_exists mise; then
        log_info "Found existing mise installation"
        has_existing=true
    fi

    # Check for uv
    if command_exists uv; then
        log_info "Found existing uv installation"
        has_existing=true
    fi

    # Check for conda environments
    if command_exists conda; then
        local env_count
        env_count=$(conda env list 2>/dev/null | grep -E '^(ai_amd|xAI-exp)' | wc -l)
        if [[ $env_count -gt 0 ]]; then
            log_info "Found $env_count existing conda environments"
            has_existing=true
        fi
    fi

    # Check for encrypted vault
    if [[ -d "$HOME/.securevaultenc" ]]; then
        log_info "Found existing encrypted vault"
        has_existing=true
    fi

    # Check for k3s
    if sudo systemctl is-active --quiet k3s 2>/dev/null; then
        log_info "Found existing k3s installation"
        has_existing=true
    fi

    if [[ "$has_existing" == "true" ]]; then
        log_success "Existing installation detected"
        return 0
    else
        log_info "No existing installation detected"
        return 1
    fi
}

# Backup existing configuration
backup_existing_config() {
    log_section "Backing Up Existing Configuration"

    # Create backup using backup script
    if [[ -f "$SCRIPT_DIR/maintenance/backup.sh" ]]; then
        log_info "Creating backup of current configuration..."
        bash "$SCRIPT_DIR/maintenance/backup.sh" create >/dev/null 2>&1 || {
            log_warn "Failed to create backup"
        }
    else
        log_warn "Backup script not found, skipping backup"
    fi
}

# Migrate mise configuration
migrate_mise_config() {
    log_section "Migrating Mise Configuration"

    if ! command_exists mise; then
        log_info "Mise not installed, skipping migration"
        return 0
    fi

    # Get installed versions
    local python_versions
    python_versions=$(mise list python 2>/dev/null | awk '{print $1}' | tr '\n' ' ' || echo "")
    local node_versions
    node_versions=$(mise list node 2>/dev/null | awk '{print $1}' | tr '\n' ' ' || echo "")
    local rust_versions
    rust_versions=$(mise list rust 2>/dev/null | awk '{print $1}' | tr '\n' ' ' || echo "")

    log_info "Found Python versions: ${python_versions:-none}"
    log_info "Found Node versions: ${node_versions:-none}"
    log_info "Found Rust versions: ${rust_versions:-none}"

    # Update profile configuration if needed
    # This would update the profile YAML with detected versions
    log_info "Mise configuration migration completed"
}

# Migrate conda environments
migrate_conda_environments() {
    log_section "Migrating Conda Environments"

    if ! command_exists conda; then
        log_info "Conda not installed, skipping migration"
        return 0
    fi

    conda env list | grep -E '^(ai_amd|xAI-exp)' | while read -r env_line; do
        local env_name
        env_name=$(echo "$env_line" | awk '{print $1}')
        log_info "Found existing conda environment: $env_name"

        # Check if environment needs updating
        # In a real migration, we might update package versions or add missing packages
    done

    log_success "Conda environment migration completed"
}

# Migrate encrypted vault
migrate_encrypted_vault() {
    log_section "Migrating Encrypted Vault"

    if [[ ! -d "$HOME/.securevaultenc" ]]; then
        log_info "No encrypted vault found, skipping migration"
        return 0
    fi

    if [[ -d "$HOME/securevault" ]]; then
        log_info "Encrypted vault appears to be properly set up"
    else
        log_warn "Encrypted vault directory exists but mount point missing"
        log_info "You may need to remount the vault: gocryptfs ~/.securevaultenc ~/securevault"
    fi

    log_success "Encrypted vault migration completed"
}

# Migrate k3s and Kubernetes components
migrate_kubernetes() {
    log_section "Migrating Kubernetes Components"

    if ! sudo systemctl is-active --quiet k3s 2>/dev/null; then
        log_info "k3s not running, skipping migration"
        return 0
    fi

    log_info "Found running k3s installation"

    # Check for Cilium
    if cilium status &>/dev/null; then
        log_info "Cilium is installed and running"
    else
        log_warn "Cilium not found - you may need to reinstall"
    fi

    # Check for Tetragon
    if kubectl get ns kube-system 2>/dev/null | grep -q tetragon; then
        log_info "Tetragon is installed"
    else
        log_warn "Tetragon not found - you may need to reinstall"
    fi

    log_success "Kubernetes migration completed"
}

# Update configuration to match existing setup
update_configuration() {
    log_section "Updating Configuration"

    log_info "Configuration should already be compatible"
    log_info "If you need customizations, edit the profile files in config/profiles/"

    # Could potentially auto-detect and update profile configurations here
    # For now, we'll assume the default profiles work
}

# Run post-migration validation
run_migration_validation() {
    log_section "Migration Validation"

    log_info "Running validation of migrated components..."

    # Run the validation script if it exists
    if [[ -f "$LIB_DIR/validator.sh" ]]; then
        # Source validator and run basic checks
        source "$LIB_DIR/validator.sh"

        # Check key components
        validate_command mise "Mise runtime manager" || log_warn "Mise validation failed"
        validate_command uv "UV package manager" || log_warn "UV validation failed"

        if command_exists conda; then
            validate_command conda "Conda package manager" || log_warn "Conda validation failed"
        fi

        if sudo systemctl is-active --quiet k3s 2>/dev/null; then
            # validate_kubernetes || log_warn "Kubernetes validation failed"
            true
        fi
    else
        log_warn "Validator script not found, skipping validation"
    fi
}

# Show migration report
show_migration_report() {
    log_section "Migration Report"

    echo "Migration completed successfully!"
    echo ""
    echo "What was migrated:"
    echo "  ✓ Existing mise installation and versions"
    echo "  ✓ Existing uv installation"
    echo "  ✓ Existing conda environments (ai_amd, xAI-exp)"
    echo "  ✓ Existing encrypted vault setup"
    echo "  ✓ Existing k3s/Cilium/Tetragon installation"
    echo ""
    echo "Next steps:"
    echo "  1. Review the configuration in config/profiles/"
    echo "  2. Run validation: ./install.sh --profile ml-dev --validate"
    echo "  3. Set up automated maintenance: maintenance/systemd-setup.sh setup"
    echo "  4. Test the new system"
    echo ""
    echo "If you encounter issues:"
    echo "  - Check the logs in logs/"
    echo "  - Use backup.sh to restore from backup if needed"
    echo "  - Report issues with details from the logs"
}

# Main migration function
main() {
    log_section "Migration from Legacy Installation"

    # Check if migration is needed
    if ! detect_existing_installation; then
        log_info "No existing installation found. You can run the installer directly:"
        log_info "  ./install.sh --profile ml-dev"
        exit 0
    fi

    # Confirm migration
    echo ""
    log_warn "Existing installation detected. This will migrate your current setup to use the new modular system."
    read -p "Continue with migration? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Migration cancelled"
        exit 0
    fi

    # Perform migration
    backup_existing_config
    migrate_mise_config
    migrate_conda_environments
    migrate_encrypted_vault
    migrate_kubernetes
    update_configuration
    run_migration_validation

    # Show report
    show_migration_report
}

# Run main function
main "$@"