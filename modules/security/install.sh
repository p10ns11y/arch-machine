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
        --set tetragon.hostProcPath=/procHost \
        --wait >/dev/null 2>&1 || {
        log_error "Failed to install Tetragon"
        return 1
    }

    kubectl -n "$namespace" rollout status ds/tetragon --timeout=60s || {
        log_warn "Tetragon rollout did not complete within timeout"
    }

    log_success "Tetragon installed"
}

# Setup encrypted vault (gocryptfs)
setup_encrypted_vault() {
    log_section "Setting up Encrypted Vault"

    local vault_enc="$HOME/.securevaultenc"
    local vault_mount="$HOME/securevault"

    if [[ -d "$vault_enc" ]]; then
        log_info "Encrypted vault already initialized"
    else
        if [[ "$DRY_RUN" == "true" ]]; then
            log_info "[DRY RUN] Would initialize encrypted vault"
        else
            mkdir -p "$vault_enc"
            log_subsection "Initializing gocryptfs vault (you will be prompted for password)"
            gocryptfs -init -scryptn=15 "$vault_enc" || {
                log_error "Failed to initialize gocryptfs vault"
                return 1
            }
            log_success "Encrypted vault initialized"
        fi
    fi

    if mountpoint -q "$vault_mount"; then
        log_info "Vault already mounted"
        return 0
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would mount encrypted vault"
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

    log_success "Security tools module installation completed ($category)"
}

# Export main function
export -f install_security