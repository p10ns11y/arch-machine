# Sentinel Progress and Lock Board

This file is the single source of truth for task claims and progress.

## Lock Rules (Branch Collision Prevention)

1. A sentinel may hold only one `in_progress` task at a time.
2. A task may have only one sentinel owner at a time.
3. Before starting work, sentinel must claim a task by updating this file.
4. If sentinel already has one `in_progress` task, it must finish or release it before claiming another.
5. Sentinel branch ownership is fixed:
   - `Virtinel` -> branch `virtinel`
   - `Eusinel` -> branch `eusinel`
   - `Safinel` -> branch `safinel`
   - `Guardwell` -> branch `guardwell`
   - `Trusinel` -> branch `trusinel`
6. Worktrees are disallowed by default. Use only when human explicitly approves exceptional collaboration.

## Status Legend

- `todo`
- `in_progress`
- `blocked`
- `review`
- `done`

## Sentinel Locks

| sentinel | branch | active_task_id | status | started_at | updated_at | notes |
|---|---|---|---|---|---|---|
| Virtinel | virtinel |  | idle |  |  |  |
| Eusinel | eusinel |  | idle |  |  |  |
| Safinel | safinel |  | idle |  |  |  |
| Guardwell | guardwell |  | idle |  |  |  |
| Trusinel | trusinel |  | idle |  |  |  |

## Task Board

| task_id | wave | task | preferred_sentinel | owner | status | priority | blocked_by | started_at | updated_at | evidence_or_pr |
|---|---|---|---|---|---|---|---|---|---|---|
| P0-1 | 1 | YAML parsing and profile validation hardening | Virtinel |  | done | high |  |  |  |  |
| P0-2 | 1 | Module loading and error handling determinism | Trusinel |  | done | high | P0-1 |  |  |  edge case tests! |
| P0-3 | 1 | Dry-run parity and baseline matrix verification | Guardwell |  | done | high | P0-2 |  |  | edge case tests!  |
| P1-4 | 2 | Security toolchain integration and verification | Safinel |  | done | high | P0-3 |  |  |  |
| P1-5 | 2 | Remediation workflow execution and policy conformance | Trusinel |  | todo | high | P1-4 |  |  |  |
| P1-6 | 2 | Python/ML environment remediation first pass | Eusinel |  | done | high | P1-5 |  |  | idempotent/repeated flow! |
| P2-7 | 3 | Maintenance pipeline reliability and scheduling | Trusinel |  | done | medium | P1-6 |  |  | live tests with cron and systemd |
| P2-8 | 3 | Rollback, backup, and failure recovery safeguards | Safinel |  | todo | medium | P2-7 |  |  |  |
| P3-9 | 4 | Evidence extraction implementation and integration | Eusinel |  | done | medium | P2-8 |  |  | it will evolve based on new logs |
| P3-10 | 4 | Blocker taxonomy and delta-rule evolution (deferred) | Virtinel |  | todo | low | P3-9 |  |  | Separate session |
| P4-11 | 5 | Offline-first consented network flow | Safinel |  | todo | medium | P3-10 |  |  |  |
| P4-12 | 5 | Cleanup docs and ancillary runbooks | Guardwell |  | todo | low | P4-11 |  |  |  |  |
| X-1 | - | Implement secure-infra profile for advanced validation | Safinel |  | done | - | - |  | 2026-04-18 | .kilo/plans/1776443819802-jolly-river.md | Advanced Kubernetes/Cilium/Tetragon validation added

## Claim/Release Workflow

- Claim:
  - set `owner` and `status=in_progress` for one task row
  - set matching sentinel row `active_task_id=<task_id>`, `status=busy`
- Release (done):
  - set task `status=done`, add evidence link
  - clear sentinel `active_task_id`, set sentinel `status=idle`
- Release (blocked):
  - set task `status=blocked`, fill `blocked_by`/notes
  - clear sentinel lock so another task can be claimed
