# Soft-obsolete candidates (2026-07 evolution pass)

**Status:** Soft only — **do not delete** until the operator confirms.  
**Pass:** Domains 1–6 assess (control · agent_transport · install · evidence · vault · verify).  
**Branch:** `feat/master-planner-arch-guardian`

When you approve a row, reply with IDs (e.g. `SO-1, SO-4`) to hard-remove or rewrite.

| ID | Path | Domain | Why | Suggested soft action |
|----|------|--------|-----|------------------------|
| SO-1 | `lib/tui.sh` + `lib/tui/*.sh` | control | Gum TEA; SN-2 freeze; superseded by `tools/archy` | Mark legacy headers; bugfix only |
| SO-2 | `bin/tinfoil.go` lookup `crates/archy/…` | control | Tree does not exist; live is `tools/archy` | Update path list (safe code fix when approved) |
| SO-3 | Thin install day-1 messaging (`install.sh` help/post-install, `docs/INSTALLATION.md` § tinfoil) | control / install | Still teaches `tinfoil tui` as primary; SN-ARCHY-1 open | Soft caveat now; rewrite after SN-ARCHY-1 |
| SO-4 | `tinfoil-name-explained.md` | control | Names tinfoil as main interactive CLI | Banner → `docs/archy.md`; keep humor section |
| SO-5 | `.cursor/plans/tui_gum_*.plan.md` | control | Gum-era plan artifact | Candidate delete later |
| SO-6 | `.grok/overnight-autonomous/cli-policy-remediation-tui/` | control | Gum-as-primary decision | Mark superseded by SN-TUI-RUST |
| SO-7 | `docs/xchat-remote.md` | agent_transport | Redirect stub to groxy | Keep alias or delete later |
| SO-8 | `tools/groxy` `dm_adapter` `list_events` / dm_events | agent_transport | Poll CLI removed; leftover API | Do not re-expose CLI; trim later |
| SO-9 | Legacy one-shots in `docs/INSTALLATION.md` (`basic_setup.sh`, fortress scripts) | install | Cited as available; profiles supersede | Point to `docs/LEGACY.md` only |
| SO-10 | CI `profile-validation` stub | install / verify | Real harness exists locally | Wire `make validate-profiles` (not a delete) |
| SO-11 | `maintenance/apply-remediation.sh` | evidence | Phase-5 stub; broken apply branch; targets already killed | Mark historical demo; rewrite or demote scorecard |
| SO-12 | Root `EVIDENCE-EXTRACTION.md` | evidence | Overlaps `docs/MAINTENANCE.md`; not in INDEX | Soft redirect banner |
| SO-13 | Weak Apr sample evidence bundles / sample logs | evidence | Parser regression fixtures; teach wrong fields | Mark as fixtures; regenerate later |
| SO-14 | `coming-next-keeper.md` verify blocks with `KEEPER_KNOWLEDGE` | vault | Contradicts shipped k=2 n=3 default | Doc-only rewrite |
| SO-15 | Cockpit VERIFY pane vs `AGENTS.md` | verify | Omits cargo tests / evidence dry-run | Expand later; soft-note partial gate |

## Direction (all domains)

| Domain | Grade | Direction |
|--------|-------|-----------|
| 1 control | B+ MVP / D PATH | Right architecture; ship SN-ARCHY-1 |
| 2 agent_transport | A- | Right; keep SN-GROXY-3 parked |
| 3 install | B | Solid compose; PATH + CI harness lag |
| 4 evidence | B+ extract / C remediation honesty | Extract OK; demote apply claims |
| 5 vault | A | Healthiest; dogfood SN-KEEP-1 |
| 6 verify | A cargo / C soft shell CI | Split brain; harden gradually |

## Already soft-synced this pass (docs/notes only — no deletes)

- `docs/INSTALLATION.md` — archy-first caveat (SO-3)
- `docs/LEGACY.md` — soft-obsolete pointer
- `docs/INDEX.md` — Grok transports + soft list link
- `tinfoil-name-explained.md` — legacy banner (SO-4)
- `EVIDENCE-EXTRACTION.md` — soft redirect (SO-12)
- `arch-design/coming-next.md` — honest scorecard (PATH D, remediation C, CI B)
- `arch-design/coming-next-keeper.md` — verify without `KEEPER_KNOWLEDGE` (SO-14)
- `maintenance/apply-remediation.sh` — SO-11 header mark
- `AGENTS.md` — hard vs soft CI; cockpit partial gate (SO-15)
- `.agents/ontology/arch-machine.graph.yaml` + stellar overlay — PATH/tinfoil honesty
