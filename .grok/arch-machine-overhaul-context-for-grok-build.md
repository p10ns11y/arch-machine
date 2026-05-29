# Arch-Machine Overhaul Context for Grok Build

**Project:** arch-machine  
**Owner:** Peramanathan Sathyamoorthy (p10ns11y)  
**Repository:** https://github.com/p10ns11y/arch-machine  
**Focus:** Prepare a comprehensive, phased overhaul plan using Grok Build's planning and multi-agent capabilities.

---

## 1. Project Mission & Positioning

**arch-machine** is a **profile-based bootstrap and maintenance system for Arch Linux workstations**, purpose-built for **ML/AI developers who also demand strong security hardening**.

**Tagline (keep the spirit):** "The only Arch Linux setup that audits itself harder than your ex audits your text messages."

**Target Users:**
- Solo ML/AI researchers and engineers on Arch Linux (primary)
- Small teams wanting reproducible, secure GPU workstations (ROCm focus)
- Security-conscious developers who want automated evidence bundles optimized for feeding to LLMs/agents

**Core Value Proposition (preserve and amplify):**
- One-command (or one-profile) transformation of a fresh Arch install into a hardened, ML-ready machine
- Automated weekly maintenance + security auditing
- **Evidence extraction** — token-efficient, AI-optimized log/SBOM/audit bundles (this is a standout differentiator)
- Modular, profile-driven design (minimal / ml-dev / security-dev)
- Fun, memorable personality without sacrificing professionalism

---

## 2. Current State Snapshot (as of late May 2026)

### Directory Structure (High-Level)
```
arch-machine/
├── .composer/                  # Personal/tool artifact — should be gitignored
├── .grok/                      # Personal/tool artifact (contains hardware-acceleration/)
├── .kilo/                      # Personal/tool artifact
├── config/
│   ├── profiles/               # minimal.yaml, ml-dev.yaml, security-dev.yaml (good)
│   └── tools.yaml
├── docs/                       # 5 files (INSTALLATION.md, MAINTENANCE.md, etc.)
├── lib/                        # Core shared logic (installer.sh, logger.sh, validator.sh, evidence.sh — **excellent**)
├── maintenance/                # ~10 scripts (security-audit.sh is 22kB, weekly-check.sh, backup.sh, systemd-setup.sh, cron-setup.sh, extract-evidence.sh, notify.sh, etc.)
├── modules/
│   ├── development/
│   ├── ml_ai/
│   ├── productivity/
│   ├── security/
│   └── system/                 # Each has its own install.sh — solid pattern
├── setups/                     # 8 scripts — **major duplication source**
│   ├── basic_setup.sh
│   ├── secure-fortress-phase0-simple.sh
│   ├── secure-ssh-gpg.sh
│   ├── security-audit.sh       # Duplicate of maintenance/security-audit.sh
│   ├── simple-ssh-gpg.sh
│   ├── torch_gpu_installer.sh
│   ├── vulnerability-tools-installer.sh
│   └── README.md
├── systemd/                    # maintenance.service + maintenance.timer (good direction)
├── AUTHORS-MOTTO.md
├── EVIDENCE-EXTRACTION.md
├── FUNREADME.md                # Highly entertaining "sentinel" branding
├── LICENSE
├── README.md                   # Good quick start, but links are inconsistent
├── SAFETY.md
├── VAULT-GUIDE.md
├── install.sh                  # **Core strength** — clean argument parsing, profile loading, dynamic module sourcing
├── migrate.sh
├── sbom.cdx.json
├── sentinels-ultimate-masters.jpg
├── tinfoil-name-explained.md
├── tinfoil.jpg
├── vector.toml                 # For Vector log shipper (monitoring)
└── logs/                       # Runtime logs
```

### Key Technical Strengths (Do Not Break These)
- `install.sh` + `lib/installer.sh` architecture: YAML profiles → dynamic `source modules/<cat>/install.sh` → call `install_<module>` — very clean and extensible.
- Profile system in `config/profiles/*.yaml` with `includes` array and customizations.
- Evidence extraction pipeline (`lib/evidence.sh` + `maintenance/extract-evidence.sh`).
- Security tooling integration (Lynis, rkhunter, ClamAV, Grype, OSV-Scanner, etc.).
- Systemd timer approach (better than cron).
- Dry-run, validate, force, verbose, and vault setup flags already exist.

### Critical Scattering & Polish Problems (This is What We Must Fix)

1. **Duplication Hell**
   - `security-audit.sh` exists in both `maintenance/` and `setups/`.
   - `cron-setup.sh` + `systemd-setup.sh` — two paths for the same goal.
   - Multiple overlapping "secure setup" scripts in `setups/`.

2. **Root Directory Pollution**
   - 15+ top-level items that are not essential entry points.
   - Personal/tool directories (`.grok/`, `.kilo/`, `.composer/`) committed to the repo.

3. **Documentation Fragmentation**
   - 7+ `.md` files at root + `docs/` folder.
   - Broken/inconsistent internal links (e.g. `INSTALLATION.md` vs `docs/INSTALLATION.md` in README).
   - No single authoritative index or architecture diagram.

4. **Branding & Tone Tension**
   - `FUNREADME.md` with "Virtinel / Eusinel / Safinel / Guardwell / Trusinel" sentinel branch philosophy and heavy tinfoil humor is memorable but makes the project feel like a personal art project rather than a serious, adoptable tool.
   - Main `README.md` is relatively dry in comparison.

5. **Missing Professional Surface**
   - No `.github/` directory (no workflows, issue templates, PR template, CODEOWNERS).
   - No CI (shellcheck, YAML lint, profile validation, markdown lint).
   - Limited contributor documentation beyond `docs/DEVELOPMENT.md`.
   - No clear "how to add a new module" or "how to create a custom profile" guide.

