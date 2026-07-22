#!/usr/bin/env bash
# Project verification cockpit — golden-ratio, insight-first layout.
# Usage: tmux-layout.sh [directory]
set -euo pipefail

DIR="${1:-.}"
SCRIPT_NAME="project-verify-layout"
VERIFY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$DIR" && pwd)"

if ! command -v tmux >/dev/null 2>&1; then
    echo "$SCRIPT_NAME: tmux not found" >&2
    exit 1
fi

if [ -z "${TMUX:-}" ]; then
    echo "$SCRIPT_NAME: must run inside tmux" >&2
    exit 1
fi

# shellcheck source=/dev/null
source "$HOME/.config/shell/bin/lib/verify-launch.sh"
# shellcheck source=/dev/null
source "$HOME/.config/shell/bin/lib/verify-layout.sh"

SESSION="$(tmux display-message -p '#{session_name}')"
ROOT="$(verify_workflow_root "$ROOT")"
verify_set_workflow_dir "$SESSION" "$ROOT" >/dev/null
tmux set-option -t "$SESSION" @workflow_mode verify

PROJECT_NAME="PROJECT_NAME"
RISK_PROFILE="MEDIUM"

verify_apply_theme "$SESSION" "$PROJECT_NAME" "$RISK_PROFILE" "$VERIFY_DIR/tmux-theme.conf"

# Pass 2 context: omit confirm split when no verify-tier pane — set to 0.
CONFIRM_SPLIT=1

if verify_layout_ok "$SESSION"; then
    tmux select-window -t 'verify'
else
    # Pass 1: GIT major left column; ops stack minor right column.
    # Pass 2: VERIFY confirm minor top; WATCH scroll major center; CMD minor bottom-right.
    # Omit FILES/SYS unless they answer a specific verify question (see skill value audit).
    verify_layout_build_golden_grid "$SESSION" "$ROOT" "$CONFIRM_SPLIT"

    if command -v lazygit >/dev/null 2>&1; then
        verify_launch_pane 'verify.0' monitor 'GIT' "$ROOT" lazygit
    else
        verify_launch_pane 'verify.0' monitor 'GIT' "$ROOT" "echo 'install lazygit (optional: paru -S lazygit)'"
    fi

    verify_launch_pane 'verify.2' watch 'WATCH' "$ROOT" 'pnpm test --watch'

    if [ "$CONFIRM_SPLIT" = "1" ]; then
        verify_launch_pane 'verify.1' verify 'VERIFY' "$ROOT" 'pnpm test'
    fi

    verify_launch_pane 'verify.3' monitor 'CMD' "$ROOT" ''

    tmux set-option -t "$SESSION" @verify_layout_version golden-4phi

    tmux select-pane -t 'verify.3'
fi

CONSOLE="$(verify_console_target "$SESSION")"
verify_maybe_rescan "$SESSION" "$CONSOLE"
tmux select-pane -t "$CONSOLE"
