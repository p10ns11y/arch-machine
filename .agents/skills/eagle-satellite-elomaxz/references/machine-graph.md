# Machine graph — Eagle, satellites, Elomaxz messages

Simple English reference for agents and humans. Implementation: `crates/archy`.

## 1. Big picture

```mermaid
flowchart TB
  subgraph Input
    K[Key press]
    L[Job line]
    D[Job done / fail]
  end

  subgraph Eagle["Eagle — thin brain"]
    M[Msg]
    U[update]
    P[Phase state machine]
    M --> U
    U --> P
    U --> C[Cmd]
  end

  subgraph Runtime["Runtime — main loop"]
    V[View draw]
    X[perform Cmd]
  end

  subgraph Sats["Satellites — domain owners"]
    I[Inventory]
    A[Audit]
    O[Omarchy]
    N[…others]
  end

  subgraph Offline["Offline job runner"]
    SP[spawn shell]
    ST[stream stdio]
    EX[poll exit]
  end

  K --> M
  L --> M
  D --> M
  C --> X
  X -->|FireSatellite| Sats
  Sats --> SP --> ST --> EX
  EX -->|JobFinished Msg| M
  V --> Operator((Operator))
  Operator --> K
```

## 2. Phase state machine (xstate-style)

```mermaid
stateDiagram-v2
  [*] --> Home
  Home --> Running: FireSatellite
  Home --> Help: ? or menu Help
  Home --> [*]: Quit

  Running --> Review: JobFinished / SpawnFailed
  Running --> Review: KillJob then finish as cancelled

  Review --> Running: NEXT re-run or other satellite
  Review --> Home: Esc / Home action
  Review --> Help: ?

  Help --> Home: Esc / Enter / h
```

| State | Meaning in plain English |
|-------|--------------------------|
| Home | You pick what to run |
| Running | A script is working; lines scroll |
| Review | Script finished; pick the next best step |
| Help | Long help text only |

## 3. One offline job DAG

```mermaid
flowchart LR
  F[Fire] --> S[Spawn]
  S --> L[Lines…]
  L --> E{Exit code}
  E -->|ok or fail| N[NEXT plan]
  N --> R[Review phase]
  R --> F2[Optional fire again]
  R --> H[Home]
```

No heartbeat. Eagle does **not** watch the process every tick for “liveness stories” — it drains lines and polls exit.

## 4. Message → command (Elomaxz / TEA)

```mermaid
sequenceDiagram
  participant Op as Operator
  participant RT as Runtime main
  participant Eg as Eagle update
  participant Sat as Satellite
  participant Sh as Shell backend

  Op->>RT: key Enter on Inventory
  RT->>Eg: Msg::Key / ActivateMenu
  Eg-->>RT: Cmd::FireSatellite Inventory
  RT->>Sat: build Command
  RT->>Sh: spawn offline
  loop while running
    Sh-->>RT: stdout line
    RT->>Eg: Msg::JobLine
  end
  Sh-->>RT: process exit
  RT->>Eg: Msg::JobFinished
  Eg->>Sat: on_finished → NEXT actions
  Eg-->>RT: Cmd::None
  RT->>Op: draw Review + NEXT bar
```

## 5. File map (read like the diagram)

```text
crates/archy/src/
  main.rs          Runtime host (draw, perform, poll)
  eagle.rs         update(Msg) → Cmd
  fsm.rs           Phase states
  msg.rs           Events
  cmd.rs           Effects
  app.rs           Model / context + perform
  satellites/      Domain owners + MENU registry
  jobs.rs          Offline spawn + stream + poll
  actions.rs       NEXT action types + inventory hints
  ui.rs            View only
  nav.rs           Pure focus helpers
  theme.rs         Light/dark palettes
```

## 6. Gum TEA twin

```mermaid
flowchart LR
  messages.sh --> update.sh
  model.sh --> update.sh
  update.sh --> model.sh
  model.sh --> view.sh
```

Same idea: messages in, model change, view out — no drawing inside update.
