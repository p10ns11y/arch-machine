#!/usr/bin/env bash
# lib/tui/view.sh — TEA view (rendering + gum I/O only; sets TUI_MSG)

# --- Presentation (full-terminal overlay) ---

tui_init_screen() {
  if [[ -e /dev/tty ]]; then
    local term_size
    term_size=$(stty size 2>/dev/null </dev/tty || true)
    if [[ -n "$term_size" ]]; then
      TERM_HEIGHT=$(echo "$term_size" | cut -d' ' -f1)
      TERM_WIDTH=$(echo "$term_size" | cut -d' ' -f2)
    fi
  fi
  TERM_WIDTH=${TERM_WIDTH:-80}
  TERM_HEIGHT=${TERM_HEIGHT:-24}
  TUI_PANEL_WIDTH=$((TERM_WIDTH - 4))
  if (( TUI_PANEL_WIDTH < 40 )); then
    TUI_PANEL_WIDTH=40
  fi
  export TERM_WIDTH TERM_HEIGHT TUI_PANEL_WIDTH
  export GUM_CHOOSE_PADDING="0 0"
  export GUM_CONFIRM_PADDING="0 0"
  export GUM_INPUT_PADDING="0 0"
  export GUM_SPIN_PADDING="0 0"
  export GUM_FILTER_PADDING="0 0"
}

tui_clear_screen() {
  if [[ -e /dev/tty ]]; then
    printf '\033[H\033[2J' >/dev/tty 2>/dev/null || clear
  else
    clear 2>/dev/null || true
  fi
}

tui_screen() {
  tui_clear_screen
  gum style --border rounded --width "$TUI_PANEL_WIDTH" --padding "1 2" --margin "0 1" "$@"
}

tui_status() {
  local level="${1:-info}"
  shift
  local fg=99
  case "$level" in
    ok|success) fg=46 ;;
    warn) fg=214 ;;
    err|error) fg=196 ;;
    info) fg=212 ;;
  esac
  gum style --foreground "$fg" --width "$TUI_PANEL_WIDTH" "$@"
}

gum_confirm_vigilant() {
  gum confirm --affirmative "Yes, I am vigilant enough" --negative "Abort, the aliens win"
}

# --- Main menu ---

view_main() {
  tui_screen \
    "🛡️  tinfoil TUI — The Good Sentinel  🛡️" \
    "v0.2.0-sentinel + gum edition" \
    "" \
    "👀 I see all your modules, all your vulns, all your choices." \
    "🥷 Trust no one. Except this beautiful menu."

  local choice
  choice=$(gum choose --header "🛡️ What shall the Sentinel do for you today?" \
    "🔍  Run Full Security Audit (tinfoil global/project)" \
    "🧹  System Cleanup + Remediation (policy-guided, with confirms)" \
    "📦  Profile Installer (choose + toggle modules + dry-run)" \
    "📜  Extract Evidence Bundle (for the AI overlords)" \
    "🛠️   Maintenance Tasks (weekly checks, timers, updates)" \
    "📜  Browse Logs & Reports (fzf + pager)" \
    "⚙️   Vigilance Settings (preferences & toggles)" \
    "🚪  Exit (The Sentinel is always watching...)" ) || {
    TUI_MSG="$MsgCancel"
    return
  }
  TUI_MSG="${MsgMainSelectPrefix}${choice}"
}

# --- Audit flow ---

view_audit_mode() {
  tui_screen "🔍 Security Audit Flow" "Choose audit scope."
  local mode
  mode=$(gum choose --header "Audit mode?" \
    "global (whole machine)" \
    "project (current dir or pick)") || {
    TUI_MSG="$MsgCancel"
    return
  }
  TUI_AUDIT_MODE="$mode"
  if [[ "$mode" == *"project"* ]]; then
    TUI_MSG="$MsgConfirm"
  else
    TUI_AUDIT_TARGET=
    TUI_MSG="$MsgConfirm"
  fi
}

