# arch-machine ontology

**Graph:** [arch-machine.graph.yaml](arch-machine.graph.yaml) · **Viz:** [GRAPH.md](GRAPH.md)  
**Docs:** [docs/archy.md](../../docs/archy.md) · [docs/groxy.md](../../docs/groxy.md)  
**Mission:** Impossible Arch self-remediation made routine via Eagle → shells → evidence.

Load **one subgraph** per task. Do not dump the full graph.

## Subgraphs (load by intent)

| Intent | Start nodes | When |
|--------|-------------|------|
| `control` | `am:ControlPlane`, `am:EagleTEA`, `am:GrokBuildCycle` | Edit `tools/archy`, TEA, local Grok Build handoff |
| `install` | `am:ProfileEngine`, `am:ModuleBay` | Profiles, `install.sh`, modules |
| `evidence` | `am:EvidenceLoop`, `am:RemediationPolicy` | Bundles, audit→fix, dry-run |
| `agent_transport` | `am:GrokAgentTransports`, `am:GroxyAcpServe`, `am:NvimGrokStdio`, `am:GroxyInject` | Remote ACP, Neovim stdio, XChat notify |
| `vault` | `am:Keeper` | Threshold secrets (`tools/keeper`) |
| `verify` | `am:VerifyGate` | lint, profiles, cargo tests, install validate |

## Concept → files

| Concept | Files |
|---------|-------|
| archy Eagle TEA | `tools/archy/`, `docs/archy.md`, skill `eagle-satellite-elomaxz` |
| Grok Build ↔ archy cycle | `docs/archy.md` § plugin · `tools/archy/src/grok_launch.rs` · plugin [p10ns11y/plugins](https://github.com/p10ns11y/plugins) `arch-machine/` |
| Profile install | `install.sh`, `lib/installer.sh`, `config/profiles/` |
| Modules | `modules/*/install.sh`, `docs/MODULES.md` |
| Maintenance / evidence | `maintenance/*.sh`, `lib/evidence.sh`, `logs/` |
| Remediation | `policies/security-remediation.md` |
| Grok agent transports | `docs/groxy.md` · `tools/groxy/` |
| groxy acp serve | `docs/groxy.md` § ACP · `bin/groxy acp serve` |
| Neovim stdio | `docs/groxy.md` § Neovim · `tools/groxy/extras/neovim/plugins/grok-acp-plugin/` |
| groxy inject | `docs/groxy.md` § inject · `bin/groxy inject` |
| Keeper | `tools/keeper/`, `modules/security/install.sh --agent-expand`, `arch-design/keeper.md` |
| Session order | skill `session-unit-order` · Omarchy + UWSM |

## Never compress

- `policies/security-remediation.md`
- `install_<module>()` under edit
- Profile `includes[]` when changing composition
- Eagle Msg/Cmd contracts when routing jobs
- Evidence schema fields agents parse
- Distinction: archy↔Grok Build cycle ≠ groxy remote transports

## Expand

| Phrase | Load |
|--------|------|
| `expand control` / `expand archy` | subgraph `control` + `docs/archy.md` |
| `expand install` | subgraph `install` + `docs/MODULES.md` |
| `expand evidence` | subgraph `evidence` |
| `expand remote` / `expand groxy` / `expand transport` | subgraph `agent_transport` + `docs/groxy.md` |
| `expand vault` / `expand keeper` | subgraph `vault` + `arch-design/keeper.md` |
