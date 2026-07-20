#!/usr/bin/env bash
# Searchable install catalog over tools.yaml + profiles (SN-CAT-1).
# Schema: tinfoil.catalog.v1 — shell backend for CLI / archy / Grok.
#
# Compatible with kislyuk/yq (jq wrapper) and plain jq.
#
# Usage:
#   ./maintenance/catalog.sh                     # list all catalog entries
#   ./maintenance/catalog.sh docker              # search query
#   ./maintenance/catalog.sh --json rocm
#   tinfoil search docker

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../" && pwd)"
CONFIG_DIR="$ROOT_DIR/config"
TOOLS_YAML="$CONFIG_DIR/tools.yaml"
PROFILES_DIR="$CONFIG_DIR/profiles"
SCHEMA_VERSION="tinfoil.catalog.v1"

MODE_JSON=false
MODE_TEXT=false
QUERY=""
LIMIT=50

usage() {
    cat <<'EOF'
tinfoil catalog — search tools.yaml + profile labels (read-only)

USAGE:
  maintenance/catalog.sh [options] [query]
  tinfoil search [query]
  tinfoil catalog [query]

OPTIONS:
  --json             JSON on stdout (schema tinfoil.catalog.v1)
  --text             Human table (default when no --json)
  --limit N          Max hits (default 50; 0 = unlimited)
  -h, --help         Show this help

EXAMPLES:
  tinfoil search docker
  tinfoil search rocm --json
  ./maintenance/catalog.sh git

Query matches name, description, or category path (case-insensitive).
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --json) MODE_JSON=true; shift ;;
        --text) MODE_TEXT=true; shift ;;
        --limit)
            LIMIT="${2:-50}"
            shift 2
            ;;
        -h|--help) usage; exit 0 ;;
        --)
            shift
            break
            ;;
        -*)
            echo "Unknown option: $1" >&2
            usage >&2
            exit 2
            ;;
        *)
            if [[ -z "$QUERY" ]]; then
                QUERY="$1"
            else
                QUERY="$QUERY $1"
            fi
            shift
            ;;
    esac
done

if [[ "$MODE_JSON" == false && "$MODE_TEXT" == false ]]; then
    MODE_TEXT=true
fi

need_cmd() { command -v "$1" >/dev/null 2>&1; }

if ! need_cmd jq; then
    echo "ERROR: jq is required for catalog" >&2
    exit 1
fi

if [[ ! -f "$TOOLS_YAML" ]]; then
    echo "ERROR: tools.yaml not found: $TOOLS_YAML" >&2
    exit 1
fi

TMPDIR_CAT="$(mktemp -d "${TMPDIR:-/tmp}/tinfoil-cat.XXXXXX")"
cleanup() { rm -rf "$TMPDIR_CAT"; }
trap cleanup EXIT

# kislyuk/yq: YAML → JSON via jq filter (no mikefarah -o flags)
yq_json() {
    local filter="$1"
    local file="$2"
    if need_cmd yq; then
        yq "$filter" "$file" 2>/dev/null
    else
        return 1
    fi
}

build_profiles_json() {
    local out='[]'
    shopt -s nullglob
    local f name includes
    for f in "$PROFILES_DIR"/*.yaml "$PROFILES_DIR"/*.yml; do
        [[ -f "$f" ]] || continue
        name=$(basename "$f")
        name=${name%.yaml}
        name=${name%.yml}
        includes='[]'
        if need_cmd yq; then
            includes=$(yq '.includes // []' "$f" 2>/dev/null || echo '[]')
        fi
        includes=$(printf '%s' "$includes" | jq '[.[] | tostring | gsub("^\"|\"$";"")]' 2>/dev/null || echo '[]')
        out=$(jq -n --argjson acc "$out" --arg n "$name" --argjson inc "$includes" \
            '$acc + [{name:$n, includes:$inc}]')
    done
    printf '%s' "$out"
}

# Flatten tools.yaml system.packages (+ rocm list) into catalog entries.
build_entries_json() {
    local sys_pkgs='[]'
    local rocm_pkgs='[]'

    if need_cmd yq; then
        sys_pkgs=$(
            yq '
              [.tools.system.packages[]? // empty
               | {
                   name: .name,
                   description: (.description // ""),
                   critical: (.critical // false),
                   kind: "package",
                   category: "system.packages"
                 }]
            ' "$TOOLS_YAML" 2>/dev/null || echo '[]'
        )
        rocm_pkgs=$(
            yq '
              [(.tools.system.rocm.packages // [])[]
               | {
                   name: .,
                   description: "ROCm compute stack package",
                   critical: false,
                   kind: "package",
                   category: "system.rocm"
                 }]
            ' "$TOOLS_YAML" 2>/dev/null || echo '[]'
        )
    else
        # Minimal scrape without yq
        local arr='[]' name
        while IFS= read -r name; do
            [[ -z "$name" ]] && continue
            arr=$(jq -n --argjson a "$arr" --arg n "$name" \
                '$a + [{name:$n, description:"", critical:false, kind:"package", category:"system.packages"}]')
        done < <(grep -E '^\s+-\s+name:' "$TOOLS_YAML" | sed -E 's/.*name:[[:space:]]*"?([^"#]+)"?.*/\1/' | tr -d ' ' || true)
        sys_pkgs="$arr"
    fi

    # Ensure valid JSON arrays
    sys_pkgs=$(printf '%s' "$sys_pkgs" | jq -c . 2>/dev/null || echo '[]')
    rocm_pkgs=$(printf '%s' "$rocm_pkgs" | jq -c . 2>/dev/null || echo '[]')

    jq -n --argjson a "$sys_pkgs" --argjson b "$rocm_pkgs" \
        '$a + $b | unique_by(.name)'
}

