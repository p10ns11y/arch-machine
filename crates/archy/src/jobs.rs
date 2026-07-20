//! Background shell / CLI jobs with line capture for the TUI output pane.

use std::io::{BufRead, BufReader};
use std::path::PathBuf;
use std::process::{Child, Command, Stdio};
use std::sync::mpsc::{self, Receiver, Sender};
use std::thread;
use std::time::Instant;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum JobKind {
    Inventory,
    Catalog,
    OmarchyStatus,
    AuditGlobal,
    AuditProject,
    InstallDryRun,
    Evidence,
    ActuateDry,
}

impl JobKind {
    pub fn label(self) -> &'static str {
        match self {
            JobKind::Inventory => "inventory",
            JobKind::Catalog => "catalog",
            JobKind::OmarchyStatus => "omarchy status",
            JobKind::AuditGlobal => "audit (global)",
            JobKind::AuditProject => "audit (project)",
            JobKind::InstallDryRun => "install --dry-run",
            JobKind::Evidence => "evidence",
            JobKind::ActuateDry => "pkg dry-run",
        }
    }
}

/// Async stdio events from a running shell backend (satellite).
/// Exit is polled via [`RunningJob::poll_exit`] — not a channel event.
#[derive(Debug, Clone)]
pub enum JobEvent {
    Line(String),
    SpawnFailed(String),
}

/// Offline-style job handle: fire command, stream lines, later poll outcome.
pub struct RunningJob {
    pub child: Option<Child>,
    pub rx: Receiver<JobEvent>,
    pub started: Instant,
    /// Keep sender alive until reader threads finish (drop order).
    _tx: Sender<JobEvent>,
}

impl RunningJob {
    pub fn spawn(mut cmd: Command) -> Self {
        let (tx, rx) = mpsc::channel();
        let started = Instant::now();

        cmd.stdout(Stdio::piped());
        cmd.stderr(Stdio::piped());
        // Don't inherit stdin — jobs are non-interactive by default
        cmd.stdin(Stdio::null());

        let mut child = match cmd.spawn() {
            Ok(c) => c,
            Err(e) => {
                let _ = tx.send(JobEvent::SpawnFailed(e.to_string()));
                return Self {
                    child: None,
                    rx,
                    started,
                    _tx: tx,
                };
            }
        };

        let stdout = child.stdout.take();
        let stderr = child.stderr.take();
        let tx_out = tx.clone();
        let tx_err = tx.clone();

        if let Some(out) = stdout {
            thread::spawn(move || {
                let reader = BufReader::new(out);
                for line in reader.lines().flatten() {
                    if tx_out.send(JobEvent::Line(line)).is_err() {
                        break;
                    }
                }
            });
        }
        if let Some(err) = stderr {
            thread::spawn(move || {
                let reader = BufReader::new(err);
                for line in reader.lines().flatten() {
                    if tx_err
                        .send(JobEvent::Line(format!("[stderr] {line}")))
                        .is_err()
                    {
                        break;
                    }
                }
            });
        }

        // Exit is polled from the UI loop (kill stays possible); no waiter thread.
        Self {
            child: Some(child),
            rx,
            started,
            _tx: tx,
        }
    }

    pub fn poll_exit(&mut self) -> Option<i32> {
        let child = self.child.as_mut()?;
        match child.try_wait() {
            Ok(Some(status)) => Some(status.code().unwrap_or(1)),
            Ok(None) => None,
            Err(_) => Some(1),
        }
    }

    pub fn kill(&mut self) {
        if let Some(child) = self.child.as_mut() {
            let _ = child.kill();
            let _ = child.wait();
        }
        self.child = None;
    }
}

pub fn build_inventory(root: &PathBuf) -> Command {
    let mut c = Command::new("bash");
    c.arg(root.join("maintenance/inventory.sh"));
    c.arg("--text");
    c.env("TINFOIL_ROOT", root);
    c.current_dir(root);
    c
}

pub fn build_catalog(root: &PathBuf, query: &str) -> Command {
    let mut c = Command::new("bash");
    c.arg(root.join("maintenance/catalog.sh"));
    c.arg("--text");
    if !query.is_empty() {
        c.arg(query);
    }
    c.env("TINFOIL_ROOT", root);
    c.current_dir(root);
    c
}

/// Dry-run update plan for a single package name (default safe actuate).
pub fn build_actuate_update_dry(root: &PathBuf, pkg: &str) -> Command {
    let mut c = Command::new("bash");
    c.arg(root.join("maintenance/package-actuate.sh"));
    c.arg("--update");
    c.arg(pkg);
    c.arg("--dry-run");
    c.env("TINFOIL_ROOT", root);
    c.current_dir(root);
    c
}

