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

# Smart logs directory: use user-writable location when running from installed
# /usr/share/tinfoil (thin sentinel install). Fall back to repo logs/ in dev.
get_logs_dir() {
    if [[ "$ROOT_DIR" == "/usr/share/tinfoil" || "$ROOT_DIR" == /usr/share/tinfoil* ]]; then
        # Installed mode → per-user location (XDG friendly)
        local data_home="${XDG_DATA_HOME:-$HOME/.local/share}"
        echo "$data_home/tinfoil/logs"
    else
        echo "$ROOT_DIR/logs"
    fi
}

LOGS_DIR="$(get_logs_dir)"
REPORTS_DIR="$LOGS_DIR/security-reports"
CONFIG_DIR="$ROOT_DIR/config"
LIB_DIR="$ROOT_DIR/lib"

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
AUDIT_MODE="global"          # "global" | "project" (set via --global / --project from tinfoil)
AUDIT_TARGET=""

# Choose a good place for the detailed text report
choose_report_path() {
    # If the tinfoil CLI told us the target project, prefer writing inside it
    if [[ -n "${TINFOIL_TARGET_DIR:-}" && -d "$TINFOIL_TARGET_DIR" ]]; then
        echo "$TINFOIL_TARGET_DIR/security-audit-$(date +%Y%m%d-%H%M%S).txt"
    elif [[ "$AUDIT_MODE" == "project" && -n "$AUDIT_TARGET" && -d "$AUDIT_TARGET" ]]; then
        local proj
        proj=$(cd "$AUDIT_TARGET" && pwd)
        echo "$proj/security-audit-$(date +%Y%m%d-%H%M%S).txt"
    else
        echo "$REPORTS_DIR/security-audit-$(date +%Y%m%d-%H%M%S).txt"
    fi
}

SECURITY_REPORT="$(choose_report_path)"
DRY_RUN="${DRY_RUN:-false}"

# Parse --global / --project <dir> passed by the tinfoil Go wrapper
parse_audit_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --global)
                AUDIT_MODE="global"
                shift
                ;;
            --project)
                AUDIT_MODE="project"
                if [[ $# -gt 1 && ! "$2" =~ ^-- ]]; then
                    AUDIT_TARGET="$2"
                    shift 2
                else
                    AUDIT_TARGET="."
                    shift
                fi
                ;;
            *)
                shift
                ;;
        esac
    done
}

parse_audit_args "$@"

# Ensure the user/global reports dir exists (project-mode reports go beside the target)
if [[ "$AUDIT_MODE" != "project" ]]; then
    ensure_dir "$REPORTS_DIR"
fi

# Helper functions
check_sudo() {
    timeout 5 sudo -n true 2>/dev/null
}

log_to_report() {
    echo "$1" >> "$SECURITY_REPORT"
}

