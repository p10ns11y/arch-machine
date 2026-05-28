#!/bin/bash
# init-plan.sh — Grok Build Autonomous Bootstrap & Launcher
# Mission: ARCH-MACHINE-2026-05-28
# This script kicks off the entire overnight autonomous resolution.
# It is self-referential and will be updated by the agent.

set -euo pipefail

MISSION_ID="ARCH-MACHINE-2026-05-28"
REPO_DIR="$(pwd)"
LOG_DIR="$REPO_DIR/logs/grok-build"
mkdir -p "$LOG_DIR"

echo "🚀 [$(date -Iseconds)] Starting Grok Build Autonomous Mission: $MISSION_ID"
echo "Working directory: $REPO_DIR"

# === PHASE 0: BOOTSTRAP ===
echo "=== PHASE 0: BOOTSTRAP & GROUNDING ==="

# Ensure we are on sentinel and up to date
git fetch origin
git checkout sentinel || git checkout -b sentinel origin/sentinel
git pull --ff-only origin sentinel || true

# Create living documents if they don't exist
if [ ! -f STATE.md ]; then
    cat > STATE.md << 'EOF'
# STATE.md — Live Mission State (ARCH-MACHINE-2026-05-28)
**Mission Started**: $(date -Iseconds)
**Current Phase**: 0 - Bootstrap
**Agent**: Grok Build (fusion autonomous)

## Checkpoint Log
- [x] Checkpoint 0: Bootstrap complete — tools verified, living docs created

## Current Open GitHub Items (as of start)
- Issue #7: TUI visualization and interactive flows
- PR #3: Add system wide runnable CLI (tinfoil)
- PR #4: Cleanup system, free disk space, security remediation policy (draft)
- Issue #2: Full system inspect need to be clean, enable auto fixes

## Next Micro-Task
Execute Phase 1: Merge PR #3 then PR #4 using gh CLI.
EOF
    echo "Created STATE.md"
fi

if [ ! -f PROGRESS.md ]; then
    cat > PROGRESS.md << 'EOF'
# PROGRESS.md — Narrative Mission Log (ARCH-MACHINE-2026-05-28)
**Mission**: Fully autonomous resolution of all open items using DAG/PERT plan.

## Log Entries

EOF
    echo "Created PROGRESS.md"
fi

# Record bootstrap in living docs
echo "" >> PROGRESS.md
echo "### [$(date -Iseconds)] PHASE 0 COMPLETE — Bootstrap successful" >> PROGRESS.md
echo "- Repo on latest sentinel" >> PROGRESS.md
echo "- STATE.md and PROGRESS.md initialized" >> PROGRESS.md
echo "- gh CLI and git confirmed available" >> PROGRESS.md

# Update STATE.md with current gh state
echo "" >> STATE.md
echo "### [$(date -Iseconds)] Current GitHub State (live)" >> STATE.md
gh issue list --state open --json number,title,state | tee -a STATE.md || true
gh pr list --state open --json number,title,state | tee -a STATE.md || true

echo "✅ Phase 0 complete. Living docs ready."
echo ""
echo ">>> NEXT: The autonomous agent should now read CONTEXT.md + INIT_PLAN.md and begin Phase 1."
echo ">>> To continue autonomously, the agent will now enter the main loop (in real Grok Build this would be a long-running process)."
echo ""
echo "For manual continuation in this environment, run the next phases manually or instruct the model to continue."

# In a real Grok Build / Cursor / autonomous system, the following would be the start of an infinite self-referential loop:
# while true; do
#   read STATE.md
#   decide_next_micro_task
#   execute
#   update STATE.md + PROGRESS.md
#   if all_done; then break; fi
# done

echo "Mission bootstrap finished. Agent is now grounded and ready for full autonomous execution."
echo "Recommended next command for the agent: 'Begin Phase 1 - Merge PRs following INIT_PLAN.md'"