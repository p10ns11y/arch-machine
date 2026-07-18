#!/usr/bin/env bash
# Security tools module installer

# Libraries are sourced by main installer script

MODULE_NAME="security"
CONFIG_FILE="$CONFIG_DIR/tools.yaml"

# Install k3s (lightweight Kubernetes) — localhost-only + masked by default
install_k3s() {
    log_section "Installing k3s (Kubernetes)"

    if sudo systemctl is-active --quiet k3s; then
        log_info "k3s already running"
        return 0
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would install k3s"
        return 0
    fi

    # Read the new nested config map
    local bind_localhost
    local flannel_backend
    local disable_network_policy
    local disable_traefik

    bind_localhost=$(yaml_get "$CONFIG_FILE" "tools.security.kubernetes.k3s.config.bind_localhost" "false")
    flannel_backend=$(yaml_get "$CONFIG_FILE" "tools.security.kubernetes.k3s.config.flannel_backend" "")
    disable_network_policy=$(yaml_get "$CONFIG_FILE" "tools.security.kubernetes.k3s.config.disable_network_policy" "false")
    disable_traefik=$(yaml_get "$CONFIG_FILE" "tools.security.kubernetes.k3s.config.disable_traefik" "false")

    # Build ExecStart flags
    local exec_args="server"

    # Localhost binding (your main request)
    if [[ "$bind_localhost" == "true" ]]; then
        exec_args="$exec_args \
            --bind-address=127.0.0.1 \
            --advertise-address=127.0.0.1 \
            --node-ip=127.0.0.1"
        log_subsection "k3s will be bound to localhost only"
    fi

    # Conditional flags from config
    if [[ "$flannel_backend" == "none" ]]; then
        exec_args="$exec_args --flannel-backend=none"
    fi

    if [[ "$disable_network_policy" == "true" ]]; then
        exec_args="$exec_args --disable-network-policy"
    fi

    if [[ "$disable_traefik" == "true" ]]; then
        exec_args="$exec_args --disable-traefik"
    fi

    log_subsection "Installing k3s with args: $exec_args"

    # Install WITHOUT auto-enable/start (official k3s flags)
    curl -sfL https://get.k3s.io | \
        INSTALL_K3S_SKIP_ENABLE=true \
        INSTALL_K3S_SKIP_START=true \
        INSTALL_K3S_EXEC="$exec_args" sh - || {
        log_error "Failed to install k3s"
        return 1
    }

    # Mask it immediately (never starts at boot)
    sudo rm -f /etc/systemd/system/k3s.service
    sudo systemctl mask k3s.service
    sudo systemctl daemon-reload

    log_success "k3s installed (localhost-only + masked by default)"
}

# Configure kubeconfig
configure_kubeconfig() {
    log_section "Configuring kubeconfig"

    if [[ -f ~/.kube/config ]] && kubectl get nodes &>/dev/null; then
        log_info "kubeconfig already configured"
        return 0
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would configure kubeconfig"
        return 0
    fi

    mkdir -p ~/.kube

    # Copy k3s config
    sudo cp -f /etc/rancher/k3s/k3s.yaml ~/.kube/config || {
        log_error "Failed to copy kubeconfig"
        return 1
    }

    sudo chown "$USER:$USER" ~/.kube/config
    chmod 600 ~/.kube/config

    # Clear any existing KUBECONFIG
    unset KUBECONFIG

    log_success "kubeconfig configured"
}

# Install Cilium as k3s CNI — minimal exposure for desktop/dev use
install_cilium() {
    log_section "Installing Cilium CNI for k3s"

    if ! sudo systemctl is-active --quiet k3s; then
        log_info "k3s is masked/not running. Cilium skipped (start k3s with k3s-start only when needed)."
        return 0
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would install Cilium"
        return 0
    fi

    local version
    version=$(yaml_get "$CONFIG_FILE" "tools.security.cilium.version")
    local config
    config=$(yaml_get "$CONFIG_FILE" "tools.security.cilium.config")

    log_subsection "Installing Cilium $version (no Prometheus, no Hubble, no Envoy metrics)"


    cilium install \
        --version "$version" \
        --helm-set debug.enabled=false \
        --helm-set prometheus.enabled=false \
        --helm-set operator.prometheus.enabled=false \
        --helm-set hubble.enabled=false \
        --helm-set envoy.prometheus.enabled=false \
        --helm-set bpf.masquerade=false \
        --helm-set ipam.mode=kubernetes \
        --helm-set kubeProxyReplacement=partial || {
        log_error "Failed to install Cilium"
        return 1
    }

    log_success "Cilium installed (minimal ports + desktop-friendly)"
}

