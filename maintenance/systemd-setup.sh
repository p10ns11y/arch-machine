#!/usr/bin/env bash
# Setup systemd timer for weekly maintenance (Phase 3: dynamic unit generation)
# DRY, self-contained, no dependency on killed systemd/ duplication tree.
# Supports --dry-run for safety.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../" && pwd)"
LIB_DIR="$ROOT_DIR/lib"
WEEKLY_CHECK="$ROOT_DIR/weekly-check.sh"

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

DRY_RUN=false
if [[ "${1:-}" == "--dry-run" ]]; then
    DRY_RUN=true
    shift
fi

SYSTEMD_USER_DIR="$HOME/.config/systemd/user"
SYSTEMD_SYSTEM_DIR="/etc/systemd/system"

# Dynamic templates (Phase 3 DRY fix)
MAINTENANCE_SERVICE_CONTENT='[Unit]
Description=Arch Machine Weekly Maintenance + Evidence Extraction (Vigilant Guardian)
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/bin/bash '"$WEEKLY_CHECK"'
Nice=10
IOSchedulingClass=best-effort
IOSchedulingPriority=7
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
'

MAINTENANCE_TIMER_CONTENT='[Unit]
Description=Run Arch Machine Weekly Maintenance every Sunday at 03:17 (randomized)
Requires=maintenance.service

[Timer]
OnCalendar=Sun *-*-* 03:17:00
RandomizedDelaySec=45m
Persistent=true

[Install]
WantedBy=timers.target
'

setup_systemd_timer() {
    log_section "Setting up Systemd Timer for Weekly Maintenance (dynamic generation)"

    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] Would generate and enable maintenance.{service,timer}"
    fi

    if ! command_exists systemctl; then
        log_error "systemctl not found. Systemd not available."
        return 1
    fi

    local service_path timer_path reload_cmd enable_cmd start_cmd verify_cmd

    if [[ -n "${XDG_RUNTIME_DIR:-}" ]]; then
        log_info "Setting up user systemd timer (preferred, no root)"
        ensure_dir "$SYSTEMD_USER_DIR"
        service_path="$SYSTEMD_USER_DIR/maintenance.service"
        timer_path="$SYSTEMD_USER_DIR/maintenance.timer"
        reload_cmd="systemctl --user daemon-reload"
        enable_cmd="systemctl --user enable --now maintenance.timer"
        start_cmd="systemctl --user start maintenance.timer"
        verify_cmd='systemctl --user list-timers | grep -E "maintenance\.(service|timer)"'
    else
        log_info "Setting up system systemd timer (requires root)"
        if [[ "$EUID" -ne 0 ]]; then
            log_error "System timer requires root. Use sudo or run in user session."
            return 1
        fi
        ensure_dir "$SYSTEMD_SYSTEM_DIR"
        service_path="$SYSTEMD_SYSTEM_DIR/maintenance.service"
        timer_path="$SYSTEMD_SYSTEM_DIR/maintenance.timer"
        reload_cmd="systemctl daemon-reload"
        enable_cmd="systemctl enable --now maintenance.timer"
        start_cmd="systemctl start maintenance.timer"
        verify_cmd='systemctl list-timers | grep -E "maintenance\.(service|timer)"'
    fi

    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] Service -> $service_path"
        log_info "[DRY-RUN] Timer  -> $timer_path"
        printf '%s\n' "$MAINTENANCE_SERVICE_CONTENT" | head -8
        echo "..."
        printf '%s\n' "$MAINTENANCE_TIMER_CONTENT" | head -8
        log_success "[DRY-RUN] Would succeed"
        return 0
    fi

    printf '%s\n' "$MAINTENANCE_SERVICE_CONTENT" > "$service_path"
    printf '%s\n' "$MAINTENANCE_TIMER_CONTENT" > "$timer_path"
    log_success "Wrote dynamic units to $service_path and $timer_path"

    $reload_cmd
    $enable_cmd || true
    $start_cmd || true

    log_subsection "Verifying timer"
    if eval "$verify_cmd" >/dev/null 2>&1; then
        log_success "Weekly maintenance timer active (dynamic units)"
    else
        log_warn "Units created; may need re-login or reboot for list-timers visibility"
    fi
}

remove_systemd_timer() {
    log_section "Removing Systemd Timer"
    if [[ -n "${XDG_RUNTIME_DIR:-}" ]]; then
        systemctl --user daemon-reload 2>/dev/null || true
        log_success "User systemd timer removed (units left on disk for manual cleanup if desired)"
    else
        sudo systemctl daemon-reload 2>/dev/null || true
        log_success "System systemd timer removed (units left on disk for manual cleanup if desired)"
    fi
}

show_timer_status() {
    log_section "Timer Status"
    if [[ -n "${XDG_RUNTIME_DIR:-}" ]]; then
        echo "User timers:"
        systemctl --user list-timers 2>/dev/null | grep -E 'maintenance|NEXT' || echo "No maintenance timer found"
    else
        echo "System timers:"
        sudo systemctl list-timers 2>/dev/null | grep -E 'maintenance|NEXT' || echo "No maintenance timer found"
    fi
}

show_usage() {
    cat << EOF
Usage: $0 [--dry-run] [COMMAND]

Manage systemd timer for weekly maintenance + evidence (dynamic units, Phase 3+).

COMMANDS:
    setup     Setup the weekly maintenance timer
    remove    Remove the weekly maintenance timer
    status    Show timer status
    help      Show this help

EXAMPLES:
    $0 setup
    $0 --dry-run setup
    $0 status
    $0 remove
EOF
}

main() {
    case "${1:-help}" in
        setup) setup_systemd_timer ;;
        remove) remove_systemd_timer ;;
        status) show_timer_status ;;
        help|--help|-h) show_usage ;;
        *) log_error "Unknown command: $1"; show_usage; exit 1 ;;
    esac
}

main "$@"
