# Verification cockpit — PROJECT_NAME

Golden-ratio mission control for post-agent verification. Every pane must answer: **what failure does this surface?**

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

| Title | Prio | Tier | Command |
|-------|------|------|---------|
| WATCH | 1 | watch | pnpm test --watch |
| CMD | 2 | monitor | (console) |
| GIT | 3 | monitor | lazygit |
| VERIFY | 4 | verify | pnpm test (`[y/N]`) |

## Commands

```bash
av                  # open cockpit; watchers start immediately
av --scan           # + agent_scan in CMD
av --launch-mutate  # allow mutate-tier panes (if any)
av --generic        # skip this layout; use generic cockpit
```

## Regenerate

Re-run `verification-cockpit` when verify steps change. Skill: `~/skills/verification-cockpit/` (or your skills library path).
