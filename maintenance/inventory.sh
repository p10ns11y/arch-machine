#!/usr/bin/env bash
# Inventory collector — surface-agnostic workstation package/tool snapshot.
# Schema: tinfoil.inventory.v1 (JSON). Consumed by CLI, future Rust TUI, Grok plugin, evidence.
#
# Usage:
#   ./maintenance/inventory.sh              # write snapshot + human summary
#   ./maintenance/inventory.sh --json       # JSON only on stdout
#   ./maintenance/inventory.sh --text       # human table only (no write)
#   ./maintenance/inventory.sh --write      # force write under logs/
#   ./maintenance/inventory.sh --no-write   # never write
#   ./maintenance/inventory.sh --explicit-only
#   ./maintenance/inventory.sh --help

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../" && pwd)"
CONFIG_DIR="$ROOT_DIR/config"
TOOLS_YAML="$CONFIG_DIR/tools.yaml"

get_logs_dir() {
    if [[ "$ROOT_DIR" == "/usr/share/tinfoil" || "$ROOT_DIR" == /usr/share/tinfoil* ]]; then
        local data_home="${XDG_DATA_HOME:-$HOME/.local/share}"
        echo "$data_home/tinfoil/logs"
    else
        echo "$ROOT_DIR/logs"
    fi
}

LOGS_DIR="$(get_logs_dir)"
SCHEMA_VERSION="tinfoil.inventory.v1"

MODE_JSON=false
MODE_TEXT=false
DO_WRITE=true
EXPLICIT_ONLY=false
INCLUDE_MISE=true
INCLUDE_UPGRADABLE=true

usage() {
    cat <<'EOF'
tinfoil inventory — list installed packages/tools (read-only)

USAGE:
  maintenance/inventory.sh [options]
  tinfoil inventory [options]

OPTIONS:
  --json             Print inventory JSON to stdout
  --text             Print human-readable summary to stdout
  --write            Write snapshot under logs/ (default on unless --json/--text only)
  --no-write         Do not write snapshot files
  --explicit-only    Only pacman explicit packages (skip tools.yaml / mise / upgrades)
  --no-mise          Skip mise runtime list
  --no-upgradable    Skip pacman -Qu
  -h, --help         Show this help

OUTPUT:
  logs/inventory-<timestamp>.json
  (optional) prints summary or full JSON per flags

Schema: tinfoil.inventory.v1
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --json) MODE_JSON=true; shift ;;
        --text) MODE_TEXT=true; shift ;;
        --write) DO_WRITE=true; shift ;;
        --no-write) DO_WRITE=false; shift ;;
        --explicit-only) EXPLICIT_ONLY=true; shift ;;
        --no-mise) INCLUDE_MISE=false; shift ;;
        --no-upgradable) INCLUDE_UPGRADABLE=false; shift ;;
        -h|--help) usage; exit 0 ;;
        *)
            echo "Unknown option: $1" >&2
            usage >&2
            exit 2
            ;;
    esac
done

# If neither --json nor --text, default human summary + write
if [[ "$MODE_JSON" == false && "$MODE_TEXT" == false ]]; then
    MODE_TEXT=true
fi

# Pure --json/--text without --write: still write by default unless --no-write
# (agents often want the file). Use --no-write to suppress.

need_cmd() {
    command -v "$1" >/dev/null 2>&1
}

if ! need_cmd jq; then
    echo "ERROR: jq is required for inventory" >&2
    exit 1
fi

TMPDIR_INV="$(mktemp -d "${TMPDIR:-/tmp}/tinfoil-inv.XXXXXX")"
cleanup() { rm -rf "$TMPDIR_INV"; }
trap cleanup EXIT

PKG_TSV="$TMPDIR_INV/packages.tsv"
TOOLS_TSV="$TMPDIR_INV/tools.tsv"
MISE_TSV="$TMPDIR_INV/mise.tsv"
UPG_TSV="$TMPDIR_INV/upgradable.tsv"
: >"$PKG_TSV"
: >"$TOOLS_TSV"
: >"$MISE_TSV"
: >"$UPG_TSV"

# --- pacman explicit (operator-installed) ---
collect_pacman_explicit() {
    if ! need_cmd pacman; then
        echo "WARN: pacman not found — empty package list" >&2
        return 0
    fi
    # name<TAB>version
    pacman -Qe 2>/dev/null | awk '{print $1 "\t" $2}' >"$PKG_TSV" || true
}