view_audit_target() {
  tui_screen "🔍 Security Audit Flow" "Project audit — pick target directory."
  local target
  target=$(gum input --placeholder "/path/to/audit (default .)" --value ".") || {
    TUI_MSG="$MsgCancel"
    return
  }
  TUI_AUDIT_TARGET="${target:-.}"
  TUI_MSG="$MsgConfirm"
}

view_audit_confirm() {
  tui_screen "🔍 Security Audit Flow" \
    "Mode: ${TUI_AUDIT_MODE:-global}" \
    "Target: ${TUI_AUDIT_TARGET:-(whole machine)}"
  if gum confirm "Launch tinfoil audit now? (may take minutes, uses live vuln DBs)"; then
    TUI_MSG="$MsgConfirm"
  else
    TUI_MSG="$MsgDeny"
  fi
}

view_audit_running() {
  tui_screen "🔍 Security Audit" "The Sentinel is auditing..."
  local tinfoil_cmd
  tinfoil_cmd="$(tinfoil_cmd_path)"
  gum spin --spinner dot --title "🛡️ Live vulns, SBOM, Lynis, etc." -- \
    bash -c "
      if [ -n '$TUI_AUDIT_TARGET' ]; then
        '$tinfoil_cmd' '$TUI_AUDIT_TARGET' 2>&1 | tee /tmp/tinfoil-audit.log
      else
        '$tinfoil_cmd' 2>&1 | tee /tmp/tinfoil-audit.log
      fi
    " || true
  TUI_MSG="$MsgDone"
}

view_audit_done() {
  tui_screen "🔍 Audit Complete"
  gum pager < /tmp/tinfoil-audit.log 2>/dev/null || cat /tmp/tinfoil-audit.log 2>/dev/null | head -100 || true
  gum confirm "Return to main menu?" || true
  TUI_MSG="$MsgBack"
}

# --- Remediation flow ---

view_remediation_policy() {
  tui_screen \
    "🧹 REMEDIATION — FOLLOW THE POLICY" \
    "" \
    "1. Audit   2. Built-in fix   3. Small fix" \
    "4. UPGRADE OR KILL   5. Transitive delete   6. Solo cleanup" \
    "" \
    "Never keep a vulnerable package 'because it still runs.'"
  if gum confirm "Proceed under this remediation policy?"; then
    TUI_MSG="$MsgConfirm"
  else
    TUI_MSG="$MsgDeny"
  fi
}

view_remediation_confirm() {
  tui_screen "🧹 Remediation" "Confirm you accept the remediation policy."
  if gum_confirm_vigilant; then
    TUI_MSG="$MsgConfirm"
  else
    tui_status warn "Aborted. The Sentinel respects your cowardice."
    TUI_MSG="$MsgDeny"
  fi
}

view_remediation_scan() {
  tui_screen "🧹 Remediation" "Running policy-guided audits..."
  gum spin --spinner line --title "Simulated audits (npm/cargo/pip/yarn + grype + osv)..." -- sleep 2
  tui_status info "DEMO: Found hypothetical critical: left-pad@1.3.0 (but we don't have node here)"
  TUI_MSG="$MsgDone"
}

view_remediation_kill() {
  tui_screen "🧹 Remediation" "Critical vulnerability detected (demo)."
  if gum confirm --affirmative "KILL the vulnerable package (simulated rm -rf)" --negative "Keep it (insecure, but ok)"; then
    tui_status ok "✅ Simulated: rm -rf node_modules/left-pad (per policy step 4/5)"
    gum spin --title "Re-auditing after kill..." -- sleep 1
    tui_status ok "✅ Post-remediation: clean (demo)"
    TUI_MSG="$MsgKillConfirm"
  else
    tui_status warn "⚠️  You kept the vuln. The Sentinel is disappointed but logging it."
    TUI_MSG="$MsgKillDeny"
  fi
}

view_remediation_done() {
  tui_screen "🧹 Remediation Complete"
  if [ -f "$ROOT/maintenance/security-audit.sh" ]; then
    tui_status info "Security audit script reference (help output):"
    timeout 8 bash "$ROOT/maintenance/security-audit.sh" --help 2>&1 | gum pager || true
  fi
  tui_status ok "Remediation flow complete. Policy followed. Evidence in /tmp if any."
  TUI_MSG="$MsgBack"
}

