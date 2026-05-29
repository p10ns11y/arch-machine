// bin/tinfoil.go
package main

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"

	"github.com/p10ns11y/arch-machine/cmd/tui"
	"github.com/spf13/cobra"
)

const version = "0.2.0-sentinel"

var rootCmd = &cobra.Command{
	Use:   "tinfoil [path]",
	Short: "The Good Sentinel security auditor",
	Long:  "tinfoil is a paranoid but practical security auditor for Arch Linux systems and projects.",
	Run:   runAudit,
}

var tuiCmd = &cobra.Command{
	Use:   "tui",
	Short: "Launch the interactive Bubble Tea TUI",
	Long:  "Starts the full graphical TUI (Go + Bubble Tea) for interactive profile selection, feature toggles, and flows.",
	RunE: func(cmd *cobra.Command, args []string) error {
		// Directly embed and run the Bubble Tea TUI (single binary, per TUI-SPEC)
		return tui.Run()
	},
}

func init() {
	rootCmd.AddCommand(tuiCmd)
}

func main() {
	if err := rootCmd.Execute(); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}

func runAudit(cmd *cobra.Command, args []string) {
	fmt.Printf("🚀 tinfoil %s — The Good Sentinel is watching 👀🛡️\n\n", version)

	var mode, targetDir string

	if len(args) == 0 {
		mode = "global"
		targetDir = os.Getenv("HOME")
	} else {
		mode = "project"
		targetDir = args[0]
		abs, err := filepath.Abs(targetDir)
		if err != nil {
			fmt.Fprintf(os.Stderr, "❌ Failed to resolve path: %v\n", err)
			os.Exit(1)
		}
		targetDir = abs

		info, err := os.Stat(targetDir)
		if err != nil || !info.IsDir() {
			fmt.Fprintf(os.Stderr, "❌ Not a directory: %s\n", targetDir)
			os.Exit(1)
		}
	}

	fmt.Printf("   Mode : %s\n   Target: %s\n\n", mode, targetDir)

	scriptPath := findScript("maintenance/security-audit.sh")

	auditCmd := exec.Command("bash", scriptPath)
	if mode == "global" {
		auditCmd.Args = append(auditCmd.Args, "--global")
	} else {
		auditCmd.Args = append(auditCmd.Args, "--project", targetDir)
	}

	auditCmd.Stdout = os.Stdout
	auditCmd.Stderr = os.Stderr
	auditCmd.Stdin = os.Stdin

	if err := auditCmd.Run(); err != nil {
		fmt.Fprintf(os.Stderr, "❌ tinfoil failed: %v\n", err)
		os.Exit(1)
	}
}



func findScript(scriptName string) string {
	// 1. Installed system location (after ./install.sh)
	if path := "/usr/share/tinfoil/" + scriptName; fileExists(path) {
		return path
	}
	// 2. Development mode (when running from repo)
	binDir := filepath.Dir(os.Args[0])
	if path := filepath.Join(binDir, "..", scriptName); fileExists(path) {
		return path
	}
	fmt.Fprintf(os.Stderr, "❌ Could not find %s\n", scriptName)
	os.Exit(1)
	return ""
}

func fileExists(path string) bool {
	_, err := os.Stat(path)
	return err == nil
}

// findTuiScript locates the legacy gum-powered interactive TUI (fallback only)
func findTuiScript() string {
	// 1. Installed system location
	if path := "/usr/share/tinfoil/lib/tui.sh"; fileExists(path) {
		return path
	}
	// 2. Dev mode from repo root (bin/.. /lib/tui.sh)
	binDir := filepath.Dir(os.Args[0])
	if path := filepath.Join(binDir, "..", "lib", "tui.sh"); fileExists(path) {
		return path
	}
	// 3. Fallback relative
	if path := "lib/tui.sh"; fileExists(path) {
		return path
	}
	fmt.Fprintf(os.Stderr, "❌ Could not find lib/tui.sh — is the TUI installed?\n")
	os.Exit(1)
	return ""
}