#!/usr/bin/env bash
# Structural check: SECRETS-EVERYDAY.md is advice-only and carries required themes.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOC="$ROOT/docs/SECRETS-EVERYDAY.md"
fail=0
[[ -f "$DOC" ]] || { echo "missing $DOC"; exit 1; }
check() {
  local pat="$1"
  if rg -q "$pat" "$DOC"; then echo "ok /$pat/"; else echo "FAIL missing /$pat/"; fail=1; fi
}
check 'Everyday secrets for developers'
check 'API key'
check 'REMEMBER'
check 'STORE offline'
check 'FREE'
check '[Rr]ecover'
check 'runtime|Reconstruct|use time'
check 'OPERATOR-MODEL'
if rg -q 'sk-[a-zA-Z0-9]{10,}|AKIA[0-9A-Z]{16}|BEGIN (RSA |OPENSSH )?PRIVATE KEY' "$DOC"; then
  echo "FAIL secret-shaped payload"; fail=1
else
  echo "ok no secret-shaped payload"
fi
for rel in \
  ../tools/keeper/docs/OPERATOR-MODEL.md \
  ../tools/keeper/docs/THREAT-MODEL.md \
  ../tools/keeper/docs/RECOVERY-CEREMONY.md \
  ../tools/keeper/README.md \
  INDEX.md \
  ../arch-design/keeper.md
do
  real="$(cd "$ROOT/docs" && realpath -m "$rel")"
  if [[ -f "$real" ]]; then echo "ok link $rel"; else echo "FAIL link $rel -> $real"; fail=1; fi
done
# INDEX points here
rg -q 'SECRETS-EVERYDAY' "$ROOT/docs/INDEX.md" || { echo "FAIL INDEX missing link"; fail=1; }
[[ "$fail" -eq 0 ]] || exit 1
echo SECRETS_EVERYDAY_DOC_OK
