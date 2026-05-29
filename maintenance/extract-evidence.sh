#!/usr/bin/env bash
# Evidence extraction runner for maintenance logs
# Generates AI-optimized evidence bundles from maintenance outputs

set -euo pipefail

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../" && pwd)"
LIB_DIR="$ROOT_DIR/lib"

# Smart logs directory (same logic as security-audit.sh)
get_logs_dir() {
    if [[ "$ROOT_DIR" == "/usr/share/tinfoil" || "$ROOT_DIR" == /usr/share/tinfoil* ]]; then
        local data_home="${XDG_DATA_HOME:-$HOME/.local/share}"
        echo "$data_home/tinfoil/logs"
    else
        echo "$ROOT_DIR/logs"
    fi
}

LOGS_DIR="$(get_logs_dir)"
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
# If tinfoil told us a specific target project, prefer writing evidence there.
if [[ -n "${TINFOIL_TARGET_DIR:-}" && -d "$TINFOIL_TARGET_DIR" ]]; then
    OUTPUT_DIR="$TINFOIL_TARGET_DIR/.tinfoil/logs"
else
    OUTPUT_DIR="$LOGS_DIR"
fi
DRY_RUN="${DRY_RUN:-false}"

# Find latest files for evidence extraction
find_latest_files() {
    local search_dirs=("$LOGS_DIR")

    # When extracting for a specific project, also look inside its .tinfoil/logs
    if [[ -n "${TINFOIL_TARGET_DIR:-}" && -d "$TINFOIL_TARGET_DIR" ]]; then
        local proj_logs="$TINFOIL_TARGET_DIR/.tinfoil/logs"
        if [[ -d "$proj_logs" ]]; then
            search_dirs+=("$proj_logs")
        fi
        # Also check for security reports written directly in the project root (from per-project audits)
        if [[ -d "$TINFOIL_TARGET_DIR" ]]; then
            search_dirs+=("$TINFOIL_TARGET_DIR")
        fi
    fi

    # Find latest security report (prefer project-specific if available)
    local security_report=""
    for d in "${search_dirs[@]}"; do
        if [[ -d "$d/security-reports" ]]; then
            local candidate
            candidate=$(find "$d/security-reports" -name "security-audit-*.txt" -type f -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -1 | cut -d' ' -f2- || echo "")
            if [[ -n "$candidate" ]]; then
                security_report="$candidate"
                break
            fi
        fi
        # Also check for reports written directly next to the project (new per-project behavior)
        local direct_report
        direct_report=$(find "$d" -maxdepth 1 -name "security-audit-*.txt" -type f -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -1 | cut -d' ' -f2- || echo "")
        if [[ -n "$direct_report" ]]; then
            security_report="$direct_report"
            break
        fi
    done

    # Use current installer.log (prefer project if present)
    local installer_log=""
    for d in "${search_dirs[@]}"; do
        if [[ -f "$d/installer.log" ]]; then
            installer_log="$d/installer.log"
            break
        fi
    done
    if [[ -z "$installer_log" ]]; then
        installer_log="$LOGS_DIR/installer.log"
    fi

    # Find latest update check JSON
    local update_json=""
    for d in "${search_dirs[@]}"; do
        local candidate
        candidate=$(find "$d" -name "update-check-*.json" -type f -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -1 | cut -d' ' -f2- || echo "")
        if [[ -n "$candidate" ]]; then
            update_json="$candidate"
            break
        fi
    done

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

        # Always try to produce a .toon (AI-optimized) version.
        # Preferred: the `toon` binary if present (very compact).
        # Fallback: just note that the JSON is already the primary artifact.
        local toon_file="${output_file%.json}.toon"
        if command_exists toon; then
            if toon "$output_file" -e -o "$toon_file" 2>/dev/null; then
                log_info "TOON version created: $toon_file (ultra-compact for LLMs)"
            else
                log_warn "toon binary failed to convert; JSON is still excellent for agents"
            fi
        else
            log_info "Evidence JSON ready: $output_file"
            log_info "(Install 'toon' for optional ultra-compact .toon sidecar)"
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