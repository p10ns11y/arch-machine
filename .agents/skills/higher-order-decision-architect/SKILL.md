---
name: higher-order-decision-architect
description: >-
  Applies first-principles, multi-order consequence analysis, inversion, systems
  thinking, probability, antifragility, and high-energy thrive ascent (2036 lens)
  before material coding decisions (architecture, dependencies, public API, security,
  data contracts, hard-to-revert refactors). Use when choosing between approaches,
  planning cross-cutting changes, or when the user asks for decision analysis,
  tradeoffs, pre-mortem, second-order effects, or thrive vision.
---

# Higher-Order Decision Architect

Before **material coding decisions**, reason through this framework internally. You do **not** need the full output block in every reply — but for non-trivial decisions, surface **Executive Verdict**, **risks**, **confidence**, and **next actions**.

**Material decision** = architecture, dependencies, public API, security, data contracts, multi-module refactors, or anything hard to revert.

**Project overlays** (load when working in that repo):

| Repo | Overlay |
|------|---------|
| shellyxz shell (`~/.config/shell`) | `arch-design/overlays/shell-kernel-decision-hooks.md` — post–SN-4a kernel/plugin/PATH/ontology hooks |
| Thepulimaangani | [examples/overlays/thepulimaangani-decision-hooks.md](../examples/overlays/thepulimaangani-decision-hooks.md) — WASM/metre contracts |

---

## Mental models (exact sequence)

1. **First principles** — Constraints, invariants, maintenance economics, human factors. Do not default to “best practice” or analogy alone.
2. **Second- & higher-order thinking** — For each option: “And then what?” until the chain stabilizes. Map 1st-, 2nd-, 3rd-order+ effects.
3. **Inversion + pre-mortem** — “How could this fail at order 2 or 3?” Then: “12–24 months later this failed — what went wrong?” Be **honest** — name scope creep, vendor anchors, doc debt, coupling.
4. **Systems thinking** — Stocks, flows, feedback loops, delays, leverage points.
5. **Probabilistic thinking** — Rough probabilities; Bayesian update when evidence arrives; avoid binary “will/won’t” when uncertain.
6. **Circle of competence + regret minimization** — Known vs guessed; which path minimizes regret for maintainers, users, agents?
7. **Antifragility** — Prefer options that **gain** from small volatility (tests, flags, contracts) vs brittle one-shot bets.
8. **High-energy optimistic long-term thriving mode** — **After** the honest pre-mortem, deliberately counter funeral drift. Run a **2036 thrive ascent** pass (see below). Platform shifts are cosmic weather you punch through; bottlenecks are judgment/trust, not typing. Risk ≠ defeat — inversion becomes **trajectory guardrails** (refuse vs build toward the horizon).

---

## Step 8 — Thrive ascent (2036 lens)

Run this **after** steps 3–7 so pessimism does not get the last word. Ground optimism in evidence; high energy ≠ denial.

### Thrive, not survive

| Funeral drift (avoid) | Thrive reframe |
|-----------------------|----------------|
| “This feature will die” without alternative | Name what **builds toward** the horizon year (default **2036**) |
| “Pivot to minimal only” | Minimal **plus** acceleration alternative — what to invest in when the force hits |
| “Abandon the project” as closing line | Freeze vs split vs shrink — with **iron-peak** foundation named |
| Binary will/won’t | Probability ranges + **Response** column |
| Pre-mortem as autopsy | Pre-mortem → **guardrails** + leading indicators |

### Mandatory thrive outputs (internal or surfaced)

1. **Ten-year thrive picture** — One sentence north star: kernel (durable) + bridge/product (evolving) + boundary. Mermaid or table when in roadmap docs ([stellar-roadmap](../stellar-roadmap/SKILL.md) §0b).
2. **Trajectory forces** — Table: Force | P(horizon) | Effect | **Response** | Confidence. Include at least one **tailwind** (e.g. POSIX shell, manifest-first agents, contract verification).
3. **Refuse vs build** — Two columns: what we **refuse** (drag) vs what we **build toward** `{YEAR}` (ascent). No “optional workflow that may die” framing for pillars the operator cares about.
4. **Iron-peak callout** — Which abstraction compounds for a decade? (e.g. `path.contract`, PLUGIN boundary, evidence schema.) Mark positive 3rd-order outcomes explicitly.
5. **Acceleration trigger** — When would pessimism say shrink? State when to **invest more** instead (evidence-weighted).
6. **Thrive bet confidence** — Confidence % on the long-horizon bet; separate from near-term implementation confidence.

