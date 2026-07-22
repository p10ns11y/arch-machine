#!/usr/bin/env bash
# lib/tui/model.sh — TEA model (application state)

# Session navigation
TUI_SCREEN=main
TUI_PREV_SCREEN=
TUI_MSG=

# Audit flow
TUI_AUDIT_MODE=
TUI_AUDIT_TARGET=.

# Installer flow
TUI_INSTALL_PROFILE=
TUI_INSTALL_MODULES=
TUI_INSTALL_DRY_RUN=true

# Evidence flow
TUI_EVIDENCE_SCOPE=
TUI_EVIDENCE_TARGET=

# Maintenance flow
TUI_MAINTENANCE_TASK=

# Settings
TUI_VIGILANCE_LEVEL=

model_init() {
  TUI_SCREEN=main
  TUI_PREV_SCREEN=
  TUI_MSG=
  TUI_AUDIT_MODE=
  TUI_AUDIT_TARGET=.
  TUI_INSTALL_PROFILE=
  TUI_INSTALL_MODULES=
  TUI_INSTALL_DRY_RUN=true
  TUI_EVIDENCE_SCOPE=
  TUI_EVIDENCE_TARGET=
  TUI_MAINTENANCE_TASK=
  TUI_VIGILANCE_LEVEL=
}

model_goto() {
  TUI_PREV_SCREEN="$TUI_SCREEN"
  TUI_SCREEN="$1"
}

model_goto_main() {
  TUI_PREV_SCREEN="$TUI_SCREEN"
  TUI_SCREEN=main
}

tinfoil_cmd_path() {
  if command -v tinfoil >/dev/null 2>&1; then
    command -v tinfoil
  elif [ -x "$ROOT/bin/tinfoil" ]; then
    echo "$ROOT/bin/tinfoil"
  elif [ -x "/usr/local/bin/tinfoil" ]; then
    echo "/usr/local/bin/tinfoil"
  else
    echo "tinfoil"
  fi
}

install_profiles_list() {
  local profiles=()
  local f
  for f in "$ROOT/config/profiles/"*.yaml; do
    [[ -e "$f" ]] || continue
    profiles+=("$(basename "$f" .yaml)")
  done
  if [ ${#profiles[@]} -eq 0 ]; then
    echo "ml-dev"
  else
    printf '%s\n' "${profiles[@]}"
  fi
}
