#!/usr/bin/env bash
# Validation library for post-installation checks

# Source logger
source "$(dirname "${BASH_SOURCE[0]}")/logger.sh"

# Source installer functions
source "$(dirname "${BASH_SOURCE[0]}")/installer.sh"

# Validate package installation
validate_package() {
    local package="$1"
    local description="${2:-$package}"

    if is_package_installed "$package"; then
        log_success "Package validated: $description"
        return 0
    else
        log_failure "Package not found: $description"
        return 1
    fi
}

# Validate service status
validate_service() {
    local service="$1"
    local description="${2:-$service}"

    if sudo systemctl is-active --quiet "$service"; then
        log_success "Service running: $description"
        return 0
    else
        log_failure "Service not running: $description"
        return 1
    fi
}

# Validate command availability
validate_command() {
    local command="$1"
    local description="${2:-$command}"

    if command_exists "$command"; then
        log_success "Command available: $description"
        return 0
    else
        log_failure "Command not found: $description"
        return 1
    fi
}

# Validate user in group
validate_user_group() {
    local group="$1"
    local user="${2:-$USER}"

    if groups "$user" | grep -q "\b$group\b"; then
        log_success "User $user is in group $group"
        return 0
    else
        log_failure "User $user is not in group $group"
        return 1
    fi
}

# Validate file exists
validate_file() {
    local file="$1"
    local description="${2:-$file}"

    if [[ -f "$file" ]]; then
        log_success "File exists: $description"
        return 0
    else
        log_failure "File not found: $description"
        return 1
    fi
}

# Validate directory exists
validate_directory() {
    local dir="$1"
    local description="${2:-$dir}"

    if [[ -d "$dir" ]]; then
        log_success "Directory exists: $description"
        return 0
    else
        log_failure "Directory not found: $description"
        return 1
    fi
}

# Validate mount point
validate_mount() {
    local mount_point="$1"
    local description="${2:-$mount_point}"

    if mountpoint -q "$mount_point"; then
        log_success "Mount point active: $mount_point: $description"
        return 0
    else
        log_failure "Mount point not active: $mount_point: $description"
        return 1
    fi
}

# Validate version constraint
validate_version() {
    local tool="$1"
    local min_version="$2"
    local description="${3:-$tool}"

    if ! command_exists "$tool"; then
        log_failure "Tool not found: $description"
        return 1
    fi

    local current_version
    current_version=$(get_version "$tool" "$tool --version")

    if [[ "$current_version" == "not installed" ]]; then
        log_failure "Cannot determine version for $description"
        return 1
    fi

    local comparison
    comparison=$(version_compare "$current_version" "$min_version")

    if [[ "$comparison" == "less" ]]; then
        log_failure "Version too old: $description ($current_version < $min_version)"
        return 1
    else
        log_success "Version OK: $description ($current_version >= $min_version)"
        return 0
    fi
}

# Validate ROCm installation
validate_rocm() {
    log_subsection "Validating ROCm installation"

    # Check if rocminfo command works
    if ! command_exists rocminfo; then
        log_failure "rocminfo command not found"
        return 1
    fi

    # Try to get GPU info
    if rocminfo >/dev/null 2>&1; then
        local gpu_name
        gpu_name=$(rocminfo 2>/dev/null | grep -m1 "Name:" | awk '{print $2 " " $3 " " $4 " " $5}' || echo "Unknown")
        log_success "ROCm GPU detected: $gpu_name"
        return 0
    else
        log_warn "ROCm installation found but no compatible GPU detected"
        return 0
    fi
}

# Validate mise installation
validate_mise() {
    log_subsection "Validating mise installation"

    if ! command_exists mise; then
        log_failure "mise command not found"
        return 1
    fi

    log_success "mise is available"
    return 0
}

# Validate uv installation
validate_uv() {
    log_subsection "Validating uv installation"

    if ! command_exists uv; then
        log_failure "uv command not found"
        return 1
    fi

    log_success "uv is available"
    return 0
}

# Run comprehensive validation
_run_validation() {
    local profile="${1:-all}"
    local is_sub_call="${2:-false}"
    local failed_checks=0

    [[ "$is_sub_call" == "false" ]] && log_section "Post-Installation Validation"

    case "$profile" in
        minimal)
            validate_command git "Git version control"
            validate_command curl "cURL utility"
            validate_command mise "mise runtime manager" || ((failed_checks++))
            validate_command uv "uv package installer" || ((failed_checks++))
            ;;
        ml-dev)
            _run_validation "minimal" "true"
            validate_rocm || ((failed_checks++))
            validate_command conda "Conda package manager" || ((failed_checks++))
            ;;
        security-dev)
            _run_validation "minimal" "true"
            # validate_kubernetes || ((failed_checks++))
            # validate_cilium || ((failed_checks++))
            # validate_tetragon || ((failed_checks++))
            validate_mount ~/securevault "Encrypted vault" || ((failed_checks++))
            ;;
        secure-infra|security-infra)
            source "$(dirname "${BASH_SOURCE[0]}")/validator_advanced.sh"
            validate_kubernetes || ((failed_checks++))
            validate_cilium || ((failed_checks++))
            validate_tetragon || ((failed_checks++))
            ;;
        all|*)
            # Validate system packages
            validate_package git "Git"
            validate_package docker "Docker" && validate_service docker "Docker service"
            validate_package tlp "TLP" && validate_service tlp "TLP service"
            validate_package ufw "UFW" && validate_service ufw "UFW service"

            # Validate development tools
            validate_mise || ((failed_checks++))
            validate_uv || ((failed_checks++))
            validate_rocm || ((failed_checks++))

            # Validate ML/AI tools
            if command_exists conda; then
                validate_command conda "Conda"
            fi

            # Validate security tools
            if command_exists kubectl; then
                echo "No clusters for laptop now..."
                # validate_kubernetes || ((failed_checks++))
                # validate_cilium || ((failed_checks++))
                # validate_tetragon || ((failed_checks++))
            fi

            # Validate encrypted storage
            if [[ -d ~/securevault ]]; then
                validate_mount ~/securevault "Encrypted vault" || ((failed_checks++))
            fi
            ;;
    esac

    if [[ $failed_checks -eq 0 ]]; then
        log_success "All validation checks passed"
        return 0
    else
        log_failure "$failed_checks validation check(s) failed"
        return 1
    fi
}

# Export functions
export -f validate_package validate_service validate_command validate_user_group
export -f validate_file validate_directory validate_mount validate_version
export -f validate_rocm validate_mise validate_uv
export -f _run_validation 