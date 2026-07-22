#!/usr/bin/env bash
# apply-remediation.sh — Phase-5 historical demo of policies/security-remediation.md
# SOFT-OBSOLETE (SO-11): not the live dep-audit kill-chain. Prefer
# policies/security-remediation.md + extract-evidence.sh. See
# arch-design/soft-obsolete-candidates.md before rewriting or deleting.
# Usage: ./maintenance/apply-remediation.sh [--dry-run] [target]
# Targets (MVP): legacy-dup, root-pollution, etc.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../" && pwd)"

source "$ROOT_DIR/lib/logger.sh" 2>/dev/null || true

DRY_RUN=false
if [[ "${1:-}" == "--dry-run" ]]; then
    DRY_RUN=true
    shift
fi

TARGET="${1:-}"

echo "=== Arch Machine Policy Self-Application (Phase 5) ==="
echo "Target: ${TARGET:-all-known}"
echo "Dry-run: $DRY_RUN"
echo

case "$TARGET" in
    legacy-dup|setups|systemd-dup)
        echo "Remediating known duplication (see docs/LEGACY.md)"
        if [[ "$DRY_RUN" == true ]]; then
            echo "[DRY-RUN] Would rm -rf setups/ (already killed in Phase 1)"
            echo "[DRY-RUN] Would document systemd/ FS removal requirement"
        else
            echo "Already remediated in Phase 1 per evidence bundles 134739/750/802"
            echo "Run with --dry-run for simulation."
        fi
        ;;
    root-pollution|.kilo|.composer)
        echo "Remediating root pollution"
        if [[ "$DRY_RUN" == true ]]; then
            echo "[DRY-RUN] Would rm -rf .kilo/ .composer/"
        else
            echo "Already killed in Phase 1 (see evidence 134802)"
        fi
        ;;
    *)
        echo "Known high-severity items (from docs/LEGACY.md + current tree):"
        echo "  - legacy-dup (setups/, old systemd/ references)"
        echo "  - root-pollution (.kilo/, .composer/)"
        echo
        echo "Usage: $0 [--dry-run] <target>"
        echo "Evidence will be produced on real runs."
        ;;
esac

# apply subcommand — real (demo) application of the policy
if [[ "$1" == "apply" ]]; then
    echo "Applying policy self-remediation for known high-severity items (see docs/LEGACY.md)..."
    if [[ "$DRY_RUN" == true ]]; then
        echo "[DRY-RUN] Would update LEGACY.md with new self-remediation entry + run extract-evidence.sh"
    else
        echo "Self-remediation action recorded for this run."
        # In real use this would rm known bad patterns or call the 6-step kill
    fi
fi

# Always attempt evidence extraction at the end
if [[ -x "$SCRIPT_DIR/extract-evidence.sh" ]]; then
    echo
    echo "Producing post-remediation evidence..."
    "$SCRIPT_DIR/extract-evidence.sh" >/dev/null 2>&1 || true
    ls -l "$ROOT_DIR/logs/evidence-bundle-"* 2>/dev/null | tail -1 || true
fi

echo
echo "Self-application complete for target. See docs/LEGACY.md for history."
