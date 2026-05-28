package main

import (
	"fmt"
	"os"
	"strings"
	"time"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/bubbles/list"
	"github.com/charmbracelet/lipgloss"
)

// Model follows the architecture in TUI-SPEC.md (Section 5)
type model struct {
	state    string // "welcome", "profile", "toggles", "running", "results"
	list     list.Model
	profile  string
	quitting bool
}

var (
	titleStyle = lipgloss.NewStyle().
			Bold(true).
			Foreground(lipgloss.Color("63")).
			MarginLeft(2)

	itemStyle = lipgloss.NewStyle().PaddingLeft(4)
)

func initialModel() model {
	return model{
		state: "welcome",
		list:  welcomeList(),
	}
}

func welcomeList() list.Model {
	items := []list.Item{
		item{title: "[i] Install / Reconfigure", desc: "Profile-based installation with dry-run"},
		item{title: "[a] Run Security Audit", desc: "Full system + dependency audit"},
		item{title: "[c] System Check + Cleanup", desc: "Remediation policy guided"},
		item{title: "[m] Maintenance (Updates + Scans)", desc: "Weekly timers and evidence"},
		item{title: "[e] Evidence Extraction", desc: "For AI agents and audits"},
		item{title: "[s] Settings & Profiles", desc: "minimal / ml-dev / security-dev"},
		item{title: "[q] Quit", desc: "The Sentinel is always watching"},
	}

	l := list.New(items, list.NewDefaultDelegate(), 70, 16)
	l.Title = "🛡️  arch-machine  •  Your AI-forged vigilant fortress"
	l.SetShowStatusBar(false)
	l.SetFilteringEnabled(false)
	l.Styles.Title = titleStyle
	return l
}

func profileList() list.Model {
	items := []list.Item{
		item{title: "minimal", desc: "Basic development tools"},
		item{title: "ml-dev", desc: "ML/AI + ROCm (recommended)"},
		item{title: "security-dev", desc: "Maximum hardening + Kubernetes"},
	}

	l := list.New(items, list.NewDefaultDelegate(), 70, 10)
	l.Title = "Select Profile (per TUI-SPEC)"
	l.SetShowStatusBar(false)
	l.SetFilteringEnabled(false)
	return l
}

type item struct {
	title, desc string
}

func (i item) Title() string       { return i.title }
func (i item) Description() string { return i.desc }
func (i item) FilterValue() string { return i.title }

func (m model) Init() tea.Cmd {
	return nil
}

func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.KeyMsg:
		switch msg.String() {
		case "ctrl+c", "q":
			m.quitting = true
			return m, tea.Quit
		case "enter":
			selected := m.list.SelectedItem()
			if selected != nil {
				title := selected.(item).title
				switch {
				case title == "[i] Install / Reconfigure":
					m.state = "profile"
					m.list = profileList()
					return m, nil
				default:
					// Placeholder for other flows
					fmt.Printf("\n[Selected: %s] — full implementation per TUI-SPEC in progress\n", title)
					return m, tea.Quit
				}
			}
		case "esc":
			if m.state == "profile" {
				m.state = "welcome"
				m.list = welcomeList()
				return m, nil
			}
		}
	}

	var cmd tea.Cmd
	m.list, cmd = m.list.Update(msg)
	return m, cmd
}

func (m model) View() string {
	if m.quitting {
		return "The Sentinel is always watching... 🛡️\n"
	}

	switch m.state {
	case "welcome":
		return "\n" + m.list.View() + "\n(Enter to select • q to quit)\n"
	case "profile":
		return "\n" + m.list.View() + "\n(Enter to choose profile • Esc to go back)\n"
	default:
		return "\n" + m.list.View() + "\n"
	}
}

func main() {
	p := tea.NewProgram(initialModel())
	if _, err := p.Run(); err != nil {
		fmt.Printf("Error running TUI: %v\n", err)
		os.Exit(1)
	}
}

