#!/usr/bin/env bash
# Read-only Omarchy host probe (SN-OM-1 companion).
# Uses official Omarchy CLI when present — see docs/omarchy-commands.md.
# Schema: tinfoil.omarchy-status.v1
#
# Usage:
#   ./maintenance/omarchy-status.sh
#   ./maintenance/omarchy-status.sh --json
#   tinfoil omarchy

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../" && pwd)"
SCHEMA_VERSION="tinfoil.omarchy-status.v1"

MODE_JSON=false
MODE_TEXT=false

usage() {
    cat <<'EOF'
tinfoil omarchy — read-only Omarchy status snapshot

USAGE:
  maintenance/omarchy-status.sh [options]
  tinfoil omarchy [options]

OPTIONS:
  --json             JSON on stdout (schema tinfoil.omarchy-status.v1)
  --text             Human summary (default)
  -h, --help         Help

Never mutates packages, themes, or configs. For package taste use:
  omarchy pkg install | omarchy pkg add …
  tinfoil pkg --update|--remove …   # dry-run default
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --json) MODE_JSON=true; shift ;;
        --text) MODE_TEXT=true; shift ;;
        -h|--help) usage; exit 0 ;;
        *)
            echo "Unknown option: $1" >&2
            usage >&2
            exit 2
            ;;
    esac
done

if [[ "$MODE_JSON" == false && "$MODE_TEXT" == false ]]; then
    MODE_TEXT=true
fi

need_cmd() { command -v "$1" >/dev/null 2>&1; }

# Prefer explicit OMARCHY_PATH bin, then PATH
resolve_omarchy() {
    if [[ -n "${OMARCHY_PATH:-}" && -x "$OMARCHY_PATH/bin/omarchy" ]]; then
        echo "$OMARCHY_PATH/bin/omarchy"
        return 0
    fi
    local home_om="${XDG_DATA_HOME:-$HOME/.local/share}/omarchy/bin/omarchy"
    if [[ -x "$home_om" ]]; then
        echo "$home_om"
        return 0
    fi
    if need_cmd omarchy; then
        command -v omarchy
        return 0
    fi
    return 1
}

run_soft() {
    # Capture stdout even when Omarchy exits non-zero (e.g. update available → 1).
    local out rc=0
    out="$("$@" 2>/dev/null)" || rc=$?
    printf '%s' "$out"
    return 0
}

OM_BIN=""
PRESENT=false
if OM_BIN="$(resolve_omarchy)"; then
    PRESENT=true
fi

ts="$(date -Iseconds)"
host="$(hostname 2>/dev/null || echo unknown)"

version=""
branch=""
channel=""
theme=""
update_available=""
battery=""
themes_json='[]'
pkg_probes_json='[]'
notes=()

if [[ "$PRESENT" == true ]]; then
    version="$(run_soft "$OM_BIN" version || true)"
    branch="$(run_soft "$OM_BIN" version branch || true)"
    channel="$(run_soft "$OM_BIN" version channel || true)"
    theme="$(run_soft "$OM_BIN" theme current || true)"
    update_available="$(run_soft "$OM_BIN" update available || true)"
    battery="$(run_soft "$OM_BIN" battery status || true)"

    # theme list → JSON array of non-empty lines
    if themes_raw="$(run_soft "$OM_BIN" theme list || true)"; then
        themes_json=$(printf '%s\n' "$themes_raw" | jq -R . | jq -s 'map(select(length>0))')
    fi

    # Presence probes for common sentinel/tooling packages
    probe_pkgs=(jq git base-devel docker gum)
    for pkg in "${probe_pkgs[@]}"; do
        ok=false
        if "$OM_BIN" pkg present "$pkg" &>/dev/null; then
            ok=true
        fi
        pkg_probes_json=$(jq -n --argjson acc "$pkg_probes_json" --arg n "$pkg" --argjson p "$ok" \
            '$acc + [{name:$n, present:$p}]')
    done
