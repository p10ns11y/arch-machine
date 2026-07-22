# External references (§13 pattern)

Copy into every stellar-roadmap document. Add project-specific rows at the top.

## Project-specific (customize per repo)

| Doc | Use |
|-----|-----|
| `{PLUGIN.md or boundary}` | Kernel must / must not |
| `{shell.md or arch doc}` | Implementation detail |
| `{VERIFICATION.md or product doc}` | Workflow verbs |
| `{risk or 10y analysis}` | Depth analysis; **§0b = thrive north star** |

### shellyxz example

| Doc | Use |
|-----|-----|
| [PLUGIN.md](https://github.com/p10ns11y/shellyxz.sh/blob/master/PLUGIN.md) | Kernel vs bridge boundary |
| [shell.md](https://github.com/p10ns11y/shellyxz.sh/blob/master/arch-design/shell.md) | PATH contract v2 |
| [VERIFICATION.md](https://github.com/p10ns11y/shellyxz.sh/blob/master/arch-design/VERIFICATION.md) | ab/av/at flows |
| [test-of-travelled-time-from-future.md](https://github.com/p10ns11y/shellyxz.sh/blob/master/arch-design/test-of-travelled-time-from-future.md) | Risk inventory; §0b supersedes tone |
| [coming-next.md](https://github.com/p10ns11y/shellyxz.sh/blob/master/arch-design/coming-next.md) | Canonical example output |

## Style sources (collab-finder — reuse across projects)

| Doc | URL | Use |
|-----|-----|-----|
| intuitive-shell-plan | https://github.com/p10ns11y/collab-finder/blob/main/reports/intuitive-shell-plan.md | Blueprint card format; dogfood gate first |
| batch-2-engineering-blueprints | https://github.com/p10ns11y/collab-finder/blob/main/reports/batch-2-engineering-blueprints.md | Scorecard grades; gantt; done-when tables |
| single-pr-intuitive-product | https://github.com/p10ns11y/collab-finder/blob/main/reports/single-pr-intuitive-product.md | Musk 5-step strict order; 2nd/3rd order guards |

## Companion skills (cross-link in §13 or header)

| Skill | Path |
|-------|------|
| stellar-roadmap | `{SKILLS_ROOT}/stellar-roadmap/SKILL.md` |
| ai-optimization | `{SKILLS_ROOT}/ai-optimization/SKILL.md` |
| fusion-sage | `{SKILLS_ROOT}/fusion-sage/SKILL.md` |
| higher-order-decision-architect | `{SKILLS_ROOT}/higher-order-decision-architect/SKILL.md` |
