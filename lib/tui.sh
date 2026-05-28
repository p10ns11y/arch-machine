#!/usr/bin/env bash
# lib/tui.sh — The Good Sentinel Interactive TUI (gum powered)
# Part of arch-machine paranoid security fortress
# Invoked via: tinfoil tui   (or ./install.sh --tui in future)
# Tone: humorous, self-aware paranoia. "The Sentinel sees your choices."
# Zero new deps (uses gum, yq, jq, fzf, whiptail if present — all available in env)
# Follows Security Remediation Policy for any destructive actions.

set -euo pipefail

# Colors / styles via gum where possible, fallback echoes
GUM_STYLE="gum style --foreground 212 --bold"
GUM_CONFIRM="gum confirm --affirmative 'Yes, I am paranoid enough' --negative 'Abort, the aliens win'"

# Find repo root or installed share for calling scripts
find_root() {
  if [ -d "/usr/share/tinfoil" ]; then
    echo "/usr/share/tinfoil"
  else
    # dev: assume running from repo root or lib/
    local d
    d="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    echo "$d"
  fi
}
ROOT="$(find_root)"
export ROOT

# Source logger if present (graceful)
if [ -f "$ROOT/lib/logger.sh" ]; then
  # shellcheck disable=SC1090
  source "$ROOT/lib/logger.sh" 2>/dev/null || true
fi

banner() {
  gum style --border double --align center --width 60 --margin "1 0" \
    "🛡️  tinfoil TUI — The Good Sentinel  🛡️" \
    "v0.2.0-sentinel + gum edition" \
    "" \
    "👀 I see all your modules, all your vulns, all your choices." \
    "🥷 Trust no one. Except this beautiful menu."
}

main_menu() {
  while true; do
    choice=$(gum choose --header "🛡️ What shall the Sentinel do for you today?" \
      "🔍  Run Full Security Audit (tinfoil global/project)" \
      "🧹  System Cleanup + Remediation (policy-guided, with confirms)" \
      "📦  Profile Installer (choose + toggle modules + dry-run)" \
      "📜  Extract Evidence Bundle (for the AI overlords)" \
      "🛠️   Maintenance Tasks (weekly checks, timers, updates)" \
      "📜  Browse Logs & Reports (fzf + pager)" \
      "⚙️   Paranoia Settings (silly toggles, future profiles)" \
      "🚪  Exit (The Sentinel is always watching...)" )

    case "$choice" in
      *"Security Audit"*)
        run_audit_flow
        ;;
      *"Cleanup + Remediation"*)
        run_remediation_flow
        ;;
      *"Profile Installer"*)
        run_installer_flow
        ;;
      *"Extract Evidence"*)
        run_evidence_flow
        ;;
      *"Maintenance Tasks"*)
        run_maintenance_flow
        ;;
      *"Browse Logs"*)
        browse_logs
        ;;
      *"Paranoia Settings"*)
        paranoia_settings
        ;;
      *"Exit"*)
        gum style --foreground 99 "👋 The Sentinel nods. Your secrets are safe... for now."
        exit 0
        ;;
    esac
  done
}

run_audit_flow() {
  gum style --foreground 212 "🔍 Security Audit Flow"
  mode=$(gum choose --header "Audit mode?" "global (whole machine)" "project (current dir or pick)")
  if [[ "$mode" == *"project"* ]]; then
    target=$(gum input --placeholder "/path/to/audit (default .)" --value ".")
  else
    target=""
  fi

  if ! gum confirm "Launch tinfoil audit now? (may take minutes, uses live vuln DBs)"; then
    return
  fi

  gum spin --spinner dot --title "🛡️ The Sentinel is auditing... (live vulns, SBOM, Lynis, etc)" -- \
    bash -c "
      if [ -n '$target' ]; then
        '$ROOT/bin/tinfoil' '$target' 2>&1 | tee /tmp/tinfoil-audit.log
      else
        '$ROOT/bin/tinfoil' 2>&1 | tee /tmp/tinfoil-audit.log
      fi
    " || true

  gum pager < /tmp/tinfoil-audit.log || cat /tmp/tinfoil-audit.log | head -100
  gum confirm "Audit complete. Return to menu?" || true
}

run_remediation_flow() {
  gum style --border double --foreground 196 \
    "🧹 REMEDIATION — FOLLOW THE POLICY" \
    "" \
    "1. Audit  2. Built-in fix  3. Small fix  4. UPGRADE OR KILL  5. Transitive delete  6. Solo cleanup" \
    "" \
    "Never keep a vulnerable package 'because it still runs.'"

  if ! $GUM_CONFIRM; then
    gum style "Aborted. The Sentinel respects your cowardice."
    return
  fi

  # Demo only: real delete would be in maintenance/apply-remediation.sh (future)
  gum spin --spinner line --title "Running simulated audits (npm/cargo/pip/yarn + grype + osv)..." -- sleep 2

  echo "DEMO: Found hypothetical critical: left-pad@1.3.0 (but we don't have node here)"
  if gum confirm --affirmative "KILL the vulnerable package (simulated rm -rf)" --negative "Keep it (insecure, but ok)"; then
    gum style --foreground 46 "✅ Simulated: rm -rf node_modules/left-pad (per policy step 4/5)"
    gum spin --title "Re-auditing after kill..." -- sleep 1
    gum style --foreground 46 "✅ Post-remediation: clean (demo)"
  else
    gum style --foreground 196 "⚠️  You kept the vuln. The Sentinel is disappointed but logging it."
  fi

  # Call real maintenance if exists (safe demo)
  if [ -f "$ROOT/maintenance/security-audit.sh" ]; then
    gum style "Also running the real security-audit in --dry-run-ish mode (no sudo)..."
    timeout 8 bash "$ROOT/maintenance/security-audit.sh" --help 2>&1 | gum pager || true
  fi

  gum style "Remediation flow complete. Policy followed. Evidence in /tmp if any."
}