# --- Installer flow ---

view_install_profile() {
  tui_screen "📦 Profile Installer" "Select installation profile."
  mapfile -t _profiles < <(install_profiles_list)
  if [ ${#_profiles[@]} -eq 1 ] && [ "${_profiles[0]}" = "ml-dev" ] && [ ! -f "$ROOT/config/profiles/ml-dev.yaml" ]; then
    tui_status warn "No profiles found. Using default: ml-dev"
    TUI_INSTALL_PROFILE="ml-dev"
    TUI_MSG="$MsgConfirm"
    return
  fi
  local selected
  selected=$(gum choose --header "Select installation profile:" "${_profiles[@]}") || {
    TUI_MSG="$MsgCancel"
    return
  }
  TUI_INSTALL_PROFILE="$selected"
  TUI_MSG="$MsgConfirm"
}

view_install_modules() {
  tui_screen "📦 Profile Installer" \
    "Selected: $TUI_INSTALL_PROFILE" \
    "From: config/profiles/$TUI_INSTALL_PROFILE.yaml"
  local includes
  includes=$(yq -r '.includes[]' "$ROOT/config/profiles/$TUI_INSTALL_PROFILE.yaml" 2>/dev/null || echo "system.base development.core")
  tui_status info "Current includes: $includes"
  if gum confirm "Customize modules? (multi-select overrides)"; then
    local chosen
    chosen=$(gum choose --no-limit --header "Toggle extra modules (space to select, enter done):" \
      "system.base" "development.core" "productivity.basic" "ml_ai.gpu" "security.hardened" "ml_ai.torch") || true
    TUI_INSTALL_MODULES="${chosen:-}"
    tui_status info "Custom selection: ${TUI_INSTALL_MODULES:-(unchanged)}"
  fi
  TUI_MSG="$MsgConfirm"
}

view_install_mode() {
  tui_screen "📦 Profile Installer" "Choose run mode."
  local dry
  dry=$(gum choose --header "Run mode?" \
    "dry-run (recommended, see what happens)" \
    "real (with confirms)") || {
    TUI_MSG="$MsgCancel"
    return
  }
  if [[ "$dry" == "dry-run"* ]]; then
    TUI_INSTALL_DRY_RUN=true
    TUI_MSG="$MsgConfirm"
  else
    TUI_INSTALL_DRY_RUN=false
    TUI_MSG="$MsgConfirm"
  fi
}

view_install_vigilant() {
  tui_screen "📦 Profile Installer" "🚨 REAL INSTALL — may take 20+ min, needs sudo, network."
  if gum_confirm_vigilant; then
    TUI_MSG="$MsgConfirm"
  else
    TUI_MSG="$MsgDeny"
  fi
}

view_install_last_chance() {
  tui_screen "📦 Profile Installer" "Last chance before system changes."
  if gum confirm "Proceed with real install?"; then
    TUI_MSG="$MsgConfirm"
  else
    TUI_MSG="$MsgDeny"
  fi
}

view_install_running() {
  tui_screen "📦 Profile Installer" "Running install..."
  if [[ "$TUI_INSTALL_DRY_RUN" == true ]]; then
    gum spin --title "Running ./install.sh --profile $TUI_INSTALL_PROFILE --dry-run ..." -- \
      bash -c "cd '$ROOT' && ./install.sh --profile '$TUI_INSTALL_PROFILE' --dry-run 2>&1 | tee /tmp/install-dry.log" || true
    gum pager < /tmp/install-dry.log 2>/dev/null || true
  else
    (
      cd "$ROOT"
      ./install.sh --profile "$TUI_INSTALL_PROFILE" --verbose 2>&1 | tee /tmp/install-real.log
    ) | gum pager || true
  fi
  TUI_MSG="$MsgBack"
}

# --- Evidence flow ---

view_evidence_scope() {
  tui_screen "📜 Evidence Extraction" "Choose evidence scope."
  local scope
  scope=$(gum choose --header "Extract evidence for..." \
    "Current system / global (default smart user location)" \
    "Specific project or folder (recommended when you audited a directory)") || {
    TUI_MSG="$MsgCancel"
    return
  }
  TUI_EVIDENCE_SCOPE="$scope"
  TUI_MSG="$MsgConfirm"
}

view_evidence_target() {
  tui_screen "📜 Evidence Extraction" "Enter project path."
  local target_dir
  target_dir=$(gum input --placeholder "Path to project (e.g. . or ~/Work/devprofile)" --value ".") || {
    TUI_MSG="$MsgCancel"
    return
  }
  TUI_EVIDENCE_TARGET="${target_dir:-.}"
  if [[ -n "$TUI_EVIDENCE_TARGET" ]]; then
    TUI_EVIDENCE_TARGET=$(cd "$TUI_EVIDENCE_TARGET" 2>/dev/null && pwd || echo "$TUI_EVIDENCE_TARGET")
  fi
  TUI_MSG="$MsgConfirm"
}

view_evidence_confirm() {
  tui_screen "📜 Evidence Extraction" \
    "Scope: $TUI_EVIDENCE_SCOPE" \
    "Target: ${TUI_EVIDENCE_TARGET:-(global)}"
  if [ ! -f "$ROOT/maintenance/extract-evidence.sh" ]; then
    tui_status warn "Evidence script not found. Demo bundle will be created."
    TUI_MSG="$MsgConfirm"
    return
  fi
  if gum confirm "Run evidence bundle extraction now?"; then
    TUI_MSG="$MsgConfirm"
  else
    TUI_MSG="$MsgDeny"
  fi
}

view_evidence_running() {
  tui_screen "📜 Evidence Extraction" "Extracting evidence bundle..."
  if [ ! -f "$ROOT/maintenance/extract-evidence.sh" ]; then
    mkdir -p /tmp/evidence-demo
    echo "Sentinel evidence $(date)" > /tmp/evidence-demo/sample.json
    tui_status ok "Demo evidence at /tmp/evidence-demo/"
    TUI_MSG="$MsgBack"
    return
  fi
  local export_cmd=""
  if [[ -n "$TUI_EVIDENCE_TARGET" ]]; then
    export_cmd="TINFOIL_TARGET_DIR='$TUI_EVIDENCE_TARGET' "
    tui_status info "Target: $TUI_EVIDENCE_TARGET → evidence written inside the project"
  fi
  gum spin --title "Extracting logs, SBOM, reports, vector traces..." -- \
    bash -c "${export_cmd}bash '$ROOT/maintenance/extract-evidence.sh' 2>&1" | tee /tmp/evidence.log || true
  gum pager < /tmp/evidence.log 2>/dev/null || true
  if [[ -n "$TUI_EVIDENCE_TARGET" && -d "$TUI_EVIDENCE_TARGET/.tinfoil/logs" ]]; then
    tui_status info "Evidence bundles in project:"
    ls -l "$TUI_EVIDENCE_TARGET/.tinfoil/logs"/evidence* 2>/dev/null | gum pager || true
  else
    ls -l logs/evidence* 2>/dev/null | gum pager || \
      ls -l "$HOME/.local/share/tinfoil/logs"/evidence* 2>/dev/null | gum pager || true
  fi
  TUI_MSG="$MsgBack"
}

# --- Maintenance flow ---

view_maintenance_menu() {
  tui_screen "🛠️ Maintenance Tasks" "Select a task."
  local task
  task=$(gum choose \
    "Weekly security + cleanup check (maintenance/weekly-check.sh)" \
    "Apply updates (safe)" \
    "Setup systemd timers (maintenance/systemd-setup.sh)" \
    "Backup (maintenance/backup.sh --dry)" \
    "Return to main menu") || {
    TUI_MSG="$MsgCancel"
    return
  }
  TUI_MAINTENANCE_TASK="$task"
  TUI_MSG="${MsgMaintenanceSelectPrefix}${task}"
}

view_maintenance_running() {
  tui_screen "🛠️ Maintenance" "Running: $TUI_MAINTENANCE_TASK"
  case "$TUI_MAINTENANCE_TASK" in
    *"Weekly"*)
      if [ -f "$ROOT/maintenance/weekly-check.sh" ]; then
        local weekly_mode="dry"
        if gum confirm "Run FULL weekly maintenance (sudo, pacman -Syu, scans — 5–15 min)?" --default=false; then
          weekly_mode="full"
        fi
        tui_status info "Running weekly-check ($weekly_mode). Output below — sudo may prompt on your terminal."
        if [[ "$weekly_mode" == "full" ]]; then
          # gum spin hides the TTY sudo needs; authenticate on real terminal first
          sudo -v </dev/tty 2>/dev/null || true
          bash "$ROOT/maintenance/weekly-check.sh" 2>&1 | tee /tmp/weekly.log || true
        else
          bash "$ROOT/maintenance/weekly-check.sh" --dry-run 2>&1 | tee /tmp/weekly.log || true
        fi
        gum pager < /tmp/weekly.log 2>/dev/null || true
      else
        tui_status warn "weekly-check.sh not found."
      fi
      ;;
    *"systemd"*)
      tui_status info "Run from shell: sudo bash $ROOT/maintenance/systemd-setup.sh"
      ;;
    *"Apply updates"*)
      tui_screen "Apply updates (safe)" "List upgradable packages only — no install."
      {
        echo "=== Upgradable packages (pacman -Qu) ==="
        if pacman -Qu 2>/dev/null; then
          :
        else
          echo "(none listed — databases may be stale; try: sudo pacman -Sy && pacman -Qu)"
        fi
      } | tee /tmp/updates-safe.log
      gum pager < /tmp/updates-safe.log 2>/dev/null || true
      ;;
    *"Backup"*)
      if [ -f "$ROOT/maintenance/backup.sh" ]; then
        bash "$ROOT/maintenance/backup.sh" list 2>&1 | tee /tmp/backup-list.log || true
        gum pager < /tmp/backup-list.log 2>/dev/null || true
      else
        tui_status warn "backup.sh not found."
      fi
      ;;
  esac
  TUI_MSG="$MsgBack"
}

