// bin/tinfoil.go
package main

import (
	"fmt"
	"os"
	"os/exec"
	"os/signal"
	"path/filepath"
	"syscall"
)

const version = "0.2.0-sentinel"

func main() {
	args := os.Args[1:]

	// Set up graceful signal handling so tinfoil never feels like a hard system exit
	setupGracefulExit()

	if len(args) == 0 {
		printBannerAndHelp()
		printGoodbye()
		return
	}

	switch args[0] {
	case "tui", "ui", "menu":
		// Prefer Ratatui control plane (entry + loop); gum is legacy fallback.
		if runRustTui(args[1:]) {
			printGoodbye()
			return
		}
		// Legacy: shell + gum TUI
		tuiScript := findTuiScript()
		cmd := exec.Command("bash", tuiScript)
		cmd.Stdout = os.Stdout
		cmd.Stderr = os.Stderr
		cmd.Stdin = os.Stdin

		err := cmd.Run()

		if err != nil {
			// Distinguish real failures from user-initiated graceful exits.
			// gum (and many interactive tools) exit with code 1 on Esc/Cancel.
			// We do NOT want to print a scary "failed" message for that.
			if exitErr, ok := err.(*exec.ExitError); ok {
				code := exitErr.ExitCode()
				// Acceptable "user exit" codes:
				// 0  = clean exit
				// 1  = common for gum cancel/Esc
				// 130 = SIGINT (Ctrl+C)
				if code == 0 || code == 1 || code == 130 {
					printGoodbye()
					return
				}
			}

			// Real failure (script not found, permission denied, crash, etc.)
			fmt.Fprintf(os.Stderr, "❌ tinfoil tui failed: %v\n", err)
			printGoodbye()
			os.Exit(1)
		}

		printGoodbye()
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

	case "vault":
		handleVault(args[1:])

	case "install":
		handleInstall(args[1:])

	case "inventory", "inv", "list-tools":
		// Surface-agnostic inventory (shell backend). Preferred over growing Go.
		// Future: Grok plugin + Rust TUI call maintenance/inventory.sh directly.
		handleInventory(args[1:])

	case "search", "catalog":
		// SN-CAT-1: searchable tools.yaml + profile catalog (read-only shell backend).
		handleShellScript("maintenance/catalog.sh", "catalog", args[1:])

	case "pkg", "actuate":
		// SN-INV-2: consent-gated update/remove (dry-run default).
		handleShellScript("maintenance/package-actuate.sh", "pkg", args[1:])

	case "omarchy", "omarchy-status":
		// SN-OM-1: read-only Omarchy host status (official omarchy CLI when present).
		handleShellScript("maintenance/omarchy-status.sh", "omarchy", args[1:])

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
	fmt.Println("  inventory, inv    List installed packages/tools (JSON snapshot; read-only)")
	fmt.Println("  search, catalog   Search tools.yaml + profiles (read-only catalog)")
	fmt.Println("  pkg, actuate      Update/remove packages (dry-run default; refuse-list)")
	fmt.Println("  omarchy           Omarchy host status (version/theme/pkg probes; read-only)")
	fmt.Println("  audit [path]      Run full security audit (global or on a directory)")
	fmt.Println("  install           Perform profiled installation (equivalent to ./install.sh)")
	fmt.Println("  vault setup|mount [enc_dir] [mount_point]   Manage encrypted gocryptfs vault")
	fmt.Println("  tui, ui, menu     Ratatui control plane (archy) or gum fallback")
	fmt.Println("  version           Show version")
	fmt.Println("  help              Show this help")
	fmt.Println()
	fmt.Println("EXAMPLES:")
	fmt.Println("  tinfoil inventory              # Explicit pkgs + tools.yaml + mise + upgrades")
	fmt.Println("  tinfoil inventory --json       # Agent-ready JSON on stdout")
	fmt.Println("  tinfoil search docker          # Catalog: which tool + profiles")
	fmt.Println("  tinfoil omarchy                # Omarchy version/theme/update (read-only)")
	fmt.Println("  tinfoil pkg --update jq        # Dry-run plan (default)")
	fmt.Println("  tinfoil audit .                # Audit current directory")
	fmt.Println("  tinfoil install --profile ml-dev --dry-run")
	fmt.Println("  tinfoil vault setup")
	fmt.Println()
	fmt.Println("Control plane: Ratatui archy (entry + loop) steers shell/Go backends.")
	fmt.Println("  tinfoil tui                # prefers archy binary, else gum")
	fmt.Println("  docs/omarchy.md            # Day-1 Omarchy + arch-machine playbook")
	fmt.Println("  docs/omarchy-commands.md   # Full Omarchy CLI reference")
	fmt.Println("  /arch-status /arch-audit   # Grok agent-as-TUI when plugin installed")
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

	// Discover Node.js package managers from the caller's real environment.
	// This is crucial when `tinfoil` is invoked under sudo or in restricted PATHs.
	// The shell script can then use these full paths instead of guessing.
	// Pass context so downstream scripts (logger, evidence, reports) know where to write artifacts.
	// This makes "tinfoil audit /some/project" write logs inside that project instead of global tinfoil dirs.
	env := os.Environ()
	env = append(env,
		"TINFOIL_PNPM="+findTool("pnpm"),
		"TINFOIL_YARN="+findTool("yarn"),
		"TINFOIL_NPM="+findTool("npm"),
		"TINFOIL_MODE="+mode,
	)
	if mode == "project" {
		env = append(env, "TINFOIL_TARGET_DIR="+targetDir)
	}
	cmd.Env = env

	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Stdin = os.Stdin

	if err := cmd.Run(); err != nil {
		if exitErr, ok := err.(*exec.ExitError); ok {
			code := exitErr.ExitCode()
			if code == 0 || code == 1 || code == 130 {
				printGoodbye()
				return
			}
		}
		fmt.Fprintf(os.Stderr, "❌ tinfoil failed: %v\n", err)
		printGoodbye()
		os.Exit(1)
	}
	printGoodbye()
}

// findTool returns the full path to a tool using the current process's PATH.
// This is the reliable way for `tinfoil` (the Go entrypoint) to discover
// pnpm/yarn/npm even when later parts of the audit run under sudo.
func findTool(name string) string {
	if p, err := exec.LookPath(name); err == nil {
		return p
	}
	return ""
}

func findScript(scriptName string) string {
	// 1. Installed system location (after ./install.sh)
	if path := "/usr/share/tinfoil/" + scriptName; fileExists(path) {
		return path
	}
	// 2. Explicit root overrides (agent / Rust TUI / packaging)
	for _, env := range []string{"TINFOIL_ROOT", "ARCH_MACHINE_ROOT"} {
		if root := os.Getenv(env); root != "" {
			if path := filepath.Join(root, scriptName); fileExists(path) {
				return path
			}
		}
	}
	// 3. Development mode: binary next to repo (…/bin/tinfoil → …/script)
	binDir := filepath.Dir(os.Args[0])
	if abs, err := filepath.Abs(binDir); err == nil {
		if path := filepath.Join(abs, "..", scriptName); fileExists(path) {
			return path
		}
	}
	// 4. Cwd is repo root (common: go build -o /tmp/tinfoil && run from repo)
	if path := scriptName; fileExists(path) {
		return path
	}
	if wd, err := os.Getwd(); err == nil {
		if path := filepath.Join(wd, scriptName); fileExists(path) {
			return path
		}
	}
	fmt.Fprintf(os.Stderr, "❌ Could not find %s\n", scriptName)
	fmt.Fprintf(os.Stderr, "   Set TINFOIL_ROOT or ARCH_MACHINE_ROOT, or run from the arch-machine repo.\n")
	os.Exit(1)
	return ""
}

func fileExists(path string) bool {
	_, err := os.Stat(path)
	return err == nil
}

// runRustTui execs archy when available (Ratatui control plane / loop controller).
// Returns true if it handled the request (found and ran, or ran with error exit).
func runRustTui(extra []string) bool {
	candidates := []string{}
	if p, err := exec.LookPath("archy"); err == nil {
		candidates = append(candidates, p)
	}
	// Dev builds relative to repo / this binary
	binDir := filepath.Dir(os.Args[0])
	for _, rel := range []string{
		filepath.Join(binDir, "archy"),
		filepath.Join(binDir, "..", "crates", "archy", "target", "release", "archy"),
		filepath.Join(binDir, "..", "crates", "archy", "target", "debug", "archy"),
		"tools/archy/target/release/archy",
		"tools/archy/target/debug/archy",
	} {
		if fileExists(rel) {
			if abs, err := filepath.Abs(rel); err == nil {
				candidates = append(candidates, abs)
			} else {
				candidates = append(candidates, rel)
			}
		}
	}
	if len(candidates) == 0 {
		return false
	}
	bin := candidates[0]
	cmd := exec.Command(bin, extra...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Stdin = os.Stdin
	env := os.Environ()
	// Ensure backends resolve
	if root := os.Getenv("TINFOIL_ROOT"); root == "" {
		if wd, err := os.Getwd(); err == nil {
			env = append(env, "TINFOIL_ROOT="+wd)
		}
	}
	cmd.Env = env
	if err := cmd.Run(); err != nil {
		if exitErr, ok := err.(*exec.ExitError); ok {
			code := exitErr.ExitCode()
			if code == 0 || code == 1 || code == 130 {
				return true
			}
		}
		fmt.Fprintf(os.Stderr, "❌ archy failed: %v (falling back to gum if available)\n", err)
		return false
	}
	return true
}

// findTuiScript locates the gum-powered interactive TUI (Phase 3, legacy)
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

// handleVault dispatches vault-related commands.
// It reuses the existing setup_encrypted_vault function from the security module.
func handleVault(args []string) {
	if len(args) == 0 {
		fmt.Println("Usage:")
		fmt.Println("  tinfoil vault setup [enc_dir] [mount_point]")
		fmt.Println("  tinfoil vault mount [enc_dir] [mount_point]")
		fmt.Println("")
		fmt.Println("Examples:")
		fmt.Println("  tinfoil vault setup")
		fmt.Println("  tinfoil vault setup ~/.myvault ~/myvault")
		fmt.Println("  tinfoil vault mount ~/.securevaultenc ~/securevault")
		return
	}

	subcommand := args[0]
	rest := args[1:]

	securityScript := findScript("modules/security/install.sh")

	// We source the module and call the appropriate function.
	// setup_encrypted_vault already handles both init + mount intelligently.
	var bashCmd string
	switch subcommand {
	case "setup":
		// Call the full setup (init if needed + mount)
		bashCmd = fmt.Sprintf(`source %q 2>/dev/null || true; setup_encrypted_vault %s`,
			securityScript, shellJoin(rest))
	case "mount":
		// For a pure mount we still delegate to the same function for now
		// (it gracefully handles "already initialized" case).
		// Future: we could add a lighter mount-only path.
		bashCmd = fmt.Sprintf(`source %q 2>/dev/null || true; setup_encrypted_vault %s`,
			securityScript, shellJoin(rest))
	default:
		fmt.Fprintf(os.Stderr, "Unknown vault subcommand: %s\n", subcommand)
		fmt.Println("Valid subcommands: setup, mount")
		os.Exit(1)
	}

	cmd := exec.Command("bash", "-c", bashCmd)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Stdin = os.Stdin

	if err := cmd.Run(); err != nil {
		if exitErr, ok := err.(*exec.ExitError); ok {
			code := exitErr.ExitCode()
			if code == 0 || code == 1 || code == 130 {
				printGoodbye()
				return
			}
		}
		fmt.Fprintf(os.Stderr, "❌ tinfoil vault %s failed: %v\n", subcommand, err)
		printGoodbye()
		os.Exit(1)
	}
	printGoodbye()
}

// shellJoin naively joins arguments for passing into bash -c.
// For production use we would use proper shell escaping, but this is sufficient
// for the common case of paths without special characters.
func shellJoin(args []string) string {
	if len(args) == 0 {
		return ""
	}
	out := ""
	for i, a := range args {
		if i > 0 {
			out += " "
		}
		out += fmt.Sprintf("%q", a)
	}
	return out
}

// setupGracefulExit registers signal handlers so that Ctrl+C or other
// termination signals result in a warm goodbye instead of an abrupt crash.
func setupGracefulExit() {
	c := make(chan os.Signal, 1)
	signal.Notify(c, os.Interrupt, syscall.SIGTERM)

	go func() {
		<-c
		fmt.Println()
		printGoodbye()
		os.Exit(0)
	}()
}

// printGoodbye prints a consistent, warm closing message for any exit path.
func printGoodbye() {
	fmt.Println()
	fmt.Println("👋  The Good Sentinel tips its hat.")
	fmt.Println("Thank you for keeping the machines honest today.")
	fmt.Println("The fortress stands stronger because of your vigilance.")
	fmt.Println()
	fmt.Println("Stay sharp. The Sentinel is always watching. 🛡️")
}

// handleInventory dispatches to maintenance/inventory.sh (read-only).
// Complex UI lives outside Go (Grok plugin / archy).
func handleInventory(args []string) {
	handleShellScript("maintenance/inventory.sh", "inventory", args)
}

// handleShellScript runs a repo maintenance/*.sh backend with args (thin dispatch only).
func handleShellScript(relPath, label string, args []string) {
	scriptPath := findScript(relPath)
	cmd := exec.Command("bash", scriptPath)
	cmd.Args = append(cmd.Args, args...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Stdin = os.Stdin
	cmd.Env = os.Environ()

	if err := cmd.Run(); err != nil {
		if exitErr, ok := err.(*exec.ExitError); ok {
			code := exitErr.ExitCode()
			if code == 0 || code == 1 || code == 130 {
				return
			}
			os.Exit(code)
		}
		fmt.Fprintf(os.Stderr, "❌ tinfoil %s failed: %v\n", label, err)
		os.Exit(1)
	}
}

// handleInstall allows the tinfoil CLI to perform full profiled installations
// exactly like ./install.sh (including all modules, tools, security profiles, etc.).
// Example: tinfoil install --profile security-dev --dry-run
func handleInstall(args []string) {
	if len(args) == 0 {
		fmt.Println("Usage: tinfoil install [options]")
		fmt.Println("")
		fmt.Println("This is equivalent to running ./install.sh with the same arguments.")
		fmt.Println("")
		fmt.Println("Common options:")
		fmt.Println("  --profile <name>     Install using a profile (minimal, ml-dev, security-dev)")
		fmt.Println("  --dry-run            Show what would be done")
		fmt.Println("  --verbose            Enable verbose logging")
		fmt.Println("  --list-profiles      List available profiles")
		fmt.Println("")
		fmt.Println("Examples:")
		fmt.Println("  tinfoil install --profile ml-dev")
		fmt.Println("  tinfoil install --profile security-dev --dry-run")
		fmt.Println("  tinfoil install --list-profiles")
		return
	}

	installerScript := findScript("install.sh")

	cmd := exec.Command("bash", installerScript)
	cmd.Args = append(cmd.Args, args...)

	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Stdin = os.Stdin

	// Pass through relevant environment (TINFOIL_* vars, etc.)
	cmd.Env = os.Environ()

	if err := cmd.Run(); err != nil {
		if exitErr, ok := err.(*exec.ExitError); ok {
			code := exitErr.ExitCode()
			if code == 0 || code == 1 || code == 130 {
				printGoodbye()
				return
			}
		}
		fmt.Fprintf(os.Stderr, "❌ tinfoil install failed: %v\n", err)
		printGoodbye()
		os.Exit(1)
	}
	printGoodbye()
}