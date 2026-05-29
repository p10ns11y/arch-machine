# Arch-Machine Overhaul — Autonomous Execution Context
**Mission ID**: ARCH-MACHINE-OVERHAUL-2026-05  
**Objective**: Execute a comprehensive, phased repository and automation overhaul to transform arch-machine into a professional-grade, security-first platform for ML/AI developers on Arch Linux, while preserving its core strengths, evidence self-loop, thin tinfoil guardian CLI, and optional humorous soul.

**Prepared by**: Grok Build (fusion autonomous agent)  
**Date**: 2026-05-29  
**Source**: `.grok/arch-machine-overhaul-context-for-grok-build.md` + exhaustive codebase exploration (duplication catalog, docs fragmentation, core engine analysis, CI gaps, tone alignment, branch history, policies).

---

## Project Mission & Positioning (Unchanged Core)

arch-machine is a **profile-based bootstrap and maintenance system for Arch Linux workstations**, purpose-built for **ML/AI developers who also demand strong security hardening**.

**Core Value Proposition (preserve and amplify)**:
- Thin `tinfoil` CLI as the universal "sentinel/guardian" entrypoint and manager (new default behavior).
- One-command (or one-profile) transformation of a fresh Arch install into a hardened, ML-ready machine.
- Automated weekly maintenance + security auditing with ruthless remediation policy.
- **Evidence extraction** — token-efficient, AI-optimized log/SBOM/audit bundles (the standout differentiator; must be protected and enhanced at every step).
- Modular, profile-driven design (minimal / ml-dev / security-dev).
- Fun, memorable personality (optional lore in FUNREADME.md) without sacrificing professionalism.

**Target Users**:
- Solo ML/AI researchers and engineers on Arch Linux (primary).
- Small teams wanting reproducible, secure GPU workstations (ROCm focus).
- Security-conscious developers who want automated evidence bundles optimized for feeding to LLMs/agents.

**Non-Negotiables (Highest Security Seniority Level)**:
- Apply the project's own `policies/security-remediation.md` ruthlessly to the codebase itself: Audit duplication/legacy as high-severity vulnerabilities; try built-in fix; small config fix if needed; otherwise upgrade (refactor) or kill (delete after extracting unique value). Never keep "because it still runs."
- Preserve and amplify the evidence self-loop (maintenance scripts → extract-evidence.sh → AI-optimized bundles).
- `install.sh` public interface (thin default + `--profile` for full) must remain functional after every phase.
- All work on hotfix/ or feature/ branches only (hotfix/sentinel-* or vir tinel-style naming per established policy). PRs to protected `sentinel` only. No direct pushes.
- Self-referential loop mandatory: Before/after every major action or phase, the agent must re-read this CONTEXT + INIT_PLAN + living STATE.md/PROGRESS.md, run the project's own `tinfoil` (thin) + `maintenance/security-audit.sh` + `maintenance/extract-evidence.sh`, commit the resulting evidence bundle, and update living docs.
- Tone: Professional/vigilant/guardian as the default surface experience. Full sentinel lore (Virt* branches, Justice League, etc.) stays exclusively in `FUNREADME.md` as optional "entertaining introduction."
- Evidence production for the overhaul itself is non-negotiable (the plan produces and consumes its own bundles).

---

## Current State Snapshot (Post-Exploration, Late May 2026)

### Critical Problems (The "Vulnerabilities" to Remediate)
1. **Duplication Hell** (High-Severity per policy):
   - Exact byte-for-byte mirrors: entire `systemd/` tree duplicates `lib/` (6 files, 1317 LOC), `modules/` (5 files, 1288 LOC), `config/` (4 yamls, 278 LOC) — ~2883 LOC total exact duplication (already gitignored but present on FS; accidental privileged copy from prior autonomous run; `maintenance/systemd-setup.sh` references non-existent units inside it).
   - Functional duplication: `setups/security-audit.sh` (106 LOC, simple standalone) vs `maintenance/security-audit.sh` (734 LOC, full integrated with libs/DRY/evidence/rootkits/perms/users). Two ssh-gpg variants. `setups/basic_setup.sh` + `secure-fortress-phase0-simple.sh` + others duplicate chunks of `modules/` + `maintenance/`.
   - Impact: Maintainability nightmare, doubled security audit surface, contradicts the project's own "delete waste ruthlessly" and "vigilant guardian" ethos. Easy to edit the wrong copy; legacy scripts can bypass modular security profiles.

