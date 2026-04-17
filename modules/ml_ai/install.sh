#!/usr/bin/env bash
# ML/AI tools module installer

# Libraries are sourced by main installer script

MODULE_NAME="ml_ai"
CONFIG_FILE="$CONFIG_DIR/tools.yaml"

# miniconda is successor of mambaforge and offers
# both conda and mamba (drop in replacement with extra commands)
# Install Mambaforge/Conda
install_conda() {
    log_section "Installing Conda/Mamba"

    if command_exists conda; then
        log_info "Conda already installed"
        # return 0
    fi

    if command_exists mamba; then
        log_info "Mamba already installed"
        return 0
    fi

    local installer_name
    installer_name=$(yaml_get "$CONFIG_FILE" "tools.ml_ai.conda.installer")
    local source_url
    source_url=$(yaml_get "$CONFIG_FILE" "tools.ml_ai.conda.source")
    source_url=$(eval echo "$source_url")



    log_subsection "Downloading $installer_name"
    local installer_file="/tmp/$installer_name-$(date +%s).sh"

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would download $source_url"
        return 0
    fi

    curl -L "$source_url" -o "$installer_file" || {
        log_error "Failed to download Conda installer"
        return 1
    }

    log_subsection "Running $installer_name installer"
    bash "$installer_file" -b -p "$HOME/mamba" || {
        log_error "Failed to install Conda"
        rm -f "$installer_file"
        return 1
    }

    rm -f "$installer_file"

    # Add to PATH
    local bashrc="$HOME/.bashrc"
    if [[ -f "$bashrc" ]] && ! grep -q "mamba/bin" "$bashrc"; then
        echo 'export PATH="$HOME/mamba/bin:$PATH"' >> "$bashrc"
        log_debug "Added Conda to PATH in $bashrc"
    fi

    # Source for current session
    export PATH="$HOME/mamba/bin:$PATH"

    log_success "Conda/Mamba installed"
}

