#!/usr/bin/env bash
# Install eye-comfort Omarchy themes + circadian/Tamil switcher onto this machine.
# Usage: ./install.sh [--set dark|light|dawn|dusk|auto|tn] [--with-timer] [--with-tn-timer] [--dry-run]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
THEMES_SRC="$SCRIPT_DIR/themes"
DOCS_SRC="$SCRIPT_DIR/docs"
BIN_SRC="$SCRIPT_DIR/bin/eye-comfort-theme"
LIB_SRC="$SCRIPT_DIR/lib"
SYSTEMD_SRC="$SCRIPT_DIR/units"
TOKENS_SRC="$SCRIPT_DIR/tokens"

OMARCHY_THEMES="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/themes"
LOCAL_BIN="$HOME/.local/bin"
LOCAL_LIB="$HOME/.local/lib/eye-comfort"
SYSTEMD_USER="$HOME/.config/systemd/user"

SET_MODE=""
WITH_TIMER=0
WITH_TN_TIMER=0
DRY=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --set)
      SET_MODE="${2:-}"
      shift 2
      ;;
    --set=*)
      SET_MODE="${1#--set=}"
      shift
      ;;
    --with-timer)
      WITH_TIMER=1
      shift
      ;;
    --with-tn-timer)
      WITH_TN_TIMER=1
      shift
      ;;
    --dry-run)
      DRY=1
      shift
      ;;
    dark|light|dawn|dusk|auto|tn)
      SET_MODE="$1"
      shift
      ;;
    -h|--help)
      sed -n '2,4p' "$0"
      exit 0
      ;;
    *)
      echo "unknown arg: $1" >&2
      exit 1
      ;;
  esac
done

run() {
  if (( DRY )); then
    echo "DRY: $*"
  else
    "$@"
  fi
}