else
    notes+=("omarchy CLI not found; set OMARCHY_PATH or install Omarchy")
    notes+=("baseline still available: config/baselines/omarchy.yaml")
fi

# Docs path for agents
cmds_doc="$ROOT_DIR/docs/omarchy-commands.md"
playbook="$ROOT_DIR/docs/omarchy.md"

notes_json=$(printf '%s\n' "${notes[@]+"${notes[@]}"}" | jq -R . | jq -s 'map(select(length>0))')

STATUS_JSON=$(
    jq -n \
        --arg schema "$SCHEMA_VERSION" \
        --arg ts "$ts" \
        --arg host "$host" \
        --arg root "$ROOT_DIR" \
        --argjson present "$PRESENT" \
        --arg om_bin "${OM_BIN:-}" \
        --arg version "$version" \
        --arg branch "$branch" \
        --arg channel "$channel" \
        --arg theme "$theme" \
        --arg update "$update_available" \
        --arg battery "$battery" \
        --argjson themes "$themes_json" \
        --argjson probes "$pkg_probes_json" \
        --argjson notes "$notes_json" \
        --arg cmds_doc "$cmds_doc" \
        --arg playbook "$playbook" \
        '{
          schema: $schema,
          timestamp: $ts,
          hostname: $host,
          root: $root,
          omarchy: {
            present: $present,
            binary: $om_bin,
            version: $version,
            branch: $branch,
            channel: $channel,
            theme_current: $theme,
            update_available: $update,
            battery: $battery,
            themes: $themes,
            pkg_probes: $probes
          },
          docs: {
            commands: $cmds_doc,
            playbook: $playbook
          },
          notes: $notes
        }'
)

print_text() {
    echo "tinfoil omarchy-status ($SCHEMA_VERSION)"
    echo "host: $host  time: $ts"
    if [[ "$PRESENT" != true ]]; then
        echo "omarchy: NOT FOUND on PATH / OMARCHY_PATH"
        for n in "${notes[@]+"${notes[@]}"}"; do
            [[ -n "$n" ]] && echo "note: $n"
        done
        echo
        echo "Command reference (offline): $cmds_doc"
        return 0
    fi
    echo "omarchy: $OM_BIN"
    echo "version: ${version:-?}  branch: ${branch:-?}  channel: ${channel:-?}"
    echo "theme:   ${theme:-?}"
    [[ -n "$update_available" ]] && echo "update:  $update_available"
    [[ -n "$battery" ]] && echo "battery: $battery"
    echo
    echo "=== pkg present probes ==="
    printf '%s' "$STATUS_JSON" | jq -r '.omarchy.pkg_probes[] | "\(if .present then "✓" else "✗" end)  \(.name)"' 2>/dev/null || true
    echo
    echo "=== themes (first 12) ==="
    printf '%s' "$STATUS_JSON" | jq -r '.omarchy.themes[:12][]' 2>/dev/null || true
    local nthemes
    nthemes=$(printf '%s' "$STATUS_JSON" | jq -r '.omarchy.themes|length')
    if [[ "${nthemes:-0}" -gt 12 ]]; then
        echo "... ($((nthemes - 12)) more; use --json)"
    fi
    echo
    echo "Flows:"
    echo "  omarchy pkg install          # interactive install TUI"
    echo "  omarchy theme set <name>     # apply theme"
    echo "  tinfoil inventory            # ownership tags"
    echo "  tinfoil search docker        # arch-machine catalog"
    echo "  docs: $playbook"
    echo "  full CLI: $cmds_doc"
}

if [[ "$MODE_JSON" == true ]]; then
    printf '%s\n' "$STATUS_JSON"
fi
if [[ "$MODE_TEXT" == true ]]; then
    if [[ "$MODE_JSON" == true ]]; then
        print_text >&2
    else
        print_text
    fi
fi

exit 0
