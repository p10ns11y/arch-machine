#!/usr/bin/env bash
# Audit user/session units for forbidden graphical-session pulls.
# Exit 0 = clean; 1 = forbidden pull found; 2 = usage/setup error.
set -euo pipefail

# Resolve through symlinks (~/skills/session-unit-order → repo tree).
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
SKILL_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
# .agents/skills/session-unit-order → repo root
ROOT="${ARCH_MACHINE_ROOT:-$(cd "$SKILL_ROOT/../../.." && pwd -P)}"

UNIT_DIRS=(
  "$ROOT/modules/productivity/eye-comfort/units"
  "${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
)
# Optional extra paths from args
UNIT_DIRS+=("$@")

pattern='^(Wants|Requires|BindsTo)=.*graphical-session'
hits=0

echo "session-unit-order audit: skill=$SKILL_ROOT root=$ROOT"
echo "scanning for ${pattern}"
for d in "${UNIT_DIRS[@]}"; do
  if [[ ! -d "$d" ]]; then
    echo "  skip (missing): $d"
    continue
  fi
  echo "  scan: $d"
  if command -v rg >/dev/null 2>&1; then
    if out=$(rg -n "$pattern" "$d" 2>/dev/null); then
      echo "$out"
      hits=$((hits + 1))
    fi
  else
    if out=$(grep -REn "$pattern" "$d" 2>/dev/null); then
      echo "$out"
      hits=$((hits + 1))
    fi
  fi
done

if ((hits > 0)); then
  echo "FAIL: found Wants=/Requires=/BindsTo= graphical-session (timer oneshots must use After= only)"
  exit 1
fi

echo "ok: no forbidden graphical-session pulls in scanned unit dirs"
exit 0
