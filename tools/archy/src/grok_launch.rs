//! Build argv for launching host `grok` with a **preloaded** interactive prompt.
//!
//! Research (host `grok --help`):
//! - Interactive multi-turn: `grok [OPTIONS] [PROMPT]` — PROMPT seeds the session.
//! - Headless one-shot: `grok -p` / `--prompt-file` — **not** the default co-pilot path.
//! - ACP server: `grok agent stdio` — needs a client; archy does not embed ACP yet.
//!
//! Default operator path: suspend TUI → interactive `grok --cwd <root> "<composed>"`.

use std::path::{Path, PathBuf};
use std::process::Command;

/// How to launch Grok for archy co-pilot.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum GrokLaunchMode {
    /// Multi-turn interactive TUI with initial PROMPT (preferred).
    Interactive,
    /// Single-turn print-and-exit (`-p`) — scripts / fallback only.
    SingleTurn,
}

/// Pure launch plan (testable without spawning).
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct GrokLaunchPlan {
    pub program: PathBuf,
    pub args: Vec<String>,
    pub cwd: PathBuf,
    pub env: Vec<(String, String)>,
    /// Full text passed as interactive PROMPT or `-p` body.
    pub composed_prompt: String,
    pub mode: GrokLaunchMode,
}

/// Compose the text that Grok should see first (ask + context path + standing orders).
///
/// Output contract: crystal-clear next actions with **actual shell commands**
/// the operator can copy-paste (dry-run first).
pub fn compose_preload_prompt(
    ask: &str,
    context_file: &Path,
    standing: &str,
) -> String {
    let ask = ask.trim();
    let standing = standing.trim();
    format!(
        "You are co-pilot for arch-machine **archy** (Omarchy / Arch Linux maintenance).\n\
         Do not invent host state — read the context file when paths/exit codes matter.\n\
         Prefer dry-run, evidence, and fail-closed safety.\n\
         \n\
         ## Your deliverable (required format)\n\
         Reply with a short diagnosis (≤5 lines), then a section exactly titled:\n\
         \n\
         ### Next actions\n\
         \n\
         Numbered list. **Every** item must include:\n\
         1. One-line goal (why)\n\
         2. A fenced `bash` block with the **real command(s)** to run from the repo root\n\
            (use absolute paths only when the context file gives them)\n\
         3. Expected success signal (exit 0 / greppable line)\n\
         \n\
         Rules for commands:\n\
         - Prefer dry-run / read-only first (`--dry-run`, `ss`, inventory, audit)\n\
         - No vague steps like \"check the logs\" without a concrete command\n\
         - No sudo password prompts in the command if avoidable; note when `sudo -n` is required\n\
         - If something is blocked (missing tool, no sudo), give the install/enable command too\n\
         - After the list, one line: `Primary: N` (the single best next step)\n\
         \n\
         ## Job-specific ask\n\
         {ask}\n\
         \n\
         ## Context file (phase, sat, exit, stdio tail)\n\
         Read: `{ctx}`\n\
         \n\
         ## Standing orders\n\
         {standing}\n",
        ask = if ask.is_empty() {
            "Review the latest archy job output. Produce ### Next actions with copy-paste bash."
        } else {
            ask
        },
        ctx = context_file.display(),
        standing = if standing.is_empty() {
            "Evidence-first; no destructive changes without dry-run confirmation."
        } else {
            standing
        },
    )
}

