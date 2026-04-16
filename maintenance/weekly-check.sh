#!/usr/bin/env bash
# Weekly maintenance check script

set -euo pipefail

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../" && pwd)"
CONFIG_DIR="$ROOT_DIR/config"
LIB_DIR="$ROOT_DIR/lib"
LOGS_DIR="$ROOT_DIR/logs"
REPORTS_DIR="$LOGS_DIR/reports"

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
NOTIFICATION_ENABLED="${NOTIFICATION_ENABLED:-false}"
REPORT_FILE="$REPORTS_DIR/maintenance-$(date +%Y%m%d-%H%M%S).txt"

# Ensure directories exist
ensure_dir "$REPORTS_DIR"

# Send notification (if enabled)
notify() {
    local message="$1"
    local urgency="${2:-normal}"

    if [[ "$NOTIFICATION_ENABLED" == "true" ]]; then
        if command_exists notify-send; then
            notify-send -u "$urgency" "System Maintenance" "$message"
        fi
    fi
}

# Generate maintenance report
generate_report() {
    local report_file="$1"

    {
        echo "=== System Maintenance Report ==="
        echo "Date: $(date)"
        echo "Hostname: $(hostname)"
        echo "User: $(whoami)"
        echo ""

        echo "=== System Information ==="
        echo "Kernel: $(uname -r)"
        echo "Uptime: $(uptime -p)"
        echo "Load Average: $(uptime | awk -F'load average:' '{print $2}')"
        echo ""

        echo "=== Disk Usage ==="
        df -h | head -1
        df -h | grep -E '^(/|/home)' || true
        echo ""

        echo "=== Memory Usage ==="
        free -h
        echo ""

        echo "=== Package Updates ==="
        if [[ -f /tmp/package_updates.txt ]]; then
            cat /tmp/package_updates.txt
        else
            echo "No package update information available"
        fi
        echo ""

        echo "=== Service Status ==="
        systemctl is-active docker tlp ufw k3s 2>/dev/null || true
        echo ""

        echo "=== Maintenance Actions ==="
        echo "System packages: $( [[ -f /tmp/system_updated ]] && echo "UPDATED" || echo "NO ACTION" )"
        echo "Tool updates: $( [[ -f /tmp/tools_updated ]] && echo "CHECKED" || echo "NO ACTION" )"
        echo "Security scan: $( [[ -f /tmp/security_scanned ]] && echo "COMPLETED" || echo "NO ACTION" )"
        echo ""

        echo "=== Issues Found ==="
        if [[ -f /tmp/maintenance_issues.txt ]]; then
            cat /tmp/maintenance_issues.txt
        else
            echo "No issues detected"
        fi
        echo ""

        echo "=== Recommendations ==="
        if [[ -f /tmp/maintenance_recommendations.txt ]]; then
            cat /tmp/maintenance_recommendations.txt
        else
            echo "No recommendations"
        fi

    } > "$report_file"
}

# Check system packages for updates
check_system_updates() {
    log_section "Checking System Package Updates"

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would check for system updates"
        return 0
    fi

    # Update package databases
    sudo pacman -Sy --quiet || {
        log_error "Failed to update package databases"
        return 1
    }

    # Check for updates
    local updates
    updates=$(pacman -Qu 2>/dev/null | wc -l)

    if [[ $updates -gt 0 ]]; then
        log_info "Found $updates package updates available"
        pacman -Qu > /tmp/package_updates.txt

        echo "Package updates available:" >> /tmp/maintenance_issues.txt
        cat /tmp/package_updates.txt >> /tmp/maintenance_issues.txt
        echo "" >> /tmp/maintenance_issues.txt

        echo "Consider running: sudo pacman -Syu" >> /tmp/maintenance_recommendations.txt
    else
        log_success "System packages are up to date"
        echo "System packages are up to date" > /tmp/package_updates.txt
    fi
}

# Update system packages
update_system_packages() {
    log_section "Updating System Packages"

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would update system packages"
        return 0
    fi

    log_subsection "Updating system packages"
    sudo pacman -Syu --noconfirm --quiet || {
        log_error "Failed to update system packages"
        return 1
    }

    touch /tmp/system_updated
    log_success "System packages updated"
}

# Check tool versions and updates
check_tool_updates() {
    log_section "Checking Tool Updates"

    # Check mise
    if command_exists mise; then
        log_subsection "Checking mise"
        local current_mise
        current_mise=$(mise --version 2>/dev/null || echo "unknown")
        log_info "mise version: $current_mise"

        if [[ "$DRY_RUN" != "true" ]]; then
            mise self-update --yes >/dev/null 2>&1 || log_warn "Failed to update mise"
        fi
    fi

    # Check uv
    if command_exists uv; then
        log_subsection "Checking uv"
        local current_uv
        current_uv=$(uv --version 2>/dev/null || echo "unknown")
        log_info "uv version: $current_uv"

        if [[ "$DRY_RUN" != "true" ]]; then
            uv self-update >/dev/null 2>&1 || log_warn "Failed to update uv"
        fi
    fi

    # Check conda environments
    if command_exists conda; then
        log_subsection "Checking conda environments"
        conda env list | grep -E '^(ai_amd|xAI-exp)' | while read -r env_line; do
            local env_name
            env_name=$(echo "$env_line" | awk '{print $1}')
            log_info "Found conda environment: $env_name"

            if [[ "$DRY_RUN" != "true" ]]; then
                conda update -n "$env_name" --all --yes >/dev/null 2>&1 || log_warn "Failed to update $env_name"
            fi
        done
    fi

    touch /tmp/tools_updated
    log_success "Tool updates checked"
}