2. **Documentation Fragmentation**:
   - Broken/inconsistent links (bare `INSTALLATION.md`/`MAINTENANCE.md` in README prose vs `docs/` in Documentation list and other files; vim examples in `docs/DEVELOPMENT.md` assume wrong cwd).
   - Duplicated profile descriptions between `README.md` and `docs/INSTALLATION.md`.
   - No single authoritative `docs/INDEX.md` or architecture diagram.
   - TUI/CLI docs scattered; legacy "secure-fortress" references linger.

3. **Missing Professional Surface**:
   - No `.github/` (no workflows, issue/PR templates, CODEOWNERS, SECURITY.md).
   - Zero CI (no shellcheck, yamllint, profile validation harness, markdown lint, evidence smoke tests, Go vet/build).
   - Limited contributor docs beyond `docs/DEVELOPMENT.md` (no "how to add a module" contract, no CI requirements).
   - Root pollution (personal/tool dirs `.grok/`, `.kilo/`, `.composer/` committed; `setups/` remnants; `systemd/` mirrors; duplicate SBOMs).

4. **Automation & Orchestration Gaps**:
   - `systemd-setup.sh` is broken (references missing files).
   - Evidence UX still raw files + basic TUI pager/fzf (no rich viewer, diffing, AI prompt templates, time-series).
   - Thin tinfoil installer (recently introduced) is good but incomplete (missing full evidence/weekly pieces for installed experience).
   - No self-application of the project's own `policies/security-remediation.md` or orwell rules to the codebase/scripts.

5. **Branding/Tone Tension** (Already Partially Resolved):
   - Professional surface is mostly "vigilant guardian" / empowering (per prior policy decisions). Full irreverent sentinel lore (Virt* branches, Justice League, cat jokes, "ex audits your text messages") is correctly isolated in `FUNREADME.md`.
   - Main README + docs feel trustworthy but lack polish, badges, single source of truth, and clear contributor path.

