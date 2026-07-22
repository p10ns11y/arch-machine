# arch-machine 🛡️🦅

**The only Arch Linux setup that audits itself harder than your ex audits your text messages.**

Meet **arch-machine** — thin-first fortress, optional ML/security bloat, and a control plane that steers shell scripts instead of reimplementing `pacman` in three languages for sport.

For the boring (useful) docs: [README.md](README.md) · [docs/archy.md](docs/archy.md) · [docs/groxy.md](docs/groxy.md) · [tools/keeper/README.md](tools/keeper/README.md).

---

### The cast (current timeline)

| Character | Job | Personality |
|-----------|-----|-------------|
| **archy** | Main control plane (Ratatui Eagle loop) | Shows a menu, runs a script, points at **NEXT**. Does not invent package logic. |
| **Shell backends** | Iron peak (`maintenance/*.sh`, `install.sh`) | Do the real work. Evidence closes the loop. |
| **groxy** | Remote surfaces (`inject` + `acp serve`) | Host → XChat **notify**, or ACP **control**. Phone DMs do **not** magically pick which of your three Grok windows is “it.” |
| **keeper** | Threshold vault (`tools/keeper`) | Any **2 of 3** (passphrase · offline escrow · device). `healthy` means you drilled once — not “vault is open, party.” |
| **Grok plugin** | Complex orchestration (`/arch-*`) | Agent-side slash commands. archy can also launch Grok with a preload. |
| **gum / tinfoil Go** | Legacy / thin shim | Still in the basement. Do not cast them as the hero in trailers. |
| **eye-comfort** | Circadian themes (Omarchy) | Soft cream days, warm umber nights. Your retinas file a thank-you note. |

```text
  keys → Msg → Eagle update → Cmd → shell satellite
                 (archy)

  ACP client ──► grok agent serve     ✅ control
  inject ──────► XChat notify         ✅ outbound only
  ambient DM ──► “which Grok?”        ❌ not productized
```

---

### Branch Philosophy – No Boring Feature Branches Allowed (mostly)

We don’t *aspire* to lame `feature/xyz` branches.  
Instead, every **named** branch is a **virtuous compound-word sentinel**. Each one has a distinct purpose and vibe, like elite AI security operatives standing guard over different aspects of the project.

![sentinels](/sentinels-ultimate-masters.jpg)

| Compound word | Breakdown                          | Vibe / Fit                              |
|---------------|------------------------------------|-----------------------------------------|
| **Virtinel**  | virtue + sentinel                  | Best overall – trustworthy guardian     |
| **Eusinel**   | eu- (Greek “good/well”) + sentinel | Elegant, positive, slightly futuristic  |
| **Safinel**   | safe + sentinel                    | Direct “secure guardian” feel           |
| **Guardwell** | guard + well (good/well)           | Simple, reassuring                      |
| **Trusinel**  | true + sentinel                    | Emphasizes reliability                  |

| Branch       | Concrete Situation                                                                 | What It Solves                                      |
|--------------|------------------------------------------------------------------------------------|-----------------------------------------------------|
| **Sentinel** | The one true default/protected branch (was `main`/`master` in the beginning)     | **The core fortress**. Stable, production-ready merges live here. Clone this and sleep. |
| **Virtinel** | Daily driver dev machine, normal work, merging stable improvements                | Balanced guardian — everyday security + monitoring stack |
| **Eusinel**  | Experimenting with AI dashboards, eye-comfort phases, or next-gen ML security     | Elegant, slightly futuristic without torching the core |
| **Safinel**  | High-security host, sensitive data, maximum hardening cosplay                    | Strongest guardian mode |
| **Guardwell**| Onboarding, docs, minimal/clean setup for humans who don’t dream in YAML         | Approachable fortress tour |
| **Trusinel** | Long-term stable / “please don’t break CI for six months”                        | Reliability cosplay for uptime cultists |

**Rule (aspirational):** These six are the Justice League. **`Sentinel`** is home base.  
**Reality check (2026):** Agents sometimes open `feat/…` and `fix/…` branches anyway — then we merge the good bits back to **Sentinel** and pretend the temporary names never happened. Classic `main`/`master` remain **genesis fossils**.

---

### What the machine actually does (in dramatic terms)

- **Bootstraps thin** — `./install.sh` (default `--thin`) drops runtime under `/usr/share/tinfoil/` without inviting the entire AUR to brunch.
- **Steers with archy** — menu → shell job → stdio drama → **NEXT** bar. Inventory, catalog, Omarchy status, audit, evidence: all scripts, one Eagle.
- **Hardens** like it owes the NSA money (Lynis, rkhunter, ClamAV, Grype… when you expand security — not on day-1 thin).
- **Profiles** — `minimal` / `ml-dev` / `security-dev` because your LLM deserves ROCm *and* your secrets deserve a drill-proven vault.
- **Evidence** — JSON/TOON bundles so “we fixed it” can testify in court (or at least in the next archy session).
- **Remote, honestly** — **groxy inject** texts you status; **ACP** controls an agent; **no** ambient “phone DM → focused Grok window” magic.
- **Keeper** — one passphrase, one offline escrow file, this device free. Lose two of three and the universe is silent. That is intentional.

### Tagline options (pick your poison)

- “Arch Linux, but it has trust issues and a Ratatui clearance.”
- “We turned ‘rolling release’ into ‘rolling evidence bundle’.”
- “Sentinels don’t sleep. Neither does the weekly timer.”
- “archy steers. Shell works. groxy notifies. keeper forgets nothing you can still prove.”
- “Omarchy-friendly. Multi-distro fantasies sold separately.”

**Warning:** May cause sudden feelings of superiority over Ubuntu users. Side effects include obsessive `security-audit.sh` runs at 2 a.m., naming your cat “Virtinel”, and arguing with agents about whether gum is “legacy” or “heritage.”

Star it. Fork it. Let **archy** watch the iron peak.  
(Just don’t ask **groxy** to mind-read your XChat into three open TUIs — it will refuse, correctly.)
