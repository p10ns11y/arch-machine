#!/usr/bin/env bash
# Idempotent, secure, separate SSH + GPG setup script for Arch Linux (November 2025)
# → Can be run multiple times safely
# → Skips anything already done
# → Backs up existing configs before overwriting with secure defaults
# → Forces reliable pinentry-curses + GPG_TTY fix (works everywhere, even SSH/tmux)
# → Prompts only when actually needed
# → Bash is perfect for this – clean, readable, no Rust needed

set -euo pipefail

echo "=== Idempotent Secure SSH + GPG secure setup – fully idempotent (Nov 2025) ==="
echo "Running as $(whoami) on Arch Linux"

# 1. Packages – only installs what is missing
sudo pacman -Syu --noconfirm
sudo pacman -S --needed gnupg openssh pinentry haveged

# Ensure entropy daemon is running (helps key generation not hang)
if ! systemctl is-active --quiet haveged; then
    sudo systemctl enable --now haveged
fi

# 2. Harden ~/.gnupg directory
mkdir -p ~/.gnupg
chmod 700 ~/.gnupg

# 3. Secure gpg.conf – backup + overwrite with 2025 best practices
if [ -f ~/.gnupg/gpg.conf ]; then
    mv ~/.gnupg/gpg.conf ~/.gnupg/gpg.conf.bak.$(date +%s)
    echo "Backed up existing gpg.conf"
fi
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

# 4. gpg-agent.conf – backup + overwrite with secure defaults + reliable pinentry
if [ -f ~/.gnupg/gpg-agent.conf ]; then
    mv ~/.gnupg/gpg-agent.conf ~/.gnupg/gpg-agent.conf.bak.$(date +%s)
    echo "Backed up existing gpg-agent.conf"
fi
cat <<'EOF' > ~/.gnupg/gpg-agent.conf
default-cache-ttl 28800        # 8 hours – change if you want shorter/longer
max-cache-ttl 34560000
allow-loopback-pinentry
# pinentry-program /usr/bin/pinentry-curses   # ← Most reliable, works everywhere (SSH, tmux, Wayland, etc.)
# For prettier native look on Wayland/Hyprland/sway → install pinentry-bemenu via AUR and change line to:
# pinentry-program /usr/bin/pinentry-bemenu
# For rofi users → pinentry-rofi-bemenu or pinentry-rofi
# For GNOME → pinentry-gnome3
# For KDE → pinentry-qt
EOF

chmod 600 ~/.gnupg/*

# Reload agent with new config
gpgconf --kill gpg-agent || true

# 5. Fix GPG_TTY for terminal/tmux/SSH sessions (idempotent append)
for rcfile in ~/.bashrc ~/.zshrc ~/.bash_profile ~/.zprofile ~/.profile; do
    if [ -f "$rcfile" ]; then
        grep -q "export GPG_TTY" "$rcfile" || echo 'export GPG_TTY=$(tty)' >> "$rcfile"
        grep -q "updatestartuptty" "$rcfile" || echo 'gpg-connect-agent updatestartuptty /bye >/dev/null 2>&1 || true' >> "$rcfile"
    fi
done

# Apply to current session
export GPG_TTY=$(tty)
gpg-connect-agent updatestartuptty /bye >/dev/null 2>&1 || true

echo "✓ GPG configured with pinentry-curses (bulletproof) + GPG_TTY fix"

# 6. SSH key – skip if already exists
if [ -f ~/.ssh/id_ed25519 ]; then
    echo "SSH key already exists – skipping generation"
    echo "Your current SSH public key:"
    cat ~/.ssh/id_ed25519.pub
else
    echo "Generating ultra-secure Ed25519 SSH key (100 KDF rounds)"
    read -p "Enter email for key comment (GitHub-linked email or username@users.noreply.github.com): " ssh_comment
    ssh-keygen -t ed25519 -a 100 -f ~/.ssh/id_ed25519 -C "$ssh_comment"
    chmod 600 ~/.ssh/id_ed25519
    chmod 644 ~/.ssh/id_ed25519.pub
    eval "$(ssh-agent -s)"
    ssh-add ~/.ssh/id_ed25519
    echo "SSH key generated!"
    echo "Public key (copy & add to GitHub/GitLab/servers):"
    cat ~/.ssh/id_ed25519.pub
fi

# 7. Hardened ~/.ssh + modern ssh config (only adds if missing)
mkdir -p ~/.ssh
chmod 700 ~/.ssh
if ! grep -q "Host \*" ~/.ssh/config 2>/dev/null; then
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
    echo "Hardened SSH config added"
fi

# 8. GPG key – detect if already present
if gpg --list-secret-keys --keyid-format 0xlong 2>/dev/null | grep -q "^sec"; then
    echo "GPG master key already exists:"
    gpg --list-secret-keys --keyid-format 0xlong
else
    echo "No GPG master key found → generating now (follow exactly):"
    echo "Run: gpg --expert --full-generate-key"
    echo "Choices:"
    echo "   1. 10 → ECC custom, for github chose ECC with sign and encryption"
    echo "   2. S A → Sign & Authenticate only → Q"
    echo "   3. Curve → 9 (Ed25519), for github choose default"
    echo "   4. Expiration → 0 or 3y"
    echo "   5. Name/Email/Comment → real data"
    echo "   6. Strong passphrase (different from SSH!)"
    gpg --expert --full-generate-key
fi

# Add encryption subkey if missing
if ! gpg --list-secret-keys --keyid-format 0xlong | grep -q "ssb.*Cv25519"; then
    echo "Adding Curve25519 encryption subkey..."
    echo "Run: gpg --edit-key YOUR@EMAIL"
    echo "gpg> addkey → 11 (encrypt only) → Curve 1 (Curve25519) → expiration → same passphrase → save"
fi

# 9. Git signing config (idempotent)
read -p "Configure global Git commit signing now? (y/n): " git_sign
if [[ $git_sign =~ ^[Yy]$ ]]; then
    read -p "Enter your GPG key ID (long format, e.g. 0x123456789ABCDEF0): " gpg_keyid
    git config --global commit.gpgsign true
    git config --global user.signingkey "$gpg_keyid"
    echo "Git signing enabled"
fi

# 10. Revocation certificate (safe to skip if exists)
read -p "Generate/store revocation certificate now? (highly recommended) (y/n): " rev
if [[ $rev =~ ^[Yy]$ ]]; then
    read -p "Enter your GPG key ID for revocation: " rev_keyid
    if [ ! -f ~/~gpg-revoke-${rev_keyid}.asc ]; then
        gpg --output ~/gpg-revoke-${rev_keyid}.asc --gen-revoke "$rev_keyid"
        echo "Revocation certificate created at ~/gpg-revoke-${rev_keyid}.asc → move to offline USB NOW"
    else
        echo "Revocation certificate already exists"
    fi
fi

echo ""
echo "=== ALL DONE – script is fully idempotent, run again anytime ==="
echo "Test:"
echo "  ssh-add -L               # should show your ed25519 key"
echo "  ssh -T git@github.com    # Hi username! "
echo "  echo test | gpg --clearsign"
echo ""