append_to_report() {
    cat >> "$SECURITY_REPORT" << EOF
$1
EOF
}

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

    # Node.js ecosystem audit — prefer pnpm (user preference), then yarn, then npm
    if [ -f "package.json" ] || [ -f "package-lock.json" ] || [ -f "yarn.lock" ] || [ -f "pnpm-lock.yaml" ]; then
        log_subsection "Node.js ecosystem audit"

        local pm="npm"
        local audit_cmd="npm audit --audit-level=moderate"
        local install_cmd="npm ci --ignore-scripts --no-audit --prefer-offline"

        # Robust detection that works even under sudo (restricted PATH).
        # We prefer paths passed by the `tinfoil` Go binary (via TINFOIL_PNPM etc.),
        # because `tinfoil` runs with the user's full original PATH and can do
        # a reliable `exec.LookPath` / `which`.
        find_pm() {
            local name="$1"
            local env_var="TINFOIL_$(echo "$name" | tr '[:lower:]' '[:upper:]')"

            # 1. Highest priority: path explicitly passed by tinfoil Go wrapper
            local from_tinfoil
            from_tinfoil=$(printenv "$env_var" 2>/dev/null || true)
            if [[ -n "$from_tinfoil" && -x "$from_tinfoil" ]]; then
                echo "$from_tinfoil"
                return 0
            fi

            # 2. Normal lookup in current PATH
            local candidate
            candidate=$(command -v "$name" 2>/dev/null || true)
            if [[ -n "$candidate" && -x "$candidate" ]]; then
                echo "$candidate"
                return 0
            fi

            # 3. Common fallback locations (fnm, corepack, homebrew, etc.)
            for candidate in \
                "$HOME/.local/share/fnm/aliases/default/bin/$name" \
                "$HOME/.fnm/aliases/default/bin/$name" \
                "/usr/local/bin/$name" \
                "/opt/homebrew/bin/$name"
            do
                if [[ -n "$candidate" && -x "$candidate" ]]; then
                    echo "$candidate"
                    return 0
                fi
            done

            # Nothing found
            echo ""
            return 0
        }

        if [ -f "pnpm-lock.yaml" ]; then
            local pnpm_bin
            pnpm_bin=$(find_pm pnpm)
            if [[ -n "$pnpm_bin" ]]; then
                pm="pnpm"
                audit_cmd="$pnpm_bin audit --audit-level moderate"
                install_cmd="$pnpm_bin install --frozen-lockfile --ignore-scripts 2>/dev/null || true"
            else
                log_warn "pnpm-lock.yaml found but pnpm not in PATH (common when running under sudo)"
                log_info "→ Skipping Node.js audit (lockfile present but no package manager available in current environment)"
                return
            fi
        elif [ -f "yarn.lock" ]; then
            local yarn_bin
            yarn_bin=$(find_pm yarn)
            if [[ -n "$yarn_bin" ]]; then
                pm="yarn"
                audit_cmd="$yarn_bin audit --level moderate || true"
                install_cmd="$yarn_bin install --frozen-lockfile --ignore-scripts 2>/dev/null || true"
            fi
        elif [ -z "$(find_pm npm)" ]; then
            log_warn "No supported Node.js package manager found in PATH (pnpm/yarn/npm)"
            return
        fi

        if [[ "$DRY_RUN" == "true" ]]; then
            log_info "[DRY RUN] Would run $pm audit"
        else
            log_info "→ Running $pm audit"
            eval "$install_cmd" >/dev/null 2>&1 || true
            eval "$audit_cmd" || log_warn "$pm audit found vulnerabilities"
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

    # Determine scan root
    local scan_dir="."

    if [[ "$AUDIT_MODE" == "project" && -n "$AUDIT_TARGET" ]]; then
        scan_dir="$AUDIT_TARGET"
        log_subsection "OSV-Scanner (project)"
    else
        log_subsection "OSV-Scanner (system)"
    fi

    # Run with osv-scanner v2+ syntax + modern exclusions + low verbosity.
    # Filter remaining pnpm noise.
    osv-scanner scan source -r "$scan_dir" \
        --experimental-exclude 'node_modules' \
        --experimental-exclude '.pnpm' \
        --experimental-exclude '.git' \
        --verbosity error \
        --format table 2>&1 \
        | grep -v -E "(Neither CPE nor PURL found|plugin transitivedependency/pomxml can be risky)" \
        || log_warn "OSV-Scanner found vulnerabilities or produced warnings"
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
    local syft_target="."

    if [[ "$AUDIT_MODE" == "project" && -n "$AUDIT_TARGET" ]]; then
        syft_target="$AUDIT_TARGET"
    fi

    log_subsection "Generating CycloneDX SBOM"
    # Exclude massive dependency trees by default in project audits
    syft "$syft_target" \
        --exclude '**/node_modules/**' \
        --exclude '**/.git/**' \
        -o cyclonedx-json > "$sbom_file" || {
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
        log_warn "Lynis not available - install with pacman -S lynis"
        log_to_report "=== LYNIS SECURITY AUDIT REPORT ===
Status: Lynis not installed"
        return 0
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would run Lynis audit"
        return 0
    fi

    local lynis_report="$REPORTS_DIR/lynis-report-$(date +%Y%m%d).txt"
    local cmd_success=false
    local warnings=0
    local suggestions=0
    local critical=0

    if check_sudo; then
        log_subsection "Executing full Lynis system audit (with sudo)"
        if timeout 30 sudo lynis audit system --quiet > "$lynis_report" 2>&1; then
            cmd_success=true
        fi
    else
        log_warn "Lynis audit skipped - sudo required for system checks"
        append_to_report "
=== LYNIS SECURITY AUDIT REPORT ===
Status: Skipped - sudo authentication required
Lynis provides comprehensive system hardening and security checks"
        return 0
    fi

    if [[ -f "$lynis_report" ]]; then
        warnings=$(( $(grep -c "Warning" "$lynis_report" 2>/dev/null | tr -d '\n' || echo "0") ))
        suggestions=$(( $(grep -c "Suggestion" "$lynis_report" 2>/dev/null | tr -d '\n' || echo "0") ))
        critical=$(( $(grep -c "Critical" "$lynis_report" 2>/dev/null | tr -d '\n' || echo "0") ))
    fi

    if [[ "$critical" -gt 0 ]]; then
        log_error "🚨 $critical critical issues found!"
    elif [[ "$warnings" -gt 0 ]]; then
        log_warn "⚠️  $warnings warnings, $suggestions suggestions"
    else
        log_info "✅ No critical issues ($suggestions suggestions)"
    fi

    append_to_report "
=== LYNIS SECURITY AUDIT REPORT ===
Report file: $lynis_report
Success: $cmd_success
Warnings: $warnings
Suggestions: $suggestions
Critical: $critical
$(if [[ "$critical" -gt 0 || "$warnings" -gt 0 ]]; then
echo "TOP ISSUES:"
grep -E "(Warning|Suggestion|Critical)" "$lynis_report" | head -5 || echo "None"
fi)
"
}

