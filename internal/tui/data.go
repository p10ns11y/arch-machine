package tui

import "github.com/p10ns11y/arch-machine/config" // we'll improve loading

// Feature represents one toggleable item in the matrix (per TUI-SPEC Screen 2)
type Feature struct {
	Name         string
	Description  string
	Enabled      bool
	Risk         string // Safe / Medium / High Vigilance
	Dependencies []string
}

// Profile is loaded from config/profiles
type Profile struct {
	Name        string
	Description string
	Features    []Feature
}

// LoadProfiles returns available profiles (stub + real path for now)
func LoadProfiles() []Profile {
	// TODO: Real loading from config/profiles/*.yaml + tools.yaml
	// For now, rich demo data that matches the spirit of the project
	return []Profile{
		{
			Name:        "minimal",
			Description: "Basic development tools (git, python, node, rust)",
			Features: []Feature{
				{Name: "base-system", Description: "Core system packages", Enabled: true, Risk: "Safe", Dependencies: []string{}},
				{Name: "git", Description: "Version control", Enabled: true, Risk: "Safe", Dependencies: []string{}},
			},
		},
		{
			Name:        "ml-dev",
			Description: "ML/AI development with ROCm and Python tooling",
			Features: []Feature{
				{Name: "base-system", Description: "Core system packages", Enabled: true, Risk: "Safe", Dependencies: []string{}},
				{Name: "rocm-gpu", Description: "AMD ROCm for GPU acceleration", Enabled: true, Risk: "Medium", Dependencies: []string{"base-system"}},
				{Name: "python-ml", Description: "PyTorch, numpy, etc via conda", Enabled: true, Risk: "Medium", Dependencies: []string{"rocm-gpu"}},
				{Name: "weekly-maintenance-timer", Description: "Automated updates & scans", Enabled: true, Risk: "Safe", Dependencies: []string{}},
			},
		},
		{
			Name:        "security-dev",
			Description: "Maximum hardening + Kubernetes",
			Features: []Feature{
				{Name: "base-system", Description: "Core system packages", Enabled: true, Risk: "Safe", Dependencies: []string{}},
				{Name: "kubernetes-hardening", Description: "k3s + Cilium + Tetragon", Enabled: false, Risk: "High Vigilance", Dependencies: []string{"base-system"}},
				{Name: "security-auditing", Description: "Lynis, grype, osv-scanner, etc", Enabled: true, Risk: "Safe", Dependencies: []string{}},
				{Name: "evidence-extraction", Description: "Automated bundle generation", Enabled: true, Risk: "Safe", Dependencies: []string{}},
			},
		},
	}
}
