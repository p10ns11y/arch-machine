// bin/tinfoil.go
package main

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
)

const version = "0.2.0-sentinel"

func main() {
	// TUI subcommand dispatch (Phase 3: shell+ gum TUI, zero extra Go deps)
	if len(os.Args) >= 2 && os.Args[1] == "tui" {
		tuiScript := findTuiScript()
		cmd := exec.Command("bash", tuiScript)
		cmd.Stdout = os.Stdout
		cmd.Stderr = os.Stderr
		cmd.Stdin = os.Stdin
		if err := cmd.Run(); err != nil {
			fmt.Fprintf(os.Stderr, "❌ tinfoil tui failed: %v\n", err)
			os.Exit(1)
		}
		return
	}

	fmt.Printf("🚀 tinfoil %s — The Good Sentinel is watching 👀🛡️\n\n", version)

	var mode, targetDir string

	if len(os.Args) == 1 {
		mode = "global"
		targetDir = os.Getenv("HOME")
	} else {
		mode = "project"
		targetDir = os.Args[1]
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

	// Smart script discovery: first look in installed location, then fallback to repo (dev mode)
	scriptPath := findScript("maintenance/security-audit.sh")

	cmd := exec.Command("bash", scriptPath)
	if mode == "global" {
		cmd.Args = append(cmd.Args, "--global")
	} else {
		cmd.Args = append(cmd.Args, "--project", targetDir)
	}

	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Stdin = os.Stdin

	if err := cmd.Run(); err != nil {
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

// findTuiScript locates the gum-powered interactive TUI (Phase 3)
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
	// 3. Fallback relative (when go run bin/tinfoil.go tui from root)
	if path := "lib/tui.sh"; fileExists(path) {
		return path
	}
	fmt.Fprintf(os.Stderr, "❌ Could not find lib/tui.sh — is the TUI installed?\n")
	os.Exit(1)
	return ""
}