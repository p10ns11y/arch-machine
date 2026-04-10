#!/usr/bin/env bash
# Check for available updates without installing them

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
UPDATE_CHECK_FILE="$LOGS_DIR/update-check-$(date +%Y%m%d).json"

# Initialize update check results
init_update_results() {
    cat << EOF > "$UPDATE_CHECK_FILE"
{
  "timestamp": "$(date -Iseconds)",
  "hostname": "$(hostname)",
  "system_packages": [],
  "tool_updates": {},
  "security_updates": [],
  "summary": {
    "total_updates": 0,
    "security_updates": 0,
    "critical_updates": 0
  }
}
EOF
}

# Add system package updates
check_system_packages() {
    log_section "Checking System Package Updates"

    # Update package databases
    sudo pacman -Sy --quiet || {
        log_error "Failed to update package databases"
        return 1
    }

    # Get available updates
    local updates
    updates=$(pacman -Qu 2>/dev/null)

    if [[ -n "$updates" ]]; then
        local update_count
        update_count=$(echo "$updates" | wc -l)

        log_info "Found $update_count system package updates"

        # Parse updates and add to JSON
        echo "$updates" | while read -r line; do
            local package
            package=$(echo "$line" | awk '{print $1}')
            local current_version
            current_version=$(echo "$line" | awk '{print $2}')
            local new_version
            new_version=$(echo "$line" | awk '{print $4}')

            # Check if this is a security update (basic heuristic)
            local is_security="false"
            if echo "$line" | grep -qi "security\|vulnerability\|cve"; then
                is_security="true"
            fi

            jq --arg pkg "$package" \
               --arg current "$current_version" \
               --arg new "$new_version" \
               --arg security "$is_security" \
               '.system_packages += [{"package": $pkg, "current_version": $current, "new_version": $new, "is_security": ($security == "true")}]' \
               "$UPDATE_CHECK_FILE" > "${UPDATE_CHECK_FILE}.tmp" && mv "${UPDATE_CHECK_FILE}.tmp" "$UPDATE_CHECK_FILE"
        done

        # Update summary
        jq --arg count "$update_count" \
           '.summary.total_updates += ($count | tonumber)' \
           "$UPDATE_CHECK_FILE" > "${UPDATE_CHECK_FILE}.tmp" && mv "${UPDATE_CHECK_FILE}.tmp" "$UPDATE_CHECK_FILE"

    else
        log_success "System packages are up to date"
    fi
}

# Check tool updates
check_tool_updates() {
    log_section "Checking Tool Updates"

    local tool_updates="{}"

    # Check mise
    if command_exists mise; then
        local current_mise
        current_mise=$(mise --version 2>/dev/null | awk '{print $2}' || echo "unknown")
        log_info "mise current version: $current_mise"

        # Note: mise doesn't have a version check command, but we can check if update is available
        tool_updates=$(echo "$tool_updates" | jq --arg tool "mise" --arg current "$current_mise" '. + {($tool): {"current": $current, "update_available": false}}')
    fi

    # Check uv
    if command_exists uv; then
        local current_uv
        current_uv=$(uv --version 2>/dev/null | awk '{print $2}' || echo "unknown")
        log_info "uv current version: $current_uv"

        tool_updates=$(echo "$tool_updates" | jq --arg tool "uv" --arg current "$current_uv" '. + {($tool): {"current": $current, "update_available": false}}')
    fi

    # Check conda environments
    if command_exists conda; then
        conda env list | grep -E '^(ai_amd|xAI-exp)' | while read -r env_line; do
            local env_name
            env_name=$(echo "$env_line" | awk '{print $1}')
            log_info "Found conda environment: $env_name"

            tool_updates=$(echo "$tool_updates" | jq --arg env "$env_name" '. + {("conda_env_" + $env): {"current": "N/A", "update_available": true}}')
        done
    fi

    # Update the JSON file
    jq --argjson updates "$tool_updates" '.tool_updates = $updates' "$UPDATE_CHECK_FILE" > "${UPDATE_CHECK_FILE}.tmp" && mv "${UPDATE_CHECK_FILE}.tmp" "$UPDATE_CHECK_FILE"
}