// FeatureToggleModel - Screen 2 per TUI-SPEC (Most Important Screen)
type featureToggleModel struct {
	features []FeatureItem
	cursor   int
	profile  string
}

type FeatureItem struct {
	Name    string
	Desc    string
	Enabled bool
	Risk    string
}

func newFeatureToggleModel(profile string) featureToggleModel {
	// Rich demo data matching project spirit (real YAML loading coming)
	feats := []FeatureItem{
		{Name: "base-system", Desc: "Core system packages", Enabled: true, Risk: "Safe"},
		{Name: "rocm-gpu", Desc: "AMD ROCm GPU acceleration", Enabled: true, Risk: "Medium"},
		{Name: "python-ml", Desc: "PyTorch + data science stack", Enabled: true, Risk: "Medium"},
		{Name: "kubernetes-hardening", Desc: "k3s + Cilium + Tetragon", Enabled: false, Risk: "High Vigilance"},
		{Name: "weekly-maintenance-timer", Desc: "Automated security + updates", Enabled: true, Risk: "Safe"},
	}
	return featureToggleModel{features: feats, profile: profile}
}

func (m featureToggleModel) Init() tea.Cmd { return nil }

func (m featureToggleModel) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.KeyMsg:
		switch msg.String() {
		case "ctrl+c", "q":
			return m, tea.Quit
		case "up", "k":
			if m.cursor > 0 {
				m.cursor--
			}
		case "down", "j":
			if m.cursor < len(m.features)-1 {
				m.cursor++
			}
		case " ":
			m.features[m.cursor].Enabled = !m.features[m.cursor].Enabled
		case "enter":
			// Proceed to Flow Runner (stub for now)
			return newFlowRunnerModel(m.profile, m.features), nil
		case "esc":
			// Go back to profile selector
			return initialModel(), nil
		}
	}
	return m, nil
}

func (m featureToggleModel) View() string {
	s := lipgloss.NewStyle().Bold(true).Render("Feature Toggle Matrix — " + m.profile) + "\n"
	s += "space: toggle • enter: launch • esc: back\n\n"

	for i, f := range m.features {
		cursor := "  "
		if i == m.cursor {
			cursor = "▶ "
		}
		check := "[ ]"
		if f.Enabled {
			check = "[x]"
		}
		riskColor := "241"
		if f.Risk == "Medium" {
			riskColor = "214"
		} else if f.Risk == "High Vigilance" {
			riskColor = "196"
		}
		line := cursor + check + " " + f.Name + "  " +
			lipgloss.NewStyle().Foreground(lipgloss.Color(riskColor)).Render(f.Risk) + "\n    " + f.Desc
		s += line + "\n"
	}
	s += "\n(p = preview size — not yet wired)"
	return s
}

// Very basic Flow Runner stub (Screen 3)
type flowRunnerModel struct {
	profile  string
	features []FeatureItem
	progress float64
	done     bool
}

func newFlowRunnerModel(profile string, features []FeatureItem) flowRunnerModel {
	return flowRunnerModel{profile: profile, features: features}
}

func (m flowRunnerModel) Init() tea.Cmd {
	return nil
}

func (m flowRunnerModel) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.KeyMsg:
		if msg.String() == "q" || msg.String() == "ctrl+c" {
			return m, tea.Quit
		}
		if m.done && msg.String() == "enter" {
			return initialModel(), nil
		}
	}
	// Fake progress
	if !m.done {
		m.progress += 0.08
		if m.progress >= 1.0 {
			m.done = true
		}
		return m, tea.Tick(120, func(t time.Time) tea.Msg { return t }) // simple animation
	}
	return m, nil
}

func (m flowRunnerModel) View() string {
	s := "🚀 Running flow for " + m.profile + "\n\n"
	bar := int(m.progress * 40)
	s += "[" + strings.Repeat("█", bar) + strings.Repeat("░", 40-bar) + "]\n"
	if m.done {
		s += "\n✅ Flow complete (simulated per TUI-SPEC)\nPress enter to return to menu"
	}
	return s
}
