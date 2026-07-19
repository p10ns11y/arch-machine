#!/usr/bin/env bash
# Consent-gated multi-package update/remove (SN-INV-2).
# Dry-run by default. Never silent bulk uninstall.
#
# Usage:
#   ./maintenance/package-actuate.sh --update pkg1 pkg2
#   ./maintenance/package-actuate.sh --remove pkg1 --dry-run
#   ./maintenance/package-actuate.sh --remove pkg1 --yes --i-accept-risk
#   tinfoil pkg --update foo
#
# Schema (JSON plan): tinfoil.actuate.v1

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../" && pwd)"
REFUSE_FILE="$ROOT_DIR/policies/package-refuse-list.txt"
SCHEMA_VERSION="tinfoil.actuate.v1"

ACTION="" # update | remove
DRY_RUN=true
YES=false
I_ACCEPT=false
PACKAGES=()

get_logs_dir() {
    if [[ "$ROOT_DIR" == "/usr/share/tinfoil" || "$ROOT_DIR" == /usr/share/tinfoil* ]]; then
        echo "${XDG_DATA_HOME:-$HOME/.local/share}/tinfoil/logs"
    else
        echo "$ROOT_DIR/logs"
    fi
}
LOGS_DIR="$(get_logs_dir)"

usage() {
    cat <<'EOF'
tinfoil package actuate — update/remove with dry-run default (SN-INV-2)

USAGE:
  maintenance/package-actuate.sh --update|--remove pkg [pkg...] [options]
  tinfoil pkg --update pkg...
  tinfoil pkg --remove pkg...

OPTIONS:
  --update           pacman -Syu for listed packages (or -S if not upgrade-only)
  --remove           pacman -Rns for listed packages
  --dry-run          Plan only (DEFAULT — never mutates without --yes)
  --yes              Execute after plan (still needs --i-accept-risk for --remove)
  --i-accept-risk    Required with --yes --remove (double consent)
  --json             Print actuate plan JSON
  -h, --help         Help

SAFETY:
  - Dry-run is the default.
  - policies/package-refuse-list.txt packages cannot be removed.
  - Remove requires --yes AND --i-accept-risk.
  - Update with --yes runs pacman -S --needed (not full -Syu world).

EXAMPLES:
  ./maintenance/package-actuate.sh --update jq --dry-run
  ./maintenance/package-actuate.sh --remove some-aur-toy --dry-run
EOF
}

MODE_JSON=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --update) ACTION=update; shift ;;
        --remove) ACTION=remove; shift ;;
        --dry-run) DRY_RUN=true; shift ;;
        --yes) YES=true; DRY_RUN=false; shift ;;
        --i-accept-risk) I_ACCEPT=true; shift ;;
        --json) MODE_JSON=true; shift ;;
        -h|--help) usage; exit 0 ;;
        --)
            shift
            while [[ $# -gt 0 ]]; do PACKAGES+=("$1"); shift; done
            break
            ;;
        -*)
            echo "Unknown option: $1" >&2
            usage >&2
            exit 2
            ;;
        *)
            PACKAGES+=("$1")
            shift
            ;;
    esac
done

if [[ -z "$ACTION" ]]; then
    echo "ERROR: require --update or --remove" >&2
    usage >&2
    exit 2
fi