# Run ClamAV virus scan
run_clamav_scan() {
    log_section "Running ClamAV Virus Scan"

    if ! command_exists clamscan; then
        log_warn "ClamAV not available, install with: pacman -S clamav"
        {
            echo ""
            echo "=== CLAMAV VIRUS SCAN REPORT ==="
            echo "Status: ClamAV not installed"
            echo "Install command: pacman -S clamav"
        } >> "$SECURITY_REPORT"
        return 0
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would run ClamAV scan"
        return 0
    fi

    # Check sudo availability
    if ! timeout 5 sudo -n true 2>/dev/null; then
        log_warn "ClamAV scan skipped - sudo authentication required"
        {
            echo ""
            echo "=== CLAMAV VIRUS SCAN REPORT ==="
            echo "Status: Skipped - sudo authentication required"
            echo "ClamAV can scan the entire system for viruses and malware"
        } >> "$SECURITY_REPORT"
        return 0
    fi

    log_subsection "Checking virus definitions"

    local scan_success=true
    local infected_count=0
    local scanned_files=0

    # Try to update virus definitions
    if timeout 30 sudo freshclam --quiet 2>/dev/null; then
        log_info "✅ Virus definitions updated"
    else
        log_warn "Could not update virus definitions (requires sudo)"
    fi

    # Quick scan of common directories
    log_subsection "Performing virus scan"
    local scan_dirs=("/home" "/etc" "/var" "/usr/local")

    for dir in "${scan_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            local result
            if result=$(timeout 60 sudo clamscan -r --quiet --no-summary "$dir" 2>/dev/null); then
                local dir_infected
                dir_infected=$(echo "$result" | grep -c "FOUND" || echo "0")
                infected_count=$((infected_count + dir_infected))

                local dir_scanned
                dir_scanned=$(echo "$result" | grep "Scanned" | sed 's/.*Scanned //' | sed 's/ files//' || echo "0")
                scanned_files=$((scanned_files + dir_scanned))
            else
                log_warn "Could not scan $dir (insufficient privileges)"
                scan_success=false
            fi
        fi
    done

    # Report results
    if [[ "$infected_count" -gt 0 ]]; then
        log_error "🚨 Found $infected_count infected files!"
    elif [[ "$scan_success" == "true" ]]; then
        log_info "✅ No viruses found ($scanned_files files scanned)"
    else
        log_warn "⚠️  Partial scan completed - some directories require sudo"
    fi

    # Log detailed results to report
    {
        echo ""
        echo "=== CLAMAV VIRUS SCAN REPORT ==="
        echo "Scan successful: $scan_success"
        echo "Files scanned: $scanned_files"
        echo "Infections found: $infected_count"
        echo ""
        if [[ "$infected_count" -gt 0 ]]; then
            echo "INFECTED FILES:"
            for dir in "${scan_dirs[@]}"; do
                if [[ -d "$dir" ]]; then
                    timeout 30 sudo clamscan -r --quiet --no-summary "$dir" 2>/dev/null | grep "FOUND" || echo "None in $dir"
                fi
            done
        fi
        echo ""
        echo "FULL SCAN COMMAND (for complete system scan):"
        echo "sudo clamscan -r / --quiet --no-summary"
    } >> "$SECURITY_REPORT"
}