**Core Strengths (Protect and Amplify — Do Not Break)**:
- `install.sh` + `lib/installer.sh` architecture (YAML profiles → dynamic sourcing of modules/*/install.sh → `install_<module>` dispatch; thin mode already partially implemented in this session).
- Evidence extraction pipeline (`lib/evidence.sh` + `maintenance/extract-evidence.sh` + self-calls from security-audit/weekly-check; AI-optimized JSON/TOON bundles; vector integration).
- Pervasive DRY, idempotency, dry-run, logging (lib/logger.sh), and safety patterns.
- `tinfoil` CLI (Go wrapper in `bin/tinfoil.go`) + emerging Bubble Tea TUI (`cmd/tui/` per updated TUI-SPEC) as the "sentinel/guardian" manager.
- Systemd timer direction, comprehensive security tooling (Lynis, rkhunter, ClamAV, Grype, OSV-Scanner, SBOM), ROCm/ML focus, vault support.
- Soul: Humor in FUNREADME + tinfoil-name-explained (reframed as "ridiculously vigilant… and proud of it"), AUTHORS-MOTTO philosophy ("Solve your own machine first, then empower others to adapt").

**Branch & Policy History Lessons** (from prior autonomous sessions):
- `sentinel` is protected (default branch). All changes via hotfix/ or feature/ branches (hotfix/sentinel-*, vir tinel-style for TUI/CLI work) + PRs only. Multiple prior hotfix/reconciliation/cleanup branches used successfully.
- Self-referential loops (STATE.md, PROGRESS.md, re-read before actions, run tinfoil + audit + extract-evidence) have been effective.
- Tone shift ("paranoid" → "vigilant guardian") already applied project-wide in professional surface.

---

## Current Open Items (as of 2026-05-29)
- Full repo hygiene and duplication remediation (primary scope of this mission).
- Professional surface (CI, .github/, contributor experience).
- Evidence UX and orchestration hardening (amplify the differentiator).
- Self-application of the project's own policies to its codebase (ironic gap).
- Complete the Bubble Tea TUI per the updated TUI-SPEC in the old handoff folder (parallel/related work on the same hotfix branch lineage).
- ROCm duplication in ml-dev (less urgent now that thin is default, but still needs smart handling).
- No open GitHub issues/PRs tied to this overhaul (per context snapshot).

**Repo**: https://github.com/p10ns11y/arch-machine  
**Default/Protected Branch**: `sentinel`  
**Working Branch for This Mission**: `hotfix/arch-machine-overhaul-20260529` (or similar hotfix/sentinel-* naming; create from current clean state).

---

## Success Criteria (How We Know We Won)
- New user clones → `./install.sh` (thin) → gets working `tinfoil` CLI → can then do `./install.sh --profile minimal` or future `tinfoil install --profile ...` for full hardened ML workstation with weekly maintenance and one-command evidence bundles.
- Contributor can add a new module following `docs/MODULES.md` in < 30 minutes; CI is green on their PR.
- Repo looks like (and is) a top-tier open-source dev tool on first GitHub view: clean root, single-source `docs/INDEX.md`, badges, SECURITY.md, contributor guides, no duplication.
- All scripts pass shellcheck; profiles validate; the overhaul itself produced auditable evidence bundles at every phase (self-referential proof).
- The platform's own security-remediation policy has been applied to its technical debt (duplication killed after audit; legacy consolidated or deleted with evidence).
- `install.sh` (thin + full) and `tinfoil` remain fully functional after every phase.
- Professional surface is the default; fun sentinel lore is optional and clearly marked.

---

## Non-Negotiables for Execution (Highest Security Seniority)
- **Self-referential loop** (mandatory for the agent): Before every major file operation, phase, or commit: (1) Re-read this CONTEXT + INIT_PLAN + current STATE.md + PROGRESS.md. (2) Run `./install.sh --thin` (or current thin path) + `tinfoil` + `maintenance/security-audit.sh` + `maintenance/extract-evidence.sh` on the working tree. (3) Commit the resulting evidence bundle (JSON + TOON if available) with message referencing the phase/action. (4) Update living STATE.md/PROGRESS.md with "Pre/Post Phase X evidence: <bundle path/sha>". Only then proceed.
- **Policy application**: Treat every duplicated or legacy artifact as a high-severity vulnerability per `policies/security-remediation.md`. Audit first (using the project's tools), built-in fix, small config fix, otherwise kill after extracting unique value. Document the remediation decision in the evidence bundle.
- **Branch & PR discipline**: Work only on `hotfix/arch-machine-overhaul-*` (or vir tinel-style for TUI-related). PR to `sentinel` only at phase gates or major milestones. No direct pushes.
- **Evidence production**: The overhaul must produce and consume its own bundles. The handoff folder is a first-class citizen of the platform.
- **Minimal disruption**: `./install.sh --profile X --dry-run` and `--validate` must continue working after every change.
- **Tone**: Professional/vigilant/guardian default. Full lore only in FUNREADME.md.
- **Idempotency, DRY, auditability**: Every change via `git mv` + exhaustive reference updates + evidence of the diff.

**This context is complete and self-contained for the autonomous agent.** Treat it (plus the living STATE.md/PROGRESS.md in this handoff folder) as the single source of truth. Re-read before every action. Execute with the highest security seniority level.

**End of CONTEXT.md** — This file will be maintained and referenced by the agent throughout the mission.