# Overlay — Vercel Eve agent (directory-as-agent)

**Type:** eve-agent · **Framework:** [Eve](https://vercel.com/eve) · **Full doc:** `arch-design/coming-next.md` *(create in target repo)* · **Init:** `npx eve@latest init my-agent`

## Fused abstraction

Agent directory (Markdown instructions + skills, TypeScript tools) + durable runtime (Workflows, Sandbox) + delivery plane (AI Gateway, Connect, channels) → one codebase, many surfaces (Slack, web, cron, API).

*Like Next.js for web apps, but for agents.*

## Mission (§0 template)

Ship production agents that survive crashes, platform churn, and channel sprawl — instructions in Markdown, tools in TypeScript, durable by default on Vercel primitives.

## Thrive north star (§0b, 3–5y)

| Role | Wins because |
|------|----------------|
| **instructions.md** | Complete agent identity without boilerplate |
| **skills/** | Focused playbooks loaded when relevant — not every prompt |
| **tools/** | Filename = tool name; `defineTool` + zod; no registration ceremony |
| **Workflows** | Checkpointed steps; park between messages; resume on delivery |
| **Sandbox** | Isolated VMs; bash + filesystem without gluing point solutions |
| **channels/** | One agent → Slack, Discord, Teams, web, API, cron |
| **connections/** | GitHub, Stripe, Linear, MCP — auth via Vercel Connect |
| **Evals** | Rubrics on every deploy + schedule |

## Agent directory map (Eve’s 9 layers)

| # | Path | Purpose |
|---|------|---------|
| 1 | `instructions.md` | Role + behavior in Markdown — runnable alone |
| 2 | `agent.ts` | Optional `defineAgent({ model })` — AI Gateway |
| 3 | `skills/` | Markdown skills with frontmatter `description` |
| 4 | `tools/*.ts` | `defineTool` + zod `inputSchema` |
| 5 | `sandbox/sandbox.ts` | Optional `defineSandbox` + `vercelSandboxBackend` |
| 6 | `channels/` | Slack, web, etc. via Connect Chat SDK |
| 7 | `connections/` | MCP/HTTP + `connect()` auth |
| 8 | `subagents/` | Child agents with own prompts/tools |
| 9 | `schedules/` | Cron markdown frontmatter — durable jobs |

## Scorecard skeleton

| Area | Grade | Evidence |
|------|-------|----------|
| Instructions clarity | ? | `instructions.md` — identity, boundaries, HITL |
| Tool contracts | ? | zod schemas; no secrets in tool bodies |
| Sandbox isolation | ? | default or `sandbox/sandbox.ts` |
| Channel coverage | ? | channels needed for prod (not CLI-only) |
| Connections auth | ? | Connect credentials, not raw tokens in repo |
| Durable workflows | ? | long-running steps use Workflows semantics |
| Human-in-the-loop | ? | approval gates for destructive tools |
| Evals | ? | suite + rubric on deploy |
| Docs / roadmap | ? | `coming-next.md` current |

## Typical SN backlog (customize)

1. **SN-1** Dogfood gate — `npx eve@latest` dev; one channel; no new tools
2. **SN-2** Harden `instructions.md` + one focused `skills/` playbook
3. **SN-3** Core `tools/` with zod + env-based API URLs
4. **SN-4** `sandbox/sandbox.ts` if bash/code execution is in scope
5. **SN-5** Primary `channels/` (web or Slack) + Connect credentials
6. **SN-6** `connections/` for external stack (GitHub, Linear, MCP)
7. **SN-7** Eval suite + deploy gate; optional `schedules/` for digests
8. **SN-8** Subagents only when main agent context is overloaded

## Guardrails (§6)

| Refuse | Build toward thrive |
|--------|---------------------|
| Monolithic prompt with all skills inlined | `skills/` loaded when relevant |
| Manual tool registration | file-per-tool in `tools/` |
| Long-lived tokens in repo | Vercel Connect `connections/` |
| Fire-and-forget side effects | Workflows + checkpointing |
| Single-channel lock-in | same agent dir → multi-channel |
| Destructive tools without HITL | approval gates; session parks until resolved |

## Key paths (mindmap seed)

`instructions.md` · `agent.ts` · `skills/` · `tools/` · `sandbox/` · `channels/` · `connections/` · `subagents/` · `schedules/` · `package.json` · `.github/workflows/`

## Verify commands (customize)

```bash
npx eve@latest init my-agent   # greenfield
# in project:
npm run build                  # if present
npm test                       # unit + tool tests
npx eve eval                   # or project eval script — run on deploy
```

**Expand full doc for:** per-tool file tables, channel credential names, gantt, monitoring (Workflows runs, sandbox health).

**Reference:** [vercel.com/eve](https://vercel.com/eve)
