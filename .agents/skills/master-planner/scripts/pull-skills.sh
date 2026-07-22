#!/usr/bin/env bash
# Install or restore arch-guardian pack via npx skills (no private paths).
set -euo pipefail

PROJECT="${1:-.}"
cd "$PROJECT"

PACK_SKILLS=(
  ai-optimization
  fusion-sage
  higher-order-decision-architect
  stellar-roadmap
  verification-cockpit
  agent-orchestrator
  looper
  git-worktrees
)

if [[ -f skills-lock.json ]]; then
  echo "Restoring from skills-lock.json…"
  npx --yes skills experimental_install
else
  echo "Installing pack from p10ns11y/skills…"
  args=()
  for s in "${PACK_SKILLS[@]}"; do
    args+=(-s "$s")
  done
  npx --yes skills add p10ns11y/skills "${args[@]}" -a cursor -y --copy
fi

mkdir -p .cursor/skills .grok/skills
for dir in .agents/skills/*/; do
  [[ -d "$dir" ]] || continue
  name="$(basename "$dir")"
  ln -sfn "../../.agents/skills/$name" ".cursor/skills/$name"
  ln -sfn "../../.agents/skills/$name" ".grok/skills/$name"
done

echo "Wired .cursor/skills and .grok/skills → .agents/skills"
ls -la .cursor/skills .grok/skills
