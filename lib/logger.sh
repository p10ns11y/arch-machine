#!/usr/bin/env bash
# Logger library for installer and maintenance scripts

LOG_DIR="${LOG_DIR:-logs}"
LOG_FILE="${LOG_FILE:-installer.log}"
LOG_LEVEL="${LOG_LEVEL:-INFO}"

# Ensure log directory exists
mkdir -p "$LOG_DIR"

# Log levels
declare -A LOG_LEVELS=(
    [DEBUG]=0
    [INFO]=1
    [WARN]=2
    [ERROR]=3
)

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get log level number
get_log_level_num() {
    local level="$1"
    case "$level" in
        DEBUG) echo 0 ;;
        INFO) echo 1 ;;
        WARN) echo 2 ;;
        ERROR) echo 3 ;;
        *) echo 1 ;;  # Default to INFO
    esac
}

# Get current timestamp
get_timestamp() {
    date '+%Y-%m-%d %H:%M:%S'
}

# Format log message
format_log() {
    local level="$1"
    local message="$2"
    local timestamp=$(get_timestamp)
    echo "[$timestamp] [$level] $message"
}

# Write to log file
log_to_file() {
    local level="$1"
    local message="$2"
    local log_file="$LOG_DIR/$LOG_FILE"
    format_log "$level" "$message" >> "$log_file"
}

# Display colored output to console
log_to_console() {
    local level="$1"
    local message="$2"
    local color="$NC"

    case "$level" in
        DEBUG) color="$BLUE" ;;
        INFO) color="$GREEN" ;;
        WARN) color="$YELLOW" ;;
        ERROR) color="$RED" ;;
    esac

    if [[ "$(get_log_level_num "$level")" -ge "$(get_log_level_num "$LOG_LEVEL")" ]]; then
        echo -e "${color}$(format_log "$level" "$message")${NC}"
    fi
}

# Main logging function
log() {
    local level="$1"
    local message="$2"

    # Validate log level
    case "$level" in
        DEBUG|INFO|WARN|ERROR) ;;
        *) level="INFO" ;;
    esac

    log_to_file "$level" "$message"
    log_to_console "$level" "$message"
}

# Convenience functions
log_debug() {
    log "DEBUG" "$1"
}

log_info() {
    log "INFO" "$1"
}

log_warn() {
    log "WARN" "$1"
}

log_error() {
    log "ERROR" "$1"
}

# Success logging
log_success() {
    log "INFO" "✅ $1"
}

# Failure logging
log_failure() {
    log "ERROR" "❌ $1"
}

# Section header
log_section() {
    local title="$1"
    local separator="========================================"
    log "INFO" ""
    log "INFO" "$separator"
    log "INFO" "🚀 $title"
    log "INFO" "$separator"
}

# Subsection header
log_subsection() {
    local title="$1"
    log "INFO" ""
    log "INFO" "→ $title"
}

# Progress indicator
log_progress() {
    local current="$1"
    local total="$2"
    local item="$3"
    log "INFO" "[$current/$total] $item"
}

# Check if log file exists and is readable
check_log_file() {
    local log_file="$LOG_DIR/$LOG_FILE"
    if [[ -f "$log_file" ]]; then
        log_debug "Log file exists: $log_file"
        return 0
    else
        log_warn "Log file not found: $log_file"
        return 1
    fi
}

# Rotate log files (keep last 5)
rotate_logs() {
    local log_file="$LOG_DIR/$LOG_FILE"
    if [[ -f "$log_file" ]]; then
        for i in {4..1}; do
            if [[ -f "$log_file.$i" ]]; then
                mv "$log_file.$i" "$log_file.$((i+1))"
            fi
        done
        mv "$log_file" "$log_file.1"
        log_debug "Rotated log files"
    fi
}

# Get log summary for the current session
get_log_summary() {
    local log_file="$LOG_DIR/$LOG_FILE"
    if [[ -f "$log_file" ]]; then
        echo "=== Log Summary ==="
        echo "Total lines: $(wc -l < "$log_file")"
        echo "Errors: $(grep -c "\[ERROR\]" "$log_file")"
        echo "Warnings: $(grep -c "\[WARN\]" "$log_file")"
        echo "Last 10 lines:"
        tail -10 "$log_file"
    else
        echo "No log file found"
    fi
}

# Export functions for use in other scripts
export -f log log_debug log_info log_warn log_error
export -f log_success log_failure log_section log_subsection log_progress
export -f check_log_file rotate_logs get_log_summary