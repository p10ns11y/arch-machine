# Stellar Roadmap — Document template (copy into target file)

Replace `{PROJECT}`, `{DATE}`, links, and bracketed placeholders.

```markdown
# Coming next — {PROJECT}

**Audience:** You · implementer · agents  
**Style:** Short words. Diagrams over prose. Optimism grounded in evidence.  
**Contract:** [{boundary-doc}]({path}) · [{risk-doc-if-any}]({path})  
**Method:** [stellar-roadmap skill]({SKILLS_ROOT}/stellar-roadmap/SKILL.md) · collab-finder blueprint style

*Last updated: {DATE}*

---

## 0. Mission (one sentence)

{One sentence: thrive through platform shifts; kernel + evolving bridge/product.}

---

## 0b. Ten-year thrive picture ({YEAR} — not survival, ascent)

{One line: why tailwinds matter.}

```mermaid
flowchart TB
  subgraph kernelY["Kernel — ship computer"]
    K1[core capability]
  end
  subgraph bridgeY["Product bridge — command ops"]
    B1[protocol or manifest]
    B2[host adapters: tmux IDE CI MCP]
  end
  subgraph weather["Cosmic weather we punch through"]
    W1[vendor churn]
    W2[platform shift]
  end
  weather --> kernelY
  kernelY --> bridgeY
  bridgeY --> OUT[Human judgment before launch]
```

| {YEAR} role | What it is | Why it still wins |
|-------------|------------|-------------------|
| **Kernel** | | |
| **Bridge** | | |
| **Boundary** | | |

**Design bet:** {What you are betting on forever vs what is today's renderer.}

---

## 1. Scorecard — what landed ({milestone})

```mermaid
flowchart LR
  subgraph shipped["Shipped A"]
    ...
  end
  subgraph open["Next altitude B/C"]
    ...
  end
  shipped --> open
```

| Area | Grade | One line | Evidence |
|------|-------|----------|----------|
| | | | |

**Plain rule:** {one line}

---

## 2. System map (today)

```mermaid
flowchart TB
  ...
```

---

## 3. {Precedence / data-flow title}

```mermaid
sequenceDiagram
  ...
```

| Layer | Owns | Must not |
|-------|------|----------|

---

## 4. Musk five-step — applied to backlog

| Step | Question | Verdict |
|------|----------|---------|

---

## 5. Trajectory forces (evidence-weighted)

| Force | P(horizon) | Effect on us | Response |
|-------|------------|--------------|----------|

**Acceleration trigger:** {when to invest more, not shrink}

---

## 6. Trajectory guardrails

```mermaid
flowchart TD
  subgraph avoid["Refuse — drag"]
  end
  subgraph build["Build toward {YEAR}"]
  end
```

| Risk | Guard | Status |

---

## 7. Blueprint cards — next work

### SN-1 · Dogfood gate (no new code)

**Problem:** ...

| Step | Pass if |
|------|---------|

### SN-N · {Title}

**Problem:** ...

```mermaid
...
```

| File | Work |
|------|------|

**Done when:** ...

**Verify:** ...

---

## 8. Scope lock (user decision)

```mermaid
flowchart LR
  ...
```

---

## 9. Sprint order

```mermaid
gantt
  title Backlog order
  dateFormat YYYY-MM-DD
  ...
```

---

## 10. Monitoring signals (command the mission)

| Signal | Healthy | Invest more when |
|--------|---------|------------------|

---

## 11. Done log ({milestone})

| # | Item | Area |

---

## 12. File touch map

```mermaid
mindmap
  root((Coming next))
  ...
```

---

## 13. References

| Doc | Use |
|-----|-----|
| {project boundary} | |
| {architecture depth} | |
| [intuitive-shell-plan](https://github.com/p10ns11y/collab-finder/blob/main/reports/intuitive-shell-plan.md) | Blueprint cards |
| [batch-2-blueprints](https://github.com/p10ns11y/collab-finder/blob/main/reports/batch-2-engineering-blueprints.md) | Scorecard, gantt |
| [single-pr-intuitive-product](https://github.com/p10ns11y/collab-finder/blob/main/reports/single-pr-intuitive-product.md) | Musk 5-step, 2nd/3rd order |
| [stellar-roadmap SKILL]({SKILLS_ROOT}/stellar-roadmap/SKILL.md) | This doc format |

---

*Plain rule: {footer}*
```