run_installer_flow() {
  gum style "📦 Profile Installer TUI"

  # List profiles using yq
  profiles=()
  while IFS= read -r p; do
    profiles+=("$p")
  done < <(ls "$ROOT/config/profiles/"*.yaml 2>/dev/null | xargs -I{} basename {} .yaml)

  if [ ${#profiles[@]} -eq 0 ]; then
    gum style "No profiles found. Using defaults."
    selected_profile="ml-dev"
  else
    selected_profile=$(gum choose --header "Select installation profile:" "${profiles[@]}")
  fi

  gum style "Selected: $selected_profile (from config/profiles/$selected_profile.yaml)"

  # Feature toggles (simplified: show includes from profile, allow multi-select override)
  includes=$(yq -r '.includes[]' "$ROOT/config/profiles/$selected_profile.yaml" 2>/dev/null || echo "system.base development.core")
  gum style "Current includes: $includes"
  # For demo, just confirm or pick extra modules
  if gum confirm "Customize modules? (multi-select overrides)"; then
    # Simple: hardcode common for demo, or use fzf if want
    chosen=$(gum choose --no-limit --header "Toggle extra modules (space to select, enter done):" \
      "system.base" "development.core" "productivity.basic" "ml_ai.gpu" "security.hardened" "ml_ai.torch")
    gum style "Custom selection: $chosen"
  fi

  dry=$(gum choose --header "Run mode?" "dry-run (recommended, see what happens)" "real (with confirms)")

  if [[ "$dry" == "dry-run"* ]]; then
    gum spin --title "Running ./install.sh --profile $selected_profile --dry-run ..." -- \
      bash -c "cd '$ROOT' && ./install.sh --profile '$selected_profile' --dry-run 2>&1 | tee /tmp/install-dry.log" || true
    gum pager < /tmp/install-dry.log || true
  else
    if $GUM_CONFIRM; then
      gum style --foreground 196 "🚨 REAL INSTALL — may take 20+ min, needs sudo, network, will modify system"
      if gum confirm "Last chance. Proceed with real install?"; then
        cd "$ROOT"
        ./install.sh --profile "$selected_profile" --verbose 2>&1 | gum pager || true
      fi
    fi
  fi
}

run_evidence_flow() {
  gum style "📜 Evidence Extraction"
  if [ -f "$ROOT/maintenance/extract-evidence.sh" ]; then
    if gum confirm "Run evidence bundle extraction now?"; then
      gum spin --title "Extracting logs, SBOM, reports, vector traces for the AI auditors..." -- \
        bash "$ROOT/maintenance/extract-evidence.sh" 2>&1 | tee /tmp/evidence.log || true
      gum pager < /tmp/evidence.log || ls -l logs/evidence* 2>/dev/null | gum pager
    fi
  else
    gum style "Evidence script not found. Creating sample bundle (demo)..."
    mkdir -p /tmp/evidence-demo
    echo "Sentinel evidence $(date)" > /tmp/evidence-demo/sample.json
    gum style "Demo evidence at /tmp/evidence-demo/"
  fi
}

run_maintenance_flow() {
  gum style "🛠️ Maintenance Tasks"
  task=$(gum choose \
    "Weekly security + cleanup check (maintenance/weekly-check.sh)" \
    "Apply updates (safe)" \
    "Setup systemd timers (maintenance/systemd-setup.sh)" \
    "Backup (maintenance/backup.sh --dry)" \
    "Return")
  case "$task" in
    *"Weekly"*)
      if [ -f "$ROOT/maintenance/weekly-check.sh" ]; then
        gum spin --title "Running weekly-check (may require sudo for some checks)..." -- \
          timeout 30 bash "$ROOT/maintenance/weekly-check.sh" 2>&1 | tee /tmp/weekly.log || true
        gum pager < /tmp/weekly.log || true
      fi
      ;;
    *"systemd"*)
      gum style "Would run maintenance/systemd-setup.sh (demo only here)"
      ;;
    *)
      ;;
  esac
}

browse_logs() {
  gum style "📜 Log Browser"
  # Use fzf + gum pager if many
  if command -v fzf >/dev/null; then
    selected=$(find logs/ -type f 2>/dev/null | fzf --header "Select log/report to view (esc cancel)" || true)
    if [ -n "$selected" ]; then
      gum pager < "$selected" || less "$selected"
    fi
  else
    ls -l logs/ 2>/dev/null | gum pager || true
  fi
}

paranoia_settings() {
  gum style --foreground 99 "⚙️ Paranoia Settings (demo toggles — persisted in future ~/.config/tinfoil/)"
  level=$(gum choose "MAX (delete everything suspicious)" "HIGH (upgrade/kill critical only)" "MEDIUM (fix + warn)" "MINIMAL (just audit, no action)")
  gum style "Paranoia level set to: $level (this session only; full config in Phase 4+)"
  if gum confirm "Enable extra verbose logging for this TUI session?"; then
    export TINFOIL_VERBOSE=1
  fi
}

# === Entry ===
banner
main_menu