# Check disk space
check_disk_space() {
    log_section "Checking Disk Space"

    local threshold=90
    local issues=0

    df -h | grep -E '^(/|/home)' | while read -r line; do
        local mount
        mount=$(echo "$line" | awk '{print $6}')
        local usage
        usage=$(echo "$line" | awk '{print $5}' | sed 's/%//')

        if [[ $usage -gt $threshold ]]; then
            log_warn "High disk usage on $mount: ${usage}%"
            echo "High disk usage on $mount: ${usage}%" >> /tmp/maintenance_issues.txt
            echo "Consider cleaning up old files or expanding storage" >> /tmp/maintenance_recommendations.txt
            ((issues++))
        else
            log_info "Disk usage on $mount: ${usage}% (OK)"
        fi
    done

    if [[ $issues -gt 0 ]]; then
        log_warn "Found $issues disk space issues"
    else
        log_success "Disk space usage is acceptable"
    fi
}

# Check service health
check_services() {
    log_section "Checking Service Health"

    local services=("docker" "tlp" "ufw")
    local issues=0

    for service in "${services[@]}"; do
        if sudo systemctl is-active --quiet "$service" 2>/dev/null; then
            log_info "Service $service is running"
        else
            log_warn "Service $service is not running"
            echo "Service $service is not running" >> /tmp/maintenance_issues.txt
            echo "Consider starting service: sudo systemctl start $service" >> /tmp/maintenance_recommendations.txt
            ((issues++))
        fi
    done

    # Check k3s if installed
    if sudo systemctl is-active --quiet k3s 2>/dev/null; then
        log_info "k3s service is running"
        # Check cluster health
        if command_exists kubectl && kubectl get nodes &>/dev/null; then
            local node_count
            node_count=$(kubectl get nodes --no-headers 2>/dev/null | wc -l)
            log_info "Kubernetes cluster has $node_count nodes"
        fi
    fi

    if [[ $issues -gt 0 ]]; then
        log_warn "Found $issues service issues"
    else
        log_success "All services are healthy"
    fi
}

# Basic security scan
basic_security_scan() {
    log_section "Basic Security Scan"

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would perform security scan"
        return 0
    fi

    touch /tmp/security_scanned

    # Check for listening services
    log_subsection "Checking listening services"
    sudo netstat -tlnp 2>/dev/null | grep LISTEN | head -10 || log_warn "Cannot check listening services"

    # Check for failed login attempts
    log_subsection "Checking recent login failures"
    sudo journalctl -u sshd -n 10 --no-pager 2>/dev/null | grep -i "failed\|invalid" | tail -5 || true

    # Check file permissions on sensitive files
    log_subsection "Checking sensitive file permissions"
    local sensitive_files=("$HOME/.ssh" "$HOME/.gnupg" "/etc/passwd" "/etc/shadow")
    for file in "${sensitive_files[@]}"; do
        if [[ -e "$file" ]]; then
            local perms
            perms=$(stat -c "%a" "$file" 2>/dev/null || echo "unknown")
            log_info "Permissions for $file: $perms"
        fi
    done

    log_success "Basic security scan completed"
}

# Cleanup old files
cleanup_old_files() {
    log_section "Cleaning Up Old Files"

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would clean up old files"
        return 0
    fi

    # Clean package cache
    log_subsection "Cleaning package cache"
    sudo paccache -rk 2 >/dev/null 2>&1 || log_warn "Failed to clean package cache"

    # Clean journal
    log_subsection "Cleaning system journal"
    sudo journalctl --vacuum-time=7d >/dev/null 2>&1 || log_warn "Failed to clean journal"

    log_success "Cleanup completed"
}

# Main maintenance function
main() {
    log_section "Weekly System Maintenance"
    log_info "Started at: $(date)"
    echo

    # Initialize temp files
    : > /tmp/maintenance_issues.txt
    : > /tmp/maintenance_recommendations.txt

    # Perform maintenance checks
    check_system_updates
    check_disk_space
    check_services
    check_tool_updates

    # Perform maintenance actions
    update_system_packages
    basic_security_scan
    cleanup_old_files

    # Generate report
    generate_report "$REPORT_FILE"
    log_success "Maintenance report generated: $REPORT_FILE"

    # Send notification
    local issue_count
    issue_count=$(wc -l < /tmp/maintenance_issues.txt)
    if [[ $issue_count -gt 0 ]]; then
        notify "Maintenance completed with $issue_count issues found. See $REPORT_FILE" "critical"
    else
        notify "Maintenance completed successfully" "normal"
    fi

    # Clean up temp files
    rm -f /tmp/package_updates.txt /tmp/system_updated /tmp/tools_updated /tmp/security_scanned
    rm -f /tmp/maintenance_issues.txt /tmp/maintenance_recommendations.txt

    # Run Vector ETL for AI optimization
    if command_exists vector && command_exists toon && command_exists jq; then
        log_info "Running Vector log ETL for AI optimization"
        if timeout 60 vector --config "$ROOT_DIR/vector.toml" && [[ -f "$ROOT_DIR/logs/parsed.ndjson" ]]; then
            jq -s '.' "$ROOT_DIR/logs/parsed.ndjson" > "$ROOT_DIR/logs/parsed.json" && \
            toon "$ROOT_DIR/logs/parsed.json" -e -o "$ROOT_DIR/logs/parsed.toon" && \
            log_success "Log ETL completed: $ROOT_DIR/logs/parsed.toon"
        fi
    fi

    log_success "Weekly maintenance completed"
    log_info "Finished at: $(date)"
}

# Run main function with all arguments
main "$@"