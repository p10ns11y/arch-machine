#!/usr/bin/env bash
set -euo pipefail

CPU_MODEL=$(grep -m1 "model name" /proc/cpuinfo | awk -F: '{print $2}' | sed 's/^[ \t]*//')
IGPU_NAME=$(rocminfo 2>/dev/null | grep -m1 "Name:" | awk '{print $2 " " $3 " " $4 " " $5}' || echo "Not detected")
ROCM_TARGET=$(rocminfo 2>/dev/null | grep -A1 "Name: gfx" | grep -o "gfx[0-9a-f]*" | head -1 || echo "unknown")
TOTAL_RAM=$(free -h | awk '/^Mem:/ {print $2}')
DATE=$(date '+%B %d, %Y')

echo "🚀 Smart ML/AI Development Setup ($DATE)"
echo "   Detected: $CPU_MODEL"
echo "             $IGPU_NAME ($ROCM_TARGET) + $TOTAL_RAM RAM"
echo

# 1. Pre-flight hardware & system checks
echo "1. Running diagnostics..."

rocminfo >/dev/null 2>&1 && ROCM_OK=1 || ROCM_OK=0
nvidia-smi >/dev/null 2>&1 && NVIDIA=1 || NVIDIA=0
[[ -d "$HOME/miniconda" || -d "$HOME/mambaforge" || -d "$HOME/.conda" ]] && CONDA_INSTALLED=1 || CONDA_INSTALLED=0
command -v code >/dev/null && VSCODE_OK=1 || VSCODE_OK=0
command -v docker >/dev/null && DOCKER_OK=1 || DOCKER_OK=0
[[ "$SHELL" = */zsh ]] && ZSH=1 || ZSH=0

echo "   ROCm detected        : $( ((ROCM_OK)) && echo "YES (gfx1152)" || echo "NO" )"
echo "   Conda/Mamba present  : $( ((CONDA_INSTALLED)) && echo "YES" || echo "NO" )"
echo "   VS Code              : $( ((VSCODE_OK)) && echo "YES" || echo "NO" )"
echo "   Docker               : $( ((DOCKER_OK)) && echo "YES" || echo "NO" )"
echo "   Current shell        : $SHELL"
echo

# 2. Update system (always safe & fast on Arch)
echo "2. Installing/updating system packages..."
sudo pacman -Syu --noconfirm --quiet

# Remove power-profiles-daemon if present (conflicts with tlp)
if pacman -Qi power-profiles-daemon &>/dev/null; then
    echo "   Removing power-profiles-daemon (conflicts with tlp)..."
    sudo pacman -Rdd --noconfirm power-profiles-daemon || true
fi


sudo pacman -S --quiet --needed base-devel git curl wget reflector rocm-hip-sdk rocm-opencl-sdk rocminfo code docker tlp tlp-rdw ufw zsh

# Enable services
sudo systemctl enable --now docker ufw tlp
sudo systemctl enable tlp-suspend.service 2>/dev/null || true   # ignore if missing
sudo usermod -aG docker,video,render "$USER"

# 4. Create/recreate the AI environment with ROCm
if [ ! -d "$HOME/miniconda/envs/ai-amd" ]; then
    echo "Creating fresh ai-amd environment with PyTorch + ROCm..."
    conda create -y -n ai-amd python=3.12 jupyterlab numpy pandas matplotlib seaborn scikit-learn xgboost lightgbm polars duckdb optuna
    source "$HOME/miniconda/bin/activate" ai-amd
    conda install -y -c conda-forge wandb
    pip install --pre torch torchvision torchaudio --index-url https://download.pytorch.org/whl/rocm6.4/
  else
    echo "ai-amd environment already exists – updating..."
    conda update -y -n ai-amd --all
fi

# Not affiliated with X's xAI yet!
# xAI experimental env with pip PyTorch (official ROCm way) with latest python version
if [ ! -d "$HOME/miniconda/envs/xAI-exp" ]; then
    echo "Creating xAI + PyTorch via pip (ROCm official method)..."
    conda create -y -n xAI-exp python=3.14
    source "$HOME/miniconda/bin/activate" xAI-exp
    echo "Installing wandb form conda-forge channel"
    conda install -y -c conda-forge wandb
    echo "Installing torch"
    pip install --pre torch torchvision torchaudio --index-url https://download.pytorch.org/whl/rocm6.4/
    echo "Installing data science packages"
    pip install jupyterlab numpy pandas matplotlib seaborn scikit-learn xgboost duckdb tqdm polars lightgbm
else
    echo "xAI-exp exists – updating..."
    conda update -y -n xAI-exp --all
fi

echo
echo "✅ All done! Your Ryzen AI laptop is now a perfect ML/AI machine."
echo
echo "Next steps:"
echo "   1. Log out & back in (or reboot) for group changes (docker, render)"
echo "   2. If you chose zsh → open new terminal and run the Powerlevel10k wizard"
echo "   3. Test: conda activate ai-amd && python -c 'import torch; print(torch.cuda.is_available())'  # → True"
echo
echo "Next: Setup Ollama + local LLMs on your NPU 🚀 (./local_ais.sh)"
