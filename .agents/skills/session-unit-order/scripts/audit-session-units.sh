#!/usr/bin/env bash
# Audit user/session units for forbidden graphical-session pulls.
# Exit 0 = clean; 1 = forbidden pull found.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
SKILL_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"

# Discover workspace root (optional eye-comfort units).
discover_repo_root() {
  if [[ -n "${ARCH_MACHINE_ROOT:-}" && -d "$ARCH_MACHINE_ROOT" ]]; then
    echo "$ARCH_MACHINE_ROOT"
    return
  fi
  if command -v git >/dev/null 2>&1; then
    local gr
    gr="$(git rev-parse --show-toplevel 2>/dev/null || true)"
    if [[ -n "$gr" ]]; then
      echo "$gr"
      return
    fi
  fi
  echo "$PWD"
}

ROOT="$(discover_repo_root)"

UNIT_DIRS=(
  "$ROOT/modules/productivity/eye-comfort/units"
  "${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
)
UNIT_DIRS+=("$@")

pattern='^(Wants|Requires|BindsTo)=.*graphical-session'
hits=0
scanned=0

echo "session-unit-order audit: skill=$SKILL_ROOT workspace=$ROOT"
echo "scanning for ${pattern}"
for d in "${UNIT_DIRS[@]}"; do
  if [[ ! -d "$d" ]]; then
    echo "  skip (missing): $d"
    continue
  fi
  scanned=$((scanned + 1))
  echo "  scan: $d"
  if command -v rg >/dev/null 2>&1; then
    if out=$(rg -n "$pattern" "$d" 2>/dev/null); then
      echo "$out"
      hits=$((hits + 1))
    fi
  else
    if out=$(grep -REn "$pattern" "$d" 2>/dev/null || true); then
      if [[ -n "$out" ]]; then
        echo "$out"
        hits=$((hits + 1))
      fi
    fi
  fi
done

if ((scanned == 0)); then
  echo "WARN: no unit dirs found; pass paths as args or run from a repo with eye-comfort units"
fi

if ((hits > 0)); then
  echo "FAIL: found Wants=/Requires=/BindsTo= graphical-session (timer oneshots must use After= only)"
  exit 1
fi

echo "ok: no forbidden graphical-session pulls in scanned unit dirs"
exit 0
