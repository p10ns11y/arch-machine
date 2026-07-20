//! Production remote control via Grok **ACP** (Agent Client Protocol).
//!
//! XChat DM → host is not reliable on `GET /2/dm_events`. ACP is the stable
//! path to drive a Grok agent session (stdio or WebSocket serve) with sessions,
//! prompts, tools, and permissions.
//!
//! This module does not re-implement ACP; it launches and documents
//! `grok agent serve` with arch-machine defaults.

use std::env;
use std::fs;
use std::net::TcpStream;
use std::path::{Path, PathBuf};
use std::process::{Command, Stdio};
use std::time::{SystemTime, UNIX_EPOCH};

const DEFAULT_BIND: &str = "127.0.0.1:2419";

/// Resolve `grok` binary on PATH or common install locations.
pub fn resolve_grok_binary() -> Option<PathBuf> {
    if let Ok(custom) = env::var("GROK_BIN") {
        let path = PathBuf::from(custom);
        if path.is_file() {
            return Some(path);
        }
    }
    if let Some(path_var) = env::var_os("PATH") {
        for directory in env::split_paths(&path_var) {
            let candidate = directory.join("grok");
            if candidate.is_file() {
                return Some(candidate);
            }
        }
    }
    let home = env::var_os("HOME").map(PathBuf::from)?;
    let bundled = home.join(".grok").join("bin").join("grok");
    if bundled.is_file() {
        return Some(bundled);
    }
    None
}

/// Ensure a secret exists (env or generate + optionally persist under state dir).
pub fn resolve_or_create_agent_secret(state_directory: &Path) -> std::io::Result<String> {
    if let Ok(secret) = env::var("GROK_AGENT_SECRET") {
        if !secret.trim().is_empty() {
            return Ok(secret);
        }
    }
    let secret_path = state_directory.join("acp-agent.secret");
    if secret_path.is_file() {
        let existing = fs::read_to_string(&secret_path)?;
        let trimmed = existing.trim().to_string();
        if !trimmed.is_empty() {
            return Ok(trimmed);
        }
    }
    fs::create_dir_all(state_directory)?;
    let generated = format!(
        "groxy-acp-{:x}-{:x}",
        SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .map(|d| d.as_nanos())
            .unwrap_or(0),
        std::process::id()
    );
    fs::write(&secret_path, format!("{generated}\n"))?;
    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt;
        let _ = fs::set_permissions(&secret_path, fs::Permissions::from_mode(0o600));
    }
    Ok(generated)
}

/// True if something accepts TCP on bind address (host:port).
pub fn is_port_listening(bind: &str) -> bool {
    TcpStream::connect(bind).is_ok()
}

/// Print operator-facing architecture for ACP remote control.
pub fn print_architecture_explanation() {
    println!(
        r#"groxy: multi-session model (any Grok workspace)
=============================================

Nuance most “DM → Grok” sketches miss:
  Several Grok TUIs can be open. None of them listen to XChat by default.
  A message must be addressed to a session (cwd / ACP endpoint / alias).
  Without addressing + a reliable inbound transport, “DM to Grok” is undefined.

What exists today (no X webhooks / Account Activity):

  CONTROL (which agent?):
    ACP client ── picks bind/cwd ──► grok agent serve  ◄── groxy acp serve
                                         │
                                         ▼
                                    tools in THAT cwd

  NOTIFY (host → human):
    any workspace ── groxy inject [--session-label NAME] ──► XChat

  NOT OFFERED:
    Phone XChat ── dm_events poll ──► “the right Grok window”
    (events often missing; no session registry; 429 under load)

Who is the chat for?
  - ACP: the client chooses the agent (bind + session/new cwd).
  - inject: optional --session-label so multi-project notifies are readable.
  - Future inbound (only with real push): DM prefix !alias … → sessions.json
    registry → ACP prompt or grok -p in that cwd. Never broadcast to all TUIs.

Commands:
  groxy acp serve [--bind 127.0.0.1:2419] [--secret …] [--cwd /any/project]
  groxy acp status | groxy acp explain
  groxy --live inject "status" --session-label my-app

Security: loopback bind by default; Tailscale/SSH for remote; secret required.
"#
    );
}

