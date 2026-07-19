//! Loop controller — single source of navigation so the operator never gets lost.

use crate::actions::{self, ActionId, NextAction};
use crate::jobs::{
    self, JobEvent, JobKind, RunningJob,
};
use crate::root;
use std::path::PathBuf;
use std::time::Duration;

/// Where the operator is (breadcrumb = path from Home).
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Screen {
    Home,
    Output,
    Help,
}

/// Grok dock layout relative to main chrome.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum GrokMode {
    /// Only main control plane
    Hidden,
    /// Main left (~60%), Grok dock right (~40%)
    Split,
    /// Grok takes the whole body (still keep header breadcrumb)
    Full,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Focus {
    Main,
    Output,
    GrokDock,
    Actions,
}

pub struct App {
    pub root: PathBuf,
    pub screen: Screen,
    pub grok_mode: GrokMode,
    pub focus: Focus,
    pub menu_idx: usize,
    pub should_quit: bool,
    pub status: String,
    pub breadcrumb: Vec<String>,

    // Output pane
    pub lines: Vec<String>,
    pub scroll: u16,
    pub auto_scroll: bool,
    pub job: Option<RunningJob>,
    pub last_kind: Option<JobKind>,
    pub last_exit: Option<i32>,
    pub next_actions: Vec<NextAction>,
    pub action_idx: usize,

    // Grok dock (context, not live PTY — launch suspends TUI)
    pub grok_context: String,
    pub grok_prompt: String,
    pub project_path: String,
    pub install_profile: String,
    /// Default catalog search query (menu entry; agents can extend later)
    pub catalog_query: String,
    /// Default package for actuate dry-run demo
    pub actuate_pkg: String,

    /// Request outer main to suspend ratatui and run grok
    pub pending_grok_launch: bool,
}

const MENU: &[&str] = &[
    "📦  Inventory — list installed tools",
    "🔎  Catalog search — tools.yaml + profiles",
    "🏛  Omarchy status — version / theme / pkg probes",
    "🔍  Audit system (global)",
    "📁  Audit project (cwd / path)",
    "📋  Install profile dry-run",
    "📜  Evidence extract (dry-run)",
    "🛠  Package actuate dry-run (update jq)",
    "🤖  Grok dock — toggle split",
    "⛶   Grok fullscreen launch",
    "❓  Help / key map",
    "🚪  Quit",
];

impl App {
    pub fn new() -> Self {
        let root = root::discover_root();
        let mut app = Self {
            root: root.clone(),
            screen: Screen::Home,
            grok_mode: GrokMode::Hidden,
            focus: Focus::Main,
            menu_idx: 0,
            should_quit: false,
            status: format!("root: {}", root.display()),
            breadcrumb: vec!["Home".into()],
            lines: Vec::new(),
            scroll: 0,
            auto_scroll: true,
            job: None,
            last_kind: None,
            last_exit: None,
            next_actions: Vec::new(),
            action_idx: 0,
            grok_context: String::new(),
            grok_prompt: default_grok_prompt(),
            project_path: ".".into(),
            install_profile: "minimal".into(),
            catalog_query: "docker".into(),
            actuate_pkg: "jq".into(),
            pending_grok_launch: false,
        };
        app.push_line(format!(
            "archy control plane · root={}",
            app.root.display()
        ));
        app.push_line("↑↓ select · Enter run · g Grok split · G full Grok · ? help · q quit".into());
        app
    }

