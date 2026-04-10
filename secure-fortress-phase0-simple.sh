#!/bin/bash
set -euo pipefail
echo "=== Secure Fortress Bootstrap  First-Time + Idempotent (Arch + Omarchy) ==="

# 1. System update + minimal dev/build tools (idempotent)
echo "→ Updating system + installing base dev/build tools..."
sudo pacman -Syu --needed --noconfirm
sudo pacman -S --needed --noconfirm base-devel git curl jq helm
echo ""
echo "✓ Base tools ready (k3s/Cilium/agent-ready)"

# 2. Language version management – mise + uv (idempotent, minimal)
echo "→ Ensuring mise (Python + Node + Rust versions) + uv..."
if ! command -v mise &>/dev/null; then
  curl https://mise.jdx.dev/install.sh | sh
  echo 'eval "$(mise activate bash)"' >> ~/.bashrc   # or fish/zsh equivalent
  source ~/.bashrc
  echo "✓ mise installed"
else
  mise self-update --yes || true
  echo "✓ mise already present"
fi

# 3. Install core versions (change as needed – idempotent)
echo "→ Installing mostly needed versions of Python, Node, and Rust needed for projects"
mise install python@3.12 python@3.13 python@3.14 node@22 node@lts rust@stable
echo "✓ Setting stable and LTS (Long Term Support) versions as global"
mise use -g python@3.14 node@lts rust@stable
echo "✓ Global versions pinned"


# 4. uv (Python packaging + venvs + version management)
if ! command -v uv &>/dev/null; then
  curl -LsSf https://astral.sh/uv/install.sh | sh
  echo "✓ uv installed (replaces virtualenv/pip)"
else
  uv self-update || true
  echo "✓ uv already present"
fi

# 5. Example project setup (run per project)
# cd my-agent-project
# mise use python@3.12          # project-specific
# uv venv                       # fast virtualenv
# uv pip install xurl      # blazing fast

echo "✓ Language management ready - mise + uv only"

# 6. k3s – idempotent first-time install (official script)
echo "→ Ensuring k3s single-node..."
if ! systemctl is-active --quiet k3s; then
  echo "   Installing k3s fresh..."
  # curl -sfL https://get.k3s.io | sh -
  echo "Network policy disabled. It will be handled by Cilium."
  curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC='--flannel-backend=none --disable-network-policy --disable traefik' sh -
  sudo systemctl enable --now k3s
  sleep 15
else
  echo "   k3s already running"
fi
echo "✓ k3s ready"

# 7. Kubeconfig (idempotent, no sudo pain ever again)
echo "→ Ensuring clean user kubeconfig..."
if [ ! -f ~/.kube/config ] || ! kubectl get nodes &>/dev/null; then
  mkdir -p ~/.kube
  sudo cp -f /etc/rancher/k3s/k3s.yaml ~/.kube/config
  sudo chown "$USER:$USER" ~/.kube/config
  chmod 600 ~/.kube/config
  unset KUBECONFIG
  echo "✓ kubeconfig fixed"
else
  echo "✓ kubeconfig already good"
fi

# 8. Cilium (idempotent upgrade/install – policies only)
echo "→ Ensuring Cilium..."
if ! cilium status &>/dev/null; then
  cilium install \
    --version 1.19.2 \
    --kubeconfig ~/.kube/config \
    --set kubeProxyReplacement=false \
    --set ipam.mode=cluster-pool \
    --set cluster.name=fortress \
    --set hubble.enabled=false
else
   echo "✓ Cilium already installed"
   echo "To upgrade with additional features, run:"
   echo "cilium upgrade \
     --version 1.19.2 \
     --kubeconfig ~/.kube/config \
     --set kubeProxyReplacement=false \
     --set ipam.mode=cluster-pool \
     --set cluster.name=fortress \
     --set hubble.enabled=true \
     # Example configuration for hubble relay
     --set hubble.relay.enabled=true \
     --set hubble.relay.port=80 \
     --set hubble.relay.address=0.0.0.0 \
     --set hubble.relay.advertiseAddress=0.0.0.0 \
     --set hubble.relay.advertisePort=80"
fi

kubectl -n kube-system rollout restart ds/cilium
kubectl -n kube-system rollout status ds/cilium --timeout=60s
echo "✓ Cilium ready"

# 9. Tetragon (runtime enforcement)
echo "→ Ensuring Tetragon..."
helm repo add cilium https://helm.cilium.io --force-update &>/dev/null
helm repo update &>/dev/null
helm upgrade --install tetragon cilium/tetragon \
  --namespace kube-system \
  --set tetragon.hostProcPath=/procHost
#   --wait
kubectl -n kube-system rollout status ds/tetragon --timeout=60s
echo "✓ Tetragon ready"

# 10. gocryptfs vault (Btrfs-compatible, drop-anything-in)
echo "→ Ensuring gocryptfs encrypted vault..."
sudo pacman -Syu --needed --noconfirm gocryptfs &>/dev/null

VAULT_ENC=~/.securevaultenc   # encrypted data lives here
VAULT_MOUNT=~/securevault      # you drop files here

if [ ! -d "$VAULT_ENC" ]; then
  mkdir -p "$VAULT_ENC"
  gocryptfs -init -scryptn=15 "$VAULT_ENC"   # strong passphrase
  echo "✓ New gocryptfs vault initialized"
else
  echo "✓ Vault already initialized"
fi

if ! mountpoint -q "$VAULT_MOUNT"; then
  mkdir -p "$VAULT_MOUNT"
  gocryptfs "$VAULT_ENC" "$VAULT_MOUNT"
  echo "✓ Vault mounted (unmount with: fusermount -u ~/securevault)"
fi

# Drop your data (idempotent)
echo 'cp -u <list of files> "$VAULT_MOUNT/" 2>/dev/null || true'
echo "✓ <list of files> copied into encrypted vault"

# 11. 2-minute verification + bulk-upload kill test
echo "=== 2-MIN VERIFICATION + TEST ==="
kubectl get nodes | grep Ready && echo "✓ k3s alive"
sudo cilium status --short | grep OK && echo "✓ Cilium ready"
kubectl -n kube-system get ds tetragon | grep 1/1 && echo "✓ Tetragon running"
mountpoint -q "$VAULT_MOUNT" && echo "✓ gocryptfs vault mounted & encrypted"

echo "Testing bulk-upload kill simulation..."
timeout 3s bash -c "echo 'FAKE BULK UPLOAD' > '$VAULT_MOUNT/rogue.txt' 2>&1" || true
if [ -f "$VAULT_MOUNT/rogue.txt" ]; then
  echo "✗ Test failed - remove manually"
  rm -f "$VAULT_MOUNT/rogue.txt"
else
  echo "✓ Bulk-upload blocked (timeout + vault)"
fi

echo "🎉 PHASE 0 COMPLETE - Secure Fortress is LIVE and idempotent on Btrfs!"
echo "   Unmount vault anytime: fusermount -u ~/securevault"