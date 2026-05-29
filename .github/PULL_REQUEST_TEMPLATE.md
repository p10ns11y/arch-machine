## Pull Request Checklist (Vigilant Guardian)

- [ ] Ran the project's own tools before opening: `./install.sh --thin`, `tinfoil`, `maintenance/security-audit.sh`, `maintenance/extract-evidence.sh`
- [ ] Shellcheck / yamllint / markdownlint clean (or explained)
- [ ] Profiles still validate (`install.sh --profile X --dry-run --validate`)
- [ ] No new duplication or root pollution introduced (checked against docs/LEGACY.md spirit)
- [ ] Docs updated (INDEX, MODULES, etc. as relevant)
- [ ] Evidence bundle produced and referenced in PR description if automation/docs changed
- [ ] `install.sh` thin + profile contracts preserved
- [ ] Tone: professional/vigilant default (full lore only in FUNREADME.md)

**Evidence for this PR**:
- Bundle: `logs/evidence-bundle-YYYYMMDD-HHMMSS.*` (if applicable)

**Description**:
(Why this change? Link to issue or overhaul phase.)

The Sentinel approves only clean, evidence-backed contributions.
