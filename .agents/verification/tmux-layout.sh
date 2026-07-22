#!/usr/bin/env bash
# arch-machine verification cockpit — golden-ratio layout.
# Usage: tmux-layout.sh [directory]
# Prerequisite: host shellyxz plugins/verification (SHELL_VERIFICATION_LIB)
set -euo pipefail

DIR="${1:-.}"
SCRIPT_NAME="arch-machine-verify-layout"
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

# SN-4a: plugin lib (never ~/.config/shell/bin/lib — that path is obsolete).
# shellcheck source=/dev/null
source "${SHELL_VERIFICATION_LIB:-${HOME}/.config/shell/plugins/verification/lib}/verify-launch.sh"
# shellcheck source=/dev/null
source "${SHELL_VERIFICATION_LIB:-${HOME}/.config/shell/plugins/verification/lib}/verify-layout.sh"

SESSION="$(tmux display-message -p '#{session_name}')"
ROOT="$(verify_workflow_root "$ROOT")"
verify_set_workflow_dir "$SESSION" "$ROOT" >/dev/null
tmux set-option -t "$SESSION" @workflow_mode verify

PROJECT_NAME="arch-machine"
RISK_PROFILE="MEDIUM"

verify_apply_theme "$SESSION" "$PROJECT_NAME" "$RISK_PROFILE" "$VERIFY_DIR/tmux-theme.conf"

CONFIRM_SPLIT=1

# Keep in sync with cockpit.yaml → cockpits.verify
VERIFY_CMD='make lint && make validate-profiles && cargo test --manifest-path tools/archy/Cargo.toml && cargo test --manifest-path tools/groxy/Cargo.toml && cargo test --manifest-path tools/keeper/Cargo.toml && go build -o /tmp/tinfoil ./bin/tinfoil.go && go vet ./bin/tinfoil.go && ./maintenance/extract-evidence.sh --dry-run'
WATCH_CMD='while true; do make lint 2>&1 | tail -40; sleep 30; done'

if verify_layout_ok "$SESSION"; then
    tmux select-window -t 'verify'
else
    verify_layout_build_golden_grid "$SESSION" "$ROOT" "$CONFIRM_SPLIT"

    if command -v lazygit >/dev/null 2>&1; then
        verify_launch_pane 'verify.0' monitor 'GIT' "$ROOT" lazygit
    else
        verify_launch_pane 'verify.0' monitor 'GIT' "$ROOT" "echo 'optional: install lazygit'"
    fi

    verify_launch_pane 'verify.2' watch 'WATCH' "$ROOT" "$WATCH_CMD"

    if [ "$CONFIRM_SPLIT" = "1" ]; then
        verify_launch_pane 'verify.1' verify 'VERIFY' "$ROOT" "$VERIFY_CMD"
    fi

    verify_launch_pane 'verify.3' monitor 'CMD' "$ROOT" ''

    tmux set-option -t "$SESSION" @verify_layout_version golden-4phi
    tmux select-pane -t 'verify.3'
fi

CONSOLE="$(verify_console_target "$SESSION")"
verify_maybe_rescan "$SESSION" "$CONSOLE"
tmux select-pane -t "$CONSOLE"