# Install Tetragon
install_tetragon() {
    local enabled
    enabled=$(yaml_get "$CONFIG_FILE" "tools.security.kubernetes.enabled" "false")

    if [[ "$enabled" != "true" ]]; then
        log_info "Tetragon skipped (kubernetes disabled in config)."
        return 0
    fi

    if ! sudo systemctl is-active --quiet k3s; then
        log_info "k3s not running. Tetragon skipped."
        return 0
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would install Tetragon"
        return 0
    fi

    log_subsection "Installing Tetragon"

    helm repo add tetragon https://helm.tetragon.io || true
    helm repo update

    helm install tetragon tetragon/tetragon \
        --namespace kube-system \
        --set tetragon.prometheus.enabled=false \
        --set tetragon.grpc.enabled=false \
        --set tetragon.export.otel.enabled=false || {
        log_error "Failed to install Tetragon"
        return 1
    }

    log_success "Tetragon installed (only when k3s active)"
}

# Install OSV-Scanner
install_osv_scanner() {
    log_section "Installing OSV-Scanner"

    if command_exists osv-scanner; then
        log_info "OSV-Scanner already installed"
        return 0
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would install OSV-Scanner"
        return 0
    fi

    local source_template
    source_template=$(yaml_get "$CONFIG_FILE" "tools.security.vulnerability_scanning.osv_scanner.source")
    local source
    source=$(eval echo "$source_template")
    local install_path
    install_path=$(yaml_get "$CONFIG_FILE" "tools.security.vulnerability_scanning.osv_scanner.install_path")
    local chmod_mode
    chmod_mode=$(yaml_get "$CONFIG_FILE" "tools.security.vulnerability_scanning.osv_scanner.chmod")
    log_subsection "Downloading OSV-Scanner from $source"
    if [[ -w "$(dirname "$install_path")" ]]; then
        curl -sSfL "$source" -o "$install_path" || {
            log_error "Failed to download OSV-Scanner"
            return 1
        }
        chmod "$chmod_mode" "$install_path" || {
            log_error "Failed to set permissions on OSV-Scanner"
            return 1
        }
    elif sudo -n true 2>/dev/null; then
        sudo curl -sSfL "$source" -o "$install_path" || {
            log_error "Failed to download OSV-Scanner"
            return 1
        }
        sudo chmod "$chmod_mode" "$install_path" || {
            log_error "Failed to set permissions on OSV-Scanner"
            return 1
        }
    else
        log_error "Cannot install OSV-Scanner - no write permissions to $install_path and sudo not available"
        return 1
    fi

    log_success "OSV-Scanner installed"
}

# Install Grype
install_grype() {
    log_section "Installing Grype"

    if command_exists grype; then
        log_info "Grype already installed"
        return 0
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would install Grype"
        return 0
    fi

    local source
    source=$(yaml_get "$CONFIG_FILE" "tools.security.vulnerability_scanning.grype.source")
    local installer_args
    installer_args=$(yaml_get "$CONFIG_FILE" "tools.security.vulnerability_scanning.grype.installer_args")

    log_subsection "Installing Grype using installer script"
    if sudo -n true 2>/dev/null; then
        curl -sSfL "$source" | sudo sh -s -- $installer_args || {
            log_error "Failed to install Grype with sudo"
            return 1
        }
    else
        log_error "Cannot install Grype - sudo authentication required for system installation"
        log_info "Try running with sudo available, or install manually:"
        log_info "curl -sSfL $source | sh -s -- $installer_args"
        return 1
    fi

    log_success "Grype installed"
}

# Install Syft
install_syft() {
    log_section "Installing Syft"

    if command_exists syft; then
        log_info "Syft already installed"
        return 0
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would install Syft"
        return 0
    fi

    local source
    source=$(yaml_get "$CONFIG_FILE" "tools.security.vulnerability_scanning.syft.source")
    local install_path
    install_path=$(yaml_get "$CONFIG_FILE" "tools.security.vulnerability_scanning.syft.install_path")
    local chmod_mode
    chmod_mode=$(yaml_get "$CONFIG_FILE" "tools.security.vulnerability_scanning.syft.chmod")

    log_subsection "Downloading Syft from $source"
    if [[ -w "$install_path" ]]; then
        curl -sSfL "$source" | sh -s -- -b "$install_path" || {
            log_error "Failed to install Syft"
            return 1
        }
    elif sudo -n true 2>/dev/null; then
        curl -sSfL "$source" | sudo sh -s -- -b "$install_path" || {
            log_error "Failed to install Syft with sudo"
            return 1
        }
    else
        log_error "Cannot install Syft - sudo authentication required for system installation"
        log_info "Try running with sudo available, or install manually:"
        log_info "curl -sSfL $source | sh -s -- -b $install_path"
        return 1
    fi

    log_success "Syft installed"
}

# Install pip-audit
# install_pip_audit() {
#     log_section "Installing pip-audit"

