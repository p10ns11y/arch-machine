#!/usr/bin/env bash
# Security audit script

# TOOL REFERENCE (Host-Level Security Scanners)
# lynis     : Comprehensive auditing & hardening scanner for Linux/Unix systems
#             → Use: Every audit run (dev machine/server/CI baseline)
#             → Solves: Misconfigurations, missing patches, weak permissions, CIS violations
# clamav    : Open-source antivirus engine & malware scanner
#             → Use: Optional deep scan (uncomment) or scheduled cron jobs
#             → Solves: Viruses, trojans, ransomware, known malware in files/directories
# rkhunter  : Rootkit Hunter – scans for known rootkits, backdoors & local exploits
#             → Use: After every security-scan.sh run (adds <30s)
#             → Solves: Hidden malware that replaces binaries, hides processes, or installs backdoors
# chkrootkit: Lightweight rootkit detector using known signature checks
#             → Use: Paired with rkhunter in every audit for cross-verification
#             → Solves: Classic rootkit patterns and system file inconsistencies
# unhide    : Forensic tool to detect hidden processes, TCP/UDP ports and files hidden by rootkits/LKMs
#             → Use: Paired with rkhunter in every audit for cross-verification
#             → Solves: Hidden processes/ports/files that rootkits try to conceal (modern technique detection)

set -euo pipefail

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../" && pwd)"
CONFIG_DIR="$ROOT_DIR/config"
LIB_DIR="$ROOT_DIR/lib"
LOGS_DIR="$ROOT_DIR/logs"
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
    local tools=("lynis" "clamav" "rkhunter" "unhide" "osv-scanner" "grype" "syft" "pip-audit" "cargo-audit")
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

    if ! sudo -n true 2>/dev/null; then
        log_info "Security tool installation skipped - sudo authentication not available"
        log_info "Install security tools manually or run with sudo available"
        return 0
    fi

    local tools_to_install=()

    # Legacy tools
    if ! command_exists lynis; then
        tools_to_install+=("lynis")
    fi

    if ! command_exists clamscan; then
        tools_to_install+=("clamav")
    fi

    if ! command_exists rkhunter; then
        tools_to_install+=("rkhunter")
    fi

    if ! command_exists unhide; then
        tools_to_install+=("unhide")
    fi

    # New vulnerability scanning tools
    if ! command_exists osv-scanner; then
        log_info "OSV-Scanner not found - install via security-dev profile or manually"
    fi

    if ! command_exists grype; then
        log_info "Grype not found - install via security-dev profile or manually"
    fi

    if ! command_exists syft; then
        log_info "Syft not found - install via security-dev profile or manually"
    fi

    if ! command_exists pip-audit; then
        log_info "pip-audit not found - will attempt to install during audit"
    fi

    if ! command_exists cargo-audit; then
        log_info "cargo-audit not found - will attempt to install during audit"
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

# Run native ecosystem audits (Node.js, Python, Rust)
run_native_ecosystem_audits() {
    log_section "Native Ecosystem Vulnerability Audits"

    # Node.js / npm audit
    if [ -f "package.json" ] || [ -f "package-lock.json" ] || [ -f "yarn.lock" ] || [ -f "pnpm-lock.yaml" ]; then
        log_subsection "Node.js / npm audit"
        if [[ "$DRY_RUN" == "true" ]]; then
            log_info "[DRY RUN] Would run npm audit"
        else
            npm ci --ignore-scripts --no-audit --prefer-offline >/dev/null 2>&1 || true
            npm audit --audit-level=moderate || log_warn "npm audit found vulnerabilities"
        fi
    else
        log_info "No Node.js project detected (skipped)"
    fi

    # Python / pip-audit
    if [ -f "requirements.txt" ] || [ -f "pyproject.toml" ] || [ -f "Pipfile" ] || [ -f "poetry.lock" ]; then
        log_subsection "Python / pip-audit"
        if [[ "$DRY_RUN" == "true" ]]; then
            log_info "[DRY RUN] Would run pip-audit"
        else
            if ! command_exists pip-audit; then
                python3 -m pip install --upgrade pip-audit --quiet || log_warn "Failed to install pip-audit"
            fi
            pip-audit --strict --desc on --vulnerability-db https://osv.dev/vuln || log_warn "pip-audit found vulnerabilities"
        fi
    else
        log_info "No Python project detected (skipped)"
    fi

    # Rust / cargo audit
    if [ -f "Cargo.toml" ] || [ -f "Cargo.lock" ]; then
        log_subsection "Rust / cargo audit"
        if [[ "$DRY_RUN" == "true" ]]; then
            log_info "[DRY RUN] Would run cargo audit"
        else
            rustup component add clippy >/dev/null 2>&1 || true
            if ! command_exists cargo-audit; then
                cargo install cargo-audit --quiet --locked || log_warn "Failed to install cargo-audit"
            fi
            cargo audit --db https://github.com/RustSec/advisory-db.git || log_warn "cargo audit found vulnerabilities"
        fi
    else
        log_info "No Rust project detected (skipped)"
    fi
}