# --- Logs browse ---

view_logs_browse() {
  tui_screen "📜 Log Browser" "Select a log or report."
  if command -v fzf >/dev/null; then
    local selected
    selected=$(find "$ROOT/logs/" logs/ -type f 2>/dev/null | fzf --header "Select log/report (Esc cancels)" || true)
    if [ -n "$selected" ]; then
      gum pager < "$selected" || less "$selected"
    fi
  else
    ls -l "$ROOT/logs/" logs/ 2>/dev/null | gum pager || true
  fi
  TUI_MSG="$MsgBack"
}

# --- Settings flow ---

view_settings_level() {
  tui_screen "⚙️ Vigilance Settings" "Set remediation aggressiveness (this session)."
  local level
  level=$(gum choose \
    "MAX (aggressive remediation)" \
    "HIGH (upgrade/kill critical issues)" \
    "MEDIUM (fix + warn)" \
    "MINIMAL (audit only, no automatic action)") || {
    TUI_MSG="$MsgCancel"
    return
  }
  TUI_VIGILANCE_LEVEL="$level"
  tui_status ok "Vigilance level set to: $level"
  TUI_MSG="$MsgConfirm"
}

view_settings_verbose() {
  tui_screen "⚙️ Vigilance Settings" "Logging preferences."
  if gum confirm "Enable extra verbose logging for this TUI session?"; then
    export TINFOIL_VERBOSE=1
    tui_status ok "Verbose logging enabled."
  fi
  TUI_MSG="$MsgBack"
}

# --- Exit ---

view_exit() {
  tui_clear_screen
  gum style --foreground 212 --border double --width "$TUI_PANEL_WIDTH" --margin "1 0" \
    "👋  The Good Sentinel tips its hat." \
    "" \
    "Thank you for keeping the machines honest today." \
    "The fortress stands stronger because of your vigilance." \
    "" \
    "Stay sharp. The Sentinel is always watching. 🛡️"
  TUI_MSG="$MsgExit"
}