if [[ ${#PACKAGES[@]} -eq 0 ]]; then
    echo "ERROR: no packages specified" >&2
    usage >&2
    exit 2
fi

need_cmd() { command -v "$1" >/dev/null 2>&1; }

if ! need_cmd jq; then
    echo "ERROR: jq required" >&2
    exit 1
fi

# Load refuse set
declare -A REFUSE=()
if [[ -f "$REFUSE_FILE" ]]; then
    while IFS= read -r line || [[ -n "$line" ]]; do
        line="${line%%#*}"
        line="$(echo "$line" | xargs 2>/dev/null || true)"
        [[ -z "$line" ]] && continue
        REFUSE["$line"]=1
    done <"$REFUSE_FILE"
fi

PLANNED=()
BLOCKED=()
MISSING=()
NOTES=()

for pkg in "${PACKAGES[@]}"; do
    if [[ "$ACTION" == "remove" && -n "${REFUSE[$pkg]:-}" ]]; then
        BLOCKED+=("$pkg")
        NOTES+=("refuse-list blocks remove: $pkg")
        continue
    fi
    if need_cmd pacman; then
        if ! pacman -Qi "$pkg" &>/dev/null; then
            if [[ "$ACTION" == "remove" ]]; then
                MISSING+=("$pkg")
                NOTES+=("not installed, skip remove: $pkg")
                continue
            fi
            # update/install path: allow if repo knows it
            if ! pacman -Si "$pkg" &>/dev/null; then
                MISSING+=("$pkg")
                NOTES+=("not found in pacman sync DB: $pkg")
                continue
            fi
        fi
    fi
    PLANNED+=("$pkg")
done

ts="$(date -Iseconds)"
host="$(hostname 2>/dev/null || echo unknown)"
would_cmd=""
case "$ACTION" in
    update)
        if [[ ${#PLANNED[@]} -gt 0 ]]; then
            would_cmd="sudo pacman -S --needed --noconfirm ${PLANNED[*]}"
        fi
        ;;
    remove)
        if [[ ${#PLANNED[@]} -gt 0 ]]; then
            would_cmd="sudo pacman -Rns --noconfirm ${PLANNED[*]}"
        fi
        ;;
esac

PLAN_JSON=$(
    jq -n \
        --arg schema "$SCHEMA_VERSION" \
        --arg ts "$ts" \
        --arg host "$host" \
        --arg action "$ACTION" \
        --argjson dry "$DRY_RUN" \
        --argjson yes "$YES" \
        --arg cmd "${would_cmd:-}" \
        --argjson planned "$(printf '%s\n' "${PLANNED[@]+"${PLANNED[@]}"}" | jq -R . | jq -s 'map(select(length>0))')" \
        --argjson blocked "$(printf '%s\n' "${BLOCKED[@]+"${BLOCKED[@]}"}" | jq -R . | jq -s 'map(select(length>0))')" \
        --argjson missing "$(printf '%s\n' "${MISSING[@]+"${MISSING[@]}"}" | jq -R . | jq -s 'map(select(length>0))')" \
        --argjson notes "$(printf '%s\n' "${NOTES[@]+"${NOTES[@]}"}" | jq -R . | jq -s 'map(select(length>0))')" \
        '{
          schema: $schema,
          timestamp: $ts,
          hostname: $host,
          action: $action,
          dry_run: $dry,
          execute: ($yes and ($dry|not)),
          planned: $planned,
          blocked: $blocked,
          missing: $missing,
          notes: $notes,
          command: $cmd
        }'
)

print_text() {
    echo "tinfoil actuate ($SCHEMA_VERSION)"
    echo "action: $ACTION  dry_run: $DRY_RUN  yes: $YES"
    echo "planned: ${PLANNED[*]:-(none)}"
    [[ ${#BLOCKED[@]} -gt 0 ]] && echo "blocked (refuse-list): ${BLOCKED[*]}"
    [[ ${#MISSING[@]} -gt 0 ]] && echo "missing/skip: ${MISSING[*]}"
    for n in "${NOTES[@]+"${NOTES[@]}"}"; do
        [[ -n "$n" ]] && echo "note: $n"
    done
    if [[ -n "$would_cmd" ]]; then
        echo "command: $would_cmd"
    fi
    # Prefer Omarchy interactive taste when CLI is present (docs/omarchy-commands.md)
    if command -v omarchy >/dev/null 2>&1 || [[ -x "${OMARCHY_PATH:-${XDG_DATA_HOME:-$HOME/.local/share}/omarchy}/bin/omarchy" ]]; then
        case "$ACTION" in
            update)
                if [[ ${#PLANNED[@]} -gt 0 ]]; then
                    echo "omarchy alt: omarchy pkg add ${PLANNED[*]}"
                fi
                ;;
            remove)
                if [[ ${#PLANNED[@]} -gt 0 ]]; then
                    echo "omarchy alt: omarchy pkg drop ${PLANNED[*]}"
                fi
                ;;
        esac
        echo "omarchy TUI: omarchy pkg install | omarchy pkg remove"
    fi
    if [[ "$DRY_RUN" == true ]]; then
        echo
        echo "DRY-RUN only — no changes. Re-run with --yes to execute updates;"
        echo "for remove, use --yes --i-accept-risk."
    fi
}

if [[ "$MODE_JSON" == true ]]; then
    printf '%s\n' "$PLAN_JSON"
else
    print_text
fi

# Write plan always (evidence)
mkdir -p "$LOGS_DIR"
stamp="$(date +%Y%m%d-%H%M%S)"
plan_path="$LOGS_DIR/actuate-${stamp}.json"
printf '%s\n' "$PLAN_JSON" >"$plan_path"
ln -sfn "$(basename "$plan_path")" "$LOGS_DIR/actuate-latest.json" 2>/dev/null \
    || cp -f "$plan_path" "$LOGS_DIR/actuate-latest.json"
if [[ "$MODE_JSON" != true ]]; then
    echo "plan: $plan_path"
fi

# Execute path
if [[ "$YES" != true || "$DRY_RUN" == true ]]; then
    exit 0
fi

if [[ ${#PLANNED[@]} -eq 0 ]]; then
    echo "Nothing to execute." >&2
    exit 1
fi

if [[ "$ACTION" == "remove" && "$I_ACCEPT" != true ]]; then
    echo "ERROR: --remove --yes requires --i-accept-risk (double consent)" >&2
    exit 2
fi

if ! need_cmd pacman; then
    echo "ERROR: pacman not available" >&2
    exit 1
fi

echo "Executing: $would_cmd"
# shellcheck disable=SC2086
case "$ACTION" in
    update)
        sudo pacman -S --needed --noconfirm "${PLANNED[@]}"
        ;;
    remove)
        sudo pacman -Rns --noconfirm "${PLANNED[@]}"
        ;;
esac

echo "actuate complete."
exit 0
