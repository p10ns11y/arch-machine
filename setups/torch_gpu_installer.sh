#!/bin/bash
set -e

echo "=== Automated PyTorch + ROCm Installer (for your Ryzen AI 840M) ==="

# 1. Detect ROCm version
if [ -f /opt/rocm/.info/version ]; then
    ROCM_FULL=$(cat /opt/rocm/.info/version)
else
    ROCM_FULL=$(hipconfig --version 2>/dev/null || echo "7.2")
fi
ROCM_VER=$(echo "$ROCM_FULL" | cut -d. -f1,2)
INDEX_URL="https://download.pytorch.org/whl/rocm${ROCM_VER}"
echo "✅ Detected ROCm ${ROCM_VER} → using ${INDEX_URL}"

# 2. Detect GPU and set HSA_OVERRIDE automatically
GFX=$(rocminfo 2>/dev/null | grep -o 'gfx[0-9][0-9][0-9][0-9]' | head -1)
# Automatically handles gfx1100, gfx1101, gfx1102… (all Ryzen AI 300 series)
# and prepares for future gfx12xx (RDNA 4) if you ever upgrade
if [[ "$GFX" =~ ^gfx11 ]]; then
    OVERRIDE="11.0.0"
    echo "✅ Detected ${GFX} (RDNA 3.5 APU / Radeon 840M family) → setting HSA_OVERRIDE_GFX_VERSION=${OVERRIDE}"
elif [[ "$GFX" =~ ^gfx12 ]]; then
    OVERRIDE="12.0.0"
    echo "✅ Detected ${GFX} (RDNA 4) → setting HSA_OVERRIDE_GFX_VERSION=${OVERRIDE}"
else
    OVERRIDE=""
    echo "✅ Detected ${GFX:-unknown GPU} — no HSA override needed (natively supported in ROCm ${ROCM_VER})"
fi

# 3. Create / activate virtual environment (keeps everything clean)
VENV_DIR="$HOME/pytorch-rocm-env"
if [ ! -d "$VENV_DIR" ]; then
    python -m venv "$VENV_DIR"
    echo "✅ Created new venv at ${VENV_DIR}"
fi
source "$VENV_DIR/bin/activate"

# 4. Install / reinstall PyTorch (always matches current ROCm)
pip install --upgrade pip
pip install torch torchvision torchaudio --index-url "$INDEX_URL"

# 5. Create a tiny activation helper so you never remember the export
cat > "$VENV_DIR/activate-rocm.sh" << EOF
#!/bin/bash
source "${VENV_DIR}/bin/activate"
export HSA_OVERRIDE_GFX_VERSION=${OVERRIDE}
echo "PyTorch ROCm environment activated (HSA_OVERRIDE_GFX_VERSION=${OVERRIDE})"
EOF
chmod +x "$VENV_DIR/activate-rocm.sh"

echo ""
echo "🎉 DONE!"
echo "To use PyTorch in the future just run:"
echo "    source ${VENV_DIR}/activate-rocm.sh"
echo ""
echo "Test it now:"
echo "    python -c \"import torch; print('GPU ready:', torch.cuda.is_available()); print(torch.cuda.get_device_name(0))\""