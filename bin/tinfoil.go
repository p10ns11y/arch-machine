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
	args := os.Args[1:]

	if len(args) == 0 {
		printBannerAndHelp()
		return
	}

	switch args[0] {
	case "tui", "ui", "menu":
		// TUI subcommand dispatch (Phase 3: shell+ gum TUI, zero extra Go deps)
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

	case "audit", "scan", "check":
		// Explicit audit subcommand (the powerful non-interactive path)
		runAudit(args[1:])

	case "version", "--version", "-v":
		fmt.Printf("tinfoil %s\n", version)
		return

	case "help", "--help", "-h":
		printBannerAndHelp()
		return

	default:
		// Backward compat + convenience:
		//   tinfoil .          → audit current dir
		//   tinfoil /some/path → audit that dir
		//   tinfoil --anything → fall through to old implicit project/global
		if args[0] == "." || filepath.IsAbs(args[0]) || looksLikePath(args[0]) {
			runAudit(args)
			return
		}
		// Unknown subcommand
		fmt.Fprintf(os.Stderr, "Unknown command: %s\n\n", args[0])
		printBannerAndHelp()
		os.Exit(1)
	}
}

// looksLikePath is a heuristic so `tinfoil /foo` and `tinfoil .` still work like before
func looksLikePath(s string) bool {
	return len(s) > 0 && (s[0] == '.' || s[0] == '/' || s[0] == '~')
}

func printBannerAndHelp() {
	fmt.Printf("🚀 tinfoil %s — The Good Sentinel is watching 👀🛡️\n\n", version)
	fmt.Println("arch-machine's advanced sentinel tool for security audits, evidence,")
	fmt.Println("maintenance, and interactive control of the fortress.")
	fmt.Println()
	fmt.Println("USAGE:")
	fmt.Println("  tinfoil [command] [arguments]")
	fmt.Println()
	fmt.Println("COMMANDS:")
	fmt.Println("  tui, ui, menu     Launch the beautiful interactive TUI (recommended)")
	fmt.Println("  audit [path]      Run full security audit (global or on a directory)")
	fmt.Println("  version           Show version")
	fmt.Println("  help              Show this help")
	fmt.Println()
	fmt.Println("EXAMPLES:")
	fmt.Println("  tinfoil tui                    # Full interactive Sentinel experience")
	fmt.Println("  tinfoil                      # This help (no heavy work)")
	fmt.Println("  tinfoil audit                  # Global system audit")
	fmt.Println("  tinfoil audit .                # Audit current directory")
	fmt.Println("  tinfoil /path/to/project       # Audit specific folder (compat)")
	fmt.Println()
	fmt.Println("The TUI is the primary way to drive the advanced capabilities")
	fmt.Println("(profiles, policy remediation, evidence bundles, maintenance, etc.).")
	fmt.Println("The CLI gives you direct, scriptable access to the same power.")
	fmt.Println()
	fmt.Println("For the full developmental arena experience, start here:")
	fmt.Println("  tinfoil tui")
}

func runAudit(extraArgs []string) {
	fmt.Printf("🚀 tinfoil %s — The Good Sentinel is watching 👀🛡️\n\n", version)

	var mode, targetDir string

	if len(extraArgs) == 0 {
		mode = "global"
		targetDir = os.Getenv("HOME")
	} else {
		mode = "project"
		targetDir = extraArgs[0]
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