#!/usr/bin/env bash
# lib/tui/update.sh — TEA update (state transitions; no gum calls)

graceful_exit() {
  view_exit
  exit 0
}

update() {
  local msg="${1:-}"

  case "$msg" in
    "$MsgCancel")
      case "$TUI_SCREEN" in
        main) ;;
        *) model_goto_main ;;
      esac
      ;;

    "$MsgBack")
      model_goto_main
      ;;

    "$MsgDeny")
      model_goto_main
      ;;

    "$MsgExit")
      exit 0
      ;;

    "$MsgMainSelectPrefix"*)
      _update_main_select "${msg#"$MsgMainSelectPrefix"}"
      ;;

    "$MsgMaintenanceSelectPrefix"*)
      _update_maintenance_select "${msg#"$MsgMaintenanceSelectPrefix"}"
      ;;

    "$MsgConfirm")
      _update_confirm
      ;;

    "$MsgDone")
      _update_done
      ;;

    "$MsgKillConfirm"|"$MsgKillDeny")
      model_goto remediation_done
      ;;

    *)
      ;;
  esac
}

_update_main_select() {
  local choice="$1"
  case "$choice" in
    *"Security Audit"*) model_goto audit_mode ;;
    *"Cleanup + Remediation"*) model_goto remediation_policy ;;
    *"Profile Installer"*) model_goto install_profile ;;
    *"Extract Evidence"*) model_goto evidence_scope ;;
    *"Maintenance Tasks"*) model_goto maintenance_menu ;;
    *"Browse Logs"*) model_goto logs_browse ;;
    *"Vigilance Settings"*) model_goto settings_level ;;
    *"Exit"*) model_goto exit ;;
  esac
}

_update_maintenance_select() {
  local task="$1"
  case "$task" in
    *"Return"*) model_goto_main ;;
    *) model_goto maintenance_running ;;
  esac
}

_update_confirm() {
  case "$TUI_SCREEN" in
    audit_mode)
      if [[ "$TUI_AUDIT_MODE" == *"project"* ]]; then
        model_goto audit_target
      else
        model_goto audit_confirm
      fi
      ;;
    audit_target) model_goto audit_confirm ;;
    audit_confirm) model_goto audit_running ;;
    remediation_policy) model_goto remediation_confirm ;;
    remediation_confirm) model_goto remediation_scan ;;
    install_profile) model_goto install_modules ;;
    install_modules) model_goto install_mode ;;
    install_mode)
      if [[ "$TUI_INSTALL_DRY_RUN" == true ]]; then
        model_goto install_running
      else
        model_goto install_vigilant
      fi
      ;;
    install_vigilant) model_goto install_last_chance ;;
    install_last_chance) model_goto install_running ;;
    evidence_scope)
      if [[ "$TUI_EVIDENCE_SCOPE" == *"Specific project"* ]]; then
        model_goto evidence_target
      elif [ ! -f "$ROOT/maintenance/extract-evidence.sh" ]; then
        model_goto evidence_running
      else
        model_goto evidence_confirm
      fi
      ;;
    evidence_target) model_goto evidence_confirm ;;
    evidence_confirm) model_goto evidence_running ;;
    settings_level) model_goto settings_verbose ;;
    exit) model_goto exit ;;
  esac
}

_update_done() {
  case "$TUI_SCREEN" in
    audit_running) model_goto audit_done ;;
    remediation_scan) model_goto remediation_kill ;;
    *) model_goto_main ;;
  esac
}

tui_run() {
  model_init
  tui_init_screen

  while [[ "$TUI_SCREEN" != "exit" ]]; do
    TUI_MSG=
    local view_fn="view_${TUI_SCREEN}"
    if declare -f "$view_fn" >/dev/null 2>&1; then
      "$view_fn"
    else
      tui_status err "Unknown screen: $TUI_SCREEN"
      model_goto_main
      continue
    fi

    if [[ "$TUI_SCREEN" == "exit" && "$TUI_MSG" == "$MsgExit" ]]; then
      exit 0
    fi

    if [[ -n "$TUI_MSG" ]]; then
      update "$TUI_MSG"
    fi
  done

  view_exit
  exit 0
}
