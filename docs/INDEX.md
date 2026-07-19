# Arch Machine — Index & Architecture

**The Vigilant Guardian Platform** for Arch Linux ML/AI workstations.

**Thin-first, evidence-always, self-remediating.**

## Quick Start (Recommended Path)

1. Clone the repo.
2. `./install.sh` (or `./install.sh --thin`) — installs only the `tinfoil` sentinel CLI + self-contained runtime (fast, zero heavy deps by default).
3. `tinfoil` or `tinfoil tui` — interactive Bubble Tea guardian (audit, cleanup, maintenance, evidence, settings).
4. For a full hardened ML workstation: `./install.sh --profile minimal` (or ml-dev / security-dev).
5. Weekly: the systemd timer (or manual `weekly-check.sh`) runs maintenance + produces AI-optimized evidence bundles in `logs/`.

See [Installation Guide](INSTALLATION.md) and [Maintenance Guide](MAINTENANCE.md) for details.

For lore and dramatic origin story only: [FUNREADME.md](FUNREADME.md).

## Architecture (Mermaid)

```mermaid
flowchart TD
    A[Thin tinfoil CLI + Bubble Tea TUI<br/>/usr/local/bin/tinfoil] -->|install --profile| B[install.sh + lib/installer.sh]
    B --> C{YAML Profiles<br/>minimal / ml-dev / security-dev}
    C --> D[modules/*/install.sh<br/>install_<module> functions]
    D --> E[lib/ (logger, validator, evidence, tui shims)]
    E --> F[maintenance/ (security-audit, weekly-check, extract-evidence, systemd-setup)]
    F --> G[Evidence Bundles<br/>logs/evidence-*.json + .toon<br/>AI-optimized, token-efficient]
    G --> H[tinfoil evidence<br/>TUI Evidence screen<br/>LLM/agent ready]
    A -->|audit / cleanup / evidence| F
    I[weekly timer / systemd units<br/>dynamic generation] --> F
    style A fill:#0a0,stroke:#0f0
    style G fill:#00f,stroke:#0ff,color:#fff
```

**Core Loop (Self-Improving Guardian)**:
Thin tinfoil → Profiles → Modules (DRY idempotent) → Libs → Maintenance/Orchestration → Evidence self-loop → TUI/CLI surface → (optional) apply-remediation policy kills.

## Key Directories & Contracts

- `docs/` — Single source of truth (this INDEX, INSTALLATION, MAINTENANCE, EVIDENCE, SECURITY, DEVELOPMENT, CONTRIBUTING, LEGACY, MODULES, PROFILES).
- `bin/tinfoil.go` + `cmd/tui/` — Production Cobra + embedded Bubble Tea guardian (single binary).
- `install.sh` + `lib/` — Profile-driven installer (thin default; explicit --profile for heavy).
- `modules/` — One directory per capability. Each must provide `install_<name>()`, support --dry-run/--validate, hook evidence where relevant.
- `maintenance/` — The orchestration heart (audit, weekly, evidence extraction, timer setup).
- `config/` — YAML profiles + tool manifests.
- `policies/` — The ruthlessly applied rules (security-remediation.md is the meta-rule for this repo itself).

See:
- [docs/MODULES.md](MODULES.md) — Authoring contract for new modules.
- [docs/PROFILES.md](PROFILES.md) — How profiles are validated and composed.
- [docs/LEGACY.md](LEGACY.md) — What was killed and why (policy application proof).
- [docs/SECRETS-EVERYDAY.md](SECRETS-EVERYDAY.md) — Developer everyday secrets: central recovery, runtime inject, API-key sprawl.
- [docs/omarchy.md](omarchy.md) — Day-1 Omarchy + arch-machine playbook (ownership, command map).
- [docs/omarchy-commands.md](omarchy-commands.md) — Full Omarchy CLI reference (host `omarchy` binaries).
- [AUTHORS-MOTTO.md](../AUTHORS-MOTTO.md) — Philosophy ("Solve your own machine first...").

## Evidence — The Differentiator (Phase 5 Amplified)

Every run produces token-efficient JSON + TOON bundles optimized for LLMs/agents.

**New in Phase 5**:
- `tinfoil evidence list` / `latest` — quick CLI access to recent bundles.
- `maintenance/apply-remediation.sh` — real callable self-application of the project's own security-remediation policy.
- `tinfoil tui` now has (or will have in full TUI-SPEC) a dedicated Evidence screen.
- `maintenance/extract-evidence.sh` produces the bundles; weekly timer + TUI make them first-class.

The overhaul itself (this handoff) ran the same loop on the project's own technical debt — proof the Sentinel watches itself.

See `tinfoil evidence help` and docs/LEGACY.md.

## Contributing & Professional Surface

- Run the project's own tools before PR: `./install.sh --thin`, `tinfoil`, `maintenance/security-audit.sh`, `maintenance/extract-evidence.sh`.
- CI (Phase 4) enforces shellcheck, profile validation, evidence smoke, Go build/vet, markdownlint.
- See [docs/CONTRIBUTING.md](CONTRIBUTING.md) and [docs/DEVELOPMENT.md](DEVELOPMENT.md).

## Status (Overhaul Mission 2026-05)

- Phase 0/1 complete (handoff bootstrap + ruthless duplication/root pollution kills per own policy; docs/LEGACY.md).
- Phase 2 items pulled forward (link hygiene started; INDEX.md live).
- Phase 3 in progress (dynamic systemd units shipped; more automation hardening next).
- Phase 4/5 + final executing under acceleration per user directive.

**The platform now self-remediates at the policy level.**

---

**Maintained by the Sentinel (Vigilant Guardian).** Evidence first. No waste.

*Last updated during accelerated autonomous execution (evidence 135543).*