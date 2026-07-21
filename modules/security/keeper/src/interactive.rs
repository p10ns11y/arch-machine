//! Interactive onboard / loop mode — secrets never on argv or shell history.
//!
//! Happy path: step wizard prompts for passphrase and secret material via a
//! [`SecretIo`] trait (TTY non-echo in production; scripted injectors in tests).

use crate::ceremony::{
    drill, get_secret, get_secret_with_escrow, init_vault, put_secret, rebind_device, status,
};
use serde_json::json;
use std::io::{self, BufRead, Write};
use std::path::{Path, PathBuf};

/// Source of interactive lines and secrets (injectable for tests).
pub trait SecretIo {
    fn print_line(&mut self, line: &str) -> Result<(), String>;
    fn read_line(&mut self, prompt: &str) -> Result<String, String>;
    /// Non-echo secret (passphrase / secret value). Implementations must not log the value.
    fn read_secret(&mut self, prompt: &str) -> Result<String, String>;
}

/// Real TTY: visible prompts + rpassword for secrets.
pub struct TtyIo {
    stdout: io::Stdout,
    stdin: io::Stdin,
}

impl TtyIo {
    pub fn new() -> Self {
        Self {
            stdout: io::stdout(),
            stdin: io::stdin(),
        }
    }
}

impl Default for TtyIo {
    fn default() -> Self {
        Self::new()
    }
}

impl SecretIo for TtyIo {
    fn print_line(&mut self, line: &str) -> Result<(), String> {
        writeln!(self.stdout, "{line}").map_err(|e| e.to_string())?;
        self.stdout.flush().map_err(|e| e.to_string())
    }

    fn read_line(&mut self, prompt: &str) -> Result<String, String> {
        write!(self.stdout, "{prompt}").map_err(|e| e.to_string())?;
        self.stdout.flush().map_err(|e| e.to_string())?;
        let mut buf = String::new();
        self.stdin
            .lock()
            .read_line(&mut buf)
            .map_err(|e| e.to_string())?;
        Ok(buf.trim_end_matches(['\r', '\n']).to_string())
    }

    fn read_secret(&mut self, prompt: &str) -> Result<String, String> {
        rpassword::prompt_password(prompt).map_err(|e| e.to_string())
    }
}

/// Scripted I/O for tests: secrets and lines come from queues (never argv).
pub struct ScriptedIo {
    pub lines: Vec<String>,
    pub secrets: Vec<String>,
    pub output: Vec<String>,
    pub line_i: usize,
    pub secret_i: usize,
}

impl ScriptedIo {
    pub fn new(lines: Vec<String>, secrets: Vec<String>) -> Self {
        Self {
            lines,
            secrets,
            output: Vec::new(),
            line_i: 0,
            secret_i: 0,
        }
    }
}

impl SecretIo for ScriptedIo {
    fn print_line(&mut self, line: &str) -> Result<(), String> {
        self.output.push(line.to_string());
        Ok(())
    }

    fn read_line(&mut self, prompt: &str) -> Result<String, String> {
        self.output.push(format!("PROMPT:{prompt}"));
        self.lines
            .get(self.line_i)
            .cloned()
            .map(|s| {
                self.line_i += 1;
                s
            })
            .ok_or_else(|| "scripted: no more lines".into())
    }

    fn read_secret(&mut self, prompt: &str) -> Result<String, String> {
        self.output.push(format!("SECRET_PROMPT:{prompt}"));
        self.secrets
            .get(self.secret_i)
            .cloned()
            .map(|s| {
                self.secret_i += 1;
                s
            })
            .ok_or_else(|| "scripted: no more secrets".into())
    }
}

/// True if escrow path sits under the operator home (recovery theater).
pub fn escrow_under_home(escrow: &Path) -> bool {
    let home = std::env::var_os("HOME").map(PathBuf::from);
    match home {
        Some(h) => escrow.starts_with(&h),
        None => false,
    }
}

/// Result of a completed onboard wizard (before optional menu loop).
#[derive(Debug, Clone)]
pub struct OnboardResult {
    pub root: PathBuf,
    pub escrow: PathBuf,
    pub secret_name: String,
    pub healthy: bool,
    pub drill_proven: bool,
    pub secret_ok: bool,
}

