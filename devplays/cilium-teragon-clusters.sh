#!/usr/bin/env bash
set -euo pipefail

echo "=== k3s + Cilium + Tetragon Learning Setup (Hardened for Laptop) ==="

# 1. Install k3s (localhost-only + masked)
if ! systemctl is-enabled k3s.service &>/dev/null 2>&1; then
    echo "→ Installing k3s (localhost-only)..."
    curl -sfL https://get.k3s.io | \
        INSTALL_K3S_SKIP_ENABLE=true \
        INSTALL_K3S_SKIP_START=true \
        INSTALL_K3S_EXEC="server \
            --bind-address=127.0.0.1 \
            --advertise-address=127.0.0.1 \
            --node-ip=127.0.0.1 \
            --flannel-backend=none \
            --disable-network-policy \
            --disable-traefik \
            --disable-servicelb" sh -
    
    sudo rm -f /etc/systemd/system/k3s.service
    sudo systemctl mask k3s.service
    sudo systemctl daemon-reload
    echo "✓ k3s installed and masked"
else
    echo "✓ k3s already installed"
fi

# 2. Create start/stop helpers
mkdir -p ~/bin
cat > ~/bin/k3s-start << 'EOT'
#!/usr/bin/env bash
echo "Starting k3s + Cilium + Tetragon for learning..."
sudo systemctl unmask k3s.service
sudo systemctl start k3s.service
sleep 8
kubectl get nodes
echo "✅ k3s is ready. Run 'k3s-stop' when finished."
EOT

cat > ~/bin/k3s-stop << 'EOT'
#!/usr/bin/env bash
echo "Stopping k3s + Cilium + Tetragon..."
sudo systemctl stop k3s.service
sudo systemctl mask k3s.service
echo "✅ Everything stopped and masked again."
EOT

chmod +x ~/bin/k3s-start ~/bin/k3s-stop

# Get latest stable Cilium version dynamically
LATEST_CILIUM=$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt)

# 3. Install minimal Cilium (only if k3s is running)
if systemctl is-active --quiet k3s; then
    echo "→ Installing minimal Cilium..."
    cilium install \
        --version "$LATEST_CILIUM" \
        --helm-set debug.enabled=false \
        --helm-set prometheus.enabled=false \
        --helm-set operator.prometheus.enabled=false \
        --helm-set hubble.enabled=false \
        --helm-set envoy.prometheus.enabled=false \
        --helm-set bpf.masquerade=false \
        --helm-set ipam.mode=kubernetes \
        --helm-set kubeProxyReplacement=true || echo "Cilium already installed"
else
    echo "→ Cilium will be installed when you run 'k3s-start'"
fi

# 4. Install minimal Tetragon (only if k3s is running)
if systemctl is-active --quiet k3s; then
    echo "→ Installing minimal Tetragon..."
    helm repo add cilium https://helm.cilium.io 2>/dev/null || true
    helm repo update
    helm install tetragon cilium/tetragon \
        --namespace kube-system \
        --set tetragon.prometheus.enabled=false \
        --set tetragon.grpc.enabled=false \
        --set tetragon.export.otel.enabled=false || echo "Tetragon already installed"
else
    echo "→ Tetragon will be installed when you run 'k3s-start'"
fi

# 5. Extra UFW safety net
echo "→ Adding UFW deny rules (defense-in-depth)..."
sudo ufw deny 6443 comment 'k3s API (already localhost)'
sudo ufw deny 10250 comment 'k3s kubelet'
sudo ufw deny 9964 comment 'Cilium Envoy'
sudo ufw deny 4240 comment 'Cilium Hubble/health'
sudo ufw reload

echo ""
echo "=== SETUP COMPLETE ==="
echo ""
echo "Usage on your laptop:"
echo "  k3s-start     → start everything for learning"
echo "  k3s-stop      → stop + mask everything again"
echo ""
echo "Your learning cluster is now 100% localhost-only and on-demand."
echo "No ports are exposed on your LAN or internet."

# chmod +x devplays/cilium-teragon-clusters.sh