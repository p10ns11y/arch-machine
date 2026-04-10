#!/usr/bin/env bash
# Notification system for maintenance alerts

set -euo pipefail

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$SCRIPT_DIR/lib"

# Load libraries
if [[ -f "$LIB_DIR/logger.sh" ]]; then
    source "$LIB_DIR/logger.sh"
else
    echo "ERROR: Logger library not found: $LIB_DIR/logger.sh"
    exit 1
fi

# Configuration
NOTIFICATION_METHOD="${NOTIFICATION_METHOD:-desktop}"  # desktop, email, webhook
EMAIL_TO="${EMAIL_TO:-}"
WEBHOOK_URL="${WEBHOOK_URL:-}"

# Send desktop notification
send_desktop_notification() {
    local title="$1"
    local message="$2"
    local urgency="${3:-normal}"

    if command_exists notify-send; then
        notify-send -u "$urgency" "$title" "$message"
        log_debug "Desktop notification sent: $title"
    else
        log_warn "notify-send not available for desktop notifications"
    fi
}

# Send email notification
send_email_notification() {
    local subject="$1"
    local message="$2"

    if [[ -z "$EMAIL_TO" ]]; then
        log_warn "EMAIL_TO not set, skipping email notification"
        return 0
    fi

    if command_exists mail; then
        echo "$message" | mail -s "$subject" "$EMAIL_TO"
        log_debug "Email notification sent to $EMAIL_TO"
    elif command_exists sendmail; then
        {
            echo "To: $EMAIL_TO"
            echo "Subject: $subject"
            echo ""
            echo "$message"
        } | sendmail -t
        log_debug "Email notification sent via sendmail to $EMAIL_TO"
    else
        log_warn "No email command available (mail/sendmail)"
    fi
}

# Send webhook notification
send_webhook_notification() {
    local title="$1"
    local message="$2"
    local status="${3:-info}"

    if [[ -z "$WEBHOOK_URL" ]]; then
        log_warn "WEBHOOK_URL not set, skipping webhook notification"
        return 0
    fi

    if command_exists curl; then
        local payload
        payload=$(cat <<EOF
{
  "title": "$title",
  "message": "$message",
  "status": "$status",
  "timestamp": "$(date -Iseconds)",
  "hostname": "$(hostname)"
}
EOF
        )

        curl -X POST "$WEBHOOK_URL" \
             -H "Content-Type: application/json" \
             -d "$payload" \
             --max-time 10 \
             --silent \
             --show-error || log_warn "Failed to send webhook notification"
    else
        log_warn "curl not available for webhook notifications"
    fi
}

# Main notification function
notify() {
    local title="$1"
    local message="$2"
    local urgency="${3:-normal}"

    case "$NOTIFICATION_METHOD" in
        desktop)
            send_desktop_notification "$title" "$message" "$urgency"
            ;;
        email)
            send_email_notification "$title" "$message"
            ;;
        webhook)
            send_webhook_notification "$title" "$message" "$urgency"
            ;;
        all)
            send_desktop_notification "$title" "$message" "$urgency"
            send_email_notification "$title" "$message"
            send_webhook_notification "$title" "$message" "$urgency"
            ;;
        *)
            log_warn "Unknown notification method: $NOTIFICATION_METHOD"
            ;;
    esac
}

# Convenience functions for different types of notifications
notify_success() {
    local message="$1"
    notify "✅ Maintenance Success" "$message" "normal"
}

notify_warning() {
    local message="$1"
    notify "⚠️  Maintenance Warning" "$message" "normal"
}

notify_error() {
    local message="$1"
    notify "❌ Maintenance Error" "$message" "critical"
}

notify_info() {
    local message="$1"
    notify "ℹ️  Maintenance Info" "$message" "normal"
}

# Test notifications
test_notifications() {
    log_section "Testing Notification System"

    log_info "Testing different notification types..."

    notify_success "This is a test success notification"
    sleep 1

    notify_warning "This is a test warning notification"
    sleep 1

    notify_error "This is a test error notification"
    sleep 1

    notify_info "This is a test info notification"

    log_success "Notification tests completed"
}

# Show notification configuration
show_config() {
    log_section "Notification Configuration"

    echo "Method: $NOTIFICATION_METHOD"
    echo "Email: ${EMAIL_TO:-Not set}"
    echo "Webhook: ${WEBHOOK_URL:-Not set}"
    echo ""

    if [[ "$NOTIFICATION_METHOD" == "desktop" ]] && ! command_exists notify-send; then
        echo "Warning: notify-send not available for desktop notifications"
    fi

    if [[ "$NOTIFICATION_METHOD" == "email" ]] && [[ -z "$EMAIL_TO" ]]; then
        echo "Warning: EMAIL_TO not set for email notifications"
    fi

    if [[ "$NOTIFICATION_METHOD" == "webhook" ]] && [[ -z "$WEBHOOK_URL" ]]; then
        echo "Warning: WEBHOOK_URL not set for webhook notifications"
    fi
}

# Show usage
show_usage() {
    cat << EOF
Usage: $0 [COMMAND]

Notification system for maintenance alerts.

COMMANDS:
    success MESSAGE    Send success notification
    warning MESSAGE    Send warning notification
    error MESSAGE      Send error notification
    info MESSAGE       Send info notification
    test               Test all notification types
    config             Show notification configuration
    help               Show this help

ENVIRONMENT VARIABLES:
    NOTIFICATION_METHOD    Notification method (desktop, email, webhook, all)
    EMAIL_TO              Email address for notifications
    WEBHOOK_URL           Webhook URL for notifications

EXAMPLES:
    $0 success "Maintenance completed successfully"
    $0 error "Critical error occurred"
    NOTIFICATION_METHOD=email EMAIL_TO=user@example.com $0 test

EOF
}

# Main function
main() {
    case "${1:-help}" in
        success)
            [[ $# -lt 2 ]] && { log_error "Message required"; exit 1; }
            notify_success "$2"
            ;;
        warning)
            [[ $# -lt 2 ]] && { log_error "Message required"; exit 1; }
            notify_warning "$2"
            ;;
        error)
            [[ $# -lt 2 ]] && { log_error "Message required"; exit 1; }
            notify_error "$2"
            ;;
        info)
            [[ $# -lt 2 ]] && { log_error "Message required"; exit 1; }
            notify_info "$2"
            ;;
        test)
            test_notifications
            ;;
        config)
            show_config
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

# If called with arguments, run main function
# If sourced, export functions
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
else
    export -f notify notify_success notify_warning notify_error notify_info
fi