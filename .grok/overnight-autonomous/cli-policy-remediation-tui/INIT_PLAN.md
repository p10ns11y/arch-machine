# INIT_PLAN.md — Autonomous Overnight Execution Plan
**Version**: 1.0 (Self-updating)  
**Mission**: ARCH-MACHINE-2026-05-28  
**Created by**: Grok (context provider)  
**Executed by**: Grok Build (fusion autonomous agent)

## How to Use This Plan
1. Copy this entire folder (`grok-build-plan/`) into the repo root or run from anywhere with repo access.
2. Execute `./init-plan.sh` (or the equivalent in your environment).
3. The script will:
   - Clone/fetch latest `sentinel`
   - Create `STATE.md` and `PROGRESS.md` (living docs)
   - Enter autonomous loop following the 5 phases below
   - Update this file and living docs at every checkpoint
   - Finish with a final summary commit

## Phase Overview (Critical Path Aligned with PERT)

**Phase 0: Bootstrap & Grounding** (30 min)
**Phase 1: Quick Wins — Merge PRs** (2–4 hours)
**Phase 2: Close Issue #2 + Verification** (30 min)
**Phase 3: Implement TUI (Issue #7)** (8–12 hours — main work)
**Phase 4: Final Integration, Self-Audit & Closeout** (2–3 hours)

Total estimated: 13–20 hours (perfect for overnight run)

---

## Detailed Autonomous Workflow (Self-Referential)

### Phase 0: Bootstrap & Grounding
**Goal**: Establish clean state, create living documents, confirm tools.

**Micro-steps** (agent must execute in order):
1. `git fetch origin`
2. `git checkout sentinel && git pull --ff-only`
3. Create `STATE.md` if missing with header + current timestamp.
4. Create `PROGRESS.md` if missing.
5. Run `gh issue list --state open` and `gh pr list --state open` → append to STATE.md
6. **Write Checkpoint 0** to STATE.md: "Bootstrap complete. Tools verified. Current open: 4 items."
7. Re-read entire CONTEXT.md and this INIT_PLAN.md before proceeding.

**Success Gate**: `STATE.md` exists with Checkpoint 0 and lists exactly the 4 open items from context.

---

### Phase 1: Quick Wins — Merge PRs (Lowest Effort, Highest Impact)
**Goal**: Merge #3 and #4 with zero conflict. Leverage existing work.

**Micro-steps**:
1. **PR #3 first** (CLI is foundational):
   - `gh pr view 3 --json state,title,headRefName`
   - Review diff: `gh pr diff 3`
   - If clean: `gh pr merge 3 --squash --delete-branch` (or merge commit if preferred)
   - Commit message: "feat(cli): add system-wide tinfoil CLI (resolves #3)"
2. **PR #4 second** (solves #2):
   - `gh pr view 4 --json state,title,headRefName`
   - If still draft: `gh pr ready 4`
   - Review diff + policy
   - `gh pr merge 4 --squash --delete-branch`
   - Commit message: "feat(security): implement cleanup + remediation policy (resolves #2, #4)"
3. **Update living docs**:
   - Append to PROGRESS.md: timestamp + "Merged PR #3 and #4. Branches deleted."
   - Update STATE.md: "Phase 1 complete. Remaining: Issue #7 + verification of #2"

**Self-Reference Rule**: Before merging each PR, re-read the last 10 lines of STATE.md to confirm order.

**Risk Mitigation**: If conflict detected → create `hotfix/rebase-YYYYMMDD`, rebase, push, then merge.

---

### Phase 2: Close Issue #2 + Quick Verification
**Goal**: Confirm Issue #2 is resolved by PR #4, close it cleanly.

**Micro-steps**:
1. `gh issue view 2`
2. Add comment: "Resolved by PR #4 (Security Remediation Policy + cleanup implementation). Full system inspect now follows ruthless audit → fix/kill policy."
3. `gh issue close 2 --reason completed`
4. Run quick smoke test:
   - `./install.sh --help` or equivalent
   - `tinfoil --version` or `which tinfoil` (after PATH update if needed)
   - Simulate remediation on a test package
5. **Checkpoint 2** in STATE.md

---

### Phase 3: Implement TUI (Issue #7) — Core Autonomous Work
**Goal**: Build beautiful, interactive TUI that lets users visualize and control all flows.

**Design Principles** (must follow):
- Use existing `tinfoil` CLI as backend (call it from TUI)
- Support flows: Install, Security Audit, System Check, Maintenance, Evidence Extraction
- Enable/disable profiles and individual modules
- Humorous/paranoid tone preserved
- Tech choice: Go (bubbletea + lipgloss) for consistency with CLI, or pure shell `gum` + `dialog` if zero new deps preferred. **Decide and document choice in first commit.**

**Actual Decision (self-updated during execution 2026-05-28)**: Selected **pure shell + `gum`** (whiptail/fzf also present). Rationale: repo is 95%+ bash (install.sh, modules/*, maintenance/*, lib/*); adding Go TUI deps would complicate install.sh (needs go.mod, network for `go get` or vendoring); gum provides beautiful interactive (choose, confirm, spin, pager, style) with zero Go changes beyond subcommand dispatch in tinfoil.go. TUI script lives in `lib/tui.sh`, invoked via `tinfoil tui` (or future `install.sh --tui`). Humorous tone + full flows + remediation integration preserved. Updated 2026-05-28 by autonomous agent.

**Micro-steps** (agent breaks further as needed):
1. Create branch: `git checkout -b feat/tui-interactive`
2. Research best TUI approach (read existing code in `modules/`, CLI source from merged PR)
3. Implement core TUI:
   - Main menu with flows
   - Profile selector (minimal / ml-dev / security-dev)
   - Feature toggle list (with descriptions from config/)
   - Confirmation + dry-run mode
   - Progress bars + live log streaming
4. Integrate with new remediation policy (call cleanup scripts)
5. Add TUI to install.sh or as standalone `tinfoil tui` subcommand
6. Write tests / manual verification steps
7. Commit frequently with clear messages
8. **Every 2 hours or major milestone**: Update PROGRESS.md + re-read STATE.md

**Self-Referential Guard**: Before writing any code, append to STATE.md: "Starting TUI subtask X. Reading current code state..."

---

### Phase 4: Final Integration, Self-Audit & Closeout
**Goal**: Polish, test everything end-to-end, close Issue #7, produce final evidence.

**Micro-steps**:
1. Merge `feat/tui-interactive` into `sentinel` (or rebase if needed)
2. Run full verification:
   - `tinfoil` CLI works
   - TUI launches and all flows execute (use dry-run where possible)
   - Remediation policy demo on sample vulnerable package
   - Systemd timers still work
   - Logs produce evidence bundles
3. Update docs:
   - Add TUI section to README
   - Update EVIDENCE-EXTRACTION.md if TUI generates better logs
4. Final self-audit:
   - `gh issue list --state open`
   - `gh pr list --state open`
   - Confirm 0 relevant open items
5. Create final commit: "chore: complete autonomous resolution of all 2026-04 issues (DAG + PERT plan executed)"
6. Push to `sentinel`
7. **Write Mission Complete** entry in STATE.md and PROGRESS.md with full summary + links to all commits/PRs

---

## Living Documents Schema (Agent Must Maintain)

### STATE.md (Current Truth — Read First, Write Last)
```markdown
# STATE.md — Live Mission State
**Last Updated**: [TIMESTAMP]
**Current Phase**: X
**Open Items Remaining**: N

## Checkpoint Log
- [ ] Checkpoint 0: Bootstrap
- [ ] Checkpoint 1: PRs merged
...

## Current Open GitHub Items
(gh output here)

## Next Micro-Task
...
```

### PROGRESS.md (Narrative History)
Append-only log of everything done, with timestamps and evidence SHAs.

---

## Emergency Protocols (If Agent Gets Lost)
1. Re-read full CONTEXT.md + INIT_PLAN.md
2. Run `gh issue list` and `gh pr list` to re-ground
3. Append "RECOVERY: Re-read context at [time]" to STATE.md
4. Resume from last successful checkpoint
5. If still lost after 3 attempts → create `recovery/branch` and push with detailed message

---

## Final Instruction to Self
You are now in **full autonomous fusion mode**.  
You have the complete context.  
You have the exact plan.  
You have the self-referential logging system to never get lost.  
Execute Phase 0 immediately, then continue non-stop until Mission Complete.

**Start Command**:
```bash
bash init-plan.sh
```

**End of INIT_PLAN.md** — This file will be updated by the agent during execution.