# --- tools.yaml names: installed? ---
collect_tools_yaml() {
    if [[ ! -f "$TOOLS_YAML" ]]; then
        return 0
    fi
    if ! need_cmd yq; then
        echo "WARN: yq not found — skipping tools.yaml match" >&2
        return 0
    fi
    local names
    # Compatible with yq 4.x (mikefarah): walk all .name scalars
    names=$(yq -r '.. | .name? // empty' "$TOOLS_YAML" 2>/dev/null | grep -v '^$' | sort -u || true)
    if [[ -z "$names" ]]; then
        # Fallback: system packages array only
        names=$(yq -r '.tools.system.packages[].name // empty' "$TOOLS_YAML" 2>/dev/null | grep -v '^$' | sort -u || true)
    fi

    local name ver installed
    while IFS= read -r name; do
        [[ -z "$name" || "$name" == "null" ]] && continue
        installed="false"
        ver=""
        if need_cmd pacman && pacman -Qi "$name" &>/dev/null; then
            installed="true"
            ver=$(pacman -Qi "$name" 2>/dev/null | awk -F': ' '/^Version/{print $2; exit}' || true)
        elif command -v "$name" &>/dev/null; then
            # CLI present but not a pacman package (e.g. mise-managed or user binary)
            installed="true"
            ver="path:$(command -v "$name")"
        fi
        printf '%s\t%s\t%s\n' "$name" "$installed" "$ver" >>"$TOOLS_TSV"
    done <<<"$names"
}

collect_mise() {
    if [[ "$INCLUDE_MISE" != true ]]; then
        return 0
    fi
    if ! need_cmd mise; then
        return 0
    fi
    # tool version source (best-effort; mise list format varies)
    mise list 2>/dev/null | awk 'NF>=2 {print $1 "\t" $2}' >"$MISE_TSV" || true
}

collect_upgradable() {
    if [[ "$INCLUDE_UPGRADABLE" != true ]]; then
        return 0
    fi
    if ! need_cmd pacman; then
        return 0
    fi
    # name old -> new  (pacman -Qu: "pkg old -> new")
    pacman -Qu 2>/dev/null | awk '{
      if (NF >= 4 && $3 == "->") print $1 "\t" $2 "\t" $4
      else if (NF >= 2) print $1 "\t" $2 "\t"
    }' >"$UPG_TSV" || true
}

collect_pacman_explicit
if [[ "$EXPLICIT_ONLY" != true ]]; then
    collect_tools_yaml
    collect_mise
    collect_upgradable
fi

# Build tools.yaml lookup set for tagging packages
TOOLS_NAMES_FILE="$TMPDIR_INV/tools_names.txt"
cut -f1 "$TOOLS_TSV" 2>/dev/null | sort -u >"$TOOLS_NAMES_FILE" || : >"$TOOLS_NAMES_FILE"

build_json() {
    local ts hostname
    ts="$(date -Iseconds)"
    hostname="$(hostname 2>/dev/null || echo unknown)"

    # packages array
    local packages_json
    packages_json=$(
        if [[ ! -s "$PKG_TSV" ]]; then
            echo '[]'
        else
            while IFS=$'\t' read -r name ver; do
                [[ -z "${name:-}" ]] && continue
                local in_tools="false"
                if grep -qxF "$name" "$TOOLS_NAMES_FILE" 2>/dev/null; then
                    in_tools="true"
                fi
                jq -nc \
                    --arg n "$name" \
                    --arg v "${ver:-}" \
                    --argjson it "$in_tools" \
                    '{name:$n, version:$v, source:"pacman-explicit", in_tools_yaml:$it}'
            done <"$PKG_TSV" | jq -s '.'
        fi
    )

    local tools_json
    tools_json=$(
        if [[ ! -s "$TOOLS_TSV" ]]; then
            echo '[]'
        else
            while IFS=$'\t' read -r name installed ver; do
                [[ -z "${name:-}" ]] && continue
                jq -nc \
                    --arg n "$name" \
                    --argjson i "${installed:-false}" \
                    --arg v "${ver:-}" \
                    '{name:$n, installed:$i, version:$v}'
            done <"$TOOLS_TSV" | jq -s '.'
        fi
    )

    local mise_json
    mise_json=$(
        if [[ ! -s "$MISE_TSV" ]]; then
            echo '[]'
        else
            while IFS=$'\t' read -r tool ver; do
                [[ -z "${tool:-}" ]] && continue
                jq -nc --arg t "$tool" --arg v "${ver:-}" '{tool:$t, version:$v}'
            done <"$MISE_TSV" | jq -s '.'
        fi
    )

    local upg_json
    upg_json=$(
        if [[ ! -s "$UPG_TSV" ]]; then
            echo '[]'
        else
            while IFS=$'\t' read -r name old new; do
                [[ -z "${name:-}" ]] && continue
                jq -nc \
                    --arg n "$name" \
                    --arg o "${old:-}" \
                    --arg w "${new:-}" \
                    '{name:$n, current:$o, available:$w}'
            done <"$UPG_TSV" | jq -s '.'
        fi
    )

    local exp_count tools_hit tools_miss upg_count mise_count
    exp_count=$(wc -l <"$PKG_TSV" | tr -d ' ')
    tools_hit=$(awk -F'\t' '$2=="true"{c++} END{print c+0}' "$TOOLS_TSV")
    tools_miss=$(awk -F'\t' '$2=="false"{c++} END{print c+0}' "$TOOLS_TSV")
    upg_count=$(wc -l <"$UPG_TSV" | tr -d ' ')
    mise_count=$(wc -l <"$MISE_TSV" | tr -d ' ')

    jq -n \
        --arg schema "$SCHEMA_VERSION" \
        --arg ts "$ts" \
        --arg host "$hostname" \
        --arg root "$ROOT_DIR" \
        --argjson packages "$packages_json" \
        --argjson tools_yaml "$tools_json" \
        --argjson mise "$mise_json" \
        --argjson upgradable "$upg_json" \
        --argjson explicit_count "$exp_count" \
        --argjson tools_hit "$tools_hit" \
        --argjson tools_miss "$tools_miss" \
        --argjson upg_count "$upg_count" \
        --argjson mise_count "$mise_count" \
        '{
          schema: $schema,
          timestamp: $ts,
          hostname: $host,
          root: $root,
          summary: {
            explicit_packages: $explicit_count,
            tools_yaml_installed: $tools_hit,
            tools_yaml_missing: $tools_miss,
            upgradable: $upg_count,
            mise_runtimes: $mise_count
          },
          packages: $packages,
          tools_yaml: $tools_yaml,
          mise: $mise,
          upgradable: $upgradable
        }'
}

