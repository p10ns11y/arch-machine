# EVIDENCE/ — Self-Referential Bundles for Arch-Machine Overhaul

This directory holds AI-optimized evidence bundles produced by the autonomous agent during execution of the 6-phase overhaul (per INIT_PLAN.md self-referential rules).

**Canonical location**: `logs/evidence-bundle-YYYYMMDD-HHMMSS.json` + `.toon` (in repo root).

**Copies here**: Used only for the agent's live session self-reference during long autonomous runs. Not committed to git (bundles can be 5-10k each; repeated copies would bloat history). The narrative in STATE.md / PROGRESS.md records exact filenames + summaries at every gate.

**How bundles are produced**:
- `./maintenance/extract-evidence.sh` (called by security-audit.sh, weekly-check.sh, and explicitly by the agent before/after every phase or major action).
- Always preceded by re-read of this handoff's CONTEXT + INIT_PLAN + STATE + PROGRESS.
- Always followed by living docs update + commit (or staged for next gate commit).

**Phase 0 bundles referenced**:
- 20260529-133707 (initial baseline)
- 20260529-134117 (branching + handoff creation)
- 20260529-134447 (Phase 0 formal closure, after EVIDENCE/ dir creation + tree clean)
- 20260529-134541 (pre-systemd-kill)
- 20260529-134653 (post systemd-kill attempt)

**Policy application note**: Every bundle is evidence that the agent's own control plane (this handoff) obeys the same ruthless security-remediation rules it applies to the rest of the repo.

The Sentinel watches itself.