# Map entry → profiles that include matching module.* tokens
attach_profiles() {
    local entries="$1"
    local profiles="$2"
    jq -n --argjson entries "$entries" --argjson profiles "$profiles" '
      def module_of($cat):
        if ($cat | startswith("system")) then "system"
        elif ($cat | startswith("development")) then "development"
        elif ($cat | startswith("ml")) then "ml_ai"
        elif ($cat | startswith("security")) then "security"
        elif ($cat | startswith("productivity")) then "productivity"
        else "system"
        end;
      $entries | map(
        . as $e
        | (module_of($e.category // "system.packages")) as $mod
        | .profiles = [
            $profiles[]
            | select(
                any(.includes[];
                  . == $mod
                  or startswith($mod + ".")
                )
              )
            | .name
          ]
      )
    '
}

mark_installed() {
    local entries="$1"
    local name installed ver
    local status_json='[]'

    while IFS= read -r name; do
        [[ -z "$name" ]] && continue
        installed=false
        ver=""
        if need_cmd pacman && pacman -Qi "$name" &>/dev/null; then
            installed=true
            ver=$(pacman -Qi "$name" 2>/dev/null | awk -F': ' '/^Version/{print $2; exit}' || true)
        elif command -v "$name" &>/dev/null; then
            installed=true
            ver="path:$(command -v "$name")"
        fi
        status_json=$(jq -n --argjson acc "$status_json" --arg n "$name" --argjson i "$installed" --arg v "$ver" \
            '$acc + [{name:$n, installed:$i, version:$v}]')
    done < <(printf '%s' "$entries" | jq -r '.[].name // empty')

    jq -n --argjson entries "$entries" --argjson st "$status_json" '
      ($st | map({key:.name, value:.}) | from_entries) as $m
      | $entries
      | map(. + {
          installed: ($m[.name].installed // false),
          version: ($m[.name].version // "")
        })
    '
}

PROFILES_JSON_DATA="$(build_profiles_json)"
ENTRIES="$(build_entries_json)"
if [[ -z "$ENTRIES" || "$ENTRIES" == "null" ]]; then
    ENTRIES='[]'
fi
ENTRIES="$(attach_profiles "$ENTRIES" "$PROFILES_JSON_DATA")"
ENTRIES="$(mark_installed "$ENTRIES")"

if [[ -n "$QUERY" ]]; then
    q_lc=$(printf '%s' "$QUERY" | tr '[:upper:]' '[:lower:]')
    ENTRIES=$(printf '%s' "$ENTRIES" | jq --arg q "$q_lc" '
      map(select(
        ((.name // "") | ascii_downcase | contains($q))
        or ((.description // "") | ascii_downcase | contains($q))
        or ((.category // "") | ascii_downcase | contains($q))
        or (any(.profiles[]?; (. | ascii_downcase | contains($q))))
      ))
    ')
fi

if [[ "${LIMIT:-50}" != "0" ]]; then
    ENTRIES=$(printf '%s' "$ENTRIES" | jq --argjson lim "$LIMIT" '.[0:$lim]')
fi

total=$(printf '%s' "$ENTRIES" | jq 'length')
ts="$(date -Iseconds)"

CATALOG_JSON=$(
    jq -n \
        --arg schema "$SCHEMA_VERSION" \
        --arg ts "$ts" \
        --arg root "$ROOT_DIR" \
        --arg q "$QUERY" \
        --argjson results "$ENTRIES" \
        --argjson total "$total" \
        --argjson profiles "$PROFILES_JSON_DATA" \
        '{
          schema: $schema,
          timestamp: $ts,
          root: $root,
          query: $q,
          summary: { hits: $total, profiles: ($profiles|length) },
          results: $results,
          profiles: $profiles
        }'
)

print_text() {
    echo "tinfoil catalog ($SCHEMA_VERSION)"
    if [[ -n "$QUERY" ]]; then
        echo "query: $QUERY"
    else
        echo "query: (all)"
    fi
    echo "hits: $(printf '%s' "$CATALOG_JSON" | jq -r .summary.hits)"
    echo
    printf '%s' "$CATALOG_JSON" | jq -r '
      .results[] |
      "\(if .installed then "✓" else "·" end)  \(.name)\(if .critical == true then "  [critical]" else "" end)\n" +
      "    \(.description // "")\n" +
      "    category=\(.category // "?")  profiles=[\(.profiles // [] | join(", "))]\(if (.version // "") != "" then "  ver=\(.version)" else "" end)"
    ' 2>/dev/null || true
    if [[ -z "$QUERY" ]]; then
        echo
        echo "Tip: tinfoil search docker   ·   tinfoil search rocm --json"
    fi
}

if [[ "$MODE_JSON" == true ]]; then
    printf '%s\n' "$CATALOG_JSON"
fi

if [[ "$MODE_TEXT" == true ]]; then
    if [[ "$MODE_JSON" == true ]]; then
        print_text >&2
    else
        print_text
    fi
fi

exit 0