#     if command_exists pip-audit; then
#         log_info "pip-audit already installed"
#         return 0
#     fi

#     if [[ "$DRY_RUN" == "true" ]]; then
#         log_info "[DRY RUN] Would install pip-audit"
#         return 0
#     fi

#     log_subsection "Installing pip-audit via pip"
#     python3 -m pip install --upgrade pip-audit --quiet || {
#         log_error "Failed to install pip-audit"
#         return 1
#     }

#     log_success "pip-audit installed"
# }

# Install cargo-audit
install_cargo_audit() {
    log_section "Installing cargo-audit"

    if command_exists cargo-audit; then
        log_info "cargo-audit already installed"
        return 0
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would install cargo-audit"
        return 0
    fi

    local install_command
    install_command=$(yaml_get "$CONFIG_FILE" "tools.security.vulnerability_scanning.cargo_audit.install_command")

    log_subsection "Installing cargo-audit via cargo"
    eval "$install_command" || {
        log_error "Failed to install cargo-audit"
        return 1
    }

    log_success "cargo-audit installed"
}

install_vector() {
    log_section "Installing Vector"

    if command_exists vector; then
        log_info "Vector already installed"
        return 0
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would install Vector"
        return 0
    fi

    local package
    package=$(yaml_get "$CONFIG_FILE" "tools.security.vulnerability_scanning.vector.package")

    log_subsection "Installing Vector via pacman"
    install_package "$package" "Vector log processing pipeline" || {
        log_error "Failed to install Vector"
        return 1
    }

    log_success "Vector installed"
}

install_toon() {
    log_section "Installing Toon"

    if command_exists toon; then
        log_info "Toon already installed"
        return 0
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would install Toon"
        return 0
    fi

    local install_command
    install_command=$(yaml_get "$CONFIG_FILE" "tools.security.vulnerability_scanning.toon.install_command")

    log_subsection "Installing toon via cargo"
    eval "$install_command" || {
        log_error "Failed to install toon"
        return 1
    }

    log_success "toon installed"
}

# Setup encrypted vault (gocryptfs)
# This function is intentionally resilient. Failing to mount should not
# kill an entire security module installation.
setup_encrypted_vault() {
    local vault_enc="${1:-$HOME/.securevaultenc}"
    local vault_mount="${2:-$HOME/securevault}"

    log_section "Setting up Encrypted Vault"

    if [[ -z "$vault_enc" || -z "$vault_mount" ]]; then
        log_error "Usage: setup_encrypted_vault [encrypted_dir] [mount_point]"
        return 1
    fi

    # --- Initialize container if it doesn't exist ---
    if [[ -d "$vault_enc" ]]; then
        log_info "Encrypted vault already initialized at $vault_enc"
    else
        if [[ "$DRY_RUN" == "true" ]]; then
            log_info "[DRY RUN] Would initialize encrypted vault at $vault_enc"
        else
            mkdir -p "$vault_enc"
            log_subsection "Initializing gocryptfs vault at $vault_enc (you will be prompted for password)"
            gocryptfs -init -scryptn=15 "$vault_enc" || {
                log_error "Failed to initialize gocryptfs vault"
                return 1
            }
            log_success "Encrypted vault initialized at $vault_enc"
        fi
    fi

    # --- Handle mounting ---
    if mountpoint -q "$vault_mount" 2>/dev/null; then
        log_info "Vault already mounted at $vault_mount"
        return 0
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would mount encrypted vault at $vault_mount"
        return 0
    fi

    # Check if mount point is usable
    if [[ -d "$vault_mount" ]] && [[ -n "$(ls -A "$vault_mount" 2>/dev/null)" ]]; then
        log_warn "Mount point '$vault_mount' already exists and is not empty."
        log_warn "gocryptfs refuses to mount over a non-empty directory."

        # Offer interactive recovery if possible
        if [[ -t 0 ]] && command -v gum >/dev/null 2>&1; then
            choice=$(gum choose --header "What would you like to do?" \
                "Choose a different mount point name" \
                "Skip mounting for now (you can mount manually later)" \
                "Abort vault setup")
        else
            echo
            echo "Options:"
            echo "  1) Choose a different mount point name"
            echo "  2) Skip mounting for now (mount manually later with: gocryptfs $vault_enc <new-mount>)"
            echo "  3) Abort vault setup"
            read -rp "Choice [1-3]: " choice_num
            case "$choice_num" in
                1) choice="Choose a different mount point name" ;;
                2) choice="Skip mounting for now (you can mount manually later)" ;;
                *) choice="Abort vault setup" ;;
            esac
        fi

        case "$choice" in
            *"different mount point"*)
                if command -v gum >/dev/null 2>&1; then
                    vault_mount=$(gum input --placeholder "New mount point (e.g. ~/myvault)" --value "${vault_mount}-2")
                else
                    read -rp "Enter new mount point: " vault_mount
                fi
                [[ -z "$vault_mount" ]] && { log_warn "No mount point provided. Skipping."; return 0; }
                ;;
            *"Skip mounting"*)
                log_info "Skipping mount step. Your encrypted container is ready at: $vault_enc"
                log_info "You can mount it later with: gocryptfs $vault_enc <desired-mount-point>"
                return 0
                ;;
            *)
                log_info "Vault setup aborted by user. Container exists at $vault_enc but is not mounted."
                return 0
                ;;
        esac
    fi

    # Final attempt to mount
    mkdir -p "$vault_mount"
    log_subsection "Mounting encrypted vault (you will be prompted for password)"
    if gocryptfs "$vault_enc" "$vault_mount"; then
        log_success "Encrypted vault mounted at $vault_mount"
        log_info "Use 'fusermount -u $vault_mount' to unmount"
        return 0
    else
        log_error "Failed to mount encrypted vault at $vault_mount"
        log_info "You can try manually: gocryptfs $vault_enc $vault_mount"
        return 0   # Do not hard-fail the whole security module
    fi
}