/// Read-only Omarchy host status (version, theme, pkg probes).
pub fn build_omarchy_status(root: &PathBuf) -> Command {
    let mut c = Command::new("bash");
    c.arg(root.join("maintenance/omarchy-status.sh"));
    c.arg("--text");
    c.env("TINFOIL_ROOT", root);
    c.current_dir(root);
    c
}

pub fn build_audit_global(root: &PathBuf) -> Command {
    // Always use the repo/runtime script so archy sees threat-focused quiet format
    // (installed `tinfoil audit` may lag behind maintenance/security-audit.sh).
    let mut c = Command::new("bash");
    c.arg(root.join("maintenance/security-audit.sh"));
    c.arg("--global");
    c.env("TINFOIL_ROOT", root);
    c.current_dir(root);
    c
}

pub fn build_audit_project(root: &PathBuf, path: &str) -> Command {
    let mut c = Command::new("bash");
    c.arg(root.join("maintenance/security-audit.sh"));
    c.arg("--project");
    c.arg(path);
    c.env("TINFOIL_ROOT", root);
    c.current_dir(root);
    c
}

pub fn build_install_dry(root: &PathBuf, profile: &str) -> Command {
    let mut c = Command::new("bash");
    c.arg(root.join("install.sh"));
    c.arg("--profile");
    c.arg(profile);
    c.arg("--dry-run");
    c.env("TINFOIL_ROOT", root);
    c.current_dir(root);
    c
}

pub fn build_evidence(root: &PathBuf) -> Command {
    let mut c = Command::new("bash");
    c.arg(root.join("maintenance/extract-evidence.sh"));
    c.arg("--dry-run");
    c.env("TINFOIL_ROOT", root);
    c.current_dir(root);
    c
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::path::PathBuf;
    use std::process::Stdio;

    fn repo_root() -> PathBuf {
        // crates/archy → repo root
        PathBuf::from(env!("CARGO_MANIFEST_DIR"))
            .parent()
            .and_then(|p| p.parent())
            .expect("repo root")
            .to_path_buf()
    }

    fn run_ok_nonempty(mut cmd: Command) {
        cmd.stdout(Stdio::piped());
        cmd.stderr(Stdio::piped());
        let out = cmd.output().expect("spawn backend");
        let stdout = String::from_utf8_lossy(&out.stdout);
        let stderr = String::from_utf8_lossy(&out.stderr);
        assert!(
            out.status.success() || !stdout.is_empty() || !stderr.is_empty(),
            "backend produced no output and failed: status={:?} stderr={stderr}",
            out.status
        );
        assert!(
            !stdout.is_empty() || !stderr.is_empty(),
            "backend produced empty stdout+stderr"
        );
    }

    #[test]
    fn inventory_builder_smoke() {
        let root = repo_root();
        run_ok_nonempty(build_inventory(&root));
    }

    #[test]
    fn catalog_builder_smoke() {
        let root = repo_root();
        run_ok_nonempty(build_catalog(&root, "docker"));
    }

    #[test]
    fn omarchy_status_builder_smoke() {
        let root = repo_root();
        run_ok_nonempty(build_omarchy_status(&root));
    }

    #[test]
    fn actuate_dry_builder_smoke() {
        let root = repo_root();
        run_ok_nonempty(build_actuate_update_dry(&root, "jq"));
    }

    #[test]
    fn audit_global_dry_run_has_threat_summary() {
        let root = repo_root();
        let mut c = Command::new("bash");
        c.arg(root.join("maintenance/security-audit.sh"));
        c.arg("--global");
        c.arg("--dry-run");
        c.env("TINFOIL_ROOT", &root);
        c.current_dir(&root);
        c.stdout(Stdio::piped());
        c.stderr(Stdio::piped());
        let out = c.output().expect("spawn audit dry-run");
        let stdout = String::from_utf8_lossy(&out.stdout);
        assert!(
            out.status.success(),
            "dry-run should exit 0: stderr={}",
            String::from_utf8_lossy(&out.stderr)
        );
        assert!(stdout.contains("## SUMMARY"), "missing SUMMARY block");
        assert!(stdout.contains("malware="), "missing malware area");
        assert!(stdout.contains("ports="), "missing ports area");
        assert!(stdout.contains("supply="), "missing supply area");
        assert!(stdout.contains("config="), "missing config area");
        assert!(!stdout.contains("🚀"), "default path must not use rocket banners");
    }
}
