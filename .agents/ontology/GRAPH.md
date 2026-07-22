# arch-machine — ontology viz

Evidence-checked against `tools/archy` jobs + `modules/security/install.sh --agent-expand` (2026-07-22).

```mermaid
flowchart TB
  subgraph control["control"]
    CP[am:ControlPlane]
    Eagle[am:EagleTEA]
  end
  subgraph install["install"]
    PE[am:ProfileEngine]
    MB[am:ModuleBay]
  end
  subgraph evidence["evidence"]
    EL[am:EvidenceLoop]
    RP[am:RemediationPolicy]
  end
  subgraph remote["remote"]
    GX[am:Groxy]
    PL[am:PluginCycle]
  end
  subgraph vault["vault"]
    KP[am:Keeper]
  end
  VG[am:VerifyGate]

  CP -->|implements| Eagle
  Eagle -->|Cmd FireSatellite| EL
  Eagle -->|InstallDry install.sh| PE
  Eagle -->|LaunchGrok| GX
  PL <-->|slash / co-pilot| Eagle
  PE -->|composes profiles| MB
  MB -->|install_security profile path| KP
  MB -.->|security --agent-expand| KP
  EL -->|governed_by| RP
  VG -.->|gates| CP
  VG -.->|gates| PE
  VG -.->|gates| EL
  VG -.->|gates| KP
```

**Not an edge:** Keeper → ProfileEngine. `--agent-expand` is the **security module** standalone entry; it builds/installs `tools/keeper`. It does **not** call ProfileEngine.

Intent → start: see [INDEX.md](INDEX.md).
