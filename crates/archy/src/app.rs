//! Loop controller — single source of navigation so the operator never gets lost.

use crate::actions::{self, ActionId, NextAction};
use crate::jobs::{self, JobEvent, JobKind, RunningJob};
use crate::nav::{self, EscEffect};
use crate::root;
use crate::theme::{self, Palette, ThemeMode};
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
    /// Light/dark resolved at startup (see theme::detect_theme_mode).
    pub theme: ThemeMode,

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

/// Short labels — detail lives in backends/help, not menu walls.
const MENU: &[&str] = &[
    "Inventory",
    "Catalog search",
    "Omarchy status",
    "Audit system",
    "Audit project",
    "Install dry-run",
    "Evidence dry-run",
    "Pkg update dry-run",
    "Co-pilot brief",
    "Launch Grok",
    "Help",
    "Quit",
];

impl App {
    pub fn new() -> Self {
        let root = root::discover_root();
        let theme = theme::detect_theme_mode();
        let mut app = Self {
            root: root.clone(),
            screen: Screen::Home,
            grok_mode: GrokMode::Hidden,
            focus: Focus::Main,
            menu_idx: 0,
            should_quit: false,
            status: format!("ready · {}", short_path(&root)),
            breadcrumb: vec!["Home".into()],
            theme,
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
            "archy · theme={} · Enter run · g brief · ? help",
            app.theme.as_str()
        ));
        app.refresh_grok_context();
        app
    }

    pub fn palette(&self) -> Palette {
        theme::palette(self.theme)
    }

    pub fn menu_items(&self) -> &'static [&'static str] {
        MENU
    }

    /// Menu entry count (layout tests / panel height).
    pub fn menu_len() -> usize {
        MENU.len()
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
                self.toggle_grok_brief();
                return;
            }
            KeyCode::Char('G') => {
                self.prepare_grok_launch(true);
                return;
            }
            KeyCode::Esc => {
                match nav::esc_effect(self.screen, self.grok_mode) {
                    EscEffect::GoHome => self.go_home(),
                    EscEffect::GrokFullToSplit => self.grok_mode = GrokMode::Split,
                    EscEffect::None => {}
                }
                return;
            }
            KeyCode::Tab => {
                self.focus = nav::tab_next_focus(
                    self.focus,
                    self.grok_mode,
                    !self.next_actions.is_empty(),
                );
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

        // Co-pilot brief: Enter launches interactive Grok (split is not a chat pane).
        if self.focus == Focus::GrokDock {
            match key.code {
                KeyCode::Enter | KeyCode::Char(' ') => {
                    self.prepare_grok_launch(false);
                    return;
                }
                _ => {}
            }
        }

        // Next-action keys work whenever suggestions exist (primary bar is always shown).
        if !self.next_actions.is_empty() {
            match key.code {
                KeyCode::Left if self.focus == Focus::Actions => {
                    self.action_idx = self.action_idx.saturating_sub(1);
                    return;
                }
                KeyCode::Right if self.focus == Focus::Actions => {
                    if self.action_idx + 1 < self.next_actions.len() {
                        self.action_idx += 1;
                    }
                    return;
                }
                KeyCode::Enter if self.focus == Focus::Actions => {
                    let id = self.next_actions[self.action_idx].id;
                    self.run_action(id);
                    return;
                }
                KeyCode::Char(c)
                    if self.next_actions.iter().any(|a| a.key == c)
                        && !(self.screen == Screen::Home
                            && self.focus == Focus::Main
                            && c.is_ascii_digit()) =>
                {
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
        self.status = format!("ready · {}", short_path(&self.root));
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
            8 => self.toggle_grok_brief(),
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
        self.job = Some(RunningJob::spawn(cmd));
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
            let hints = actions::JobHints::from_lines(&self.lines);
            self.next_actions = actions::suggest_with_hints(kind, code, &hints);
            self.action_idx = 0;
            self.focus = Focus::Actions;
            self.refresh_grok_context();
        }
    }

    /// Toggle co-pilot briefing split (not a live chat). Opening focuses the brief.
    fn toggle_grok_brief(&mut self) {
        self.grok_mode = nav::toggle_grok_mode(self.grok_mode);
        self.refresh_grok_context();
        match self.grok_mode {
            GrokMode::Hidden => {
                if self.focus == Focus::GrokDock {
                    self.focus = Focus::Main;
                }
                self.status = "brief:off".into();
            }
            GrokMode::Split | GrokMode::Full => {
                self.focus = Focus::GrokDock;
                self.status = "brief:on · Enter=launch".into();
            }
        }
    }

    fn refresh_grok_context(&mut self) {
        let tail: Vec<&str> = self.lines.iter().rev().take(40).map(|s| s.as_str()).collect();
        let mut t = tail;
        t.reverse();
        let exit = self
            .last_exit
            .map(|c| c.to_string())
            .unwrap_or_else(|| {
                if self.job.is_some() {
                    "running".into()
                } else {
                    "—".into()
                }
            });
        let kind = self.last_kind.map(|k| k.label()).unwrap_or("none");
        self.grok_context = format!(
            "archy co-pilot session\n\
             surface: archy (Ratatui control plane)\n\
             root: {}\n\
             last_job: {kind}\n\
             exit: {exit}\n\
             profile_default: {}\n\
             catalog_query: {}\n\
             actuate_pkg: {}\n\
             \n--- output tail ---\n{}",
            self.root.display(),
            self.install_profile,
            self.catalog_query,
            self.actuate_pkg,
            t.join("\n")
        );
    }

    /// Job-aware one-liner the operator (or Grok) should act on next.
    pub fn suggested_grok_ask(&self) -> String {
        let exit = self.last_exit;
        match self.last_kind {
            None => {
                "Inventory this Omarchy host, then propose the safest next dry-run action."
                    .into()
            }
            Some(JobKind::Inventory) => {
                if exit == Some(0) {
                    "From this inventory: flag drift vs omarchy-baseline and tools.yaml; suggest one dry-run fix."
                        .into()
                } else {
                    "Inventory failed — diagnose the backend error and a safe re-run.".into()
                }
            }
            Some(JobKind::Catalog) => {
                format!(
                    "Catalog search for '{}': recommend install/update dry-run or skip.",
                    self.catalog_query
                )
            }
            Some(JobKind::OmarchyStatus) => {
                "Read Omarchy status: theme/version/pkg probes — any action needed?".into()
            }
            Some(JobKind::AuditGlobal) | Some(JobKind::AuditProject) => {
                if exit == Some(0) {
                    "Summarize audit findings; rank remediations; prefer dry-run / non-destructive first."
                        .into()
                } else {
                    "Audit exited non-zero — explain failures and the safest next step.".into()
                }
            }
            Some(JobKind::InstallDryRun) => {
                format!(
                    "Review install --profile {} --dry-run plan; call out risks before any apply.",
                    self.install_profile
                )
            }
            Some(JobKind::Evidence) => {
                "Evidence dry-run finished — what should we include or fix before a real extract?"
                    .into()
            }
            Some(JobKind::ActuateDry) => {
                format!(
                    "Package actuate dry-run for '{}': confirm plan, refuse-list, Omarchy alt path.",
                    self.actuate_pkg
                )
            }
        }
    }

    pub fn prepare_grok_launch(&mut self, fullscreen_hint: bool) {
        self.refresh_grok_context();
        if fullscreen_hint {
            self.grok_mode = GrokMode::Full;
        } else if self.grok_mode == GrokMode::Hidden {
            self.grok_mode = GrokMode::Split;
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
                    }
                }
            }
            ActionId::OpenInventory => self.activate_menu_index(0),
            ActionId::RunAudit => self.activate_menu_index(3),
            ActionId::RunEvidence => self.activate_menu_index(6),
            ActionId::InstallDry => self.activate_menu_index(5),
            ActionId::ActuateDry => self.activate_menu_index(7),
            ActionId::LaunchGrok => self.prepare_grok_launch(false),
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
        // Pass session root + standing orders + job-aware ask for agents that honor env.
        c.env("TINFOIL_ROOT", &self.root);
        c.env("ARCHY_ROOT", &self.root);
        c.env("TINFOIL_GROK_CONTEXT_HINT", &self.grok_prompt);
        c.env("ARCHY_GROK_ASK", self.suggested_grok_ask());
        c.env(
            "ARCHY_GROK_CONTEXT_FILE",
            self.root.join("logs/archy-grok-context.txt"),
        );
        // Interactive: inherit stdio when suspended
        Some(c)
    }
}

fn default_grok_prompt() -> String {
    "You are co-piloting arch-machine via archy on Omarchy. \
     Read logs/archy-grok-context.txt for session tail. \
     Use inventory, audit, and evidence. Prefer dry-run. \
     Suggest next fix actions; do not invent package state."
        .into()
}

fn short_path(p: &std::path::Path) -> String {
    let s = p.display().to_string();
    if s.len() > 36 {
        format!("…{}", &s[s.len() - 34..])
    } else {
        s
    }
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
