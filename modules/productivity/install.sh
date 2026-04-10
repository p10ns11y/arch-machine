#!/usr/bin/env bash
# Productivity tools module installer

# Source libraries
source "$(dirname "${BASH_SOURCE[0]}")/../lib/logger.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/installer.sh"

MODULE_NAME="productivity"
CONFIG_FILE="$CONFIG_DIR/tools.yaml"

# Install productivity packages
install_productivity_tools() {
    local category="$1"
    log_section "Installing Productivity Tools ($category)"

    # Define packages based on category
    local packages=()

    case "$category" in
        basic)
            # Basic productivity tools
            packages=("htop" "tmux" "git-delta" "bat" "fd" "ripgrep")
            ;;
        full|*)
            # Extended productivity tools
            packages=("htop" "tmux" "git-delta" "bat" "fd" "ripgrep" "fzf" "neovim" "lazygit")
            ;;
    esac

    if [[ ${#packages[@]} -eq 0 ]]; then
        log_info "No productivity packages to install for category $category"
        return 0
    fi

    local total=${#packages[@]}
    local current=0

    for package in "${packages[@]}"; do
        ((current++))
        log_progress "$current" "$total" "$package"
        install_package "$package" || log_warn "Failed to install $package"
    done

    log_success "Productivity tools installed ($category)"
}

# Main productivity module function
install_productivity() {
    local category="${1:-basic}"

    log_section "Productivity Tools Module Installation ($category)"

    install_productivity_tools "$category"

    log_success "Productivity tools module installation completed ($category)"
}

# Main productivity module function
install_productivity() {
    local category="${1:-basic}"
    log_section "Productivity Tools Module Installation"

    install_productivity_tools

    log_success "Productivity tools module installation completed"
}

# Export main function
export -f install_productivity