# Run rootkit checks
run_rootkit_checks() {
    log_section "Running Rootkit Detection"

    local rootkit_found=false
    local tools_available=()

    command_exists unhide && tools_available+=("unhide")
    command_exists rkhunter && tools_available+=("rkhunter")

    if [[ ${#tools_available[@]} -eq 0 ]]; then
        log_info "No rootkit detection tools available"
        append_to_report "
=== ROOTKIT DETECTION REPORT ===
Status: No tools available
Install: pacman -S rkhunter unhide
"
        return 0
    fi

    log_info "Using tools: ${tools_available[*]}"

    # unhide
    if command_exists unhide; then
        if [[ "$DRY_RUN" == "true" ]]; then
            log_info "[DRY RUN] Would run unhide"
        elif check_sudo; then
            local unhide_output
            if unhide_output=$(timeout 15 sudo unhide 2>&1) && echo "$unhide_output" | grep -q -E "(Found|HIDDEN|WARNING)"; then
                local issues
                issues=$(echo "$unhide_output" | grep -c -E "(Found|HIDDEN|WARNING)" || echo "0")
                log_warn "⚠️  Unhide: $issues potential issues"
                rootkit_found=true
            else
                log_info "✅ Unhide: No issues"
            fi
        else
            log_warn "Unhide skipped - sudo required"
        fi
    fi

    # rkhunter
    if command_exists rkhunter; then
        if [[ "$DRY_RUN" == "true" ]]; then
            log_info "[DRY RUN] Would run rkhunter"
        elif check_sudo; then
            timeout 10 sudo rkhunter --update >/dev/null 2>&1 || true
            local rkhunter_output
            if rkhunter_output=$(timeout 30 sudo rkhunter --check --quiet 2>&1) && echo "$rkhunter_output" | grep -q -E "(Warning|Rootkit)"; then
                local issues
                issues=$(echo "$rkhunter_output" | grep -c -E "(Warning|Rootkit)" || echo "0")
                log_warn "⚠️  Rkhunter: $issues issues"
                rootkit_found=true
            else
                log_info "✅ Rkhunter: No issues"
            fi
        else
            log_warn "Rkhunter skipped - sudo required"
        fi
    fi

    if [[ "$rootkit_found" == "true" ]]; then
        log_error "🚨 Rootkit indicators detected!"
    else
        log_info "✅ No rootkit indicators"
    fi

    append_to_report "
=== ROOTKIT DETECTION REPORT ===
Tools: ${tools_available[*]}
Issues found: $rootkit_found
$(if ! check_sudo; then echo "Note: Full checks require sudo"; fi)
"
}

# Fix file permissions
fix_file_permissions() {
    local file="$1"
    local expected_perm="$2"

    # Determine if sudo is needed (system files vs user files)
    if [[ "$file" =~ ^/etc/ ]]; then
        if check_sudo; then
            sudo chmod "$expected_perm" "$file" && log_success "Fixed permissions for $file" || log_error "Failed to fix $file"
        else
            log_warn "Cannot fix $file - sudo required"
        fi
    else
        chmod "$expected_perm" "$file" && log_success "Fixed permissions for $file" || log_error "Failed to fix $file"
    fi
}

# Check file permissions
check_file_permissions() {
    log_section "Checking File Permissions"

    local fixed_count=0
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
                log_warn "Misconfigured: $file (expected $expected_perm, got $actual_perm)"
                echo -n "Fix permissions for $file? (y/n): "
                read -r response
                case "$response" in
                    [Yy]|[Yy][Ee][Ss])
                        fix_file_permissions "$file" "$expected_perm"
                        ((fixed_count++))
                        ;;
                    *)
                        issues+=("$file: expected $expected_perm, got $actual_perm")
                        ;;
                esac
            fi
        fi
    done

    # Check for world-writable files
    log_subsection "Checking for world-writable files"
    local world_writable
    world_writable=$(find /home -type f -perm -002 2>/dev/null | wc -l)
    if [[ "$world_writable" -gt 0 ]]; then
        issues+=("Found $world_writable world-writable files in /home")
        log_warn "Found $world_writable world-writable files in /home (not auto-fixed)"
    fi

    if [[ ${#issues[@]} -gt 0 ]]; then
        log_warn "Remaining permission issues:"
        for issue in "${issues[@]}"; do
            log_warn "  $issue"
        done
    else
        log_success "File permissions are correct"
    fi

    if [[ $fixed_count -gt 0 ]]; then
        log_info "Fixed $fixed_count permission issues"
    fi
}

# Check running services
check_running_services() {
    log_section "Checking Running Services"

    log_subsection "Listing listening services"
    local services_count
    services_count=$(ss -tln 2>/dev/null | grep -c LISTEN 2>/dev/null || echo "0")
    services_count=$(echo "$services_count" | tr -d '[:space:]' | grep -o '^[0-9]*$' || echo "0")

    if [[ "$services_count" -gt 0 ]]; then
        log_info "Found $services_count active listening services"
        # Show a few key services
        ss -tln 2>/dev/null | grep LISTEN | head -5 | awk '{print "  " $4 " (" $1 ")"}' | while read -r line; do
            log_info "$line"
        done
        if [[ "$services_count" -gt 5 ]]; then
            log_info "  ... and $((services_count - 5)) more"
        fi
    else
        log_warn "Cannot check listening services"
    fi

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

    local total_users=0
    local unlocked=0
    local locked=0
    local no_password=0
    local unlocked_list=""
    local locked_list=""

    if check_sudo; then
        # Full audit with sudo
        local passwd_output
        if passwd_output=$(timeout 10 sudo passwd -S -a 2>&1); then
            total_users=$(echo "$passwd_output" | wc -l)
            unlocked_list=$(echo "$passwd_output" | awk '$2 != "L" {print $1}')
            unlocked=$(echo "$unlocked_list" | wc -w)
            locked_list=$(echo "$passwd_output" | awk '$2 == "L" {print $1}')
            locked=$(echo "$locked_list" | wc -w)
            no_password=$(echo "$passwd_output" | awk '$2 == "NP" {print}' | wc -l)

            log_info "Found $unlocked unlocked, $locked locked accounts"

            if [[ "$no_password" -gt 0 ]]; then
                log_warn "⚠️  $no_password accounts have NO PASSWORD set!"
            fi
        else
            log_warn "Failed to get user account details"
        fi
    else
        # Fallback without sudo
        log_warn "Limited user account check - sudo required for full audit"
        local user_list
        user_list=$(getent passwd | cut -d: -f1 | tr '\n' ' ')
        total_users=$(echo "$user_list" | wc -w)
        log_info "System has $total_users total user accounts (lock status unknown without sudo)"
    fi

    # Log to report
    append_to_report "
=== USER ACCOUNTS REPORT ===
Total accounts: $total_users
$(if check_sudo; then
echo "Unlocked: $unlocked
Locked: $locked
No password: $no_password

UNLOCKED ACCOUNTS:
$(echo "$unlocked_list" | sed 's/^/  /')

LOCKED ACCOUNTS:
$(echo "$locked_list" | sed 's/^/  /')"
else
echo "ALL ACCOUNTS (lock status unknown):
$(echo "$user_list" | sed 's/ /\n  /g')

RECOMMENDATION: Run with sudo for lock status and password details"
fi)
"
    log_success "User account check completed"
}


# Lightweight reminder for updating the modern vulnerability scanners.
# The tools themselves already emit "A newer version is available" during runs.
check_for_tool_updates() {
    log_subsection "Security Tool Update Check"

    log_info "Key scanners checked during this run: syft, grype, osv-scanner"

    local syft_path grype_path
    syft_path=$(command -v syft 2>/dev/null || true)
    grype_path=$(command -v grype 2>/dev/null || true)

    if [[ "$syft_path" == */go/bin/* || "$grype_path" == */go/bin/* ]]; then
        log_info "Detected Go installation. Update with:"
        echo "    go install github.com/anchore/syft/cmd/syft@latest"
        echo "    go install github.com/anchore/grype/cmd/grype@latest"
        echo "    go install github.com/google/osv-scanner/v2/cmd/osv-scanner@latest"
    else
        # These are the exact same methods used by arch-machine's security.full installer
        log_info "To update (same method used by 'security.full' in arch-machine):"

        echo ""
        echo "  # Syft (SBOM generator)"
        echo "  curl -sSfL https://get.anchore.io/syft | sudo sh -s -- -b /usr/local/bin"
        echo ""
        echo "  # Grype (vulnerability scanner)"
        echo "  curl -sSfL https://raw.githubusercontent.com/anchore/grype/main/install.sh \\"
        echo "    | sudo sh -s -- -b /usr/local/bin"
        echo ""
        echo "  # OSV-Scanner (universal vulnerability scanner)"
        echo "  curl -sSfL \"https://github.com/google/osv-scanner/releases/latest/download/\" \\"
        echo "    \"osv-scanner_\$(uname -s | tr '[:upper:]' '[:lower:]')_\$(uname -m | sed 's/x86_64/amd64/')\" \\"
        echo "    -o /tmp/osv-scanner && sudo install -m 755 /tmp/osv-scanner /usr/local/bin/osv-scanner"
    fi

    echo ""
    log_info "Note: These tools are installed via official scripts / direct binaries by arch-machine,"
    log_info "not through pacman (except on some custom setups)."
    log_info "Re-run the security module with 'security.full' after updating if desired."
}

# Generate security report
generate_security_report() {
    local tools
    tools=$(check_security_tools | tr '\n' ' ')

    append_to_report "
=== SECURITY AUDIT SUMMARY ===
Date: $(date)
Hostname: $(hostname)
User: $(whoami)
Tools used: $tools

Key artifacts:
• sbom.cdx.json - CycloneDX SBOM (commit to version control)
• $SECURITY_REPORT - Full report

Recommendations:
• Review warnings/errors in detailed sections
• Address HIGH/CRITICAL vulnerability findings
• Commit SBOM to version control
• Fix file permission issues
• Update security tools regularly
• Review user accounts/services
• Run with sudo for complete audit if possible

Next steps:
• Run weekly: $0
• Monitor logs for suspicious activity
• Keep system/applications updated
• Review/commit SBOM

=== AUDIT COMPLETE ===
"

    log_success "Report generated: $SECURITY_REPORT"
}

# Main security audit function
main() {
    log_section "Security Audit"
    if [[ "$AUDIT_MODE" == "project" && -n "$AUDIT_TARGET" ]]; then
        log_info "Mode: Project audit on $AUDIT_TARGET"
        if [[ "$(id -u)" -eq 0 ]]; then
            log_warn "Running as root. Package managers (pnpm/npm) and some tools may not be in PATH."
            log_info "Consider running without sudo for project audits when possible."
        fi
    else
        log_info "Mode: Full system (global) audit"
    fi
    log_info "Starting comprehensive security audit..."

    # Install security tools (skipped without sudo in both modes)
    install_security_tools

    # Always run project-relevant / directory-scoped modern scans
    # (these respect current working directory or target)
    run_native_ecosystem_audits
    run_osv_scanner_audit
    run_sbom_grype_audit

    if [[ "$AUDIT_MODE" == "global" ]]; then
        # Heavy global system checks — only make sense in full machine audit
        run_lynis_audit
        # run_clamav_scan
        run_rootkit_checks
        check_file_permissions          # includes the expensive /home world-writable scan
        check_running_services
        check_user_accounts
    else
        log_info "Project mode: Skipping global system checks (services, users, Lynis, rootkits, full /home scan)"
        log_info "Focus: code-level vulns, SBOM, native ecosystem audits in current directory"
    fi

    # Generate report
    generate_security_report

    # Extract evidence for AI agents (robust path for both installed + dev)
    local evidence_script
    if [[ -f "$ROOT_DIR/maintenance/extract-evidence.sh" ]]; then
        evidence_script="$ROOT_DIR/maintenance/extract-evidence.sh"
    elif [[ -f "/usr/share/tinfoil/maintenance/extract-evidence.sh" ]]; then
        evidence_script="/usr/share/tinfoil/maintenance/extract-evidence.sh"
    fi

    if [[ -n "$evidence_script" ]]; then
        log_info "Extracting evidence bundle for AI agents"
        # In project mode, evidence script will also prefer user-writable smart paths
        "$evidence_script" >/dev/null 2>&1 || log_warn "Evidence extraction failed"
    fi

    log_success "Security audit completed"

    check_for_tool_updates
}

# Run main function
main "$@"