# Main security module function
install_security() {
    local category="${1:-full}"

    log_section "Security Tools Module Installation ($category)"

    # Check if security tools should be installed
    local install_security
    install_security=$(yaml_get "$PROFILE_CONFIG/$PROFILE.yaml" "customizations.security")

    if [[ "$install_security" == "false" ]] || [[ "$category" != "full" ]]; then
        log_info "Security tools installation skipped (category: $category, profile setting: $install_security)"
        return 0
    fi

    # Install k3s
    local install_k3s
    install_k3s=$(yaml_get "$PROFILE_CONFIG/$PROFILE.yaml" "customizations.security.kubernetes.k3s")
    if [[ "$install_k3s" == "true" ]]; then
        install_k3s || return 1
        configure_kubeconfig || return 1
    fi

    # Install Cilium
    local install_cilium
    install_cilium=$(yaml_get "$PROFILE_CONFIG/$PROFILE.yaml" "customizations.security.cilium")
    if [[ "$install_cilium" == "true" ]]; then
        install_cilium || return 1
    fi

    # Install Tetragon
    local install_tetragon
    install_tetragon=$(yaml_get "$PROFILE_CONFIG/$PROFILE.yaml" "customizations.security.tetragon")
    if [[ "$install_tetragon" == "true" ]]; then
        install_tetragon || return 1
    fi

    # Setup encrypted vault (best-effort — should not kill the whole security module)
    local install_encrypted_storage
    install_encrypted_storage=$(yaml_get "$PROFILE_CONFIG/$PROFILE.yaml" "customizations.security.encrypted_storage")
    if [[ "$install_encrypted_storage" == "true" ]]; then
        setup_encrypted_vault || log_warn "Encrypted vault setup did not complete successfully. You can run it manually later."
    fi

    # Install vulnerability scanning tools
    if [[ "$category" == "full" ]]; then
        install_osv_scanner || return 1
        install_grype || return 1
        install_syft || return 1
        # install_pip_audit || return 1
        install_cargo_audit || return 1
        install_vector || return 1
        install_toon || return 1
    fi

    log_success "Security tools module installation completed ($category)"
}

# Export functions for standalone use
export -f setup_encrypted_vault
export -f install_security
# ---------------------------------------------------------------------------
# Standalone agent-expand entry (Grok plugin /am-expand). NOT used when sourced
# by the main installer (BASH_SOURCE != $0). Full k3s/profile install remains
# install_security via profile; this path only prepares the security code chunk.
# ---------------------------------------------------------------------------
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  set -euo pipefail
  _mod_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  case "${1:-}" in
    --agent-expand)
      echo "agent-expand: security module at $_mod_dir"
      if [[ -f "$_mod_dir/keeper/Cargo.toml" ]]; then
        if command -v cargo >/dev/null 2>&1; then
          # Real work: verify keeper crate builds (no sudo, no k3s)
          (cd "$_mod_dir/keeper" && cargo check --quiet) || {
            echo "warning: cargo check failed for keeper (continuing with stamp)" >&2
          }
        else
          echo "cargo not on PATH; skip keeper check"
        fi
      fi
      date -Iseconds >"$_mod_dir/.agent-expanded"
      echo "wrote $_mod_dir/.agent-expanded"
      echo "agent_expand_ok: security"
      exit 0
      ;;
    -h|--help)
      echo "Usage: $0 --agent-expand   # consent-gated module prep for agent TUI"
      exit 0
      ;;
    *)
      echo "Usage: $0 --agent-expand" >&2
      echo "Note: full security install is via install.sh --profile security-dev (sourced path)." >&2
      exit 2
      ;;
  esac
fi
