# TUI-SPEC.md — Detailed Specification for arch-machine TUI (Issue #7)
**Version**: 1.0  
**Language**: Go (Bubble Tea + Lip Gloss + Bubbles)  
**Integration**: Uses the new `tinfoil` CLI binary as backend  
**Tone**: Vigilant, humorous, self-aware ("tinfoil hat" energy) — confident and empowering rather than fear-based.

---

## 1. Core Philosophy
The TUI must make the "vigilant self-healing Arch fortress" **actually usable** by regular humans while keeping the over-the-top security personality.

Key goals from Issue #7:
- See what will be installed before committing
- Enable/disable profiles and individual modules/features
- Run different flows interactively: Installation, Security Audit, System Checks, Maintenance, Evidence Extraction
- Dry-run / preview mode everywhere
- Live feedback + beautiful logs

---

## 2. Recommended Tech Stack (Locked In)

- **Framework**: [Bubble Tea](https://github.com/charmbracelet/bubbletea) (MVU pattern)
- **Styling**: [Lip Gloss](https://github.com/charmbracelet/lipgloss)
- **Components**: [Bubbles](https://github.com/charmbracelet/bubbles) (list, spinner, progress, viewport, textinput)
- **CLI Framework** (for `tinfoil` binary): Cobra (already likely used in PR #3)
- **Config Parsing**: Use existing `yq` / `jq` or Go `viper` + YAML

**Why not shell TUI (gum/dialog)?**
- Go + Bubble Tea gives far superior UX, mouse support, resizing, live updates, and consistency with the `tinfoil` CLI.
- Single binary distribution remains trivial.

---

## 3. Binary Structure (Recommended)

After merging PR #3, the CLI should support:

```bash
tinfoil                    # Main CLI (existing)
tinfoil tui                # Launch the full interactive TUI
tinfoil install --dry-run  # Headless
tinfoil audit --profile security-dev
tinfoil maintenance
```

The TUI binary can be the same `tinfoil` with a `tui` subcommand (preferred for distribution simplicity).

---

## 4. Main Screens & User Flow

### Screen 0: Welcome / Dashboard (Vigilant Guardian Greeting)
```
╔══════════════════════════════════════════════════════════════╗
║  🛡️  arch-machine  •  Your AI-forged vigilant fortress      ║
║  "Because your ex isn't the only one auditing your life"    ║
╠══════════════════════════════════════════════════════════════╣
║  Status: Sentinel Active  |  Last Audit: 2h ago             ║
║  Current Profile: security-dev                              ║
╠══════════════════════════════════════════════════════════════╣
║  [i] Install / Reconfigure                                  ║
║  [a] Run Security Audit                                     ║
║  [c] System Check + Cleanup                                 ║
║  [m] Maintenance (Updates + Scans)                          ║
║  [e] Evidence Extraction (for AI agents)                    ║
║  [s] Settings & Profiles                                    ║
║  [q] Quit                                                   ║
╚══════════════════════════════════════════════════════════════╝
```

### Screen 1: Profile Selector
- Radio list: `minimal` | `ml-dev` | `security-dev`
- Shows short description + estimated install size + security level
- "Preview changes" button

### Screen 2: Feature Toggle Matrix (Most Important Screen)
Beautiful table with:
- Module / Feature name
- Description (from `config/`)
- Enabled/Disabled toggle (checkbox)
- Risk level (🟢 Safe / 🟡 Medium / 🔴 High Vigilance)
- Dependencies

Example:
```
┌─────────────────────────────────────────────────────────────────┐
│ Feature                          │ Status    │ Risk   │ Desc    │
├─────────────────────────────────────────────────────────────────┤
│ [x]  base-system                 │ Enabled   │ 🟢     │ Core... │
│ [x]  rocm-gpu                    │ Enabled   │ 🟡     │ AMD...  │
│ [ ]  kubernetes-hardening        │ Disabled  │ 🔴     │ K8s...  │
│ [x]  weekly-maintenance-timer    │ Enabled   │ 🟢     │ ...     │
└─────────────────────────────────────────────────────────────────┘
```

Controls: `space` = toggle, `enter` = confirm selection, `p` = preview install size

### Screen 3: Flow Runner (with Live View)
When user chooses a flow (e.g. "Install"):
- Shows selected profile + enabled features
- Dry-run toggle (default ON)
- Big "LAUNCH" button (red if not dry-run)
- Progress bar + live scrolling log viewport
- Real-time output from `tinfoil` subcommands or shell scripts
- Ability to cancel mid-flow

### Screen 4: Results / Evidence View
After flow completes:
- Summary (success / warnings / critical issues)
- "View full evidence bundle" button (opens `EVIDENCE-EXTRACTION.md` style output)
- "Apply changes" (if dry-run) or "Re-run with fixes"

---

## 5. Architecture (MVU Pattern)

```go
type model struct {
    state       string          // "welcome", "profile", "toggles", "running", "results"
    profile     string
    features    []Feature       // from config/
    selected    map[string]bool
    dryRun      bool
    progress    float64
    logViewport viewport.Model
    spinner     spinner.Model
    // ... other bubble components
}

func (m model) Init() tea.Cmd { ... }
func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) { ... }
func (m model) View() string { ... }
```

**Data Flow**:
1. TUI loads `config/profiles.yaml` + `config/modules/`
2. User makes selections
3. On "Launch" → TUI spawns `exec.Command("tinfoil", "install", "--profile", ..., "--features", ...)` or directly calls shell scripts with proper env
4. Streams stdout/stderr into the viewport in real time
5. On completion → parses output for summary

---

## 6. Key Implementation Details

### Config Loading
- Parse existing profile definitions (don't duplicate logic)
- Support both YAML and the current shell-based config

### Calling Backend
- Prefer calling the `tinfoil` binary (after PR #3 merge) for consistency
- Fall back to direct shell script execution when needed
- Always support `--dry-run` flag propagation

### Theming (Vigilant Guardian Style)
- Dark background with red/cyan accents
- Use `lipgloss` for borders, colors, and "tinfoil" ASCII art
- Subtle animations (spinner with tin foil hat emoji or similar)

### Error Handling
- Never let the TUI crash the system
- Always offer "Safe Mode" (dry-run + confirmation)
- On critical error → show "EVIDENCE LOG" and suggest remediation steps (tie into PR #4 policy)

### Keyboard Shortcuts (Consistent)
- `q` / `Ctrl+C` = Quit (with confirmation)
- `?` = Help overlay
- `tab` / `shift+tab` = Navigate sections
- `enter` = Select / Confirm

---

## 7. Development Order (for Autonomous Agent)

**Recommended micro-phases inside Phase 3**:

1. **Setup** (1h)
   - Add `go.mod` dependencies: `bubbletea`, `lipgloss`, `bubbles`, `cobra` (if not present)
   - Create `cmd/tui/` package

2. **Core Model + Welcome Screen** (2h)
   - Basic MVU skeleton + dashboard

3. **Profile + Feature Toggle Screens** (3h)
   - Load from `config/`
   - Beautiful table with checkboxes

4. **Flow Runner + Live Logs** (3h)
   - Progress + viewport streaming
   - Dry-run support

5. **Integration & Polish** (2h)
   - Wire up real `tinfoil` commands
   - Results screen + evidence view
   - Theming + keyboard shortcuts

6. **Testing + Docs** (1h)
   - Manual test all flows
   - Add TUI section to README

---

## 8. Success Criteria for TUI

- User can select profile + toggle 5+ features without touching terminal
- All 5 flows (Install, Audit, Check, Maintenance, Evidence) launch from TUI
- Dry-run works perfectly and shows exact diff
- Live logs are readable and beautiful
- Humorous tone is preserved ("This action will make your system 47% more vigilant")
- Binary size remains reasonable (<20MB)
- Works on both light and dark terminals

---

## 9. Future Extensions (After v1)

- Mouse support (Bubble Tea has it)
- Remote mode (run TUI on another machine, control this one)
- AI agent mode (auto-apply safe fixes using the remediation policy from PR #4)
- Export TUI session as evidence bundle

---

**This spec is now the single source of truth for the TUI.**

The autonomous agent should treat this document as mandatory reading before starting Phase 3.