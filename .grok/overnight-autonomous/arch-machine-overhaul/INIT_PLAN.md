# INIT_PLAN.md — Autonomous Arch-Machine Overhaul Execution Plan
**Version**: 1.0 (Self-updating)  
**Mission**: ARCH-MACHINE-OVERHAUL-2026-05 (Full Repo Hygiene + Professionalization)  
**Created by**: Grok Build (fusion autonomous agent, Plan Mode)  
**Executed by**: Grok Build (fusion autonomous agent) — highest security seniority level

**Stellarfusion Mindset**: Grand-scale (stellar) integrative fusion of the project's DNA — ruthless application of its own `policies/security-remediation.md` to its technical debt (duplication/legacy as high-severity vulnerabilities), ML/AI reproducibility + evidence self-loops as first-class, elegant modular automation, preserved soul/humor as optional lore — into one polished, self-auditing, adoptable platform. Highest security seniority: Every action, file op, and decision is executed as if by a principal security architect + ML platform expert. Zero-trust. Evidence mandatory. The plan itself is sentinel-grade.

---

## How to Use This Plan (Self-Referential — Mandatory)
1. The agent must be in the repo root with access to `tinfoil`, `./install.sh`, `maintenance/security-audit.sh`, `maintenance/extract-evidence.sh`, `gh`, and git.
2. Before **every** major action, phase, or commit: 
   - Re-read this INIT_PLAN.md + living `STATE.md` + `PROGRESS.md` + `CONTEXT.md` (in this handoff folder).
   - Run the project's own tools on the current tree: `./install.sh --thin` (or current thin path) + `tinfoil` + `maintenance/security-audit.sh` + `maintenance/extract-evidence.sh`.
   - Commit the resulting evidence bundle (JSON + .toon if available) with message referencing the phase/action + "evidence: <path>".
   - Update `STATE.md` with "Pre/Post Phase X evidence: <bundle path/sha>".
3. All work on `hotfix/arch-machine-overhaul-*` (or vir tinel-style for TUI-related) branches only. PRs to protected `sentinel` only at phase gates. No direct pushes.
4. Apply the project's own `policies/security-remediation.md` ruthlessly: Audit (using the project's tools), built-in fix, small config fix, otherwise kill (delete) after extracting unique value. Never keep "because it still runs." Document the decision in the evidence bundle.
5. Maintain the handoff folder as a first-class, evidence-producing citizen of the platform.
6. The plan is self-updating: After each phase or major milestone, append lessons, new micro-steps, or refinements to this file and living docs.
7. `install.sh` public interface (thin default + `--profile` for full, `--dry-run`, `--validate`, etc.) must remain functional after every change.

**Bootstrap**:
- `./init-plan.sh` equivalent (or manual): Ensure on clean hotfix branch from current `sentinel`, create/update living docs, run baseline evidence bundle, enter autonomous loop following the phases below.
- Update this file and living docs at every checkpoint.
- Finish with a final summary commit + PR to `sentinel` (after evidence confirms success).

---

## Phase Overview (Critical Path — 5–6 Logical Phases)

**Total Estimated**: 20–40 hours (spread over multiple sessions; take natural pauses between phases).

1. **Phase 0: Preparation, Safety & Handoff Bootstrap** (XS, 1–2h)
2. **Phase 1: Structure & Hygiene — Ruthless Remediation of Duplication** (S/M, 4–8h)
3. **Phase 2: Documentation Consolidation** (S, 3–6h)
4. **Phase 3: Automation Unification & Orchestration Hardening** (M, 6–12h)
5. **Phase 4: Quality & CI Foundations** (S/M, 4–8h)
6. **Phase 5: Polish, Branding Balance, Feature Gaps & Self-Application of Policy** (M/L, 8–16h)

**Overarching Rules (Non-Negotiable — Highest Security Seniority)**:
- Self-referential loop before/after every major action (see "How to Use").
- Apply `policies/security-remediation.md` + orwell rules to every artifact touched.
- Branch/PR discipline (hotfix/ only; PRs to `sentinel` at gates).
- Evidence production for the overhaul itself (bundles committed at every gate).
- `install.sh` contract preserved.
- Tone: Professional/vigilant default; full lore only in `FUNREADME.md`.
- Order: Phases are sequential with safe rollback points. Quick wins can be pulled forward.

