#!/usr/bin/env bash
# Evidence extraction runner for maintenance logs
# Generates AI-optimized evidence bundles from maintenance outputs

set -euo pipefail

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../" && pwd)"
LIB_DIR="$ROOT_DIR/lib"
LOGS_DIR="$ROOT_DIR/logs"
REPORTS_DIR="$LOGS_DIR/reports"

# Load dependencies
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

if [[ -f "$LIB_DIR/evidence.sh" ]]; then
    source "$LIB_DIR/evidence.sh"
else
    echo "ERROR: Evidence library not found: $LIB_DIR/evidence.sh"
    exit 1
fi

# Default values
OUTPUT_DIR="$LOGS_DIR"
DRY_RUN="${DRY_RUN:-false}"

# Find latest files for evidence extraction
find_latest_files() {
    # Find latest security report
    local security_report=""
    if [[ -d "$LOGS_DIR/security-reports" ]]; then
        security_report=$(find "$LOGS_DIR/security-reports" -name "security-audit-*.txt" -type f -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -1 | cut -d' ' -f2- || echo "")
    fi

    # Use current installer.log
    local installer_log="$LOGS_DIR/installer.log"

    # Find latest update check JSON
    local update_json=""
    update_json=$(find "$LOGS_DIR" -name "update-check-*.json" -type f -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -1 | cut -d' ' -f2- || echo "")

    echo "$security_report|$installer_log|$update_json"
}

# Main extraction function
run_evidence_extraction() {
    log_section "Evidence Extraction"

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would extract evidence from maintenance logs"
        return 0
    fi

    # Find latest relevant files
    local files
    files=$(find_latest_files)
    IFS='|' read -r security_report installer_log update_json <<< "$files"

    if [[ -z "$security_report" && -z "$installer_log" && -z "$update_json" ]]; then
        log_warn "No maintenance log files found for evidence extraction"
        return 0
    fi

    log_info "Processing evidence sources:"
    [[ -n "$security_report" ]] && log_info "  Security report: $security_report"
    [[ -n "$installer_log" ]] && log_info "  Installer log: $installer_log"
    [[ -n "$update_json" ]] && log_info "  Update check: $update_json"

    # Generate output filename
    local timestamp
    timestamp=$(date +"%Y%m%d-%H%M%S")
    local output_file="$OUTPUT_DIR/evidence-bundle-$timestamp.json"

    # Create evidence bundle
    if create_evidence_bundle "$output_file" "$security_report" "$installer_log" "$update_json"; then
        log_success "Evidence bundle created successfully"

        # Show summary
        local summary
        summary=$(jq -r '.summary | "Critical: \(.critical_issues), Errors: \(.errors_count), Warnings: \(.warnings_count), Total: \(.total_issues)"' "$output_file" 2>/dev/null || echo "Summary unavailable")
        log_info "Evidence summary: $summary"

        # Optional: Create TOON version if toon is available
        if command_exists toon; then
            local toon_file="${output_file%.json}.toon"
            if toon "$output_file" -e -o "$toon_file" 2>/dev/null; then
                log_info "TOON version created: $toon_file"
            fi
        fi
    else
        log_error "Failed to create evidence bundle"
        return 1
    fi
}

# Show usage information
usage() {
    cat << EOF
Evidence Extraction Runner

Extracts high-signal evidence from maintenance logs for AI agents.

USAGE:
    $0 [OPTIONS]

OPTIONS:
    -o, --output DIR    Output directory for evidence bundles (default: logs/)
    -d, --dry-run       Show what would be done without making changes
    -h, --help          Show this help message

EXAMPLES:
    $0                          # Extract evidence to logs/evidence-bundle-*.json
    $0 -o /tmp/evidence         # Extract to custom directory
    $0 --dry-run                # Preview extraction

OUTPUT:
    evidence-bundle-YYYYMMDD-HHMMSS.json    # Main evidence bundle
    evidence-bundle-YYYYMMDD-HHMMSS.toon    # TOON-compressed version (if toon available)
EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -o|--output)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        -d|--dry-run)
            DRY_RUN="true"
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Ensure output directory exists
mkdir -p "$OUTPUT_DIR"

# Run evidence extraction
run_evidence_extraction