# Create conda environment
create_conda_env() {
    local env_name="$1"
    local python_version="$2"
    local packages=("${@:3}")

    log_subsection "Creating conda environment: $env_name"

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would create conda env: $env_name"
        return 0
    fi

    # Create environment
    mamba create -y -n "$env_name" python="$python_version" || {
        log_error "Failed to create mamba environment $env_name"
        return 1
    }

    # Install packages
    if [[ ${#packages[@]} -gt 0 ]]; then
        log_subsection "Installing packages in $env_name"
        mamba install -y -n "$env_name" "${packages[@]}" || {
            log_warn "Some packages failed to install in $env_name"
        }
    fi

    log_success "Conda environment $env_name created"
}

# Setup AI environment
setup_ai_environment() {
    local env_name="ai_amd"
    local python_version
    python_version=$(yaml_get "$CONFIG_FILE" "tools.ml_ai.conda.environments.ai_amd.python")

    # Get packages
    local packages=()
    mapfile -t packages < <(yaml_get "$CONFIG_FILE" "tools.ml_ai.conda.environments.ai_amd.packages[]")

    # Get conda packages
    local conda_packages=()
    mapfile -t conda_packages < <(yaml_get "$CONFIG_FILE" "tools.ml_ai.conda.environments.ai_amd.conda_packages[]")

    # Get pip packages
    local pip_packages=()
    mapfile -t pip_packages < <(yaml_get "$CONFIG_FILE" "tools.ml_ai.conda.environments.ai_amd.pip_packages[]")

    # Dynamically detect ROCm version for pip index
    local rocm_full
    if [ -f /opt/rocm/.info/version ]; then
        rocm_full=$(cat /opt/rocm/.info/version)
    else
        rocm_full=$(hipconfig --version 2>/dev/null || echo "7.2")
    fi
    local rocm_ver=$(echo "$rocm_full" | cut -d. -f1,2)
    local pip_index="https://download.pytorch.org/whl/rocm${rocm_ver}"

    # Check if environment already exists
    if mamba env list | grep -q "^$env_name "; then
        log_info "Environment $env_name already exists, updating..."
        mamba update -y -n "$env_name" --all || log_warn "Failed to update $env_name"
        return 0
    fi

    # Create environment
    create_conda_env "$env_name" "$python_version" "${packages[@]}"

    # Activate and install additional packages
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would set up $env_name environment"
        return 0
    fi

    log_subsection "Setting up $env_name environment"

    # Activate environment
    source "$HOME/mamba/bin/activate" "$env_name" || {
        log_error "Failed to activate $env_name environment"
        return 1
    }

    # Install conda packages
    if [[ ${#conda_packages[@]} -gt 0 ]]; then
        mamba install -y -c conda-forge "${conda_packages[@]}" || log_warn "Some conda packages failed"
    fi

    # Install pip packages
    if [[ ${#pip_packages[@]} -gt 0 ]]; then
        if [[ -n "$pip_index" ]]; then
            pip install --pre "${pip_packages[@]}" --index-url "$pip_index" || log_warn "Some pip packages failed"
        else
            pip install --pre "${pip_packages[@]}" || log_warn "Some pip packages failed"
        fi
    fi

    log_success "AI environment $env_name configured"
}

# Setup xAI experimental environment
setup_xai_environment() {
    local env_name="xai_exp"
    local python_version
    python_version=$(yaml_get "$CONFIG_FILE" "tools.ml_ai.conda.environments.xai_exp.python")

    # Get packages
    local packages=()
    mapfile -t packages < <(yaml_get "$CONFIG_FILE" "tools.ml_ai.conda.environments.xai_exp.packages[]")

    # Get conda packages
    local conda_packages=()
    mapfile -t conda_packages < <(yaml_get "$CONFIG_FILE" "tools.ml_ai.conda.environments.xAI_exp.conda_packages[]")

    # Get pip packages
    local pip_packages=()
    mapfile -t pip_packages < <(yaml_get "$CONFIG_FILE" "tools.ml_ai.conda.environments.xai_exp.pip_packages[]")

    # Dynamically detect ROCm version for pip index
    local rocm_full
    if [ -f /opt/rocm/.info/version ]; then
        rocm_full=$(cat /opt/rocm/.info/version)
    else
        rocm_full=$(hipconfig --version 2>/dev/null || echo "7.2")
    fi
    local rocm_ver=$(echo "$rocm_full" | cut -d. -f1,2)
    local pip_index="https://download.pytorch.org/whl/rocm${rocm_ver}"

    # Check if environment already exists
    if mamba env list | grep -q "^$env_name "; then
        log_info "Environment $env_name already exists, updating..."
        mamba update -y -n "$env_name" --all || log_warn "Failed to update $env_name"
        return 0
    fi

    # Create environment
    create_conda_env "$env_name" "$python_version" "${packages[@]}"

    # Activate and install additional packages
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would set up $env_name environment"
        return 0
    fi

    log_subsection "Setting up $env_name environment"

    # Activate environment
    source "$HOME/mamba/bin/activate" "$env_name" || {
        log_error "Failed to activate $env_name environment"
        return 1
    }

    # Install conda packages
    if [[ ${#conda_packages[@]} -gt 0 ]]; then
        mamba install -y -c conda-forge "${conda_packages[@]}" || log_warn "Some conda packages failed"
    fi

    # Install pip packages
    if [[ ${#pip_packages[@]} -gt 0 ]]; then
        if [[ -n "$pip_index" ]]; then
            pip install --pre "${pip_packages[@]}" --index-url "$pip_index" || log_warn "Some pip packages failed"
        else
            pip install --pre "${pip_packages[@]}" || log_warn "Some pip packages failed"
        fi
    fi

    log_success "xAI experimental environment $env_name configured"
}

# Test PyTorch installation
test_pytorch() {
    log_section "Testing PyTorch Installation"

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would test PyTorch installation"
        return 0
    fi

    # Test in ai_amd environment
    if mamba env list | grep -q "^ai_amd "; then
        log_subsection "Testing PyTorch in ai_amd environment"

        source "$HOME/mamba/bin/activate" ai_amd
        python -c "import torch; print('CUDA available:', torch.cuda.is_available())" || {
            log_warn "PyTorch test failed in ai_amd environment"
        }
        log_subsection "Torch cuda available"

        mamba deactivate
    fi

    # Test in xAI-exp environment
    if mamba env list | grep -q "^xai_exp "; then
        log_subsection "Testing PyTorch in xAI-exp environment"

        source "$HOME/mamba/bin/activate" xAI-exp
        python -c "import torch; print('CUDA available:', torch.cuda.is_available())" || {
            log_warn "PyTorch test failed in xAI-exp environment"
        }
        mamba deactivate
    fi
}

# Main ML/AI module function
install_ml_ai() {
    local category="${1:-full}"

    log_section "ML/AI Tools Module Installation ($category)"

    # Check if ML/AI tools should be installed
    local install_ml_ai
    install_ml_ai=$(yaml_get "$PROFILE_CONFIG/$PROFILE.yaml" "customizations.ml_ai")

    if [[ "$install_ml_ai" == "false" ]] || [[ "$category" != "full" ]]; then
        log_info "ML/AI tools installation skipped (category: $category, profile setting: $install_ml_ai)"
        return 0
    fi

    # Install Conda
    install_conda || return 1

    # Setup environments
    local environments
    mapfile -t environments < <(yaml_get "$PROFILE_CONFIG/$PROFILE.yaml" "customizations.ml_ai.conda.environments[]")

    if [[ "$environments" == "null" ]] || [[ ${#environments} -eq 0 ]]; then
        log_subsection "default envs"
        # Default environments
        setup_ai_environment
        setup_xai_environment
    else
        # Profile-specific environments
        log_subsection "profile envs"
        for env in "${environments[@]}"; do
            case "$env" in
                ai_amd) setup_ai_environment ;;
                xai_exp) setup_xai_environment ;;
            esac
        done
    fi

    # Test PyTorch
    test_pytorch

    log_success "ML/AI tools module installation completed ($category)"
}

# Export main function
export -f install_ml_ai