fn read_passphrase_confirmed(io: &mut dyn SecretIo) -> Result<String, String> {
    let a = io.read_secret("Passphrase (not echoed): ")?;
    if a.is_empty() {
        return Err("passphrase cannot be empty".into());
    }
    let b = io.read_secret("Confirm passphrase: ")?;
    if a != b {
        return Err("passphrases do not match".into());
    }
    Ok(a)
}

/// Step-by-step onboard: practice-or-real → escrow warning → init → put → recover → status.
///
/// Passphrase and secret are read only via `io` secret prompts — never argv.
pub fn run_onboard(
    io: &mut dyn SecretIo,
    root: PathBuf,
    escrow: PathBuf,
    practice: bool,
) -> Result<OnboardResult, String> {
    io.print_line("══════════════════════════════════════════════════════")?;
    io.print_line("  keeper onboard — secrets stay off argv and history")?;
    io.print_line("  Model: any 2 of { passphrase · offline escrow · device }")?;
    io.print_line("  healthy ≠ vault open — only means recover drill worked")?;
    io.print_line("══════════════════════════════════════════════════════")?;

    if practice {
        io.print_line(&format!("Mode: PRACTICE  root={root:?}"))?;
    } else {
        io.print_line(&format!("Mode: REAL vault  root={root:?}"))?;
    }

    if escrow_under_home(&escrow) {
        io.print_line("")?;
        io.print_line("⚠  Escrow path is under $HOME.")?;
        io.print_line("   Offline recovery requires a copy OFF this laptop (USB / other house).")?;
        if !practice {
            let ans = io.read_line("Type YES to continue knowing this is incomplete recovery: ")?;
            if ans != "YES" {
                return Err("aborted: move escrow off-machine before real secrets".into());
            }
        } else {
            io.print_line("   (practice OK — for real vault, put escrow on USB first)")?;
        }
    } else {
        io.print_line(&format!("Escrow: {escrow:?} (outside $HOME — good)"))?;
    }

    let pass = read_passphrase_confirmed(io)?;

    if root.join("meta.json").exists() {
        io.print_line("Vault already exists — skipping init.")?;
    } else {
        io.print_line("Step: init vault…")?;
        let res = init_vault(&root, &pass, &escrow).map_err(|e| e.to_string())?;
        io.print_line(&format!(
            "  ok k={} n={} model={} seal={}",
            res.k, res.n, res.model, res.seal_algorithm
        ))?;
        io.print_line("  → Copy escrow OFF this machine before real secrets.")?;
    }

    let name = {
        let n = io.read_line("Secret name (e.g. mfa): ")?;
        if n.is_empty() {
            "demo".to_string()
        } else {
            n
        }
    };

    let secret = io.read_secret("Secret value (not echoed): ")?;
    if secret.is_empty() {
        return Err("secret value cannot be empty".into());
    }
    put_secret(&root, &pass, &name, &secret).map_err(|e| e.to_string())?;
    io.print_line(&format!("  put {name} ok"))?;

    // Verify daily get without re-printing secret into logs if we can compare
    let got = get_secret(&root, &pass, &name).map_err(|e| e.to_string())?;
    if got != secret {
        return Err("get mismatch after put".into());
    }
    io.print_line("  get (passphrase+device) ok")?;

    // Escrow path without passphrase (simulates forgot passphrase)
    let got_esc = get_secret_with_escrow(&root, &escrow, &name).map_err(|e| e.to_string())?;
    if got_esc != secret {
        return Err("escrow get mismatch".into());
    }
    io.print_line("  get --escrow (offline+device, no passphrase) ok")?;

    io.print_line("Step: recover drill (offline + device)…")?;
    let dr = drill(&root, &escrow).map_err(|e| e.to_string())?;
    if !dr.ok || !dr.canary_ok {
        return Err("drill failed".into());
    }
    let st = status(&root).map_err(|e| e.to_string())?;
    io.print_line(&format!(
        "  status healthy={} drillProven={} reason={}",
        st.healthy, st.drill_proven, st.reason
    ))?;
    if !st.healthy {
        return Err("expected healthy after drill".into());
    }

    io.print_line("")?;
    io.print_line("Onboard complete. Prefer: keeper loop  (or this menu next).")?;
    io.print_line("Never put secrets on the shell command line.")?;

    Ok(OnboardResult {
        root,
        escrow,
        secret_name: name,
        healthy: st.healthy,
        drill_proven: st.drill_proven,
        secret_ok: true,
    })
}

