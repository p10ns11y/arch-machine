#!/usr/bin/env bash
# Evidence extraction library for AI-optimized log processing
# Extracts high-signal insights from maintenance logs

# Load dependencies
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/logger.sh" ]]; then
    source "$SCRIPT_DIR/logger.sh"
else
    echo "ERROR: Logger library not found"
    exit 1
fi

# Extract evidence from security audit reports
# Usage: extract_security_evidence <report_file>
extract_security_evidence() {
    local report_file="$1"
    local evidence="{}"

    if [[ ! -f "$report_file" ]]; then
        echo '{"error": "security report file not found"}'
        return 1
    fi

    # Extract key metrics using grep and construct JSON
    local status="unknown"
    local success="false"
    local critical_issues=0
    local warnings=0
    local suggestions=0
    local total_accounts=0
    local unlocked_accounts=0
    local locked_accounts=0
    local blockers="[]"

    # Parse status and success
    if grep -q "Status:.*completed" "$report_file"; then
        status="completed"
    elif grep -q "Status:.*partial" "$report_file"; then
        status="partial"
    elif grep -q "Status:.*skipped" "$report_file"; then
        status="skipped"
    fi

    if grep -q "Success: true" "$report_file"; then
        success="true"
    fi

    # Extract numeric metrics
    critical_issues=$(grep -o "Critical: [0-9]*" "$report_file" | grep -o "[0-9]*$" | head -1 || echo "0")
    warnings=$(grep -o "Warnings: [0-9]*" "$report_file" | grep -o "[0-9]*$" | head -1 || echo "0")
    suggestions=$(grep -o "Suggestions: [0-9]*" "$report_file" | grep -o "[0-9]*$" | head -1 || echo "0")
    total_accounts=$(grep -o "Total accounts: [0-9]*" "$report_file" | grep -o "[0-9]*$" | head -1 || echo "0")
    unlocked_accounts=$(grep -o "Unlocked: [0-9]*" "$report_file" | grep -o "[0-9]*$" | head -1 || echo "0")
    locked_accounts=$(grep -o "Locked: [0-9]*" "$report_file" | grep -o "[0-9]*$" | head -1 || echo "0")

    # Build blockers array
    local blocker_list=""
    if grep -q "sudo.*required\|sudo.*authentication" "$report_file"; then
        blocker_list="$blocker_list\"sudo_required\","
    fi
    if grep -q "authentication.*not available" "$report_file"; then
        blocker_list="$blocker_list\"auth_failures\","
    fi
    if grep -q "not available.*profile" "$report_file"; then
        blocker_list="$blocker_list\"tools_missing\","
    fi
    if [[ -n "$blocker_list" ]]; then
        blockers="[${blocker_list%,}]"
    fi

    # Construct JSON output
    cat << EOF
{
  "status": "$status",
  "success": $success,
  "critical_issues": $critical_issues,
  "warnings": $warnings,
  "suggestions": $suggestions,
  "user_accounts": {
    "total": $total_accounts,
    "unlocked": $unlocked_accounts,
    "locked": $locked_accounts
  },
  "blockers": $blockers
}
EOF
}