### Provenance (shellyxz shell pattern)

Applied in `~/.config/shell`:

- `arch-design/coming-next.md` — § Trajectory forces (2036-oriented) with Response + Confidence
- `arch-design/test-of-travelled-time-from-future.md` — honest pre-mortem **then** split/kernel-vs-cockpit thrive framing
- `planned-features/done/sprint-jun-2026-pr8.md` — Ten-year thrive picture mermaid (kernel2036 → bridge2036 → launch)
- [stellar-roadmap](../stellar-roadmap/SKILL.md) — §0b thrive picture, §5 trajectory forces, §6 guardrails

---

## Mandatory process

1. **Diagnose the critical zone** — Single highest-leverage / highest-uncertainty bottleneck. If unclear, ask 1–2 sharp questions.
2. **Deconstruct with first principles**
3. **Map consequence chain** (1st → 2nd → 3rd+) with rough probabilities
4. **Inversion & pre-mortem** on top 2–3 options (honest failure modes + mitigations)
5. **Systems + antifragility**
6. **Thrive ascent (step 8)** — 2036 lens: forces + responses, refuse vs build, iron-peak, acceleration trigger
7. **Synthesize** — One recommendation + explicit confidence + assumptions + **leading indicators** to watch

---

## Output format (non-trivial decisions)

**Executive Verdict** (1–2 sentences)

**Critical Area Identified** — One sentence

**First Principles Breakdown** — Bullets

**Consequence Chain** — Table: Order | Effect | Probability | Impact (H/M/L) | Notes

**Inversion & pre-mortem risks** — Top failure modes at order 2+ and mitigations

**Thrive ascent (2036)** — North star one-liner; trajectory forces table (with **Response**); refuse vs build; iron-peak abstraction; thrive bet confidence %

**Recommended Decision** — Clear action + 2–3 sentence rationale (must not read as defeat if a pillar is worth keeping)

**Confidence & uncertainties** — Near-term confidence %; thrive bet confidence %; key assumptions; monitoring signals

**Immediate next actions** — Max 3 concrete steps

---

## Non-negotiable rules

- Be direct; say “unknown” or “outside reliable competence” when true.
- No corporate hedge-speak; prefer precise language.
- Prefer long-term (3rd-order+) value over short-term optics when they conflict.
- Weak evidence → state probability ranges.
- **Pre-mortem is mandatory and honest — but never the final beat.** Always follow with thrive ascent (step 8).
- **Do not close** a material decision advisory on shrink/abandon without naming refuse vs build and at least one acceleration alternative.
- When closing a decision advisory turn, you may ask: “Stress-test further or apply to another project area?”

---

## Activation

- User asks for tradeoffs, architecture choice, “what could go wrong”, pre-mortem, second-order effects, or thrive/2036 vision.
- Agent is about to pick dependencies, public API shape, security model, or a cross-module refactor.
- Pair with domain skills ([bdd-strategizer](../bdd-strategizer/SKILL.md) for test-first decomposition; [fusion-sage](../fusion-sage/SKILL.md) for long-term surplus; [stellar-roadmap](../stellar-roadmap/SKILL.md) for §0b/§5/§6 in backlog docs; [ai-optimization](../ai-optimization/SKILL.md) for evidence-first scouting).
- **Shellyxz shell:** load `arch-design/overlays/shell-kernel-decision-hooks.md` before kernel/plugin/PATH/ontology splits; pair with `.agents/ontology/GRAPH.md` for boundary context.

## Cursor rule (optional)

Symlink [rules/higher-order-decision-architect.mdc](../rules/higher-order-decision-architect.mdc) into `.cursor/rules/` with `alwaysApply: true` to route material decisions to this skill without pasting the full framework every turn.

**Example provenance:** [Thepulimaangani](https://github.com/p10ns11y/thepulimaangani) (Tamil prosody / WASM parser decisions); [shellyxz shell](https://github.com/p10ns11y/shellyxz.sh) (2036 thrive ascent + trajectory forces).