/// Build interactive (default) or single-turn launch plan.
///
/// `fullscreen` maps to `grok --fullscreen` when interactive.
pub fn plan_launch(
    grok_bin: impl Into<PathBuf>,
    root: &Path,
    ask: &str,
    context_file: &Path,
    standing: &str,
    fullscreen: bool,
    mode: GrokLaunchMode,
) -> GrokLaunchPlan {
    let program = grok_bin.into();
    let cwd = root.to_path_buf();
    let composed = compose_preload_prompt(ask, context_file, standing);
    let mut args: Vec<String> = Vec::new();

    // Always pin cwd for repo-local tools/AGENTS.md discovery.
    args.push("--cwd".into());
    args.push(cwd.display().to_string());

    match mode {
        GrokLaunchMode::Interactive => {
            if fullscreen {
                args.push("--fullscreen".into());
            }
            // Positional PROMPT seeds multi-turn agent session (not bare `grok`).
            args.push(composed.clone());
        }
        GrokLaunchMode::SingleTurn => {
            // Headless fallback only — not primary Explain path.
            args.push("-p".into());
            args.push(composed.clone());
        }
    }

    let env = vec![
        ("ARCHY_ROOT".into(), cwd.display().to_string()),
        ("TINFOIL_ROOT".into(), cwd.display().to_string()),
        ("ARCHY_GROK_ASK".into(), ask.to_string()),
        (
            "ARCHY_GROK_CONTEXT_FILE".into(),
            context_file.display().to_string(),
        ),
    ];

    GrokLaunchPlan {
        program,
        args,
        cwd,
        env,
        composed_prompt: composed,
        mode,
    }
}

impl GrokLaunchPlan {
    /// Materialize a `std::process::Command` from this plan.
    pub fn to_command(&self) -> Command {
        let mut c = Command::new(&self.program);
        c.current_dir(&self.cwd);
        for a in &self.args {
            c.arg(a);
        }
        for (k, v) in &self.env {
            c.env(k, v);
        }
        c
    }

    /// True if argv includes a non-empty preload (positional or `-p` body).
    pub fn has_preload_prompt(&self) -> bool {
        let is_preload = |a: &str| {
            !a.starts_with('-')
                && (a.contains("### Next actions")
                    || a.contains("Job-specific ask")
                    || a.contains("Suggested ask"))
        };
        match self.mode {
            GrokLaunchMode::Interactive => self.args.last().map(|a| is_preload(a)).unwrap_or(false),
            GrokLaunchMode::SingleTurn => self.args.windows(2).any(|w| {
                (w[0] == "-p" || w[0] == "--single") && is_preload(&w[1])
            }),
        }
    }
}

/// Context + prompt file paths under the repo root.
pub fn context_file_path(root: &Path) -> PathBuf {
    root.join("logs/archy-grok-context.txt")
}

pub fn prompt_file_path(root: &Path) -> PathBuf {
    root.join("logs/archy-grok-prompt.txt")
}

