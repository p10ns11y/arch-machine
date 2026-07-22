# arch-machine ontology

**Graph:** [arch-machine.graph.yaml](arch-machine.graph.yaml) · **Viz:** [GRAPH.md](GRAPH.md)  
**Mission:** Impossible Arch self-remediation made routine via Eagle → shells → evidence.

Load **one subgraph** per task. Do not dump the full graph.

## Subgraphs (load by intent)

| Intent | Start nodes | When |
|--------|-------------|------|
| `control` | `am:ControlPlane`, `am:EagleTEA` | Edit `tools/archy`, TEA Msg/Cmd, job routing |
| `install` | `am:ProfileEngine`, `am:ModuleBay` | Profiles, `install.sh`, modules |
| `evidence` | `am:EvidenceLoop`, `am:RemediationPolicy` | Bundles, audit→fix, dry-run |
| `remote` | `am:Groxy`, `am:PluginCycle` | groxy inject/ACP, Grok plugin slash cmds |
| `vault` | `am:Keeper` | Threshold secrets (`tools/keeper`) |
| `verify` | `am:VerifyGate` | lint, profiles, cargo tests, install validate |

## Concept → files

| Concept | Files |
|---------|-------|
| Eagle TEA | `tools/archy/`, `docs/archy.md`, skill `eagle-satellite-elomaxz` |
| Profile install | `install.sh`, `lib/installer.sh`, `config/profiles/` |
| Modules | `modules/*/install.sh`, `docs/MODULES.md` |
| Maintenance | `maintenance/*.sh` |
| Evidence | `lib/evidence.sh`, `maintenance/extract-evidence.sh`, `logs/` |
| Remediation | `policies/security-remediation.md` |
| Groxy | `tools/groxy/`, `docs/groxy.md`, `bin/groxy` |
| Keeper | `tools/keeper/`, `modules/security/install.sh --agent-expand`, `arch-design/keeper.md` |
| Session order | skill `session-unit-order` · Omarchy + UWSM |
| Plugin ↔ archy | `docs/archy.md` · plugin repo `docs/CROSS-REF.md` ([p10ns11y/plugins](https://github.com/p10ns11y/plugins) `arch-machine/`) |

## Never compress

- `policies/security-remediation.md`
- `install_<module>()` under edit
- Profile `includes[]` when changing composition
- Eagle Msg/Cmd contracts when routing jobs
- Evidence schema fields agents parse

## Expand

| Phrase | Load |
|--------|------|
| `expand control` | subgraph `control` + `docs/archy.md` |
| `expand install` | subgraph `install` + `docs/MODULES.md` |
| `expand evidence` | subgraph `evidence` |
| `expand remote` | subgraph `remote` + `docs/groxy.md` |
| `expand vault` | subgraph `vault` + `arch-design/keeper.md` |
