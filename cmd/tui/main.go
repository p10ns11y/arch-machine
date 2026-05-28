package main

import (
	"fmt"
	"os"

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
