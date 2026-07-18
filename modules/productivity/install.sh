#!/usr/bin/env bash
# Productivity tools module installer

# Libraries are sourced by main installer script

MODULE_NAME="productivity"
CONFIG_FILE="$CONFIG_DIR/tools.yaml"

# Install productivity packages
install_productivity_tools() {
    local category="${1:-basic}"
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

# Export main function
export -f install_productivity
# Standalone agent-expand entry (Grok plugin). Skip when sourced by main installer.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  set -euo pipefail
  _mod_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  case "${1:-}" in
    --agent-expand)
      echo "agent-expand: productivity module at $_mod_dir"
      date -Iseconds >"$_mod_dir/.agent-expanded"
      echo "wrote $_mod_dir/.agent-expanded"
      echo "agent_expand_ok: productivity"
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
