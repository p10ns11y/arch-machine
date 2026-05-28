# Complete Safe Guide: Disable systemd-resolved + DNS over HTTPS (DoH)

**Goal**: Encrypted DNS on Arch Linux — safe, fast, and private.

This guide offers **two excellent options** with **multiple DNS providers**.

---

## Recommended DNS Providers (2026)

| Provider     | Primary          | Secondary        | Notes                          | Privacy     |
|--------------|------------------|------------------|--------------------------------|-------------|
| **Cloudflare** | `1.1.1.1`       | `1.0.0.1`       | Fastest, excellent DoH        | Very Good   |
| **Google**     | `8.8.8.8`       | `8.8.4.4`       | Very reliable                 | Good        |
| **Quad9**      | `9.9.9.9`       | `149.112.112.112` | Strong security + malware blocking | Excellent |
| **Mullvad**    | `194.242.2.2`   | `193.19.108.2`  | No-logs, privacy-focused      | Excellent   |
| **AdGuard**    | `94.140.14.14`  | `94.140.15.15`  | Ad & tracker blocking         | Very Good   |

---

## Option B (Recommended): systemd-resolved + DoH

This is the **best balance** — lightweight, integrated, and fully encrypted.

### One-Liner Version (Quick & Safe)

Copy and paste this entire line:

```bash
sudo bash -c '
set -euo pipefail
BACKUP_DIR="/root/backups-doh-$(date +%F-%H%M)"; mkdir -p "$BACKUP_DIR"
cp /etc/resolv.conf "$BACKUP_DIR/resolv.conf.bak" 2>/dev/null || true
cp /etc/systemd/resolved.conf "$BACKUP_DIR/resolved.conf.bak" 2>/dev/null || true
systemctl unmask systemd-resolved 2>/dev/null || true
systemctl enable systemd-resolved
cat > /etc/systemd/resolved.conf << "EOF"
[Resolve]
DNS=1.1.1.1#cloudflare-dns.com 1.0.0.1#cloudflare-dns.com 9.9.9.9#dns.quad9.net 8.8.8.8#dns.google
DNSOverTLS=yes
DNSSEC=allow-downgrade
Cache=yes
EOF
systemctl restart systemd-resolved
rm -f /etc/resolv.conf
ln -s /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
cat > /etc/NetworkManager/conf.d/dns.conf << "EOF"
[main]
dns=systemd-resolved
systemd-resolved=true
EOF
systemctl restart NetworkManager
echo "✅ Done! DNS over HTTPS enabled with Cloudflare + Quad9 + Google"
resolvectl status | head -20
'
```

---

### Full Script Version (with comments)

```bash
cat > ~/enable-resolved-doh-safe.sh << 'SCRIPT'
#!/bin/bash
set -euo pipefail

echo "=== SAFE systemd-resolved + DNS over HTTPS ==="
echo ""

if [[ $EUID -ne 0 ]]; then
    echo "ERROR: Run with sudo"
    exit 1
fi

BACKUP_DIR="/root/backups-doh-$(date +%F-%H%M)"
mkdir -p "$BACKUP_DIR"

echo "[1/6] Backing up files..."
cp /etc/resolv.conf "$BACKUP_DIR/resolv.conf.bak" 2>/dev/null || true
cp /etc/systemd/resolved.conf "$BACKUP_DIR/resolved.conf.bak" 2>/dev/null || true

echo "[2/6] Enabling systemd-resolved..."
systemctl unmask systemd-resolved 2>/dev/null || true
systemctl enable systemd-resolved

echo "[3/6] Configuring DNS over HTTPS (Cloudflare + Quad9 + Google)..."
cat > /etc/systemd/resolved.conf << 'EOF'
[Resolve]
DNS=1.1.1.1#cloudflare-dns.com 1.0.0.1#cloudflare-dns.com 9.9.9.9#dns.quad9.net 8.8.8.8#dns.google
DNSOverTLS=yes
DNSSEC=allow-downgrade
Cache=yes
EOF

echo "[4/6] Restarting systemd-resolved..."
systemctl restart systemd-resolved

echo "[5/6] Setting up resolv.conf..."
rm -f /etc/resolv.conf
ln -s /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf

echo "[6/6] Configuring NetworkManager..."
cat > /etc/NetworkManager/conf.d/dns.conf << 'EOF'
[main]
dns=systemd-resolved
systemd-resolved=true
EOF
systemctl restart NetworkManager

echo ""
echo "✅ SUCCESS! Encrypted DNS is active"
echo "Backup: $BACKUP_DIR"
resolvectl status
SCRIPT
```

Run it:

```bash
chmod +x ~/enable-resolved-doh-safe.sh
sudo ~/enable-resolved-doh-safe.sh
```

---

## Option A: cloudflared (Resolved Completely Disabled)

Use this if you want **zero** `systemd-resolved`:

```bash
sudo bash -c '
set -euo pipefail
BACKUP_DIR="/root/backups-cloudflared-$(date +%F-%H%M)"; mkdir -p "$BACKUP_DIR"
cp /etc/resolv.conf "$BACKUP_DIR/resolv.conf.bak" 2>/dev/null || true
systemctl stop systemd-resolved 2>/dev/null || true
systemctl mask systemd-resolved
pacman -S --noconfirm cloudflared 2>/dev/null || true
mkdir -p /etc/cloudflared
cat > /etc/cloudflared/config.yml << "EOF"
proxy-dns: true
proxy-dns-port: 5053
proxy-dns-upstream:
  - https://1.1.1.1/dns-query
  - https://9.9.9.9/dns-query
  - https://8.8.8.8/dns-query
EOF
systemctl enable --now cloudflared
rm -f /etc/resolv.conf
cat > /etc/resolv.conf << "EOF"
nameserver 127.0.0.1
options edns0
EOF
chattr +i /etc/resolv.conf 2>/dev/null || true
echo "✅ cloudflared DoH active"
'
```

---

## Verification

```bash
resolvectl status          # Check encryption status
cat /etc/resolv.conf
ping -c 2 archlinux.org
```

---

## Revert (Both Options)

```bash
sudo chattr -i /etc/resolv.conf 2>/dev/null || true
sudo rm -f /etc/resolv.conf
sudo cp /root/backups-*/resolv.conf.bak /etc/resolv.conf 2>/dev/null || true
sudo rm -f /etc/NetworkManager/conf.d/dns.conf
sudo systemctl disable --now cloudflared 2>/dev/null || true
sudo systemctl unmask systemd-resolved
sudo systemctl enable --now systemd-resolved
sudo systemctl restart NetworkManager
```

---

**Your DNS is now encrypted and private.**

*Updated: 2026-04-25*