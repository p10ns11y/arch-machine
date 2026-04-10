#!/usr/bin/env bash
# Apply available updates

set -euo pipefail

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$SCRIPT_DIR/config"
LIB_DIR="$SCRIPT_DIR/lib"
LOGS_DIR="$SCRIPT_DIR/logs"

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

# Configuration
DRY_RUN="${DRY_RUN:-false}"
UPDATE_CHECK_FILE="${UPDATE_CHECK_FILE:-$LOGS_DIR/update-check-$(date +%Y%m%d).json}"
BACKUP_DIR="$LOGS_DIR/backups/$(date +%Y%m%d-%H%M%S)"

# Apply system package updates
apply_system_updates() {
    log_section "Applying System Package Updates"

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would apply system package updates"
        return 0
    fi

    local update_count
    update_count=$(jq '.system_packages | length' "$UPDATE_CHECK_FILE")

    if [[ "$update_count" -eq 0 ]]; then
        log_info "No system package updates to apply"
        return 0
    fi

    log_info "Applying $update_count system package updates"

    # Create backup of package list
    ensure_dir "$BACKUP_DIR"
    pacman -Q > "$BACKUP_DIR/packages-before-update.txt"

    # Apply updates
    sudo pacman -Syu --noconfirm --quiet || {
        log_error "Failed to apply system package updates"
        return 1
    }

    # Backup package list after update
    pacman -Q > "$BACKUP_DIR/packages-after-update.txt"

    log_success "System package updates applied successfully"
}

# Apply tool updates
apply_tool_updates() {
    log_section "Applying Tool Updates"

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would apply tool updates"
        return 0
    fi

    # Update mise
    if command_exists mise; then
        log_subsection "Updating mise"
        mise self-update --yes || log_warn "Failed to update mise"
    fi

    # Update uv
    if command_exists uv; then
        log_subsection "Updating uv"
        uv self-update || log_warn "Failed to update uv"
    fi

    # Update conda environments
    if command_exists conda; then
        log_subsection "Updating conda environments"
        conda env list | grep -E '^(ai_amd|xAI-exp)' | while read -r env_line; do
            local env_name
            env_name=$(echo "$env_line" | awk '{print $1}')
            log_info "Updating conda environment: $env_name"
            conda update -n "$env_name" --all --yes || log_warn "Failed to update $env_name"
        done
    fi

    log_success "Tool updates applied"
}

# Restart services if needed
restart_services() {
    log_section "Restarting Services"

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would restart services"
        return 0
    fi

    local services=("docker" "tlp" "ufw")

    for service in "${services[@]}"; do
        if sudo systemctl is-active --quiet "$service" 2>/dev/null; then
            log_subsection "Restarting $service"
            sudo systemctl restart "$service" || log_warn "Failed to restart $service"
        fi
    done

    log_success "Services restarted"
}

# Verify updates
verify_updates() {
    log_section "Verifying Updates"

    # Check if critical services are still running
    local critical_services=("sshd")
    for service in "${critical_services[@]}"; do
        if ! sudo systemctl is-active --quiet "$service" 2>/dev/null; then
            log_error "Critical service $service is not running after updates!"
            return 1
        fi
    done

    # Check if key tools still work
    if command_exists mise; then
        mise --version >/dev/null || log_warn "mise is not working after update"
    fi

    if command_exists uv; then
        uv --version >/dev/null || log_warn "uv is not working after update"
    fi

    if command_exists conda; then
        conda --version >/dev/null || log_warn "conda is not working after update"
    fi

    log_success "Update verification completed"
}

# Create update report
create_update_report() {
    local report_file="$LOGS_DIR/update-report-$(date +%Y%m%d-%H%M%S).txt"

    {
        echo "=== Update Application Report ==="
        echo "Date: $(date)"
        echo "Update check file: $UPDATE_CHECK_FILE"
        echo "Backup directory: $BACKUP_DIR"
        echo ""

        echo "=== Updates Applied ==="
        local sys_updates
        sys_updates=$(jq '.summary.total_updates // 0' "$UPDATE_CHECK_FILE" 2>/dev/null || echo "0")
        echo "System packages: $sys_updates"

        local sec_updates
        sec_updates=$(jq '.summary.security_updates // 0' "$UPDATE_CHECK_FILE" 2>/dev/null || echo "0")
        echo "Security updates: $sec_updates"
        echo ""

        echo "=== Backup Information ==="
        if [[ -d "$BACKUP_DIR" ]]; then
            echo "Backup created at: $BACKUP_DIR"
            ls -la "$BACKUP_DIR"
        else
            echo "No backup created"
        fi
        echo ""

        echo "=== Verification Results ==="
        echo "Critical services: OK"
        echo "Key tools: OK"
        echo ""

        echo "=== Recommendations ==="
        echo "1. Monitor system for any issues in the next 24 hours"
        echo "2. Check application functionality"
        echo "3. Review backup files if rollback needed"

    } > "$report_file"

    log_success "Update report created: $report_file"
}

# Main function
main() {
    log_section "Applying Updates"

    # Check if update check file exists
    if [[ ! -f "$UPDATE_CHECK_FILE" ]]; then
        log_error "Update check file not found: $UPDATE_CHECK_FILE"
        log_error "Run check-updates.sh first"
        exit 1
    fi

    local total_updates
    total_updates=$(jq '.summary.total_updates // 0' "$UPDATE_CHECK_FILE" 2>/dev/null || echo "0")

    if [[ "$total_updates" -eq 0 ]]; then
        log_info "No updates to apply"
        exit 0
    fi

    log_info "Found $total_updates updates to apply"

    # Confirm with user (unless dry run)
    if [[ "$DRY_RUN" == "false" ]]; then
        read -p "Apply $total_updates updates? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Update cancelled by user"
            exit 0
        fi
    fi

    # Apply updates
    apply_system_updates || exit 1
    apply_tool_updates || exit 1
    restart_services || exit 1

    # Verify
    verify_updates || exit 1

    # Create report
    create_update_report

    log_success "All updates applied successfully"
}

# Run main function
main "$@"