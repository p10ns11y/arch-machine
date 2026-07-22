# Soft-obsolete candidates → hard pass (2026-07)

**Status:** Hard pass executed on `feat/master-planner-arch-guardian` (docs + deletes only; **no application code**).  
**Soft commit:** `docs: soft domain evolution pass (1–6) with SO inventory`  
**This pass:** remove approved artifacts + rewrite docs that taught them.

| ID | Outcome |
|----|---------|
| SO-1 | **Deferred (code).** `lib/tui/` stays on disk; docs no longer treat gum as product. |
| SO-2 | **Deferred (code).** `bin/tinfoil.go` path list untouched. |
| SO-3 | **Docs rewritten.** `docs/INSTALLATION.md` archy-first; install.sh help strings unchanged (code). |
| SO-4 | **Rewritten.** `tinfoil-name-explained.md` = humor only. |
| SO-5 | **Deleted.** `.cursor/plans/tui_gum_*.plan.md` |
| SO-6 | **Deleted.** `.grok/overnight-autonomous/cli-policy-remediation-tui/` |
| SO-7 | **Deleted.** `docs/xchat-remote.md` → use `docs/groxy.md` |
| SO-8 | **Deferred (code).** groxy leftover poll API not trimmed. |
| SO-9 | **Docs rewritten.** Legacy one-shots → LEGACY only. |
| SO-10 | **Deferred (CI).** profile-validation stub not wired. |
| SO-11 | **Deleted.** `maintenance/apply-remediation.sh` |
| SO-12 | **Deleted.** root `EVIDENCE-EXTRACTION.md` → `docs/MAINTENANCE.md` |
| SO-13 | **Deleted.** Apr sample evidence/logs under `logs/*-sample*` |
| SO-14 | **Done (soft).** keeper verify without `KEEPER_KNOWLEDGE` |
| SO-15 | **Docs/cockpit sync.** VERIFY pane aligned with fuller AGENTS.md gate |

## Still deferred (needs code later)

- SN-ARCHY-1 / install PATH messaging (`install.sh`)
- `bin/tinfoil.go` dead `crates/archy` paths
- gum tree removal or quarantine
- groxy `list_events` / dm_events trim
- CI `make validate-profiles` hard-fail

## Direction (unchanged)

| Domain | Grade | Direction |
|--------|-------|-----------|
| 1 control | B+ MVP / D PATH | Ship SN-ARCHY-1 |
| 2 agent_transport | A- | Keep SN-GROXY-3 parked |
| 3 install | B | PATH + CI harness lag |
| 4 evidence | B+ extract / C apply honesty | Policy lives; stub applicator gone |
| 5 vault | A | Dogfood SN-KEEP-1 |
| 6 verify | A cargo / C soft shell | Harden CI gradually |
