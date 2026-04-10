#!/usr/bin/env bash
# Core installer library functions

# Source logger
source "$(dirname "${BASH_SOURCE[0]}")/logger.sh"

# Global variables
CONFIG_DIR="${CONFIG_DIR:-config}"
TOOLS_CONFIG="$CONFIG_DIR/tools.yaml"
PROFILE_CONFIG="$CONFIG_DIR/profiles"
DRY_RUN="${DRY_RUN:-false}"
FORCE="${FORCE:-false}"

# Check if yq is available for YAML parsing
check_yaml_parser() {
    if command -v yq &>/dev/null; then
        YAML_PARSER="yq"
    elif command -v jq &>/dev/null && command -v yq-go &>/dev/null; then
        YAML_PARSER="yq-go"
    else
        log_error "Neither yq nor yq-go found. Please install one for YAML processing."
        return 1
    fi
    log_debug "Using YAML parser: $YAML_PARSER"
}

# Parse YAML value
yaml_get() {
    local file="$1"
    local path="$2"

    case "$YAML_PARSER" in
        yq)
            yq -r "$path" "$file" 2>/dev/null
            ;;
        yq-go)
            yq-go r "$file" "$path" 2>/dev/null
            ;;
    esac
}

# Check if package is installed
is_package_installed() {
    local package="$1"
    pacman -Qi "$package" &>/dev/null
}

# Install package with pacman
install_package() {
    local package="$1"
    local description="${2:-$package}"

    if is_package_installed "$package"; then
        log_info "Package already installed: $package"
        return 0
    fi

    log_subsection "Installing $description ($package)"

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would install: $package"
        return 0
    fi

    if sudo pacman -S --needed --noconfirm "$package"; then
        log_success "Installed $package"
        return 0
    else
        log_failure "Failed to install $package"
        return 1
    fi
}

# Install multiple packages
install_packages() {
    local packages=("$@")

    for package in "${packages[@]}"; do
        if [[ "$package" == *":"* ]]; then
            # Format: "package:description"
            local pkg_name="${package%%:*}"
            local pkg_desc="${package#*:}"
            install_package "$pkg_name" "$pkg_desc" || return 1
        else
            install_package "$package" || return 1
        fi
    done
}

# Enable and start systemd service
enable_service() {
    local service="$1"
    local description="${2:-$service}"

    log_subsection "Enabling service: $description"

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would enable service: $service"
        return 0
    fi

    if sudo systemctl enable --now "$service"; then
        log_success "Enabled and started $service"
        return 0
    else
        log_failure "Failed to enable $service"
        return 1
    fi
}

# Add user to group
add_user_to_group() {
    local group="$1"
    local user="${2:-$USER}"

    log_subsection "Adding user $user to group $group"

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would add $user to $group"
        return 0
    fi

    if sudo usermod -aG "$group" "$user"; then
        log_success "Added $user to $group"
        return 0
    else
        log_failure "Failed to add $user to $group"
        return 1
    fi
}

# Download and run installer script
run_installer_script() {
    local url="$1"
    local description="$2"
    local temp_file="/tmp/installer-$(basename "$url")"

    log_subsection "Installing $description from $url"

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would download and run: $url"
        return 0
    fi

    if curl -fsSL "$url" -o "$temp_file"; then
        if bash "$temp_file"; then
            log_success "Installed $description"
            rm -f "$temp_file"
            return 0
        else
            log_failure "Failed to install $description"
            rm -f "$temp_file"
            return 1
        fi
    else
        log_failure "Failed to download installer from $url"
        return 1
    fi
}

# Check if command exists
command_exists() {
    command -v "$1" &>/dev/null
}

# Get version of installed tool
get_version() {
    local tool="$1"
    local version_cmd="$2"

    if command_exists "$tool"; then
        eval "$version_cmd" 2>/dev/null | head -1
    else
        echo "not installed"
    fi
}

# Compare versions (basic semantic version comparison)
version_compare() {
    local version1="$1"
    local version2="$2"

    if [[ "$version1" == "$version2" ]]; then
        echo "equal"
        return 0
    fi

    # Simple version comparison (doesn't handle all cases)
    local IFS=.
    local v1_parts=($version1)
    local v2_parts=($version2)

    for i in {0..2}; do
        local v1_part="${v1_parts[$i]:-0}"
        local v2_part="${v2_parts[$i]:-0}"

        if (( v1_part > v2_part )); then
            echo "greater"
            return 0
        elif (( v1_part < v2_part )); then
            echo "less"
            return 0
        fi
    done

    echo "equal"
}

# Create directory if it doesn't exist
ensure_dir() {
    local dir="$1"

    if [[ ! -d "$dir" ]]; then
        if [[ "$DRY_RUN" == "true" ]]; then
            log_info "[DRY RUN] Would create directory: $dir"
        else
            mkdir -p "$dir" && log_debug "Created directory: $dir"
        fi
    fi
}

# Backup file
backup_file() {
    local file="$1"
    local backup_suffix="${2:-$(date +%s)}"

    if [[ -f "$file" ]]; then
        local backup="$file.bak.$backup_suffix"
        if [[ "$DRY_RUN" == "true" ]]; then
            log_info "[DRY RUN] Would backup $file to $backup"
        else
            cp "$file" "$backup" && log_debug "Backed up $file to $backup"
        fi
    fi
}

# Check system requirements
check_system_requirements() {
    log_section "System Requirements Check"

    # Check if running on Arch Linux
    if [[ ! -f /etc/arch-release ]]; then
        log_error "This installer is designed for Arch Linux only"
        return 1
    fi

    # Check for sudo
    if ! command_exists sudo; then
        log_error "sudo is required but not installed"
        return 1
    fi

    # Check internet connection
    if ! ping -c 1 -W 5 8.8.8.8 &>/dev/null; then
        log_error "Internet connection required"
        return 1
    fi

    log_success "System requirements met"
    return 0
}

# Initialize installer
init_installer() {
    log_section "Installer Initialization"

    # Check YAML parser
    check_yaml_parser || return 1

    # Check system requirements
    check_system_requirements || return 1

    # Ensure config files exist
    if [[ ! -f "$TOOLS_CONFIG" ]]; then
        log_error "Tools configuration not found: $TOOLS_CONFIG"
        return 1
    fi

    log_success "Installer initialized successfully"
    return 0
}

# Export functions
export -f is_package_installed install_package install_packages
export -f enable_service add_user_to_group run_installer_script
export -f command_exists get_version version_compare
export -f ensure_dir backup_file check_system_requirements init_installer