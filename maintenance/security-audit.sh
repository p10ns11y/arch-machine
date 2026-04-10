#!/usr/bin/env bash
# Security audit script

set -euo pipefail

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$SCRIPT_DIR/config"
LIB_DIR="$SCRIPT_DIR/lib"
LOGS_DIR="$SCRIPT_DIR/logs"
REPORTS_DIR="$LOGS_DIR/security-reports"

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
SECURITY_REPORT="$REPORTS_DIR/security-audit-$(date +%Y%m%d-%H%M%S).txt"
DRY_RUN="${DRY_RUN:-false}"

# Ensure directories exist
ensure_dir "$REPORTS_DIR"

# Check if security tools are available
check_security_tools() {
    local tools=("lynis" "clamav" "rkhunter" "chkrootkit")
    local available_tools=()

    for tool in "${tools[@]}"; do
        if command_exists "$tool"; then
            available_tools+=("$tool")
        fi
    done

    echo "${available_tools[@]}"
}

# Install security tools if not present
install_security_tools() {
    log_section "Installing Security Audit Tools"

    local tools_to_install=()

    if ! command_exists lynis; then
        tools_to_install+=("lynis")
    fi

    if ! command_exists clamscan; then
        tools_to_install+=("clamav")
    fi

    if ! command_exists rkhunter; then
        tools_to_install+=("rkhunter")
    fi

    if ! command_exists chkrootkit; then
        tools_to_install+=("chkrootkit")
    fi

    if [[ ${#tools_to_install[@]} -gt 0 ]]; then
        log_info "Installing security tools: ${tools_to_install[*]}"
        for tool in "${tools_to_install[@]}"; do
            install_package "$tool" || log_warn "Failed to install $tool"
        done
    else
        log_info "All security tools already installed"
    fi
}

# Run Lynis security audit
run_lynis_audit() {
    log_section "Running Lynis Security Audit"

    if ! command_exists lynis; then
        log_warn "Lynis not available, skipping"
        return 0
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would run Lynis audit"
        return 0
    fi

    log_subsection "Executing Lynis system audit"
    local lynis_report="$REPORTS_DIR/lynis-report-$(date +%Y%m%d).txt"

    sudo lynis audit system --quiet --report-file "$lynis_report" || {
        log_warn "Lynis audit completed with warnings"
    }

    if [[ -f "$lynis_report" ]]; then
        log_success "Lynis report saved to: $lynis_report"

        # Extract warnings and suggestions
        local warnings
        warnings=$(grep -c "Warning" "$lynis_report" 2>/dev/null || echo "0")
        local suggestions
        suggestions=$(grep -c "Suggestion" "$lynis_report" 2>/dev/null || echo "0")

        log_info "Lynis found: $warnings warnings, $suggestions suggestions"
    fi
}

# Run ClamAV virus scan
run_clamav_scan() {
    log_section "Running ClamAV Virus Scan"

    if ! command_exists clamscan; then
        log_warn "ClamAV not available, skipping"
        return 0
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would run ClamAV scan"
        return 0
    fi

    # Update virus definitions
    log_subsection "Updating ClamAV virus definitions"
    sudo freshclam --quiet || log_warn "Failed to update virus definitions"

    # Scan common directories
    log_subsection "Scanning system directories"
    local scan_dirs=("/home" "/etc" "/var" "/usr/local")
    local infected_files=()

    for dir in "${scan_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            log_info "Scanning $dir"
            local result
            result=$(sudo clamscan -r --quiet --no-summary "$dir" 2>/dev/null | grep "FOUND" || true)
            if [[ -n "$result" ]]; then
                infected_files+=("$result")
            fi
        fi
    done

    if [[ ${#infected_files[@]} -gt 0 ]]; then
        log_error "Found ${#infected_files[@]} infected files!"
        for infection in "${infected_files[@]}"; do
            log_error "  $infection"
        done
    else
        log_success "No viruses found"
    fi
}

# Run rootkit checks
run_rootkit_checks() {
    log_section "Running Rootkit Detection"

    local rootkit_found=false

    # chkrootkit
    if command_exists chkrootkit; then
        log_subsection "Running chkrootkit"
        if [[ "$DRY_RUN" == "true" ]]; then
            log_info "[DRY RUN] Would run chkrootkit"
        else
            local chkrootkit_result
            chkrootkit_result=$(sudo chkrootkit 2>/dev/null | grep "INFECTED" || true)
            if [[ -n "$chkrootkit_result" ]]; then
                log_error "chkrootkit found infections:"
                echo "$chkrootkit_result" | while read -r line; do
                    log_error "  $line"
                done
                rootkit_found=true
            else
                log_success "chkrootkit: No infections found"
            fi
        fi
    fi

    # rkhunter
    if command_exists rkhunter; then
        log_subsection "Running rkhunter"
        if [[ "$DRY_RUN" == "true" ]]; then
            log_info "[DRY RUN] Would run rkhunter"
        else
            # Update rkhunter
            sudo rkhunter --update >/dev/null 2>&1 || true

            local rkhunter_result
            rkhunter_result=$(sudo rkhunter --check --quiet 2>/dev/null | grep -E "(Warning|Rootkit)" || true)
            if [[ -n "$rkhunter_result" ]]; then
                log_warn "rkhunter found issues:"
                echo "$rkhunter_result" | while read -r line; do
                    log_warn "  $line"
                done
            else
                log_success "rkhunter: No issues found"
            fi
        fi
    fi

    if [[ "$rootkit_found" == "true" ]]; then
        log_error "Rootkit detection found infections!"
    fi
}

# Check file permissions
check_file_permissions() {
    log_section "Checking File Permissions"

    local issues=()

    # Check sensitive files
    local sensitive_files=(
        "/etc/passwd:644"
        "/etc/shadow:600"
        "/etc/ssh/sshd_config:600"
        "$HOME/.ssh/id_rsa:600"
        "$HOME/.ssh/id_ed25519:600"
        "$HOME/.gnupg/secring.gpg:600"
    )

    for file_perm in "${sensitive_files[@]}"; do
        local file="${file_perm%%:*}"
        local expected_perm="${file_perm#*:}"

        if [[ -f "$file" ]]; then
            local actual_perm
            actual_perm=$(stat -c "%a" "$file" 2>/dev/null || echo "unknown")

            if [[ "$actual_perm" != "$expected_perm" ]]; then
                issues+=("$file: expected $expected_perm, got $actual_perm")
            fi
        fi
    done

    # Check for world-writable files
    log_subsection "Checking for world-writable files"
    local world_writable
    world_writable=$(find /home -type f -perm -002 2>/dev/null | wc -l)
    if [[ "$world_writable" -gt 0 ]]; then
        issues+=("Found $world_writable world-writable files in /home")
    fi

    if [[ ${#issues[@]} -gt 0 ]]; then
        log_warn "File permission issues found:"
        for issue in "${issues[@]}"; do
            log_warn "  $issue"
        done
    else
        log_success "File permissions look good"
    fi
}

# Check running services
check_running_services() {
    log_section "Checking Running Services"

    log_subsection "Listing listening services"
    sudo netstat -tlnp 2>/dev/null | grep LISTEN | head -10 || log_warn "Cannot check listening services"

    # Check for suspicious services
    local suspicious_ports=("12345" "31337" "6667" "6668" "6669")
    local found_suspicious=()

    for port in "${suspicious_ports[@]}"; do
        if sudo netstat -tlnp 2>/dev/null | grep -q ":$port "; then
            found_suspicious+=("$port")
        fi
    done

    if [[ ${#found_suspicious[@]} -gt 0 ]]; then
        log_warn "Found services listening on suspicious ports: ${found_suspicious[*]}"
    else
        log_info "No suspicious listening services found"
    fi
}

# Check user accounts
check_user_accounts() {
    log_section "Checking User Accounts"

    # Check for accounts with empty passwords
    local empty_passwd
    empty_passwd=$(sudo awk -F: '($2 == "") {print $1}' /etc/shadow 2>/dev/null | wc -l)
    if [[ "$empty_passwd" -gt 0 ]]; then
        log_error "Found $empty_passwd accounts with empty passwords!"
    fi

    # Check for accounts with UID 0
    local uid_zero
    uid_zero=$(sudo awk -F: '($3 == 0) {print $1}' /etc/passwd 2>/dev/null | grep -v root | wc -l)
    if [[ "$uid_zero" -gt 0 ]]; then
        log_error "Found additional accounts with UID 0!"
    fi

    # Check for unlocked accounts
    local unlocked
    unlocked=$(sudo passwd -S -a 2>/dev/null | grep -v "Password locked" | wc -l)
    log_info "Found $unlocked unlocked user accounts"

    log_success "User account check completed"
}

# Generate security report
generate_security_report() {
    {
        echo "=== Security Audit Report ==="
        echo "Date: $(date)"
        echo "Hostname: $(hostname)"
        echo "User: $(whoami)"
        echo ""

        echo "=== Tools Used ==="
        local tools
        tools=$(check_security_tools)
        for tool in $tools; do
            echo "  $tool"
        done
        echo ""

        echo "=== Findings ==="
        echo "See detailed logs above for specific findings"
        echo ""

        echo "=== Recommendations ==="
        echo "1. Review all warnings and errors in the log"
        echo "2. Address any file permission issues"
        echo "3. Keep security tools updated"
        echo "4. Regularly review user accounts and services"
        echo "5. Consider enabling automatic security updates"
        echo ""

        echo "=== Next Steps ==="
        echo "Run this audit weekly: $0"
        echo "Monitor logs for suspicious activity"
        echo "Keep system and applications updated"

    } > "$SECURITY_REPORT"

    log_success "Security report generated: $SECURITY_REPORT"
}

# Main security audit function
main() {
    log_section "Security Audit"
    log "Starting comprehensive security audit..."

    # Install security tools
    install_security_tools

    # Run security checks
    run_lynis_audit
    run_clamav_scan
    run_rootkit_checks
    check_file_permissions
    check_running_services
    check_user_accounts

    # Generate report
    generate_security_report

    log_success "Security audit completed"
}

# Run main function
main "$@"