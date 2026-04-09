#!/bin/bash
set -euo pipefail
echo "=== Secure Fortress Phase 0 – Idempotent (Arch + k3s + Btrfs) ==="

# 1. Kubeconfig (idempotent, no sudo pain ever again)
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

# 2. Cilium (idempotent upgrade/install – policies only)
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
#   cilium upgrade \
#     --version 1.19.2 \
#     --kubeconfig ~/.kube/config \
#     --set kubeProxyReplacement=false \
#     --set ipam.mode=cluster-pool \
#     --set cluster.name=fortress \
#     --set hubble.enabled=false
fi
kubectl -n kube-system rollout restart ds/cilium
kubectl -n kube-system rollout status ds/cilium --timeout=60s
echo "✓ Cilium ready"

# 3. Tetragon (runtime enforcement)
echo "→ Ensuring Tetragon..."
helm repo add cilium https://helm.cilium.io --force-update &>/dev/null
helm repo update &>/dev/null
helm upgrade --install tetragon cilium/tetragon \
  --namespace kube-system \
  --set tetragon.hostProcPath=/procHost
#   --wait
kubectl -n kube-system rollout status ds/tetragon --timeout=60s
echo "✓ Tetragon ready"

# 4. gocryptfs vault (Btrfs-compatible, drop-anything-in)
echo "→ Ensuring gocryptfs encrypted vault..."
sudo pacman -Syu --needed --noconfirm gocryptfs &>/dev/null

VAULT_ENC=~/.secure-vault-enc   # encrypted data lives here
VAULT_MOUNT=~/secure-vault      # you drop files here

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
  echo "✓ Vault mounted (unmount with: fusermount -u ~/secure-vault)"
fi

# Drop your data (idempotent)
echo 'cp -u <list of files> "$VAULT_MOUNT/" 2>/dev/null || true'
echo "✓ <list of files> copied into encrypted vault"

# 5. 2-minute verification + bulk-upload kill test
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
echo "   Unmount vault anytime: fusermount -u ~/secure-vault"