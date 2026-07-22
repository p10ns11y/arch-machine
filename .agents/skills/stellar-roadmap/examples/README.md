# Stellar roadmap — repo-type overlays

**Purpose:** One-page scout context so agents refresh roadmaps without re-reading full `coming-next.md` (~30% fewer tokens on similar updates).

**When to load:** Before editing §1–§7 of a roadmap. Pair with **ai-optimization** (hierarchy-first scout).

| Overlay | Repo type | Canonical full doc |
|---------|-----------|-------------------|
| [shell-kernel.md](shell-kernel.md) | Portable shell / dotfiles kernel + PLUGIN boundary | Target project's `arch-design/coming-next.md` (or equivalent) |
| [eve-agent.md](eve-agent.md) | [Vercel Eve](https://vercel.com/eve) agent directory | *(create `arch-design/coming-next.md` in target repo)* |

**Shell config dogfood:** full overlay with live paths in skills library [shellyxz-shell-kernel.md](../../examples/overlays/shellyxz-shell-kernel.md).

**Usage:** Tell the agent: `Load stellar-roadmap/examples/shell-kernel.md overlay; expand full coming-next only for SN-N being edited.`

**Add overlays:** Copy `eve-agent.md` as a template; keep ≤80 lines; fused abstraction + scorecard skeleton + SN priorities only.