# Extract evidence from installer logs
# Usage: extract_installer_evidence <log_file> [max_entries]
extract_installer_evidence() {
    local log_file="$1"
    local max_entries="${2:-50}"

    if [[ ! -f "$log_file" ]]; then
        echo '{"error": "installer log file not found"}'
        return 1
    fi

    # Extract ERROR and WARN entries with timestamps
    # Format: [timestamp] [level] message
    local error_entries=""
    local warning_entries=""

    # Process errors
    while IFS= read -r line; do
        if [[ "$line" =~ ^\[([^\]]+)\]\ \[ERROR\]\ (.+)$ ]]; then
            local timestamp="${BASH_REMATCH[1]}"
            local message="${BASH_REMATCH[2]}"
            # Escape quotes in message
            message=$(echo "$message" | sed 's/"/\\"/g')
            error_entries="$error_entries{\"timestamp\":\"$timestamp\",\"message\":\"$message\",\"category\":\"error\"},"
        fi
    done < <(grep '^\[.*\] \[ERROR\]' "$log_file" | tail -"$max_entries")

    # Process warnings
    while IFS= read -r line; do
        if [[ "$line" =~ ^\[([^\]]+)\]\ \[WARN\]\ (.+)$ ]]; then
            local timestamp="${BASH_REMATCH[1]}"
            local message="${BASH_REMATCH[2]}"
            # Escape quotes in message
            message=$(echo "$message" | sed 's/"/\\"/g')
            warning_entries="$warning_entries{\"timestamp\":\"$timestamp\",\"message\":\"$message\",\"category\":\"warning\"},"
        fi
    done < <(grep '^\[.*\] \[WARN\]' "$log_file" | tail -"$max_entries")

    # Remove trailing commas and construct JSON
    if [[ -n "$error_entries" ]]; then
        error_entries="[${error_entries%,}]"
    else
        error_entries="[]"
    fi

    if [[ -n "$warning_entries" ]]; then
        warning_entries="[${warning_entries%,}]"
    else
        warning_entries="[]"
    fi

    local total_unique=$(( $(echo "$error_entries" | jq '. | length') + $(echo "$warning_entries" | jq '. | length') ))

    cat << EOF
{
  "errors": $error_entries,
  "warnings": $warning_entries,
  "total_unique": $total_unique,
  "max_entries": $max_entries
}
EOF
}

# Extract evidence from update check JSON files
# Usage: extract_update_evidence <json_file>
extract_update_evidence() {
    local json_file="$1"

    if [[ ! -f "$json_file" ]]; then
        echo '{"error": "update check file not found"}'
        return 1
    fi

    # Use jq to extract and structure the update evidence
    jq '{
      timestamp: .timestamp,
      system_packages: (.system_packages | length),
      tool_updates: (.tool_updates | keys | length),
      security_updates: (.security_updates | length),
      summary: .summary
    }' "$json_file" 2>/dev/null || echo '{"error": "failed to parse update check JSON"}'
}

# Create evidence bundle combining all sources
# Usage: create_evidence_bundle <output_file> [security_report] [installer_log] [update_json]
create_evidence_bundle() {
    local output_file="$1"
    local security_report="$2"
    local installer_log="$3"
    local update_json="$4"

    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local hostname
    hostname=$(hostname)

    local security_evidence="{}"
    local installer_evidence="{}"
    local update_evidence="{}"

    # Extract evidence from each source
    if [[ -n "$security_report" ]]; then
        security_evidence=$(extract_security_evidence "$security_report")
    fi

    if [[ -n "$installer_log" ]]; then
        installer_evidence=$(extract_installer_evidence "$installer_log")
    fi

    if [[ -n "$update_json" ]]; then
        update_evidence=$(extract_update_evidence "$update_json")
    fi

    # Calculate summary metrics
    local critical_issues
    critical_issues=$(echo "$security_evidence" | jq '.critical_issues // 0')
    local errors_count
    errors_count=$(echo "$installer_evidence" | jq '.errors | length')
    local warnings_count
    warnings_count=$(echo "$installer_evidence" | jq '.warnings | length')
    local blockers
    blockers=$(echo "$security_evidence" | jq '.blockers // []')

    # Create evidence bundle
    cat << EOF > "$output_file"
{
  "timestamp": "$timestamp",
  "hostname": "$hostname",
  "evidence": {
    "security": $security_evidence,
    "installer": $installer_evidence,
    "updates": $update_evidence
  },
  "summary": {
    "critical_issues": $critical_issues,
    "errors_count": $errors_count,
    "warnings_count": $warnings_count,
    "total_issues": $((critical_issues + errors_count + warnings_count)),
    "blockers": $blockers
  }
}
EOF

    log_success "Evidence bundle created: $output_file"
}