---

## Detailed Autonomous Workflow (Self-Referential)

### Phase 0: Preparation, Safety & Handoff Bootstrap (XS, 1–2h)
**Goal**: Safe workspace + self-referential control plane (this handoff folder) that itself embodies highest security seniority.

**Micro-steps (agent must execute in order, with evidence after each)**:
1. Ensure on a clean hotfix branch: `git checkout -b hotfix/arch-machine-overhaul-20260529` (or similar; base from current clean `sentinel`).
2. Run baseline evidence: `./install.sh --thin` (if safe) + `tinfoil` + `maintenance/security-audit.sh` + `maintenance/extract-evidence.sh`. Commit the bundle.
3. Create/update this handoff folder (already partially done in execution start):
   - `CONTEXT.md` (synthesized + exploration findings).
   - This `INIT_PLAN.md` (self-updating).
   - `STATE.md` (live checkpoints, open items, evidence refs).
   - `PROGRESS.md` (append-only narrative + SHAs + bundle links).
   - `EVIDENCE/` subdir for bundles.
4. Update root `.gitignore` if any new tool artifacts appear (strengthen for future accidents).
5. **Write Checkpoint 0** to `STATE.md` + append to `PROGRESS.md`: "Handoff bootstrap complete. Baseline evidence bundle committed. Self-referential loop active. Current open: duplication hell, docs fragmentation, missing CI, evidence UX, no self-policy application."
6. Re-read entire `CONTEXT.md`, this `INIT_PLAN.md`, and living STATE/PROGRESS before proceeding.

**Success Gate**: Handoff folder exists with living docs. Baseline evidence bundle committed. Agent can state the self-referential loop rules from memory. `install.sh --thin` and `--profile minimal --dry-run` still work.

---

### Phase 1: Structure & Hygiene — Ruthless Remediation of Duplication (S/M, 4–8h)
**Goal**: Apply the project's own security-remediation policy to "high-severity vulnerable" duplicated/legacy code. Clean root. Preserve unique value.

**Micro-steps (with mandatory evidence + living doc update after every batch)**:
1. **Kill the `systemd/` tree** (exact ~2883 LOC duplication of lib/modules/config; already gitignored + broken; accidental copy):
   - Pre-action: Re-read docs + run full evidence bundle on the tree.
   - `git rm -r --cached systemd/` (or physical delete + git add -u).
   - Update any references (mainly `maintenance/systemd-setup.sh` and docs that mention the tree).
   - Commit with evidence bundle + "Phase 1: killed systemd/ duplicate (high-severity vuln per policy)".
   - Update STATE/PROGRESS.