/// Launch `grok agent serve` (replaces this process on success).
pub fn exec_agent_serve(
    bind: &str,
    secret: &str,
    working_directory: Option<&Path>,
    always_approve: bool,
    model: Option<&str>,
) -> i32 {
    let Some(grok) = resolve_grok_binary() else {
        eprintln!("error: `grok` not found on PATH (or GROK_BIN / ~/.grok/bin/grok)");
        eprintln!("Install Grok Build CLI, then re-run: groxy acp serve");
        return 127;
    };

    if is_port_listening(bind) {
        eprintln!("error: something is already listening on {bind}");
        eprintln!("Stop it, or choose another --bind. Check: groxy acp status");
        return 1;
    }

    let mut command = Command::new(&grok);
    command.arg("agent");
    if always_approve {
        command.arg("--always-approve");
    }
    if let Some(model_id) = model {
        command.arg("--model").arg(model_id);
    }
    command
        .arg("serve")
        .arg("--bind")
        .arg(bind)
        .arg("--secret")
        .arg(secret);

    if let Some(cwd) = working_directory {
        command.current_dir(cwd);
    }

    eprintln!("starting ACP WebSocket agent:");
    eprintln!("  binary: {}", grok.display());
    eprintln!("  bind:   {bind}");
    eprintln!("  secret: (set; length {})", secret.len());
    if let Some(cwd) = working_directory {
        eprintln!("  cwd:    {}", cwd.display());
    }
    eprintln!();
    eprintln!("Clients connect with the ACP WebSocket client + secret.");
    eprintln!("Local only by default — use SSH/Tailscale for remote.");
    eprintln!("Notify on XChat (optional): groxy --live inject \"status\"");
    eprintln!();

    // Inherit stdio so operator sees agent logs / generated messages
    command
        .stdin(Stdio::inherit())
        .stdout(Stdio::inherit())
        .stderr(Stdio::inherit());

    match command.status() {
        Ok(status) => status.code().unwrap_or(1),
        Err(error) => {
            eprintln!("failed to spawn grok agent serve: {error}");
            1
        }
    }
}

pub fn print_status(bind: &str, state_directory: &Path) {
    let listening = is_port_listening(bind);
    let grok = resolve_grok_binary();
    let secret_path = state_directory.join("acp-agent.secret");
    println!("ACP remote status");
    println!("  bind:           {bind}");
    println!(
        "  listening:      {}",
        if listening { "yes" } else { "no" }
    );
    println!(
        "  grok binary:    {}",
        grok.map(|p| p.display().to_string())
            .unwrap_or_else(|| "(not found)".into())
    );
    println!(
        "  secret file:    {} ({})",
        secret_path.display(),
        if secret_path.is_file() {
            "present"
        } else {
            "absent — will create on serve"
        }
    );
    if env::var("GROK_AGENT_SECRET").is_ok() {
        println!("  GROK_AGENT_SECRET: set in environment");
    } else {
        println!("  GROK_AGENT_SECRET: unset (file or auto-generate)");
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::net::TcpListener;

    #[test]
    fn port_listening_detects_open_socket() {
        let listener = TcpListener::bind("127.0.0.1:0").expect("bind ephemeral");
        let addr = listener.local_addr().expect("addr");
        let bind = format!("127.0.0.1:{}", addr.port());
        assert!(is_port_listening(&bind));
        drop(listener);
        // May still be in TIME_WAIT briefly; only assert true while held
    }

    #[test]
    fn secret_persists_under_state_dir() {
        let dir = tempfile::tempdir().unwrap();
        let secret_one = resolve_or_create_agent_secret(dir.path()).unwrap();
        let secret_two = resolve_or_create_agent_secret(dir.path()).unwrap();
        assert_eq!(secret_one, secret_two);
        assert!(!secret_one.is_empty());
    }

    /// Drives shipped `resolve_grok_binary` against the real host install
    /// (PATH / GROK_BIN / ~/.grok/bin/grok) — same binary avante spawns for ACP stdio.
    #[test]
    fn resolve_grok_binary_finds_real_executable() {
        let path = resolve_grok_binary().expect(
            "grok binary must resolve via PATH, GROK_BIN, or ~/.grok/bin/grok for ACP clients",
        );
        assert!(
            path.is_file(),
            "resolved path is not a file: {}",
            path.display()
        );
        #[cfg(unix)]
        {
            use std::os::unix::fs::PermissionsExt;
            let mode = std::fs::metadata(&path)
                .expect("metadata")
                .permissions()
                .mode();
            assert_ne!(mode & 0o111, 0, "grok is not executable: {}", path.display());
        }
        // Agent surface used by Neovim avante acp_providers args
        let help = std::process::Command::new(&path)
            .args(["agent", "stdio", "--help"])
            .output()
            .expect("spawn grok agent stdio --help");
        assert!(
            help.status.success(),
            "grok agent stdio --help failed: {}",
            String::from_utf8_lossy(&help.stderr)
        );
        let stdout = String::from_utf8_lossy(&help.stdout);
        assert!(
            stdout.to_lowercase().contains("stdio") || stdout.to_lowercase().contains("agent"),
            "unexpected help output: {stdout}"
        );
    }

    #[test]
    fn resolve_grok_binary_respects_grok_bin_env() {
        let dir = tempfile::tempdir().unwrap();
        let fake = dir.path().join("grok");
        std::fs::write(&fake, b"#!/bin/sh\necho fake\n").unwrap();
        #[cfg(unix)]
        {
            use std::os::unix::fs::PermissionsExt;
            let mut perms = std::fs::metadata(&fake).unwrap().permissions();
            perms.set_mode(0o755);
            std::fs::set_permissions(&fake, perms).unwrap();
        }
        // SAFETY: test-only env override; single-threaded cargo test default for this unit
        unsafe { std::env::set_var("GROK_BIN", &fake) };
        let resolved = resolve_grok_binary().expect("GROK_BIN should win");
        unsafe { std::env::remove_var("GROK_BIN") };
        assert_eq!(resolved, fake);
    }
}