/// Interactive command menu after onboard (or for existing vaults).
/// Commands: status | get | put | recover | rebind | help | quit
pub fn run_loop(
    io: &mut dyn SecretIo,
    root: PathBuf,
    escrow: Option<PathBuf>,
) -> Result<(), String> {
    io.print_line("keeper loop — type help · secrets via prompts only · quit to exit")?;
    loop {
        let cmd = io.read_line("keeper> ")?;
        let cmd = cmd.trim();
        if cmd.is_empty() {
            continue;
        }
        match cmd {
            "quit" | "exit" | "q" => {
                io.print_line("bye")?;
                return Ok(());
            }
            "help" | "?" => {
                io.print_line("  status              vault health (healthy ≠ open)")?;
                io.print_line("  get                 read secret (passphrase prompt)")?;
                io.print_line("  get-escrow          read via offline escrow (no passphrase)")?;
                io.print_line("  put                 store secret (name + non-echo value)")?;
                io.print_line("  recover             drill offline+device → healthy")?;
                io.print_line("  rebind              new machine: P+escrow reseal device")?;
                io.print_line("  quit                leave loop")?;
            }
            "status" => {
                let st = status(&root).map_err(|e| e.to_string())?;
                let body = serde_json::to_string_pretty(&json!({
                    "exists": st.exists,
                    "healthy": st.healthy,
                    "drillProven": st.drill_proven,
                    "model": st.model,
                    "k": st.k,
                    "n": st.n,
                    "reason": st.reason,
                    "remember": st.remember,
                    "storeOffline": st.store_offline,
                    "free": st.free,
                    "note": "healthy only means recover drill worked once",
                }))
                .map_err(|e| e.to_string())?;
                io.print_line(&body)?;
            }
            "get" => {
                let name = io.read_line("name: ")?;
                let pass = io.read_secret("Passphrase: ")?;
                match get_secret(&root, &pass, &name) {
                    Ok(v) => io.print_line(&v)?,
                    Err(e) => io.print_line(&format!("error: {e}"))?,
                }
            }
            "get-escrow" => {
                let esc = match &escrow {
                    Some(p) => p.clone(),
                    None => PathBuf::from(io.read_line("escrow path: ")?),
                };
                let name = io.read_line("name: ")?;
                match get_secret_with_escrow(&root, &esc, &name) {
                    Ok(v) => io.print_line(&v)?,
                    Err(e) => io.print_line(&format!("error: {e}"))?,
                }
            }
            "put" => {
                let name = io.read_line("name: ")?;
                let pass = io.read_secret("Passphrase: ")?;
                let val = io.read_secret("Secret value (not echoed): ")?;
                match put_secret(&root, &pass, &name, &val) {
                    Ok(()) => io.print_line(&format!(r#"{{"ok":true,"name":"{name}"}}"#))?,
                    Err(e) => io.print_line(&format!("error: {e}"))?,
                }
            }
            "recover" => {
                let esc = match &escrow {
                    Some(p) => p.clone(),
                    None => PathBuf::from(io.read_line("escrow path: ")?),
                };
                match drill(&root, &esc) {
                    Ok(dr) => {
                        let st = status(&root).map_err(|e| e.to_string())?;
                        io.print_line(&format!(
                            r#"{{"ok":{},"healthy":{},"drillProven":{},"path":"{}"}}"#,
                            dr.ok, st.healthy, st.drill_proven, dr.path
                        ))?;
                    }
                    Err(e) => io.print_line(&format!("error: {e}"))?,
                }
            }
            "rebind" => {
                let esc = match &escrow {
                    Some(p) => p.clone(),
                    None => PathBuf::from(io.read_line("escrow path: ")?),
                };
                let pass = io.read_secret("Passphrase (rebind needs P+escrow): ")?;
                match rebind_device(&root, &pass, &esc, None, None) {
                    Ok(rb) => {
                        let body = serde_json::to_string_pretty(&rb).map_err(|e| e.to_string())?;
                        io.print_line(&body)?;
                        io.print_line("Copy NEW escrow offline; run recover once.")?;
                    }
                    Err(e) => io.print_line(&format!("error: {e}"))?,
                }
            }
            other => io.print_line(&format!("unknown command: {other} (help)"))?,
        }
    }
}

/// Full interactive entry: optional onboard wizard then loop.
pub fn run_interactive_session(
    io: &mut dyn SecretIo,
    root: PathBuf,
    escrow: PathBuf,
    skip_onboard_if_exists: bool,
    practice: bool,
) -> Result<OnboardResult, String> {
    let exists = root.join("meta.json").exists();
    let result = if exists && skip_onboard_if_exists {
        io.print_line("Vault exists — entering loop (onboard skipped).")?;
        OnboardResult {
            root: root.clone(),
            escrow: escrow.clone(),
            secret_name: String::new(),
            healthy: status(&root).map(|s| s.healthy).unwrap_or(false),
            drill_proven: status(&root).map(|s| s.drill_proven).unwrap_or(false),
            secret_ok: false,
        }
    } else if exists {
        // Still offer put/drill path via loop only
        io.print_line("Vault exists — skip full init; use loop commands.")?;
        OnboardResult {
            root: root.clone(),
            escrow: escrow.clone(),
            secret_name: String::new(),
            healthy: status(&root).map(|s| s.healthy).unwrap_or(false),
            drill_proven: status(&root).map(|s| s.drill_proven).unwrap_or(false),
            secret_ok: false,
        }
    } else {
        run_onboard(io, root.clone(), escrow.clone(), practice)?
    };

    let enter = io.read_line("Enter command loop? [Y/n]: ")?;
    if enter.is_empty() || enter.eq_ignore_ascii_case("y") || enter.eq_ignore_ascii_case("yes") {
        run_loop(io, root, Some(escrow))?;
    }
    Ok(result)
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::tempdir;

    #[test]
    fn onboard_scripted_reaches_healthy_without_env_passphrase() {
        let dir = tempdir().unwrap();
        let root = dir.path().join("vault");
        let escrow = dir.path().join("escrow.json");
        // Escrow not under HOME for this test (tempdir)
        let mut io = ScriptedIo::new(
            vec![
                "demo".into(), // secret name
            ],
            vec![
                "practice-pass-xx".into(),
                "practice-pass-xx".into(), // confirm
                "demo-secret-value".into(),
            ],
        );
        // practice=true skips YES for home escrow
        let res = run_onboard(&mut io, root.clone(), escrow.clone(), true).unwrap();
        assert!(res.healthy);
        assert!(res.drill_proven);
        assert!(res.secret_ok);
        assert_eq!(res.secret_name, "demo");
        // Secret never printed to output lines
        let joined = io.output.join("\n");
        assert!(
            !joined.contains("demo-secret-value"),
            "secret must not appear in UI log"
        );
        assert!(
            !joined.contains("practice-pass-xx"),
            "passphrase must not appear in UI log"
        );
        // Can still get via library
        assert_eq!(
            get_secret(&root, "practice-pass-xx", "demo").unwrap(),
            "demo-secret-value"
        );
    }

    #[test]
    fn loop_get_put_via_prompts() {
        let dir = tempdir().unwrap();
        let root = dir.path().join("vault");
        let escrow = dir.path().join("escrow.json");
        init_vault(&root, "loop-pass-xx", &escrow).unwrap();
        put_secret(&root, "loop-pass-xx", "x", "one").unwrap();

        let mut io = ScriptedIo::new(
            vec![
                "get".into(),
                "x".into(),
                "put".into(),
                "y".into(),
                "status".into(),
                "quit".into(),
            ],
            vec![
                "loop-pass-xx".into(), // get passphrase
                "loop-pass-xx".into(), // put passphrase
                "two".into(),          // put value
            ],
        );
        run_loop(&mut io, root.clone(), Some(escrow)).unwrap();
        assert_eq!(get_secret(&root, "loop-pass-xx", "y").unwrap(), "two");
        assert!(io.output.iter().any(|l| l.contains("\"healthy\"")));
    }

    #[test]
    fn escrow_under_home_detects_home_paths() {
        if let Ok(home) = std::env::var("HOME") {
            assert!(escrow_under_home(Path::new(&home).join("foo.json").as_path()));
            assert!(!escrow_under_home(Path::new("/media/usb/escrow.json")));
        }
    }
}
