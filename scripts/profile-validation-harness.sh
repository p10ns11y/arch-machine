#!/usr/bin/env bash
# Phase 4 Profile Validation Harness
# Exercises that every profile's includes[] has a corresponding module/ dir
# and that the expected install_<module> symbol can be sourced.
# Run from repo root: ./scripts/profile-validation-harness.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG_DIR="$ROOT_DIR/config"
PROFILES_DIR="$CONFIG_DIR/profiles"

echo "=== Arch Machine Profile Validation Harness (Phase 4) ==="
echo "Root: $ROOT_DIR"
echo

failures=0

for profile in "$PROFILES_DIR"/*.yaml "$PROFILES_DIR"/*.yml; do
    [[ -f "$profile" ]] || continue
    name=$(basename "$profile" .yaml)
    name=${name%.yml}

    echo "Validating profile: $name"

    # Extract includes using basic yq or grep fallback
    if command -v yq >/dev/null 2>&1; then
        modules=$(yq '.includes[]' "$profile" 2>/dev/null || echo "")
    else
        modules=$(grep -E '^\s*-\s*' "$profile" | sed 's/.*- //' | tr -d '"' || echo "")
    fi

    for mod in $modules; do
        mod_dir="$ROOT_DIR/modules/$mod"
        if [[ ! -d "$mod_dir" ]]; then
            echo "  FAIL: module dir missing for '$mod' (profile $name)"
            ((failures++))
            continue
        fi

        # Check for install script
        if [[ ! -f "$mod_dir/install.sh" ]]; then
            echo "  FAIL: $mod/install.sh missing (profile $name)"
            ((failures++))
            continue
        fi

        # Very light symbol check (source in subshell)
        if ! (source "$mod_dir/install.sh" 2>/dev/null && declare -F "install_$mod" >/dev/null); then
            echo "  WARN: install_$mod function not clearly exported from $mod/install.sh (profile $name)"
            # Not hard fail for now — many modules use different patterns
        else
            echo "  OK: $mod (install_$mod present)"
        fi
    done
done

echo
if [[ $failures -eq 0 ]]; then
    echo "=== All profiles validated successfully ==="
    exit 0
else
    echo "=== Validation completed with $failures failure(s) ==="
    exit 1
fi