# Run OSV-Scanner universal scan
run_osv_scanner_audit() {
    log_section "OSV-Scanner Universal Vulnerability Scan"

    if ! command_exists osv-scanner; then
        log_warn "OSV-Scanner not available - install via security-dev profile"
        return 0
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would run OSV-Scanner"
        return 0
    fi

    log_subsection "Running OSV-Scanner on project"
    osv-scanner scan --format table . || log_warn "OSV-Scanner found vulnerabilities"
}

# Run Syft SBOM generation and Grype scan
run_sbom_grype_audit() {
    log_section "SBOM Generation and Vulnerability Scan"

    if ! command_exists syft; then
        log_warn "Syft not available - install via security-dev profile"
        return 0
    fi

    if ! command_exists grype; then
        log_warn "Grype not available - install via security-dev profile"
        return 0
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would generate SBOM and scan with Grype"
        return 0
    fi

    local sbom_file="sbom.cdx.json"

    log_subsection "Generating CycloneDX SBOM"
    syft . -o cyclonedx-json > "$sbom_file" || {
        log_error "Failed to generate SBOM"
        return 1
    }
    log_success "SBOM saved to: $sbom_file (ready for version control)"

    log_subsection "Scanning SBOM with Grype"
    grype sbom:"$sbom_file" --fail-on high --only-fixed || log_warn "High/critical vulnerabilities found in SBOM"
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

    if ! sudo -n true 2>/dev/null; then
        log_warn "Lynis audit skipped - sudo authentication not available"
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

    if ! sudo -n true 2>/dev/null; then
        log_warn "ClamAV scan skipped - sudo authentication not available"
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

    if ! sudo -n true 2>/dev/null; then
        log_warn "Rootkit checks skipped - sudo authentication not available"
        return 0
    fi

    local rootkit_found=false

    # unhide
    if command_exists unhide; then
        log_subsection "Running unhide"
        if [[ "$DRY_RUN" == "true" ]]; then
            log_info "[DRY RUN] Would run unhide"
        else
            local unhide_result
            unhide_result=$(sudo unhide 2>/dev/null | grep -E "(Found|HIDDEN|WARNING)" || true)
            if [[ -n "$unhide_result" ]]; then
                log_warn "unhide found potential issues:"
                echo "$unhide_result" | while read -r line; do
                    log_warn "  $line"
                done
            else
                log_success "unhide: No hidden processes found"
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
    timeout 10 ss -tlnp 2>/dev/null | head -10 || log_warn "Cannot check listening services"

    # Check for suspicious services
    local suspicious_ports=("12345" "31337" "6667" "6668" "6669")
    local found_suspicious=()

    for port in "${suspicious_ports[@]}"; do
        if timeout 5 ss -tlnp 2>/dev/null | grep -q ":$port "; then
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

    if ! sudo -n true 2>/dev/null; then
        log_warn "User account check skipped - sudo authentication not available"
        return 0
    fi

    # Check for accounts with empty passwords
    local empty_passwd
    empty_passwd=$(sudo awk -F: '($2 == "") {print $1}' /etc/shadow 2>/dev/null | wc -l 2>/dev/null || echo "0")
    empty_passwd=$(echo "$empty_passwd" | tr -d '[:space:]' | grep -o '^[0-9]*$' || echo "0")
    if [[ "$empty_passwd" -gt 0 ]]; then
        log_error "Found $empty_passwd accounts with empty passwords!"
    fi

    # Check for accounts with UID 0
    local uid_zero
    uid_zero=$(sudo awk -F: '($3 == 0) {print $1}' /etc/passwd 2>/dev/null | grep -v root | wc -l 2>/dev/null || echo "0")
    uid_zero=$(echo "$uid_zero" | tr -d '[:space:]' | grep -o '^[0-9]*$' || echo "0")
    if [[ "$uid_zero" -gt 0 ]]; then
        log_error "Found additional accounts with UID 0!"
    fi

    # Check for unlocked accounts
    local unlocked
    local unlocked_list
    unlocked_list=$(sudo passwd -S -a 2>/dev/null | grep -v "Password locked" | grep -v '^$' || true)
    unlocked=$(echo "$unlocked_list" | grep -c . 2>/dev/null || echo "0")
    unlocked=$(echo "$unlocked" | tr -d '[:space:]' | grep -o '^[0-9]*$' || echo "0")

    log_info "Found $unlocked unlocked user accounts"

    # Debug: show what we got
    # log_info "DEBUG: unlocked_list contains: $(echo "$unlocked_list" | wc -l) lines"

    # Show details about unlocked accounts
    if [[ "$unlocked" -gt 0 ]] && [[ "$unlocked" -le 50 ]]; then
        log_subsection "Unlocked accounts details:"
        echo "$unlocked_list" | while read -r line; do
            local username
            username=$(echo "$line" | awk '{print $1}')
            local status
            status=$(echo "$line" | awk '{print $2}')
            case "$status" in
                "P") log_info "  $username: Password set" ;;
                "NP") log_warn "  $username: No password (insecure!)" ;;
                "L") ;; # Should not happen due to grep -v
                *) log_info "  $username: Status $status" ;;
            esac
        done
    elif [[ "$unlocked" -gt 10 ]]; then
        log_info "  (showing first 10 of $unlocked accounts)"
        echo "$unlocked_list" | head -10 | while read -r line; do
            [[ -z "$line" ]] && continue
            local username
            username=$(echo "$line" | awk '{print $1}')
            local status
            status=$(echo "$line" | awk '{print $2}')
            case "$status" in
                "P") log_info "  $username: Password set" ;;
                "NP") log_warn "  $username: No password (insecure!)" ;;
                "L") ;; # Should not happen due to grep -v
                *) log_info "  $username: Status $status" ;;
            esac
        done
    fi

    # Check for accounts with no password (most concerning)
    local no_password
    no_password=$(echo "$unlocked_list" | grep " NP " | wc -l 2>/dev/null || echo "0")
    no_password=$(echo "$no_password" | tr -d '[:space:]' | grep -o '^[0-9]*$' || echo "0")
    if [[ "$no_password" -gt 0 ]]; then
        log_warn "Found $no_password accounts with NO PASSWORD - these are security risks!"
        log_info "  Run: sudo passwd -S -a | grep ' NP ' to see which accounts"
    fi

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

        echo "=== Artifacts ==="
        echo "• sbom.cdx.json          → CycloneDX SBOM (in project root - commit to version control)"
        echo "• $SECURITY_REPORT       → Detailed security audit report"
        echo ""

    echo "=== Recommendations ==="
    echo "1. Review all warnings and errors in the log"
    echo "2. Address any HIGH/CRITICAL findings from vulnerability scans"
    echo "3. Commit sbom.cdx.json to version control for software composition tracking"
    echo "4. Address any file permission issues"
    echo "5. Keep security tools updated"
    echo "6. Regularly review user accounts and services"
    echo "7. Aim for Lynis Hardening Index ≥ 75"
    echo "8. Consider enabling automatic security updates"
    echo ""

    echo "=== Next Steps ==="
    echo "Run this audit weekly: $0"
    echo "Monitor logs for suspicious activity"
    echo "Keep system and applications updated"
    echo "Review and commit SBOM to version control"

    } > "$SECURITY_REPORT"

    log_success "Security report generated: $SECURITY_REPORT"
}

# Main security audit function
main() {
    log_section "Security Audit"
    log_info "Starting comprehensive security audit..."

    # Install security tools
    install_security_tools

    # Run modern vulnerability scans
    run_native_ecosystem_audits
    run_osv_scanner_audit
    run_sbom_grype_audit

    # Run legacy security checks
    run_lynis_audit
    # run_clamav_scan
    run_rootkit_checks
    # check_file_permissions
    check_running_services
    check_user_accounts

    # Generate report
    generate_security_report

    log_success "Security audit completed"
}

# Run main function
main "$@"