# Check for security advisories
check_security_updates() {
    log_section "Checking Security Advisories"

    # This is a basic implementation - in production, you'd integrate with
    # Arch security tracker or other vulnerability databases

    log_info "Checking for Arch Linux security advisories"

    # Try to get security news from Arch Linux RSS (if curl available)
    if command_exists curl; then
        local security_feed="https://security.archlinux.org/tracker/rss"
        local security_items
        security_items=$(curl -s "$security_feed" 2>/dev/null | grep -c "<item>" || echo "0")

        if [[ "$security_items" -gt 0 ]]; then
            log_info "Found $security_items security advisories"

            jq --arg count "$security_items" \
               '.security_updates += [{"source": "arch_security_tracker", "count": ($count | tonumber), "url": "https://security.archlinux.org"}]' \
               "$UPDATE_CHECK_FILE" > "${UPDATE_CHECK_FILE}.tmp" && mv "${UPDATE_CHECK_FILE}.tmp" "$UPDATE_CHECK_FILE"
        fi
    fi
}

# Calculate summary
calculate_summary() {
    log_section "Calculating Update Summary"

    # Count security updates
    local security_count
    security_count=$(jq '.system_packages[] | select(.is_security == true) | .package' "$UPDATE_CHECK_FILE" | wc -l)

    # Update summary
    jq --arg security "$security_count" \
       '.summary.security_updates = ($security | tonumber)' \
       "$UPDATE_CHECK_FILE" > "${UPDATE_CHECK_FILE}.tmp" && mv "${UPDATE_CHECK_FILE}.tmp" "$UPDATE_CHECK_FILE"

    local total_updates
    total_updates=$(jq '.summary.total_updates' "$UPDATE_CHECK_FILE")

    log_info "Update Summary:"
    log_info "  Total updates: $total_updates"
    log_info "  Security updates: $security_count"
}

# Display results
display_results() {
    log_section "Update Check Results"

    echo "=== Available Updates ==="
    echo

    # System packages
    local sys_updates
    sys_updates=$(jq '.system_packages | length' "$UPDATE_CHECK_FILE")
    if [[ "$sys_updates" -gt 0 ]]; then
        echo "System Packages ($sys_updates):"
        jq -r '.system_packages[] | "  \(.package): \(.current_version) → \(.new_version)\(if .is_security then " [SECURITY]" else "" end)"' "$UPDATE_CHECK_FILE"
        echo
    else
        echo "System Packages: Up to date"
        echo
    fi

    # Tool updates
    local tool_count
    tool_count=$(jq '.tool_updates | length' "$UPDATE_CHECK_FILE")
    if [[ "$tool_count" -gt 0 ]]; then
        echo "Tools:"
        jq -r '.tool_updates | to_entries[] | "  \(.key): \(.value.current)"' "$UPDATE_CHECK_FILE"
        echo
    fi

    # Security updates
    local sec_updates
    sec_updates=$(jq '.security_updates | length' "$UPDATE_CHECK_FILE")
    if [[ "$sec_updates" -gt 0 ]]; then
        echo "Security Advisories:"
        jq -r '.security_updates[] | "  \(.source): \(.count) items"' "$UPDATE_CHECK_FILE"
        echo
    fi

    echo "Report saved to: $UPDATE_CHECK_FILE"
}

# Main function
main() {
    log_section "Update Check"
    log "Checking for available updates..."

    # Initialize results file
    init_update_results

    # Perform checks
    check_system_packages
    check_tool_updates
    check_security_updates
    calculate_summary

    # Display results
    display_results

    log_success "Update check completed"
}

# Run main function
main "$@"