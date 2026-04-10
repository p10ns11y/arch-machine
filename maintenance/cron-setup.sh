#!/usr/bin/env bash
# Setup cron job for weekly maintenance (fallback for systems without systemd)

set -euo pipefail

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../" && pwd)"
LIB_DIR="$ROOT_DIR/lib"

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
MAINTENANCE_SCRIPT="$SCRIPT_DIR/weekly-check.sh"
CRON_SCHEDULE="0 2 * * 1"  # Every Monday at 2 AM
CRON_COMMENT="# Weekly system maintenance"

# Setup cron job
setup_cron_job() {
    log_section "Setting up Cron Job for Weekly Maintenance"

    # Check if cron is available
    if ! command_exists crontab; then
        log_error "crontab not found. Cron not available."
        return 1
    fi

    # Check if maintenance script exists
    if [[ ! -x "$MAINTENANCE_SCRIPT" ]]; then
        log_error "Maintenance script not found or not executable: $MAINTENANCE_SCRIPT"
        return 1
    fi

    log_info "Setting up cron job with schedule: '$CRON_SCHEDULE'"

    # Get current crontab
    local current_crontab
    current_crontab=$(crontab -l 2>/dev/null || echo "")

    # Remove existing maintenance cron job if present
    current_crontab=$(echo "$current_crontab" | grep -v "$CRON_COMMENT" || true)
    current_crontab=$(echo "$current_crontab" | grep -v "$MAINTENANCE_SCRIPT" || true)

    # Add new cron job
    local new_cron_job="$CRON_SCHEDULE $MAINTENANCE_SCRIPT $CRON_COMMENT"
    current_crontab=$(printf '%s\n%s\n' "$current_crontab" "$new_cron_job")

    # Remove empty lines and install new crontab
    current_crontab=$(echo "$current_crontab" | sed '/^[[:space:]]*$/d')

    echo "$current_crontab" | crontab -

    log_success "Cron job installed"
    log_info "Maintenance will run every Monday at 2:00 AM"
}

# Remove cron job
remove_cron_job() {
    log_section "Removing Cron Job"

    # Get current crontab
    local current_crontab
    current_crontab=$(crontab -l 2>/dev/null || echo "")

    # Remove maintenance cron job
    local original_lines
    original_lines=$(echo "$current_crontab" | wc -l)
    current_crontab=$(echo "$current_crontab" | grep -v "$CRON_COMMENT" || true)
    current_crontab=$(echo "$current_crontab" | grep -v "$MAINTENANCE_SCRIPT" || true)

    local new_lines
    new_lines=$(echo "$current_crontab" | wc -l)

    # Install updated crontab
    if [[ $new_lines -gt 0 ]]; then
        echo "$current_crontab" | crontab -
    else
        crontab -r 2>/dev/null || true
    fi

    local removed_lines=$((original_lines - new_lines))
    log_success "Removed $removed_lines cron job(s)"
}

# Show cron status
show_cron_status() {
    log_section "Cron Job Status"

    echo "Current crontab:"
    crontab -l || echo "No crontab entries"

    echo
    echo "Maintenance script: $MAINTENANCE_SCRIPT"
    echo "Schedule: $CRON_SCHEDULE (Every Monday at 2:00 AM)"

    # Check if maintenance job exists
    if crontab -l 2>/dev/null | grep -q "$MAINTENANCE_SCRIPT"; then
        log_success "Maintenance cron job is active"
    else
        log_warn "Maintenance cron job not found"
    fi
}

# Test cron job (run maintenance script now)
test_cron_job() {
    log_section "Testing Maintenance Script"

    if [[ ! -x "$MAINTENANCE_SCRIPT" ]]; then
        log_error "Maintenance script not executable: $MAINTENANCE_SCRIPT"
        return 1
    fi

    log_info "Running maintenance script for testing..."
    bash "$MAINTENANCE_SCRIPT" --dry-run
}

# Show usage
show_usage() {
    cat << EOF
Usage: $0 [COMMAND]

Manage cron job for weekly maintenance (systemd alternative).

COMMANDS:
    setup     Setup the weekly maintenance cron job
    remove    Remove the weekly maintenance cron job
    status    Show cron job status
    test      Test the maintenance script (dry run)
    help      Show this help

EXAMPLES:
    $0 setup    # Setup weekly cron job
    $0 status   # Check cron status
    $0 test     # Test maintenance script
    $0 remove   # Remove cron job

CRON SCHEDULE:
    $CRON_SCHEDULE  # Every Monday at 2:00 AM

EOF
}

# Main function
main() {
    case "${1:-help}" in
        setup)
            setup_cron_job
            ;;
        remove)
            remove_cron_job
            ;;
        status)
            show_cron_status
            ;;
        test)
            test_cron_job
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