2. **Audit + targeted kill/consolidate `setups/`** (784 LOC + variants):
   - Pre-action evidence bundle.
   - `setups/security-audit.sh` (106 LOC) → kill (maintenance/ 734 LOC version wins; it integrates evidence + libs).
   - `setups/secure-ssh-gpg.sh` + `simple-ssh-gpg.sh` → consolidate (feature-rich wins); move winner to `maintenance/` if appropriate or keep as documented legacy example.
   - Other setups scripts (basic, secure-fortress-phase0, torch, vuln-tools) → audit for unique value → kill after extraction (most duplicated in modules/maintenance). Move any truly unique notes to `docs/LEGACY.md` or `docs/examples/`.
   - Delete empty `setups/` (or turn into tiny legacy-examples/ with deprecation warning).
   - Update **every** reference (install.sh, bin/tinfoil.go, cmd/tui, maintenance/*, all docs/*.md, README, etc.) using exhaustive grep.
   - Commit in small batches with evidence after each.
3. **Root hygiene**:
   - Delete/move personal/tool remnants (`.composer/`, `.kilo/`, stray `.grok/` artifacts not part of this handoff) after audit. Strengthen `.gitignore`.
   - Duplicate SBOMs → audit + keep authoritative; delete other with evidence.
   - `installers/` (empty) → delete.
   - Update all references.
4. **Update every cross-reference** across the codebase (install.sh, bin/tinfoil.go, cmd/tui/main.go, all maintenance/*.sh, modules/*, docs/*, README, FUNREADME, tinfoil-name-explained.md, EVIDENCE-EXTRACTION.md, STATE/PROGRESS, policies if any, vector.toml, etc.).
5. Create `docs/LEGACY.md` (or section) documenting the cleanup with dates, evidence bundles, and rationale (policy application).
6. After every batch: Run full evidence (tinfoil + security-audit + extract), commit bundle, update living docs, re-read INIT_PLAN + STATE.
7. **Write Checkpoint 1**: "Phase 1 complete. Duplication remediated per policy (systemd/ killed, setups/ consolidated). All references updated. Evidence bundles committed. install.sh --thin + --profile minimal --dry-run still functional."

**Risks + Mitigation** (per plan):
- Breaking legacy users → Clear deprecation in docs/LEGACY.md + migrate.sh updates + evidence proving core paths intact.
- Missing a reference → Exhaustive grep + new CI harness (Phase 4) + self-audit with tinfoil.
- Deleting unique value → Full pre-delete evidence bundle + git history.

**Effort**: S/M. **Order**: After Phase 0. systemd/ kill first (lowest risk). Test install flows after every batch.

---

### Phase 2: Documentation Consolidation (S, 3–6h)
**Goal**: Single source of truth in `docs/`. Fix links. Surface vision (AUTHORS-MOTTO + security-first policy). Make onboarding trivial.

**Micro-steps** (evidence + doc updates after every batch):
1. Move/rename root docs that belong in `docs/`: `EVIDENCE-EXTRACTION.md` → `docs/EVIDENCE.md` (consolidate content); `SAFETY.md` → `docs/SECURITY.md`. Update all references (README, other docs, tinfoil-name-explained.md, etc.).
2. Create `docs/INDEX.md` (authoritative map + mermaid architecture diagram showing thin tinfoil → profiles → modules + lib/ sourcing → maintenance/ orchestration + evidence self-loop + tinfoil/TUI as guardians; quick start with thin tinfoil first; "for lore see FUNREADME.md").
3. Create `docs/MODULES.md` (exact authoring contract: what `install_<module>` must implement, DRY support, evidence hooks, testing via --dry-run/--validate, how it appears in profiles).
4. Create `docs/PROFILES.md` (authoring + validation).
5. Create/enhance `docs/CONTRIBUTING.md` (pull from DEVELOPMENT.md + add CI requirements, "run the project's own tools before PR").
6. Consolidate duplicated profile descriptions (README + docs/INSTALLATION.md) → aggressive cross-refs only.
7. Move/enhance "Legacy Scripts" section into `docs/INSTALLATION.md` or `docs/LEGACY.md` with deprecation + links to consolidated maintenance/ versions.
8. Prominently link `AUTHORS-MOTTO.md` from README intro + `docs/INDEX.md` (excerpt the "Solve your own machine first, then empower others to adapt" philosophy).
9. Fix **all** link inconsistencies (grep for bare `INSTALLATION.md`, `MAINTENANCE.md`, vim examples in DEVELOPMENT.md; standardize on `docs/FOO.md` or correct relatives from root).
10. Update any script comments or help text with new paths/tone.
11. After every batch: evidence bundle (including link check), commit, update living docs, re-read plan.
12. **Write Checkpoint 2**: "Phase 2 complete. Single source of truth in docs/. All links fixed. Vision surfaced. Contributor guides created. Evidence committed."

**Risks + Mitigation**: Broken links during transition → Exhaustive grep + markdown-link-check (will be in CI) + evidence of docs tree.

**Effort**: S. **Order**: After major kills in Phase 1 (so you're not documenting things about to be deleted). Can overlap with ref updates in Phase 1.

---

### Phase 3: Automation Unification & Orchestration Hardening (M, 6–12h)
**Goal**: One source for maintenance/automation. Fix broken references. Make evidence self-loop production-grade. Preserve DRY/idempotency.

**Micro-steps** (evidence after every change):
1. Fix `maintenance/systemd-setup.sh`: Create the missing `systemd/maintenance.{service,timer}` units in the clean tree (or make the script generate them dynamically from templates — preferred for DRY). Update all references (docs, scripts).
2. Consolidate any remaining functional dups between `maintenance/` and former `setups/` (fold unique value into modular equivalents with comments).
3. Strengthen thin tinfoil installer (already improved) to also install minimal pieces needed for full evidence extraction + weekly-check (so installed `tinfoil` user gets complete guardian experience).
4. Unify evidence UX (ensure `extract-evidence.sh` + callers consistent; make silent calls from security-audit/weekly-check more visible/optional with flag).
5. Add better error messages and guards for incomplete evidence.
6. Update all callers (install.sh, bin/tinfoil.go, cmd/tui/main.go, other maintenance/*.sh, docs) for any changed paths.
7. After every change: evidence bundle (including orchestration test), commit, living docs update, re-read plan.
8. **Write Checkpoint 3**: "Phase 3 complete. Orchestration hardened (systemd/ fixed). Evidence self-loop production-grade. Thin tinfoil now complete for evidence/weekly. All references updated. Evidence committed."

**Risks + Mitigation**: Breaking existing timer setups → Clear migration notes in docs/MAINTENANCE.md + migrate.sh + evidence proving new units work.

**Effort**: M. **Order**: After Phase 1 hygiene (no point fixing references to deleted items).

---

### Phase 4: Quality & CI Foundations (S/M, 4–8h)
**Goal**: Professional surface + enforceable quality. Make the handoff's self-referential loop enforceable via CI.

**Micro-steps**:
1. Create full `.github/` structure:
   - `workflows/ci.yml`: Triggers on push/PR to sentinel/main. Jobs: shellcheck (on **/*.sh, excluding former dupes), yamllint (config/ + any remaining), markdownlint, go build/vet (cmd/, bin/, internal/), profile-validation-harness (new lightweight script exercising yaml_get + module existence + install_$module symbol for every profile's includes[]), evidence-bundle-smoke-test (on sample logs + `--dry-run` paths).
   - ISSUE_TEMPLATE/ + bug_report.md + feature_request.md.
   - PULL_REQUEST_TEMPLATE.md (checklist: shellcheck clean, profiles validate, docs updated, evidence-tested, no new duplication).
   - CODEOWNERS, SECURITY.md (vuln reporting process tying into tinfoil + evidence), dependabot.yml.
2. Add supporting root files: `.yamllint.yml`, `.markdownlint.json` (relaxed for humor/docs), `.shellcheckrc`, `Makefile` or `justfile` with `lint`, `validate-profiles`, `test-evidence-smoke` targets.
3. Update `.gitignore` for lint caches.
4. Add CI badges to `README.md`.
5. Update `docs/DEVELOPMENT.md` + `docs/CONTRIBUTING.md` with "CI requirements" and "run the project's own tools before PR".
6. After every addition: evidence bundle (including new CI jobs where possible), commit, living docs, re-read plan.
7. **Write Checkpoint 4**: "Phase 4 complete. Professional surface live (.github/ + CI green on key paths). Self-referential loop now enforceable. Badges + templates added. Evidence committed."

**Risks + Mitigation**: CI noise on any remaining dupes → Explicit ignores in jobs (post-Phase 1 cleanup).

**Effort**: S/M (mostly new files + one small validation script; the explore subagent already provided the exact recommended jobs).

**Order**: After Phase 1 (clean tree) and Phase 2 (docs stable). Skeleton can start earlier.

---

### Phase 5: Polish, Branding Balance, Feature Gaps & Self-Application of Policy (M/L, 8–16h)
**Goal**: Professional first impression + optional fun. Close gaps visible after foundation is solid. Make the platform self-remediating at policy level.

**Micro-steps** (evidence after every change):
1. Tone/branding balance: Ensure main `README.md` + `docs/INDEX.md` + `AUTHORS-MOTTO.md` (prominently linked/excerpted) feel trustworthy. Confirm full sentinel lore (Virt* table, Justice League, cat joke, dramatic taglines) lives 100% inside `FUNREADME.md` with clear "entertaining introduction only" positioning.
2. Evidence UX (amplify the differentiator): Add `tinfoil evidence view <bundle>`, bundle diffing/time-series helpers, one-click "send optimized prompt to LLM/agent". Update Bubble Tea TUI (per TUI-SPEC) with a real Evidence screen. Update `extract-evidence.sh` + callers for richer output.
3. Self-application of policy: Create/surface `maintenance/apply-remediation.sh` (or equivalent) that TUI/weekly-check can call for real (not demo) "kill" operations on high-severity findings. Have the overhaul itself run the project's security-remediation policy against any remaining legacy/dupe it touches.
4. Small feature gaps: Smarter ROCm handling in `modules/ml_ai/` (single system install + shared base env or clear single-env recommendation for heavy users). Optional "sentinel lore toggle" in TUI/docs if desired.
5. Contributor experience: Validate that new `docs/MODULES.md` + `docs/CONTRIBUTING.md` + CI make adding a module trivial and safe.
6. Update remaining script comments, tinfoil help text, etc., for new tone and thin-first story.
7. After every change: full evidence (including new UX/features), commit, living docs, re-read plan.
8. **Write Checkpoint 5 / Mission Close**: "Phase 5 complete. Professional surface + optional fun balanced. Evidence UX amplified. Self-policy application live. Platform now self-remediating at policy level. All success metrics met. Final evidence bundle + summary commit + PR to sentinel."

**Risks + Mitigation**: Over-polishing before foundation → Strict phase gating (this is last). Scope creep on evidence viewer → MVP first (better docs + one subcommand + TUI page), full viewer in post-overhaul recs.

**Effort**: M/L.

**Order**: Dead last.

---

## Living Documents Schema (Agent Must Maintain)

### STATE.md (Current Truth — Read First, Write Last)
```markdown
# STATE.md — Live Overhaul State
**Last Updated**: [TIMESTAMP]
**Current Phase**: X
**Open Items Remaining**: N (duplication, docs links, CI, evidence UX, self-policy application, etc.)

## Checkpoint Log
- [ ] Phase 0: Handoff bootstrap + baseline evidence
- [ ] Phase 1: Duplication remediation
...
- [ ] Final evidence bundle + mission close PR

## Current Evidence Bundles
(List of committed bundles with SHAs/paths for each phase/gate)

## Next Micro-Task
...
```

### PROGRESS.md (Narrative History)
Append-only log of everything done, with timestamps, commit SHAs, evidence bundle links, and lessons learned.

---

## Quick Wins (Pull Forward Where Safe)
1. Kill `systemd/` tree (Phase 1) — already ignored, broken, accidental.
2. Fix all link paths (Phase 2) — grep + update bare names.
3. Add CI badge skeleton + SECURITY.md + PR template (Phase 4 early).
4. Strengthen thin tinfoil installer + its messaging (already in progress).
5. Audit + targeted kill of obvious `setups/` dups with evidence.
6. Prominently link AUTHORS-MOTTO.md from README + docs/INDEX.md.
7. Run baseline evidence bundle on current tree as Phase 0 proof.

---

## Risk Register (Top 5)
1. Breaking user workflows → Strict interface preservation + evidence at every gate + remediation policy applied.
2. Incomplete reference updates → Exhaustive grep + new CI harness + self-audit.
3. Re-introduction of duplication → Stronger .gitignore + CI failures + docs/CONTRIBUTING explicit rule.
4. Evidence pipeline brittleness during overhaul → Plan itself mandates full extraction at every gate.
5. Scope creep (especially Phase 5) → Ruthless phase gating in handoff (INIT_PLAN + STATE).

---

## Post-Overhaul Recommendations
- Rich Evidence UX (TUI viewer, diffing, AI prompt templates, `tinfoil evidence` subcommands).
- Complete Bubble Tea TUI per TUI-SPEC (full flows, real backend wiring, evidence screen).
- tinfoil as universal orchestrator (`tinfoil install --profile`, `tinfoil evidence send-to-llm`, auto-remediation loops using the now-real apply-remediation path).
- Smarter ROCm paths in ml-dev.
- Profile marketplace / examples repo (once MODULES.md + CI solid).
- Remote/multi-machine + AI agent modes.
- Full self-remediation of the platform (weekly + evidence + tinfoil detecting drift/duplication and proposing fixes).
- Multi-distro support (once hygiene debt paid).

---

**This plan is the single source of truth for the autonomous agent.** Re-read before every action. Execute with highest security seniority. The Sentinel (Vigilant Guardian) approves.

**End of INIT_PLAN.md** — Self-updating. Update after every phase or major milestone.