6. **Automation Not Fully Standardized**
   - Maintenance scripts are numerous but not cohesively orchestrated beyond the weekly timer.

---

## 3. Overhaul Vision & Principles

**Vision:** Turn arch-machine into the **default professional-grade choice** for security-conscious ML/AI developers on Arch Linux — while keeping the soul, humor, and "it just works" magic.

**Core Principles for the Overhaul (apply ruthlessly):**
- **Single Source of Truth** — All documentation lives in `docs/` with a clear `docs/INDEX.md` or enhanced `README.md`.
- **Zero Functional Duplication** — One `security-audit.sh`, one automation path (systemd), one place for setup helpers.
- **Clean Root** — Only `install.sh`, `README.md`, `LICENSE`, `migrate.sh` (if still needed), and perhaps `CONTRIBUTING.md` at the top level.
- **Professional First Impression + Optional Fun** — Main README and first-run experience feel trustworthy and polished. The wild humor lives in `FUNREADME.md` and an optional "lore" section.
- **Idempotent & Observable Everything** — Every script must be safe to re-run; rich logging + evidence output is non-negotiable.
- **Extensibility First** — Clear, documented patterns for adding modules, profiles, and custom evidence collectors.
- **Minimal Disruption** — The `install.sh --profile ml-dev` flow must continue working at every step of the migration.

**Success Metrics (how we know we won):**
- New user clones repo → runs install → gets a fully functional, hardened ML workstation with weekly maintenance and one-command evidence bundle.
- Contributor can add a new module following `docs/MODULES.md` in < 30 minutes.
- Repo looks like a top-tier open-source dev tool on first GitHub view (clean README, badges, structure).
- All scripts pass shellcheck; profiles validate; CI is green.

---

## 4. Your Task as Grok Build (Detailed Instructions)

You are an expert software architect and refactoring specialist with deep experience in developer tooling, Linux automation, and large-scale repository hygiene.

**Step 1: Analyze & Propose Ideal Final Structure**
Propose the **ideal final directory layout** (show a clean tree). Justify every top-level item.

**Step 2: Create a Phased Overhaul Plan**
Break the work into **5–6 logical phases** (example skeleton below — improve it):

- **Phase 0: Preparation & Safety** (backups, branch strategy, validation harness)
- **Phase 1: Structure & Hygiene** (move/delete/consolidate files, fix `.gitignore`, clean root)
- **Phase 2: Documentation Consolidation** (single source of truth, fix all links, add architecture diagram, module authoring guide)
- **Phase 3: Automation Unification** (standardize on systemd, merge or delete duplicate scripts, improve orchestration)
- **Phase 4: Quality & CI Foundations** (add `.github/`, shellcheck, profile validator, markdown lint, basic tests)
- **Phase 5: Polish, Branding Balance & Feature Gaps** (tone alignment, new contributor experience, evidence UX improvements, optional "sentinel" lore toggle)

For **each phase** provide:
- Exact list of file operations (move `setups/security-audit.sh` → delete, rename `maintenance/security-audit.sh` to `maintenance/audit.sh` or keep name, etc.)
- New files to create (with purpose and high-level content outline)
- Code/logic changes required (or "implement in next Grok Build session")
- Risks + mitigation
- Effort estimate (XS / S / M / L)
- Order of operations so `install.sh` remains functional after every phase

**Step 3: Prioritization & Quick Wins**
Highlight 5–7 "quick wins" that deliver visible improvement with low risk (e.g., root cleanup, docs link fixes, adding `.github/`).

**Step 4: Risk Register**
List the top 5 risks to a successful overhaul and how to mitigate them.

**Step 5: Post-Overhaul Recommendations**
Suggest follow-up enhancements (e.g., TUI status dashboard, better ROCm detection, profile marketplace, evidence bundle viewer, etc.) that become feasible after the foundation is solid.

**Tone & Style Guidelines for Your Output:**
- Be **ruthless but respectful** of the existing core logic (especially `install.sh` + `lib/`).
- Protect and amplify the **evidence extraction** feature — it is one of the strongest differentiators.
- Keep the fun personality visible but make the **professional surface** the default experience.
- Use clear, actionable language suitable for direct execution by Grok Build or a human maintainer.

**Context Engineering Notes for You:**
- You have full access to the repository via your tools. Use `github___get_file_contents` liberally to inspect any file before proposing changes.
- When proposing moves, always consider `git mv` semantics and update all references (including inside scripts and docs).
- The `install.sh` script must remain the single entry point; do not change its public interface unless absolutely necessary.

---

## 5. Additional Context You May Need

- **FUNREADME.md** contains the full "sentinel" branding lore (Virtinel, Eusinel, Safinel, Guardwell, Trusinel branches) — decide how much of this survives in the professional version.
- `install.sh` is ~400 lines and already quite robust (argument parsing, library loading, profile resolution, validation hooks).
- Evidence feature is split between `lib/evidence.sh` and `maintenance/extract-evidence.sh` — worth unifying.
- The project already has good safety notes (`SAFETY.md`) and a vault setup flow — preserve and surface these better.

---

**Ready when you are.**

Paste the entire content above (or just this file) into Grok Build using **Plan Mode**:

```bash
grok plan --context arch-machine-overhaul-context-for-grok-build.md
# or
grok --max-agents 4 "Execute the arch-machine overhaul plan, starting with Phase 0 and 1"
```

I am ready to help you execute any phase once the plan is approved, or to refine this context further.

---

*Prepared with care by Grok (xAI) — May 2026*  
*Goal: Make arch-machine the tool its creator is proud to recommend to other ML engineers.*