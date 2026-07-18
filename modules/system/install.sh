#!/usr/bin/env bash
# System module installer

# Libraries are sourced by main installer script

MODULE_NAME="system"
CONFIG_FILE="$CONFIG_DIR/tools.yaml"

# Install system packages
install_system_packages() {
    local category="$1"
    log_section "Installing System Packages ($category)"

    # Get packages from config
    local packages
    mapfile -t packages < <(yaml_get "$CONFIG_FILE" "tools.system.packages[].name")

    if [[ ${#packages[@]} -eq 0 ]]; then
        log_warn "No system packages defined in configuration"
        return 0
    fi

    local packages_to_install=()

    # Filter packages based on category
    case "$category" in
        base)
            # Only critical packages for base installation
            local package_count
            package_count=$(yaml_get "$CONFIG_FILE" "tools.system.packages | length")
            for ((i=0; i<package_count; i++)); do
                local critical
                critical=$(yaml_get "$CONFIG_FILE" "tools.system.packages[$i].critical")
                if [[ "$critical" == "true" ]]; then
                    local package
                    package=$(yaml_get "$CONFIG_FILE" "tools.system.packages[$i].name")
                    packages_to_install+=("$package")
                fi
            done
            ;;
        full|*)
            # All packages for full installation
            packages_to_install=("${packages[@]}")
            ;;
    esac

    if [[ ${#packages_to_install[@]} -eq 0 ]]; then
        log_info "No packages to install for category $category"
        return 0
    fi

    local total=${#packages_to_install[@]}
    local current=0

    for package in "${packages_to_install[@]}"; do
        ((current++))
        local description
        # Find description for this package
        local package_count
        package_count=$(yaml_get "$CONFIG_FILE" "tools.system.packages | length")
        for ((i=0; i<package_count; i++)); do
            local pkg_name
            pkg_name=$(yaml_get "$CONFIG_FILE" "tools.system.packages[$i].name")
            if [[ "$pkg_name" == "$package" ]]; then
                description=$(yaml_get "$CONFIG_FILE" "tools.system.packages[$i].description")
                break
            fi
        done

        log_progress "$current" "$total" "$package"

        install_package "$package" "$description" || return 1
    done

    log_success "System packages installation completed ($category)"
}

# Install ROCm packages
install_rocm() {
    local category="$1"
    log_section "Installing ROCm Packages"

    # Check if ROCm should be installed based on category or profile customization
    local install_rocm="false"

    # Check profile customization first
    local profile_rocm
    profile_rocm=$(yaml_get "$PROFILE_CONFIG/$PROFILE.yaml" "customizations.system.rocm" 2>/dev/null || echo "null")
    if [[ "$profile_rocm" == "true" ]]; then
        install_rocm="true"
    elif [[ "$category" == "full" ]] && [[ "$profile_rocm" != "false" ]]; then
        # For full category, install ROCm unless explicitly disabled
        install_rocm="true"
    fi

    if [[ "$install_rocm" != "true" ]]; then
        log_info "ROCm installation skipped (category: $category)"
        return 0
    fi

    local packages
    mapfile -t packages < <(yaml_get "$CONFIG_FILE" "tools.system.rocm.packages[]")

    for package in "${packages[@]}"; do
        install_package "$package" "ROCm $package" || return 1
    done

    log_success "ROCm packages installed"
}

# Enable system services
enable_system_services() {
    log_section "Enabling System Services"

    # Get services from installed packages that have services defined
    local services=()
    local package_count
    package_count=$(yaml_get "$CONFIG_FILE" "tools.system.packages | length")

    for ((i=0; i<package_count; i++)); do
        local service
        service=$(yaml_get "$CONFIG_FILE" "tools.system.packages[$i].service")
        if [[ "$service" != "null" && -n "$service" ]]; then
            local package
            package=$(yaml_get "$CONFIG_FILE" "tools.system.packages[$i].name")
            services+=("$service:$package service")
        fi
    done

    for service_desc in "${services[@]}"; do
        local service="${service_desc%%:*}"
        local description="${service_desc#*:}"

        # Special handling for services that might conflict
        if [[ "$service" == "tlp" ]]; then
            # Remove conflicting power-profiles-daemon
            if is_package_installed power-profiles-daemon; then
                log_subsection "Removing conflicting power-profiles-daemon"
                sudo pacman -Rdd --noconfirm power-profiles-daemon || true
            fi
        fi

        enable_service "$service" "$description" || log_warn "Failed to enable $service"
    done

    log_success "System services configured"
}

# Add user to necessary groups
configure_user_groups() {
    log_section "Configuring User Groups"

    local groups=("docker" "video" "render")

    for group in "${groups[@]}"; do
        add_user_to_group "$group" || log_warn "Failed to add user to $group"
    done

    log_info "Note: Log out and back in for group changes to take effect"
    log_success "User groups configured"
}

# Update system packages
update_system() {
    log_section "Updating System Packages"

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would update system packages"
        return 0
    fi

    log_subsection "Synchronizing package databases"
    sudo pacman -Sy --noconfirm || return 1

    log_subsection "Upgrading packages"
    sudo pacman -Su --noconfirm || return 1

    log_success "System packages updated"
}

# Detect hardware
detect_hardware() {
    log_section "Hardware Detection"

    # CPU information
    local cpu_model
    cpu_model=$(grep -m1 "model name" /proc/cpuinfo | awk -F: '{print $2}' | sed 's/^[ \t]*//')
    log_info "CPU: $cpu_model"

    # GPU information
    local igpu_name
    igpu_name=$(rocminfo 2>/dev/null | grep -m1 "Name:" | awk '{print $2 " " $3 " " $4 " " $5}' || echo "Not detected")
    local rocm_target
    rocm_target=$(rocminfo 2>/dev/null | grep -A1 "Name: gfx" | grep -o "gfx[0-9a-f]*" | head -1 || echo "unknown")
    log_info "GPU: $igpu_name ($rocm_target)"

    # RAM information
    local total_ram
    total_ram=$(free -h | awk '/^Mem:/ {print $2}')
    log_info "RAM: $total_ram"

    local date
    date=$(date '+%B %d, %Y')
    log_info "Date: $date"
}

# Main system module function
install_system() {
    local category="${1:-full}"

    log_section "System Module Installation ($category)"

    # Update system first
    update_system || return 1

    # Detect hardware
    detect_hardware

    # Install packages
    install_system_packages "$category" || return 1

    # Install ROCm if enabled
    install_rocm "$category" || return 1

    # Enable services
    enable_system_services

    # Configure user groups
    configure_user_groups

    log_success "System module installation completed ($category)"
}

# Export main function
export -f install_system
# Standalone agent-expand entry (Grok plugin). Skip when sourced by main installer.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  set -euo pipefail
  _mod_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  case "${1:-}" in
    --agent-expand)
      echo "agent-expand: system module at $_mod_dir"
      date -Iseconds >"$_mod_dir/.agent-expanded"
      echo "wrote $_mod_dir/.agent-expanded"
      echo "agent_expand_ok: system"
      exit 0
      ;;
    -h|--help)
      echo "Usage: $0 --agent-expand"
      exit 0
      ;;
    *)
      echo "Usage: $0 --agent-expand" >&2
      exit 2
      ;;
  esac
fi
