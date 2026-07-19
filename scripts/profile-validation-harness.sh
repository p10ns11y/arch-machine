#!/usr/bin/env bash
# Profile Validation Harness (SN-3)
# Every profile includes[] entry maps to modules/<module>/install.sh with install_<module>.
# includes use "module.category" form (e.g. system.base → modules/system + install_system).
# Run from repo root: ./scripts/profile-validation-harness.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PROFILES_DIR="$ROOT_DIR/config/profiles"
MODULES_DIR="$ROOT_DIR/modules"

echo "=== Arch Machine Profile Validation Harness ==="
echo "Root: $ROOT_DIR"
echo

failures=0
warnings=0

inc_fail() {
    failures=$((failures + 1))
}

inc_warn() {
    warnings=$((warnings + 1))
}

# Parse includes from a profile YAML without requiring yq for the happy path.
# Emits one include token per line (no quotes).
extract_includes() {
    local profile="$1"
    if command -v yq >/dev/null 2>&1; then
        # kislyuk/yq (jq wrapper): filter first, then file
        yq -r '.includes[]?' "$profile" 2>/dev/null \
            | sed -E 's/^["'\'']//; s/["'\'']$//' \
            | grep -v '^$' || true
        return 0
    fi
    # Fallback: lines under includes: that look like "  - token"
    awk '
      /^includes:[[:space:]]*$/ { in_inc=1; next }
      in_inc && /^[^[:space:]#]/ { exit }
      in_inc && /^[[:space:]]*-[[:space:]]*/ {
        sub(/^[[:space:]]*-[[:space:]]*/, "")
        gsub(/["'\'']/, "")
        sub(/[[:space:]]+#.*$/, "")
        gsub(/[[:space:]]+$/, "")
        if (length($0)) print
      }
    ' "$profile"
}

validate_include() {
    local profile_name="$1"
    local inc="$2"
    # module.category or bare module
    local module category
    if [[ "$inc" == *.* ]]; then
        module="${inc%%.*}"
        category="${inc#*.}"
    else
        module="$inc"
        category=""
    fi

    # Only top-level module dirs are real install units
    local mod_dir="$MODULES_DIR/$module"
    if [[ ! -d "$mod_dir" ]]; then
        echo "  FAIL: module dir missing for include '$inc' → modules/$module (profile $profile_name)"
        inc_fail
        return
    fi

    if [[ ! -f "$mod_dir/install.sh" ]]; then
        echo "  FAIL: $module/install.sh missing (include $inc, profile $profile_name)"
        inc_fail
        return
    fi

    local sym="install_${module}"
    # Do not source install.sh here — modules expect CONFIG_DIR and trip set -u.
    # Contract: install_<module>() or function install_<module> must appear in the file.
    if ! grep -qE "^${sym}\\(\\)|^function[[:space:]]+${sym}" "$mod_dir/install.sh"; then
        echo "  FAIL: symbol $sym not found in $module/install.sh (include $inc, profile $profile_name)"
        inc_fail
        return
    fi

    if [[ -n "$category" ]]; then
        echo "  OK: $inc → modules/$module ($sym, category=$category)"
    else
        echo "  OK: $inc → modules/$module ($sym)"
    fi
}

shopt -s nullglob
profiles=("$PROFILES_DIR"/*.yaml "$PROFILES_DIR"/*.yml)
if [[ ${#profiles[@]} -eq 0 ]]; then
    echo "FAIL: no profiles under $PROFILES_DIR"
    exit 1
fi

for profile in "${profiles[@]}"; do
    [[ -f "$profile" ]] || continue
    name=$(basename "$profile")
    name=${name%.yaml}
    name=${name%.yml}

    echo "Validating profile: $name"

    mapfile -t modules < <(extract_includes "$profile")
    if [[ ${#modules[@]} -eq 0 ]]; then
        echo "  FAIL: no includes[] in profile $name"
        inc_fail
        continue
    fi

    for mod in "${modules[@]}"; do
        validate_include "$name" "$mod"
    done
    echo
done

echo "=== Summary: failures=$failures warnings=$warnings ==="
if [[ "$failures" -eq 0 ]]; then
    echo "=== All profiles validated successfully ==="
    exit 0
fi
echo "=== Validation completed with $failures failure(s) ==="
exit 1
