# Ordered Sentinel Prompt Pack

Use these prompts in order. Each sentinel must claim exactly one task in `progress.md` before coding.

## Global Starter Prompt (run before each task)

```text
You are <SENTINEL_NAME> on branch <SENTINEL_BRANCH>.
Read `.composer/waves/progress.md` and verify:
1) you have no other `in_progress` task,
2) the target task has no current owner,
3) dependencies in `blocked_by` are done.
Then claim the task in `progress.md`, execute it, and continuously update `progress.md` status and evidence.
Do not start another task until this one is `done` or `blocked`.
Do not use worktrees unless human explicitly approves.
```

## Prompt 5: Trusinel -> P1-5

```text
Claim task P1-5 after P1-4 is done.
Objective: apply security remediation workflow end-to-end per policy.
Sequence: simple fix -> upgrade -> remove; include lock/cache handling.
Deliverables:
- remediation decisions traceable,
- policy conformance evidence,
- regression entries for failures.
When complete, mark task done and release lock.
```

## Prompt 6: Eusinel -> P1-6

```text
Claim task P1-6 after P1-5 is done.
Objective: prioritize Python/ML environment remediation (ai_amd, xai_exp).
Deliverables:
- vulnerability reduction pass completed,
- impact notes on env reproducibility,
- unresolved issues bucketed in regression log.
When complete, mark task done and release lock.
```

## Prompt 7: Trusinel -> P2-7

```text
Claim task P2-7 after P1-6 is done.
Objective: harden maintenance pipeline and scheduling reliability.
Deliverables:
- stable weekly execution path,
- service health/reporting checks,
- operational issues logged and bucketed.
When complete, mark task done and release lock.
```

## Prompt 8: Safinel -> P2-8

```text
Claim task P2-8 after P2-7 is done.
Objective: add rollback/backup/failure-recovery safeguards.
Deliverables:
- pre-flight backup checks,
- rollback path documented and tested,
- high-risk failure modes mitigated.
When complete, mark task done and release lock.
```

## Prompt 9: Eusinel -> P3-9

```text
Claim task P3-9 after P2-8 is done.
Objective: implement and integrate compact AI evidence extraction bundles.
Deliverables:
- structured high-signal bundles,
- integration into maintenance outputs,
- quality checks for completeness and noise reduction.
When complete, mark task done and release lock.
```

## Prompt 10: Virtinel -> P3-10 (separate session)

```text
Claim task P3-10 only when human opens dedicated session.
Objective: evolve blocker taxonomy and delta rules.
Deliverables:
- revised taxonomy proposal,
- comparison logic for run-over-run deltas,
- migration notes for existing evidence consumers.
When complete, mark task done and release lock.
```

## Prompt 11: Safinel -> P4-11

```text
Claim task P4-11 after P3-10 is done (or if human reprioritizes).
Objective: implement offline-first installer with explicit network consent.
Deliverables:
- offline checks before network use,
- explicit consent gate before reconnect/download,
- safe fallbacks for unavailable network controls.
When complete, mark task done and release lock.
```

## Prompt 12: Guardwell -> P4-12

```text
Claim task P4-12 after P4-11 is done.
Objective: complete cleanup docs and operator runbooks.
Deliverables:
- concise runbooks for install/validate/rollback/regression triage,
- docs aligned with current behavior,
- stale idea notes clearly marked non-authoritative.
When complete, mark task done and release lock.
```
