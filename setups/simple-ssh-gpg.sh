#!/usr/bin/env bash
# Secure SEPARATE SSH + GPG setup script for Arch Linux (November 2025)
# → Traditional approach: one Ed25519 SSH key + separate ECC GPG key (Ed25519 signing + Cv25519 encryption)
# → Two passphrases (one for SSH, one for GPG) → simpler daily use, no gpg-agent SSH quirks
# → Maximum security: 100 KDF rounds on SSH key, very high s2k-count on GPG, hardened configs

set -euo pipefail

echo "=== Arch Linux separate SSH + GPG secure setup (traditional & bulletproof) ==="
echo "Run as normal user"

# 1. Install everything needed
sudo pacman -Syu --noconfirm
sudo pacman -S --needed gnupg openssh pinentry gcr haveged

# Optional better pinentry (uncomment your DE/WM)
# sudo pacman -S pinentry-gtk   # GNOME/XFCE/etc
# sudo pacman -S pinentry-qt    # KDE
# sudo pacman -S pinentry-bemenu  # sway/i3/wayland minimal

# 2. Ensure entropy (helps key generation not stall)
sudo systemctl start haveged
sudo systemctl enable haveged

# 3. Create & harden .gnupg
mkdir -p ~/.gnupg
chmod 700 ~/.gnupg

# 4. Hardened gpg.conf
cat <<'EOF' > ~/.gnupg/gpg.conf
no-emit-version
no-comments
keyid-format 0xlong
with-fingerprint
use-agent
personal-cipher-preferences AES256
personal-digest-preferences SHA512
cert-digest-algo SHA512
s2k-cipher-algo AES256
s2k-digest-algo SHA512
s2k-count 65011712
charset utf-8
fixed-list-mode
disable-cipher-algo 3DES
require-cross-certification
default-preference-list SHA512 SHA384 SHA256 AES256 AES192 AES CAMELLIA256 CAMELLIA192 ZLIB BZIP2 ZIP Uncompressed
EOF

# 5. gpg-agent.conf (long cache only if you fully trust the laptop)
cat <<'EOF' > ~/.gnupg/gpg-agent.conf
default-cache-ttl 28800        # 8 hours
max-cache-ttl 34560000
allow-loopback-pinentry
pinentry-program /usr/bin/pinentry-curses   # change if you installed gtk/qt/bemenu version
EOF

chmod 600 ~/.gnupg/*

# Kill agent to reload config
gpgconf --kill gpg-agent

echo "✓ GPG config done"

# 6. Generate ultra-secure Ed25519 SSH key (100 KDF rounds = extremely brute-force resistant)
echo ""
echo "Generating SSH key – this is interactive"
ssh-keygen -t ed25519 -a 100 -f ~/.ssh/id_ed25519 -C "p10ns11y@users.noreply.github.com $(date +%Y)"
# → Use a very strong passphrase (diceware 7+ words or 30+ random chars)
# → Do NOT use -N "" empty passphrase on a laptop

chmod 600 ~/.ssh/id_ed25519
chmod 644 ~/.ssh/id_ed25519.pub

# Harden ~/.ssh
chmod 700 ~/.ssh

# Optional: add to ~/.ssh/config for extra security
cat <<'EOF' >> ~/.ssh/config

Host *
  AddKeysToAgent yes
  IdentitiesOnly yes
  PasswordAuthentication no
  ChallengeResponseAuthentication no
  PubkeyAuthentication yes
  KexAlgorithms curve25519-sha256,curve25519-sha256@libssh.org,diffie-hellman-group16-sha512
  Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com
  MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com
  HostKeyAlgorithms ssh-ed25519,ecdsa-sha2-nistp256,ecdsa-sha2-nistp384,ecdsa-sha2-nistp521
EOF

echo "✓ SSH key generated with 100 KDF rounds"

# 7. Generate modern ECC GPG master key + encryption subkey
echo ""
echo "Now generating GPG key – follow these exact choices for maximum security:"
echo ""
echo "Run: gpg --expert --full-generate-key"
echo ""
echo "1. Type → 10 (ECC with custom capabilities)"
echo "2. Capabilities → S A (Sign & Authenticate only – Encrypt will be toggled off)"
echo "    Then type → Q"
echo "3. Curve → 9 (Ed25519)"
echo "4. Expiration → 0 or 3y/5y"
echo "5. Name / Email / Comment → your real data"
echo "6. Passphrase → VERY strong (different from SSH passphrase!)"
echo ""
echo "After master key → add encryption subkey:"
echo "gpg --edit-key your@email.com"
echo "gpg> addkey"
echo "→ 11 (ECC encrypt only)"
echo "→ Curve → 1 (Curve25519)"
echo "→ Expiration → 1y or 2y"
echo "→ Same strong passphrase"
echo "gpg> save"

# 8. Git config for commit signing
read -p "Enter your GPG key ID (long format, e.g. 0x123456789ABCDEF): " gpgkey
git config --global commit.gpgsign true
git config --global user.signingkey "$gpgkey"

# 9. Generate revocation certificate NOW (critical!)
gpg --output ~/gpg-revoke-$gpgkey.asc --gen-revoke "$gpgkey"
echo "→ Move ~/gpg-revoke-$gpgkey.asc to an offline USB in a safe place RIGHT NOW"

echo ""
echo "=== ALL DONE ==="
echo ""
echo "SSH public key to add to GitHub/GitLab/servers:"
cat ~/.ssh/id_ed25519.pub
echo ""
echo "Test everything:"
echo "ssh-add -L                # should show your ed25519 key"
echo "ssh -T git@github.com     # should say Hi username!"
echo "echo test | gpg --clearsign  # should work"
echo ""
echo "You now have the most secure traditional & secure setup possible in 2025."
echo "Two strong passphrases, separate keys, no gpg-agent SSH complexity."

# YubiKey migration ready:
# When you get a YubiKey 5, just say – I have a full script to move authentication + signing subkeys to it while keeping encryption on disk (best of both worlds).
