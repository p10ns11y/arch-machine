# Overlay — shell kernel + verification bridge

**Type:** shell-kernel · **Canonical doc:** `{REPO}/arch-design/coming-next.md` · **Boundary:** `{REPO}/PLUGIN.md`

## Fused abstraction

Ship computer (kernel: PATH, migrate, recover) + command bridge (ab/av/at, tmux, cockpit.yaml) + hull bays (PLUGIN) → host-agnostic human verification before launch.

## Scorecard skeleton

| Area | Grade | Evidence |
|------|-------|----------|
| path.contract + project phase | — | `path-contract-project.sh`, overlay order |
| PLUGIN boundary | — | `PLUGIN.md`; physical split open? |
| Agent strict PATH | — | `ab --strict`, `tool.contract` |
| Cockpit + manifest | — | `cockpit.yaml`, tmux layouts |
| Test discovery | — | project test scripts |
| Per-project tmux | — | `ts` / project layout |

## Open SN priority (template)

1. **SN-1** Dogfood gate — run `av` in repo, no new code
2. **SN-2** Per-project env fragment (direnv / phase)
3. **SN-3** Agent strict PATH (plugin only)
4. **SN-4** Modular split of verification plugins
5. **SN-5** Cockpit simplify — keep navigators, tiered launch
6. **SN-7** MCP export for manifest (thrive bet)

## Key paths (customize per repo)

`arch-design/architecture.md` · `core/path-resolve.sh` · verification manifest · `planned-features/done/`

## Verify (customize)

```bash
bin/check-shell.sh          # or project equivalent
bin/cockpit-mcp.sh verify . # if MCP surface exists
```

**Expand full doc for:** shipped cards → `{REPO}/planned-features/done/`.
