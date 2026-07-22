# Verification cockpit — arch-machine

Golden-ratio mission control for post-agent verification. Every pane answers: **what failure does this surface?**

## Flows

| Alias | Config here | Notes |
|-------|-------------|-------|
| `av` | `tmux-layout.sh` (+ `cockpit.yaml` verify map) | Host shellyxz delegates when this file is executable |
| `at` | `cockpit.yaml` → `cockpits.test` | Priority runners (`max_run: 2`) |
| `ab` | `cockpit.yaml` → `cockpits.build` | `nvim .` (avante + grok-acp) |

## Layout (φ 62% / 38%)

```
+----------------------------+------------------+
|                            | VERIFY (minor)   |
|  GIT (tui-side, 62% w)     |------------------|
|  lazygit full height       | WATCH (scroll)   |
|                            |------------------|
|                            | CMD (interactive)|
+----------------------------+------------------+
     git column 62%              ops column 38%
```

| Title | Prio | Tier | What you learn |
|-------|------|------|----------------|
| WATCH | 1 | watch | `make lint` loop every 30s |
| CMD | 2 | monitor | `agent_scan`, manual verify |
| GIT | 3 | monitor | lazygit — agent diffs |
| VERIFY | 4 | verify | AGENTS.md pre-PR gate (`[y/N]`; omits `install.sh --thin --validate`) |

## Commands

```bash
av                  # open cockpit; WATCH starts immediately
av --scan           # + agent_scan in CMD
av --generic        # skip this layout; host generic cockpit
at                  # top 2: make lint + archy cargo test
at --watch          # same, every 60s
ab                  # build window → nvim . (cockpits.build)
```

## Regenerate

Re-run `verification-cockpit` when verify/test steps change. Skill SoT: shellyxz `.agents/skills/verification-cockpit/` (pull into locked skills when ready).