/// Write context + prompt files (operator-visible, also referenced in preload).
pub fn write_launch_files(
    root: &Path,
    grok_context: &str,
    ask: &str,
    standing: &str,
) -> std::io::Result<(PathBuf, PathBuf, String)> {
    let ctx = context_file_path(root);
    if let Some(parent) = ctx.parent() {
        std::fs::create_dir_all(parent)?;
    }
    let composed = compose_preload_prompt(ask, &ctx, standing);
    std::fs::write(
        &ctx,
        format!(
            "{}\n\n--- suggested ask ---\n{}\n\n--- standing orders ---\n{}\n\n--- composed preload ---\n{}\n",
            grok_context, ask, standing, composed
        ),
    )?;
    let prompt_path = prompt_file_path(root);
    std::fs::write(&prompt_path, &composed)?;
    Ok((ctx, prompt_path, composed))
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::path::PathBuf;

    #[test]
    fn interactive_plan_includes_positional_prompt_not_bare_grok() {
        let root = PathBuf::from("/tmp/archy-root-fixture");
        let ctx = root.join("logs/archy-grok-context.txt");
        let plan = plan_launch(
            "/usr/bin/grok",
            &root,
            "Explain audit FAIL on malware",
            &ctx,
            "dry-run first",
            false,
            GrokLaunchMode::Interactive,
        );
        assert_eq!(plan.mode, GrokLaunchMode::Interactive);
        assert!(plan.has_preload_prompt(), "must preload prompt: {:?}", plan.args);
        // No bare launch: argv longer than just program
        assert!(
            plan.args.len() >= 3,
            "expect --cwd + path + PROMPT, got {:?}",
            plan.args
        );
        assert_eq!(plan.args[0], "--cwd");
        assert_eq!(plan.args[1], root.display().to_string());
        let prompt = plan.args.last().unwrap();
        assert!(prompt.contains("Explain audit FAIL"));
        assert!(
            prompt.contains("Job-specific ask") || prompt.contains("Suggested ask")
        );
        assert!(prompt.contains("### Next actions"));
        assert!(prompt.contains(ctx.display().to_string().as_str()));
        // Must NOT be single-turn -p as default interactive
        assert!(!plan.args.iter().any(|a| a == "-p" || a == "--single"));
        assert_eq!(plan.cwd, root);
    }

    #[test]
    fn fullscreen_adds_flag() {
        let root = PathBuf::from("/repo");
        let ctx = root.join("logs/c.txt");
        let plan = plan_launch(
            "grok",
            &root,
            "ask",
            &ctx,
            "orders",
            true,
            GrokLaunchMode::Interactive,
        );
        assert!(plan.args.iter().any(|a| a == "--fullscreen"));
        assert!(plan.has_preload_prompt());
    }

    #[test]
    fn single_turn_uses_dash_p_not_as_default_explain() {
        let root = PathBuf::from("/repo");
        let ctx = root.join("logs/c.txt");
        let plan = plan_launch(
            "grok",
            &root,
            "one shot",
            &ctx,
            "",
            false,
            GrokLaunchMode::SingleTurn,
        );
        assert_eq!(plan.mode, GrokLaunchMode::SingleTurn);
        assert!(plan.has_preload_prompt());
        assert!(plan.args.iter().any(|a| a == "-p"));
    }

    #[test]
    fn compose_includes_context_path() {
        let p = compose_preload_prompt("do X", Path::new("/r/logs/ctx.txt"), "stand");
        assert!(p.contains("do X"));
        assert!(p.contains("/r/logs/ctx.txt"));
        assert!(p.contains("stand"));
    }

    #[test]
    fn compose_requires_next_actions_with_bash_commands() {
        let p = compose_preload_prompt(
            "explain audit",
            Path::new("/repo/logs/archy-grok-context.txt"),
            "dry-run first",
        );
        assert!(
            p.contains("### Next actions"),
            "must require Next actions section: {p}"
        );
        assert!(
            p.contains("fenced `bash`") || p.contains("```bash") || p.contains("bash` block"),
            "must require bash command blocks: {p}"
        );
        assert!(p.contains("Primary:"));
        assert!(p.contains("Suggested ask") || p.contains("Job-specific ask"));
        // has_preload still works
        let plan = plan_launch(
            "grok",
            Path::new("/repo"),
            "explain audit",
            Path::new("/repo/logs/archy-grok-context.txt"),
            "dry-run first",
            false,
            GrokLaunchMode::Interactive,
        );
        assert!(plan.has_preload_prompt());
        assert!(plan.composed_prompt.contains("### Next actions"));
    }

    #[test]
    fn to_command_sets_cwd_and_env() {
        let root = PathBuf::from("/repo");
        let ctx = root.join("logs/c.txt");
        let plan = plan_launch(
            "grok",
            &root,
            "ask-me",
            &ctx,
            "orders",
            false,
            GrokLaunchMode::Interactive,
        );
        let cmd = plan.to_command();
        let s = format!("{cmd:?}");
        assert!(s.contains("ask-me") || plan.composed_prompt.contains("ask-me"));
        assert!(plan.env.iter().any(|(k, v)| k == "ARCHY_GROK_ASK" && v == "ask-me"));
        assert!(plan
            .env
            .iter()
            .any(|(k, v)| k == "ARCHY_GROK_CONTEXT_FILE" && v.contains("logs/c.txt")));
    }
}
