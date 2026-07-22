# arch-machine — ontology viz

Evidence: [docs/archy.md](../../docs/archy.md) · [docs/groxy.md](../../docs/groxy.md) · `tools/archy` jobs · `modules/security/install.sh` (2026-07-22).

```mermaid
flowchart TB
  subgraph control["control — local archy Eagle"]
    CP[am:ControlPlane]
    Eagle[am:EagleTEA]
    GB[am:GrokBuildCycle]
  end

  subgraph install["install"]
    PE[am:ProfileEngine]
    MB[am:ModuleBay]
  end

  subgraph evidence["evidence"]
    EL[am:EvidenceLoop]
    RP[am:RemediationPolicy]
  end

  subgraph transport["agent_transport — Grok agent transports"]
    GAT[am:GrokAgentTransports]
    Serve[am:GroxyAcpServe]
    Stdio[am:NvimGrokStdio]
    Inj[am:GroxyInject]
  end

  subgraph vault["vault"]
    KP[am:Keeper]
  end

  VG[am:VerifyGate]

  CP -->|implements| Eagle
  Eagle -->|FireSatellite| EL
  Eagle -->|InstallDry| PE
  Eagle <-->|G/p preload · exit resumes| GB
  GB -->|plugin /arch-*| Eagle

  PE -->|composes| MB
  MB -.->|security --agent-expand| KP
  MB -->|install_security profile| KP
  EL -->|governed_by| RP

  GAT --- Serve
  GAT --- Stdio
  GAT --- Inj
  Serve -->|WS wraps| AgentWS[grok agent serve]
  Stdio -->|IDE child| AgentIO[grok agent stdio]
  Inj -->|host→XChat| XChat[XChat DM]

  VG -.->|gates| CP
  VG -.->|gates| PE
  VG -.->|gates| EL
  VG -.->|gates| KP
  VG -.->|gates| GAT
```

## Do not confuse

| Surface | Is | Is not |
|---------|----|--------|
| **archy** (local Eagle TUI) | Menu → satellites → NEXT; `G`/`p` opens **Grok Build** with preload; exit returns to archy | Remote phone/laptop control |
| **GrokBuildCycle** | Plugin `/arch-*` ↔ archy handoff | groxy |
| **groxy acp serve** | Long-lived WS remote control of a cwd | archy co-pilot; Neovim daily path |
| **Neovim stdio** | avante spawns `grok agent stdio` | Needs `acp serve` |
| **groxy inject** | Host → XChat **notify** only | Inbound DM control |

Intent → start: [INDEX.md](INDEX.md).