    pub fn menu_items(&self) -> &'static [&'static str] {
        MENU
    }

    pub fn set_breadcrumb(&mut self, parts: &[&str]) {
        self.breadcrumb = parts.iter().map(|s| (*s).to_string()).collect();
    }

    pub fn push_line(&mut self, line: String) {
        // Cap memory
        if self.lines.len() > 8_000 {
            self.lines.drain(0..2_000);
            if self.scroll > 2000 {
                self.scroll = self.scroll.saturating_sub(2000);
            }
        }
        self.lines.push(line);
        if self.auto_scroll {
            self.scroll = self.lines.len().saturating_sub(1) as u16;
        }
    }

    pub fn on_key(&mut self, key: crossterm::event::KeyEvent) {
        use crossterm::event::{KeyCode, KeyModifiers};

        if key.modifiers.contains(KeyModifiers::CONTROL) && key.code == KeyCode::Char('c') {
            if self.job.is_some() {
                self.cancel_job();
                return;
            }
            self.should_quit = true;
            return;
        }

        // Global keys
        match key.code {
            KeyCode::Char('q') if self.screen == Screen::Home && self.focus == Focus::Main => {
                self.should_quit = true;
                return;
            }
            KeyCode::Char('?') => {
                self.screen = Screen::Help;
                self.set_breadcrumb(&["Home", "Help"]);
                return;
            }
            KeyCode::Char('g') => {
                self.grok_mode = match self.grok_mode {
                    GrokMode::Hidden => GrokMode::Split,
                    GrokMode::Split => GrokMode::Hidden,
                    GrokMode::Full => GrokMode::Split,
                };
                self.status = format!("Grok dock: {:?}", self.grok_mode);
                return;
            }
            KeyCode::Char('G') => {
                self.prepare_grok_launch(true);
                return;
            }
            KeyCode::Esc => {
                if self.screen != Screen::Home {
                    self.go_home();
                } else if self.grok_mode == GrokMode::Full {
                    self.grok_mode = GrokMode::Split;
                }
                return;
            }
            KeyCode::Tab => {
                self.focus = match self.focus {
                    Focus::Main => Focus::Output,
                    Focus::Output => {
                        if self.grok_mode != GrokMode::Hidden {
                            Focus::GrokDock
                        } else if !self.next_actions.is_empty() {
                            Focus::Actions
                        } else {
                            Focus::Main
                        }
                    }
                    Focus::GrokDock => {
                        if !self.next_actions.is_empty() {
                            Focus::Actions
                        } else {
                            Focus::Main
                        }
                    }
                    Focus::Actions => Focus::Main,
                };
                return;
            }
            _ => {}
        }

        if self.screen == Screen::Help {
            if matches!(key.code, KeyCode::Esc | KeyCode::Enter | KeyCode::Char('h')) {
                self.go_home();
            }
            return;
        }

        // Next-action bar
        if self.focus == Focus::Actions && !self.next_actions.is_empty() {
            match key.code {
                KeyCode::Left => {
                    self.action_idx = self.action_idx.saturating_sub(1);
                    return;
                }
                KeyCode::Right => {
                    if self.action_idx + 1 < self.next_actions.len() {
                        self.action_idx += 1;
                    }
                    return;
                }
                KeyCode::Enter => {
                    let id = self.next_actions[self.action_idx].id;
                    self.run_action(id);
                    return;
                }
                KeyCode::Char(c) => {
                    if let Some(a) = self.next_actions.iter().find(|a| a.key == c).map(|a| a.id)
                    {
                        self.run_action(a);
                        return;
                    }
                }
                _ => {}
            }
        }

        // Scroll output
        if self.focus == Focus::Output || self.screen == Screen::Output {
            match key.code {
                KeyCode::Up | KeyCode::Char('k') => {
                    self.auto_scroll = false;
                    self.scroll = self.scroll.saturating_sub(1);
                    return;
                }
                KeyCode::Down | KeyCode::Char('j') => {
                    self.scroll = (self.scroll + 1).min(self.lines.len().saturating_sub(1) as u16);
                    return;
                }
                KeyCode::PageUp => {
                    self.auto_scroll = false;
                    self.scroll = self.scroll.saturating_sub(10);
                    return;
                }
                KeyCode::PageDown => {
                    self.scroll = (self.scroll + 10).min(self.lines.len().saturating_sub(1) as u16);
                    return;
                }
                KeyCode::Char(' ') if self.job.is_none() => {
                    self.auto_scroll = true;
                    self.scroll = self.lines.len().saturating_sub(1) as u16;
                    return;
                }
                _ => {}
            }
        }

        // Home menu
        if self.screen == Screen::Home && self.focus == Focus::Main {
            match key.code {
                KeyCode::Up | KeyCode::Char('k') => {
                    self.menu_idx = self.menu_idx.saturating_sub(1);
                }
                KeyCode::Down | KeyCode::Char('j') => {
                    if self.menu_idx + 1 < MENU.len() {
                        self.menu_idx += 1;
                    }
                }
                KeyCode::Enter | KeyCode::Char(' ') => {
                    self.activate_menu();
                }
                KeyCode::Char(c) if c.is_ascii_digit() => {
                    let n = c.to_digit(10).unwrap_or(0) as usize;
                    if n >= 1 && n <= MENU.len() {
                        self.menu_idx = n - 1;
                        self.activate_menu();
                    }
                }
                _ => {}
            }
        }
    }

    fn go_home(&mut self) {
        self.screen = Screen::Home;
        self.focus = Focus::Main;
        self.set_breadcrumb(&["Home"]);
        self.status = format!("root: {}", self.root.display());
    }

    fn activate_menu(&mut self) {
        match self.menu_idx {
            0 => self.start_job(JobKind::Inventory, "Inventory", jobs::build_inventory(&self.root)),
            1 => self.start_job(
                JobKind::Catalog,
                &format!("Catalog search '{}'", self.catalog_query),
                jobs::build_catalog(&self.root, &self.catalog_query),
            ),
            2 => self.start_job(
                JobKind::OmarchyStatus,
                "Omarchy status",
                jobs::build_omarchy_status(&self.root),
            ),
            3 => self.start_job(
                JobKind::AuditGlobal,
                "Audit global",
                jobs::build_audit_global(&self.root),
            ),
            4 => self.start_job(
                JobKind::AuditProject,
                &format!("Audit {}", self.project_path),
                jobs::build_audit_project(&self.root, &self.project_path),
            ),
            5 => self.start_job(
                JobKind::InstallDryRun,
                &format!("Install {} --dry-run", self.install_profile),
                jobs::build_install_dry(&self.root, &self.install_profile),
            ),
            6 => self.start_job(
                JobKind::Evidence,
                "Evidence dry-run",
                jobs::build_evidence(&self.root),
            ),
            7 => self.start_job(
                JobKind::ActuateDry,
                &format!("Actuate update {} --dry-run", self.actuate_pkg),
                jobs::build_actuate_update_dry(&self.root, &self.actuate_pkg),
            ),
            8 => {
                self.grok_mode = match self.grok_mode {
                    GrokMode::Hidden => GrokMode::Split,
                    _ => GrokMode::Hidden,
                };
                self.status = format!("Grok dock: {:?}", self.grok_mode);
            }
            9 => self.prepare_grok_launch(true),
            10 => {
                self.screen = Screen::Help;
                self.set_breadcrumb(&["Home", "Help"]);
            }
            11 => self.should_quit = true,
            _ => {}
        }
    }

    pub fn start_job(&mut self, kind: JobKind, title: &str, cmd: std::process::Command) {
        if self.job.is_some() {
            self.status = "Job already running — Ctrl+C to cancel".into();
            return;
        }
        self.lines.clear();
        self.scroll = 0;
        self.auto_scroll = true;
        self.last_exit = None;
        self.next_actions.clear();
        self.screen = Screen::Output;
        self.focus = Focus::Output;
        self.set_breadcrumb(&["Home", kind.label()]);
        self.push_line(format!("▶ starting: {title}"));
        self.push_line(format!("  kind={}  root={}", kind.label(), self.root.display()));
        self.push_line(String::new());
        self.status = format!("running: {title}");
        self.last_kind = Some(kind);
        self.job = Some(RunningJob::spawn(kind, title.into(), cmd));
        self.refresh_grok_context();
    }

    pub fn cancel_job(&mut self) {
        if let Some(mut j) = self.job.take() {
            j.kill();
            self.push_line("■ cancelled".into());
            self.status = "cancelled".into();
            self.finish_job_ui(1);
        }
    }

    pub fn tick(&mut self) {
        // Drain job events
        let mut finished_code: Option<i32> = None;
        let mut spawn_fail: Option<String> = None;
        let mut lines_buf = Vec::new();

        if let Some(job) = self.job.as_mut() {
            while let Ok(ev) = job.rx.try_recv() {
                match ev {
                    JobEvent::Line(l) => lines_buf.push(l),
                    JobEvent::Finished { code, .. } => finished_code = Some(code),
                    JobEvent::SpawnFailed(e) => spawn_fail = Some(e),
                }
            }
            if finished_code.is_none() {
                if let Some(code) = job.poll_exit() {
                    // Drain remaining lines briefly
                    thread_sleep_drain(job, &mut lines_buf);
                    finished_code = Some(code);
                }
            }
        }

        for l in lines_buf {
            self.push_line(l);
        }

        if let Some(e) = spawn_fail {
            self.push_line(format!("✗ spawn failed: {e}"));
            self.job = None;
            self.finish_job_ui(1);
            return;
        }

        if let Some(code) = finished_code {
            let elapsed = self
                .job
                .as_ref()
                .map(|j| j.started.elapsed().as_millis())
                .unwrap_or(0);
            self.job = None;
            self.push_line(String::new());
            self.push_line(format!(
                "■ finished exit={code} elapsed={elapsed}ms"
            ));
            self.status = format!("done exit={code}");
            self.finish_job_ui(code);
        }
    }

    fn finish_job_ui(&mut self, code: i32) {
        self.last_exit = Some(code);
        if let Some(kind) = self.last_kind {
            self.next_actions = actions::suggest(kind, code);
            self.action_idx = 0;
            self.focus = Focus::Actions;
            self.refresh_grok_context();
        }
    }

    fn refresh_grok_context(&mut self) {
        let tail: Vec<&str> = self.lines.iter().rev().take(40).map(|s| s.as_str()).collect();
        let mut t = tail;
        t.reverse();
        let exit = self
            .last_exit
            .map(|c| c.to_string())
            .unwrap_or_else(|| "running".into());
        let kind = self
            .last_kind
            .map(|k| k.label())
            .unwrap_or("none");
        self.grok_context = format!(
            "arch-machine tinfoil session\nroot: {}\nlast_job: {kind}\nexit: {exit}\n\n--- output tail ---\n{}",
            self.root.display(),
            t.join("\n")
        );
    }

    pub fn prepare_grok_launch(&mut self, fullscreen_hint: bool) {
        self.refresh_grok_context();
        if fullscreen_hint {
            self.grok_mode = GrokMode::Full;
        }
        self.pending_grok_launch = true;
        self.status = "launching Grok (TUI suspends)…".into();
    }

    pub fn run_action(&mut self, id: ActionId) {
        match id {
            ActionId::BackHome => self.go_home(),
            ActionId::ReRun => {
                if let Some(kind) = self.last_kind {
                    match kind {
                        JobKind::Inventory => self.activate_menu_index(0),
                        JobKind::Catalog => self.activate_menu_index(1),
                        JobKind::OmarchyStatus => self.activate_menu_index(2),
                        JobKind::AuditGlobal => self.activate_menu_index(3),
                        JobKind::AuditProject => self.activate_menu_index(4),
                        JobKind::InstallDryRun => self.activate_menu_index(5),
                        JobKind::Evidence => self.activate_menu_index(6),
                        JobKind::ActuateDry => self.activate_menu_index(7),
                        JobKind::Custom => {}
                    }
                }
            }
            ActionId::OpenInventory => self.activate_menu_index(0),
            ActionId::RunAudit => self.activate_menu_index(3),
            ActionId::RunEvidence => self.activate_menu_index(6),
            ActionId::InstallDry => self.activate_menu_index(5),
            ActionId::LaunchGrok => self.prepare_grok_launch(false),
            ActionId::ScrollTop => {
                self.scroll = 0;
                self.auto_scroll = false;
            }
        }
    }

    fn activate_menu_index(&mut self, idx: usize) {
        self.menu_idx = idx;
        // Don't change home selection permanently for re-run from output
        let saved_screen = self.screen;
        self.activate_menu();
        if matches!(idx, 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7) {
            // job started
            let _ = saved_screen;
        }
    }

    pub fn grok_launch_command(&self) -> Option<std::process::Command> {
        let grok = which::which("grok")
            .or_else(|_| which::which("grok-build"))
            .ok()?;
        let mut c = std::process::Command::new(grok);
        c.current_dir(&self.root);
        // Pass a short kickoff via env for agents that honor it; user can chat freely.
        c.env("TINFOIL_ROOT", &self.root);
        c.env("TINFOIL_GROK_CONTEXT_HINT", &self.grok_prompt);
        // Interactive: inherit stdio when suspended
        Some(c)
    }
}

fn default_grok_prompt() -> String {
    "You are co-piloting arch-machine via archy on Omarchy. \
     Use inventory, audit reports, and evidence. Prefer dry-run. \
     Suggest next fix actions; do not invent package state."
        .into()
}

fn thread_sleep_drain(job: &RunningJob, buf: &mut Vec<String>) {
    for _ in 0..20 {
        while let Ok(ev) = job.rx.try_recv() {
            if let JobEvent::Line(l) = ev {
                buf.push(l);
            }
        }
        std::thread::sleep(Duration::from_millis(5));
    }
}
