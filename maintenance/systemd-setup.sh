#!/usr/bin/env bash
# Setup systemd timer for weekly maintenance

set -euo pipefail

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../" && pwd)"
SYSTEMD_DIR="$ROOT_DIR/systemd"
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
SERVICE_FILE="$SYSTEMD_DIR/maintenance.service"
TIMER_FILE="$SYSTEMD_DIR/maintenance.timer"
SYSTEMD_USER_DIR="$HOME/.config/systemd/user"

# Setup systemd timer
setup_systemd_timer() {
    log_section "Setting up Systemd Timer for Weekly Maintenance"

    # Check if systemd is available
    if ! command_exists systemctl; then
        log_error "systemctl not found. Systemd not available."
        return 1
    fi

    # Check if we're in a user session or system session
    if [[ -n "${XDG_RUNTIME_DIR:-}" ]]; then
        # User systemd
        log_info "Setting up user systemd timer"

        ensure_dir "$SYSTEMD_USER_DIR"

        # Copy service file
        sed "s|%USER%|$USER|g; s|%h|$HOME|g" "$SERVICE_FILE" > "$SYSTEMD_USER_DIR/maintenance.service"

        # Copy timer file
        cp "$TIMER_FILE" "$SYSTEMD_USER_DIR/maintenance.timer"

        # Enable and start timer
        systemctl --user daemon-reload
        systemctl --user enable maintenance.timer
        systemctl --user start maintenance.timer

        log_success "User systemd timer enabled"
    else
        # System systemd (requires root)
        log_info "Setting up system systemd timer (requires sudo)"

        if [[ "$EUID" -eq 0 ]]; then
            # Running as root
            sed "s|%USER%|$SUDO_USER|g; s|%h|$HOME|g" "$SERVICE_FILE" > "/etc/systemd/system/maintenance.service"
            cp "$TIMER_FILE" "/etc/systemd/system/maintenance.timer"

            systemctl daemon-reload
            systemctl enable maintenance.timer
            systemctl start maintenance.timer

            log_success "System systemd timer enabled"
        else
            log_error "System timer setup requires root privileges"
            log_info "Run with sudo or set up user timer"
            return 1
        fi
    fi

    # Verify timer is active
    log_subsection "Verifying timer setup"
    if [[ -n "${XDG_RUNTIME_DIR:-}" ]]; then
        systemctl --user list-timers | grep maintenance || {
            log_error "Timer not found in user timers"
            return 1
        }
    else
        sudo systemctl list-timers | grep maintenance || {
            log_error "Timer not found in system timers"
            return 1
        }
    fi

    log_success "Weekly maintenance timer is now active"
}

# Remove systemd timer
remove_systemd_timer() {
    log_section "Removing Systemd Timer"

    if [[ -n "${XDG_RUNTIME_DIR:-}" ]]; then
        # User systemd
        systemctl --user stop maintenance.timer 2>/dev/null || true
        systemctl --user disable maintenance.timer 2>/dev/null || true
        rm -f "$SYSTEMD_USER_DIR/maintenance.service" "$SYSTEMD_USER_DIR/maintenance.timer"
        systemctl --user daemon-reload
        log_success "User systemd timer removed"
    else
        # System systemd
        sudo systemctl stop maintenance.timer 2>/dev/null || true
        sudo systemctl disable maintenance.timer 2>/dev/null || true
        sudo rm -f "/etc/systemd/system/maintenance.service" "/etc/systemd/system/maintenance.timer"
        sudo systemctl daemon-reload
        log_success "System systemd timer removed"
    fi
}

# Show timer status
show_timer_status() {
    log_section "Timer Status"

    if [[ -n "${XDG_RUNTIME_DIR:-}" ]]; then
        echo "User timers:"
        systemctl --user list-timers | grep maintenance || echo "No maintenance timer found"
    else
        echo "System timers:"
        sudo systemctl list-timers | grep maintenance || echo "No maintenance timer found"
    fi

    echo
    echo "Next run:"
    if [[ -n "${XDG_RUNTIME_DIR:-}" ]]; then
        systemctl --user list-timers | grep maintenance | awk '{print $7, $8, $9}' || true
    else
        sudo systemctl list-timers | grep maintenance | awk '{print $7, $8, $9}' || true
    fi
}

# Show usage
show_usage() {
    cat << EOF
Usage: $0 [COMMAND]

Manage systemd timer for weekly maintenance.

COMMANDS:
    setup     Setup the weekly maintenance timer
    remove    Remove the weekly maintenance timer
    status    Show timer status
    help      Show this help

EXAMPLES:
    $0 setup    # Setup weekly timer
    $0 status   # Check timer status
    $0 remove   # Remove timer

EOF
}

# Main function
main() {
    case "${1:-help}" in
        setup)
            setup_systemd_timer
            ;;
        remove)
            remove_systemd_timer
            ;;
        status)
            show_timer_status
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