#!/usr/bin/env bash
# Development tools module installer

# Libraries are sourced by main installer script

MODULE_NAME="development"
CONFIG_FILE="$CONFIG_DIR/tools.yaml"

# Install mise (runtime version manager)
install_mise() {
    log_section "Installing mise (Runtime Manager)"

    if command_exists mise; then
        log_info "mise already installed"
        # Self-update if possible
        mise self-update --yes 2>/dev/null || log_debug "Could not self-update mise"
        return 0
    fi

    local url="https://mise.jdx.dev/install.sh"
    run_installer_script "$url" "mise" || return 1

    # Add to shell profile
    local bashrc="$HOME/.bashrc"
    if [[ -f "$bashrc" ]] && ! grep -q "mise activate bash" "$bashrc"; then
        echo 'eval "$(mise activate bash)"' >> "$bashrc"
        log_debug "Added mise activation to $bashrc"
    fi

    # Source for current session
    eval "$(mise activate bash)" 2>/dev/null || true

    log_success "mise installed and configured"
}

# Install language versions with mise
install_mise_versions() {
    log_section "Installing Language Versions with mise"

    # Get versions from profile or use defaults
    local python_versions=()
    local node_versions=()
    local rust_versions=()

    # Try to get from profile first
    if [[ -f "$PROFILE_CONFIG/$PROFILE.yaml" ]]; then
        mapfile -t python_versions < <(yaml_get "$PROFILE_CONFIG/$PROFILE.yaml" "customizations.development.mise.versions.python[]")
        mapfile -t node_versions < <(yaml_get "$PROFILE_CONFIG/$PROFILE.yaml" "customizations.development.mise.versions.node[]")
        mapfile -t rust_versions < <(yaml_get "$PROFILE_CONFIG/$PROFILE.yaml" "customizations.development.mise.versions.rust[]")
    fi

    # Fall back to config defaults
    if [[ ${#python_versions[@]} -eq 0 ]]; then
        mapfile -t python_versions < <(yaml_get "$CONFIG_FILE" "tools.development.mise.versions.python[]")
    fi
    if [[ ${#node_versions[@]} -eq 0 ]]; then
        mapfile -t node_versions < <(yaml_get "$CONFIG_FILE" "tools.development.mise.versions.node[]")
    fi
    if [[ ${#rust_versions[@]} -eq 0 ]]; then
        mapfile -t rust_versions < <(yaml_get "$CONFIG_FILE" "tools.development.mise.versions.rust[]")
    fi

    # Install Python versions
    for version in "${python_versions[@]}"; do
        log_subsection "Installing Python $version"
        mise install "python@$version" || log_warn "Failed to install Python $version"
    done

    # Install Node versions
    for version in "${node_versions[@]}"; do
        log_subsection "Installing Node $version"
        mise install "node@$version" || log_warn "Failed to install Node $version"
    done

    # Install Rust versions
    for version in "${rust_versions[@]}"; do
        log_subsection "Installing Rust $version"
        mise install "rust@$version" || log_warn "Failed to install Rust $version"
    done

    # Set global versions
    local global_python
    local global_node
    local global_rust

    global_python=$(yaml_get "$CONFIG_FILE" "tools.development.mise.global.python")
    global_node=$(yaml_get "$CONFIG_FILE" "tools.development.mise.global.node")
    global_rust=$(yaml_get "$CONFIG_FILE" "tools.development.mise.global.rust")

    if [[ -n "$global_python" ]]; then
        mise use -g "python@$global_python" || log_warn "Failed to set global Python"
    fi
    if [[ -n "$global_node" ]]; then
        mise use -g "node@$global_node" || log_warn "Failed to set global Node"
    fi
    if [[ -n "$global_rust" ]]; then
        mise use -g "rust@$global_rust" || log_warn "Failed to set global Rust"
    fi

    log_success "Language versions configured"
}

# Install uv (Python package manager)
install_uv() {
    log_section "Installing uv (Python Package Manager)"

    if command_exists uv; then
        log_info "uv already installed"
        # Self-update if possible
        uv self-update 2>/dev/null || log_debug "Could not self-update uv"
        return 0
    fi

    local url="https://astral.sh/uv/install.sh"
    run_installer_script "$url" "uv" || return 1

    log_success "uv installed"
}

# TODO: IDE installation will be handled separately in future iterations
# IDEs require special installation methods (shell scripts, AppImages, etc.)
# and will have dedicated installers/updaters

# Main development module function
install_development() {
    local category="${1:-full}"

    log_section "Development Tools Module Installation ($category)"

    case "$category" in
        core)
            # Minimal development tools
            install_mise || return 1
            install_mise_versions
            install_uv || return 1
            ;;
        full|*)
            # Full development environment
            install_mise || return 1
            install_mise_versions
            install_uv || return 1
            # TODO: IDE installation moved to separate system
            ;;
    esac

    log_success "Development tools module installation completed ($category)"
}

# Export main function
export -f install_development