INVENTORY_JSON="$(build_json)"

stamp="$(date +%Y%m%d-%H%M%S)"
OUT_JSON="$LOGS_DIR/inventory-${stamp}.json"

if [[ "$DO_WRITE" == true ]]; then
    mkdir -p "$LOGS_DIR"
    printf '%s\n' "$INVENTORY_JSON" >"$OUT_JSON"
    # Keep a stable "latest" pointer for agents/TUI/Rust without globbing
    ln -sfn "$(basename "$OUT_JSON")" "$LOGS_DIR/inventory-latest.json" 2>/dev/null \
        || cp -f "$OUT_JSON" "$LOGS_DIR/inventory-latest.json"
fi

print_text() {
    local s
    s=$(printf '%s' "$INVENTORY_JSON" | jq -r '.summary | "explicit=\(.explicit_packages) tools_yaml_ok=\(.tools_yaml_installed) tools_yaml_miss=\(.tools_yaml_missing) upgradable=\(.upgradable) mise=\(.mise_runtimes)"')
    echo "tinfoil inventory ($SCHEMA_VERSION)"
    echo "host: $(printf '%s' "$INVENTORY_JSON" | jq -r .hostname)  time: $(printf '%s' "$INVENTORY_JSON" | jq -r .timestamp)"
    echo "summary: $s"
    if [[ "$DO_WRITE" == true && -f "$OUT_JSON" ]]; then
        echo "wrote: $OUT_JSON"
        echo "latest: $LOGS_DIR/inventory-latest.json"
    fi
    echo
    echo "=== Explicit packages (pacman -Qe) — first 40 ==="
    printf '%s' "$INVENTORY_JSON" | jq -r '
      .packages[:40][] |
      "\(.name)  \(.version)\(if .in_tools_yaml then "  [tools.yaml]" else "" end)"
    ' 2>/dev/null || true
    local total
    total=$(printf '%s' "$INVENTORY_JSON" | jq -r '.summary.explicit_packages')
    if [[ "${total:-0}" -gt 40 ]]; then
        echo "... ($((total - 40)) more; use --json for full list)"
    fi
    echo
    echo "=== tools.yaml catalog status ==="
    printf '%s' "$INVENTORY_JSON" | jq -r '
      .tools_yaml[] |
      "\(if .installed then "✓" else "✗" end)  \(.name)  \(.version // "")"
    ' 2>/dev/null || true
    local upg
    upg=$(printf '%s' "$INVENTORY_JSON" | jq -r '.summary.upgradable')
    if [[ "${upg:-0}" -gt 0 ]]; then
        echo
        echo "=== Upgradable (pacman -Qu) — first 20 ==="
        printf '%s' "$INVENTORY_JSON" | jq -r '
          .upgradable[:20][] | "\(.name)  \(.current) -> \(.available)"
        ' 2>/dev/null || true
    fi
}

if [[ "$MODE_JSON" == true ]]; then
    printf '%s\n' "$INVENTORY_JSON"
fi

if [[ "$MODE_TEXT" == true ]]; then
    if [[ "$MODE_JSON" == true ]]; then
        # When both requested, text goes to stderr so JSON stays clean on stdout
        print_text >&2
    else
        print_text
    fi
fi

exit 0
