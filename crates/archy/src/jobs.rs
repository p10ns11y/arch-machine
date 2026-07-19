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
    #[allow(dead_code)]
    Custom,
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
            JobKind::Custom => "job",
        }
    }
}

#[derive(Debug, Clone)]
pub enum JobEvent {
    Line(String),
    #[allow(dead_code)]
    Finished { code: i32, elapsed_ms: u128 },
    SpawnFailed(String),
}

pub struct RunningJob {
    #[allow(dead_code)]
    pub kind: JobKind,
    #[allow(dead_code)]
    pub title: String,
    pub child: Option<Child>,
    pub rx: Receiver<JobEvent>,
    pub started: Instant,
    /// keep sender alive until threads finish (drop order)
    _tx: Sender<JobEvent>,
}

impl RunningJob {
    pub fn spawn(kind: JobKind, title: String, mut cmd: Command) -> Self {
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
                    kind,
                    title,
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

        // Waiter thread
        let tx_wait = tx.clone();
        // We cannot move child into waiter if we want kill — keep child in RunningJob
        // and poll try_wait from the UI loop instead of a waiter thread.
        // Drop unused to silence; finish polling is in App::poll_job.
        let _ = tx_wait;

        Self {
            kind,
            title,
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
    // Prefer installed tinfoil, else bash security-audit
    if let Ok(t) = which::which("tinfoil") {
        let mut c = Command::new(t);
        c.arg("audit");
        c.env("TINFOIL_ROOT", root);
        c.current_dir(root);
        return c;
    }
    let mut c = Command::new("bash");
    c.arg(root.join("maintenance/security-audit.sh"));
    c.arg("--global");
    c.env("TINFOIL_ROOT", root);
    c.current_dir(root);
    c
}

pub fn build_audit_project(root: &PathBuf, path: &str) -> Command {
    if let Ok(t) = which::which("tinfoil") {
        let mut c = Command::new(t);
        c.arg("audit");
        c.arg(path);
        c.env("TINFOIL_ROOT", root);
        c.current_dir(root);
        return c;
    }
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
