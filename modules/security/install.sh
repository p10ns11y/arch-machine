#!/usr/bin/env bash
# Security tools module installer

# Libraries are sourced by main installer script

MODULE_NAME="security"
CONFIG_FILE="$CONFIG_DIR/tools.yaml"

# Install k3s (lightweight Kubernetes)
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

    local config
    config=$(yaml_get "$CONFIG_FILE" "tools.security.kubernetes.k3s.config")

    local exec_args=""
    if [[ "$config" == *"flannel_backend"* ]]; then
        exec_args="$exec_args --flannel-backend=none"
    fi
    if [[ "$config" == *"disable_network_policy"* ]]; then
        exec_args="$exec_args --disable-network-policy"
    fi
    if [[ "$config" == *"disable_traefik"* ]]; then
        exec_args="$exec_args --disable-traefik"
    fi

    log_subsection "Installing k3s with args: $exec_args"

    # Install k3s
    curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="$exec_args" sh - || {
        log_error "Failed to install k3s"
        return 1
    }

    sudo systemctl enable --now k3s || {
        log_error "Failed to enable k3s service"
        return 1
    }

    sleep 15  # Wait for k3s to start

    log_success "k3s installed and started"
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

# Install Cilium
install_cilium() {
    log_section "Installing Cilium"

    if cilium status &>/dev/null; then
        log_info "Cilium already installed"
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

    log_subsection "Installing Cilium $version"

    cilium install \
        --version "$version" \
        --kubeconfig ~/.kube/config \
        --set kubeProxyReplacement=false \
        --set ipam.mode=cluster-pool \
        --set cluster.name=fortress \
        --set hubble.enabled=false || {
        log_error "Failed to install Cilium"
        return 1
    }

    # Wait for Cilium to be ready
    kubectl -n kube-system rollout restart ds/cilium
    kubectl -n kube-system rollout status ds/cilium --timeout=60s || {
        log_warn "Cilium rollout did not complete within timeout"
    }

    log_success "Cilium installed"
}

# Install Tetragon
install_tetragon() {
    log_section "Installing Tetragon"

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would install Tetragon"
        return 0
    fi

    # Add Helm repo
    helm repo add cilium https://helm.cilium.io --force-update >/dev/null 2>&1
    helm repo update >/dev/null 2>&1

    local namespace
    namespace=$(yaml_get "$CONFIG_FILE" "tools.security.tetragon.namespace")

    helm upgrade --install tetragon cilium/tetragon \
        --namespace "$namespace" \
        --set tetragon.hostProcPath=/procHost >/dev/null 2>&1 || {
        log_error "Failed to install Tetragon"
        return 1
    }

    # Timer visualization could be better
    # Async/await flow if possible
    kubectl -n "$namespace" rollout status ds/tetragon --timeout=20s || {
        log_warn "Tetragon rollout did not complete within timeout"
    }

    log_success "Tetragon installed"
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
install_pip_audit() {
    log_section "Installing pip-audit"

    if command_exists pip-audit; then
        log_info "pip-audit already installed"
        return 0
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would install pip-audit"
        return 0
    fi

    log_subsection "Installing pip-audit via pip"
    python3 -m pip install --upgrade pip-audit --quiet || {
        log_error "Failed to install pip-audit"
        return 1
    }

    log_success "pip-audit installed"
}

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
setup_encrypted_vault() {
    local vault_enc="${1:-$HOME/.securevaultenc}"
    local vault_mount="${2:-$HOME/securevault}"

    log_section "Setting up Encrypted Vault"

    # Validate paths
    if [[ -z "$vault_enc" || -z "$vault_mount" ]]; then
        log_error "Usage: setup_encrypted_vault [encrypted_dir] [mount_point]"
        log_error "Example: setup_encrypted_vault ~/.myvault ~/.vault"
        return 1
    fi

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

    if mountpoint -q "$vault_mount"; then
        log_info "Vault already mounted at $vault_mount"
        return 0
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would mount encrypted vault at $vault_mount"
        return 0
    fi

    mkdir -p "$vault_mount"
    log_subsection "Mounting encrypted vault (you will be prompted for password)"
    gocryptfs "$vault_enc" "$vault_mount" || {
        log_error "Failed to mount encrypted vault"
        return 1
    }

    log_success "Encrypted vault mounted at $vault_mount"
    log_info "Use 'fusermount -u $vault_mount' to unmount"
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

    # Setup encrypted vault
    local install_encrypted_storage
    install_encrypted_storage=$(yaml_get "$PROFILE_CONFIG/$PROFILE.yaml" "customizations.security.encrypted_storage")
    if [[ "$install_encrypted_storage" == "true" ]]; then
        setup_encrypted_vault || return 1
    fi

    # Install vulnerability scanning tools
    if [[ "$category" == "full" ]]; then
        install_osv_scanner || return 1
        install_grype || return 1
        install_syft || return 1
        install_pip_audit || return 1
        install_cargo_audit || return 1
        install_vector || return 1
        install_toon || return 1
    fi

    log_success "Security tools module installation completed ($category)"
}

# Export functions for standalone use
export -f setup_encrypted_vault
export -f install_security