link_backgrounds() {
  # Share wallpapers: dawn←light, dusk←dark (avoid duplicating JPGs in git)
  local dest="$1"
  local src="$2"
  run mkdir -p "$dest/backgrounds"
  if (( DRY )); then
    echo "DRY: symlink backgrounds $src → $dest"
    return
  fi
  local f
  shopt -s nullglob
  for f in "$src"/backgrounds/*; do
    [[ -e "$f" ]] || continue
    ln -sfn "$f" "$dest/backgrounds/$(basename "$f")"
  done
  shopt -u nullglob
}

echo "eye-comfort install → $OMARCHY_THEMES"
run mkdir -p "$OMARCHY_THEMES" "$LOCAL_BIN" "$LOCAL_LIB"

for f in PALETTE.md PRODUCT.md DESIGN.md DESIGN-TN.md PRODUCT-TN.md; do
  if [[ -f "$DOCS_SRC/$f" ]]; then
    run cp -a "$DOCS_SRC/$f" "$OMARCHY_THEMES/$f"
  fi
done

if [[ -d "$TOKENS_SRC" ]]; then
  run mkdir -p "$OMARCHY_THEMES/eye-comfort-tokens"
  if (( DRY )); then
    echo "DRY: copy tokens"
  else
    rsync -a "$TOKENS_SRC/" "$OMARCHY_THEMES/eye-comfort-tokens/"
  fi
fi

for t in eye-comfort-dark eye-comfort-light eye-comfort-dawn eye-comfort-dusk \
         eye-comfort-tn-kurinji eye-comfort-tn-mullai eye-comfort-tn-marutham \
         eye-comfort-tn-neythal eye-comfort-tn-palai; do
  if [[ -d "$THEMES_SRC/$t" ]]; then
    run mkdir -p "$OMARCHY_THEMES/$t"
    if (( DRY )); then
      echo "DRY: rsync $THEMES_SRC/$t/ → $OMARCHY_THEMES/$t/"
    else
      rsync -a --delete --exclude backgrounds "$THEMES_SRC/$t/" "$OMARCHY_THEMES/$t/"
    fi
    echo "  installed theme: $t"
  fi
done

# Wallpaper sharing after rsync --exclude backgrounds
if [[ -d "$OMARCHY_THEMES/eye-comfort-light" ]]; then
  if (( DRY )); then
    echo "DRY: ensure light/dark backgrounds present"
  else
    rsync -a "$THEMES_SRC/eye-comfort-light/backgrounds/" "$OMARCHY_THEMES/eye-comfort-light/backgrounds/"
    rsync -a "$THEMES_SRC/eye-comfort-dark/backgrounds/" "$OMARCHY_THEMES/eye-comfort-dark/backgrounds/"
  fi
fi
# TN wallpaper READMEs (and any future JPGs)
for t in eye-comfort-tn-kurinji eye-comfort-tn-mullai eye-comfort-tn-marutham \
         eye-comfort-tn-neythal eye-comfort-tn-palai; do
  if [[ -d "$THEMES_SRC/$t/backgrounds" ]]; then
    if (( DRY )); then
      echo "DRY: rsync $t backgrounds"
    else
      mkdir -p "$OMARCHY_THEMES/$t/backgrounds"
      rsync -a "$THEMES_SRC/$t/backgrounds/" "$OMARCHY_THEMES/$t/backgrounds/"
    fi
  fi
done
link_backgrounds "$OMARCHY_THEMES/eye-comfort-dawn" "$OMARCHY_THEMES/eye-comfort-light"
link_backgrounds "$OMARCHY_THEMES/eye-comfort-dusk" "$OMARCHY_THEMES/eye-comfort-dark"

run cp -a "$BIN_SRC" "$LOCAL_BIN/eye-comfort-theme"
run chmod +x "$LOCAL_BIN/eye-comfort-theme"
# Typeset fragment (optional merge into Ghostty user config)
GHOSTTY_FRAG="$SCRIPT_DIR/snippets/ghostty.fragment.conf"
if [[ -f "$GHOSTTY_FRAG" ]]; then
  run mkdir -p "${XDG_CONFIG_HOME:-$HOME/.config}/eye-comfort"
  run cp -a "$GHOSTTY_FRAG" "${XDG_CONFIG_HOME:-$HOME/.config}/eye-comfort/ghostty.fragment.conf"
  echo "  ghostty fragment: ~/.config/eye-comfort/ghostty.fragment.conf"
fi
if (( DRY )); then
  echo "DRY: rsync lib"
else
  rsync -a "$LIB_SRC/" "$LOCAL_LIB/"
  chmod +x "$LOCAL_LIB/test_schedule.py" 2>/dev/null || true
  chmod +x "$LOCAL_LIB/test_tamil_schedule.py" 2>/dev/null || true
fi
echo "  switcher: $LOCAL_BIN/eye-comfort-theme"
echo "  lib: $LOCAL_LIB"

# Neovim hotreload (fix stock omarchy forcing background=dark on LazyReload)
NVIM_HOTRELOAD_SRC="$SCRIPT_DIR/nvim/omarchy-theme-hotreload.lua"
NVIM_PLUGINS="${XDG_CONFIG_HOME:-$HOME/.config}/nvim/lua/plugins"
if [[ -f "$NVIM_HOTRELOAD_SRC" ]]; then
  run mkdir -p "$NVIM_PLUGINS"
  run cp -a "$NVIM_HOTRELOAD_SRC" "$NVIM_PLUGINS/omarchy-theme-hotreload.lua"
  echo "  nvim: $NVIM_PLUGINS/omarchy-theme-hotreload.lua"
fi

# Omarchy theme-set.d hook → reload open nvim + tmux after omarchy-theme-set
HOOK_SRC="$SCRIPT_DIR/hooks/theme-set.d/90-reload-nvim-tmux.sh"
HOOK_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/hooks/theme-set.d"
if [[ -f "$HOOK_SRC" ]]; then
  run mkdir -p "$HOOK_DIR"
  run cp -a "$HOOK_SRC" "$HOOK_DIR/90-reload-nvim-tmux.sh"
  if (( ! DRY )); then
    chmod +x "$HOOK_DIR/90-reload-nvim-tmux.sh"
  fi
  echo "  hook: $HOOK_DIR/90-reload-nvim-tmux.sh"
fi

# Yazi flavors (optional)
YAZI_SRC="$SCRIPT_DIR/yazi"
YAZI_CFG="${XDG_CONFIG_HOME:-$HOME/.config}/yazi"
if [[ -d "$YAZI_SRC/flavors" ]]; then
  run mkdir -p "$YAZI_CFG/flavors"
  for fl in "$YAZI_SRC/flavors"/*.yazi; do
    [[ -d "$fl" ]] || continue
    name=$(basename "$fl")
    if (( DRY )); then
      echo "DRY: rsync yazi flavor $name"
    else
      rsync -a --delete "$fl/" "$YAZI_CFG/flavors/$name/"
    fi
    echo "  yazi flavor: $name"
  done
  if [[ -f "$YAZI_SRC/theme.toml" ]]; then
    run cp -a "$YAZI_SRC/theme.toml" "$YAZI_CFG/theme.toml"
  fi
fi

if [[ -f "$LOCAL_LIB/test_schedule.py" ]] && (( ! DRY )); then
  PYTHONPATH="$LOCAL_LIB" python3 "$LOCAL_LIB/test_schedule.py"
fi
if [[ -f "$LOCAL_LIB/test_tamil_schedule.py" ]] && (( ! DRY )); then
  PYTHONPATH="$LOCAL_LIB" python3 "$LOCAL_LIB/test_tamil_schedule.py"
fi

if (( WITH_TIMER )); then
  run mkdir -p "$SYSTEMD_USER"
  run cp -a "$SYSTEMD_SRC/eye-comfort-theme.service" "$SYSTEMD_SRC/eye-comfort-theme.timer" "$SYSTEMD_USER/"
  if (( ! DRY )); then
    systemctl --user daemon-reload
    systemctl --user enable --now eye-comfort-theme.timer
    echo "  timer enabled"
  fi
fi

if (( WITH_TN_TIMER )); then
  run mkdir -p "$SYSTEMD_USER"
  run cp -a "$SYSTEMD_SRC/eye-comfort-tn.service" "$SYSTEMD_SRC/eye-comfort-tn.timer" "$SYSTEMD_USER/"
  if (( ! DRY )); then
    systemctl --user daemon-reload
    systemctl --user enable --now eye-comfort-tn.timer
    echo "  tn timer enabled (Nazhigai ≈24 min; waybar restore in switcher)"
  fi
fi

if [[ -n "$SET_MODE" ]]; then
  if ! command -v omarchy-theme-set >/dev/null 2>&1; then
    echo "warn: omarchy-theme-set not on PATH; skip --set" >&2
  elif (( DRY )); then
    echo "DRY: would set mode $SET_MODE"
  else
    case "$SET_MODE" in
      dark|light|dawn|dusk|auto|tn)
        "$LOCAL_BIN/eye-comfort-theme" "$SET_MODE"
        ;;
      *) echo "unknown --set $SET_MODE (use dark|light|dawn|dusk|auto|tn)" >&2; exit 1 ;;
    esac
  fi
fi

echo "done."
echo "  Apply: omarchy-theme-set eye-comfort-{dawn,light,dusk,dark}"
echo "  Tamil: omarchy-theme-set eye-comfort-tn-{kurinji,mullai,marutham,neythal,palai}"
echo "  Circadian: eye-comfort-theme [--help]"
echo "  Tamil calendrical: eye-comfort-theme tn [--tinai …] [--help]"
echo "  Cycle wallpaper: omarchy theme bg next"
