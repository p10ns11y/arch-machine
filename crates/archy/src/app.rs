//! Model (xstate *context*) + runtime effect performer.
//!
//! Control transitions live in [`crate::eagle`]; this module holds state and
//! executes [`crate::cmd::Cmd`] (spawn offline satellites, kill, quit flags).

use crate::actions::NextAction;
use crate::cmd::Cmd;
use crate::eagle;
use crate::fsm::Phase;
use crate::jobs::{JobEvent, JobKind, RunningJob};
use crate::msg::Msg;
use crate::root;
use crate::satellites::{self, SatelliteId};
use crate::theme::{self, Palette, ThemeMode};
use std::path::PathBuf;
use std::time::Duration;

/// Where the operator is (view chrome; kept in sync with [`Phase`]).
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Screen {
    Home,
    Output,
    Help,
}

/// Grok dock layout relative to main chrome (orthogonal region).
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum GrokMode {
    Hidden,
    Split,
    Full,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Focus {
    Main,
    Output,
    GrokDock,
    Actions,
}

/// Application context (xstate machine context + invoked job handle).
pub struct App {
    pub root: PathBuf,
    /// Finite control state (Eagle FSM).
    pub phase: Phase,
    pub screen: Screen,
    pub grok_mode: GrokMode,
    pub focus: Focus,
    pub menu_idx: usize,
    pub should_quit: bool,
    pub status: String,
    pub breadcrumb: Vec<String>,
    pub theme: ThemeMode,

    pub lines: Vec<String>,
    pub scroll: u16,
    pub auto_scroll: bool,
    pub job: Option<RunningJob>,
    pub last_kind: Option<JobKind>,
    pub last_satellite: Option<SatelliteId>,
    pub last_exit: Option<i32>,
    pub next_actions: Vec<NextAction>,
    pub action_idx: usize,

    pub grok_context: String,
    pub grok_prompt: String,
    pub project_path: String,
    pub install_profile: String,
    pub catalog_query: String,
    pub actuate_pkg: String,

    pub pending_grok_launch: bool,
    /// Set when FireSatellite is requested; cleared when spawn assigns running.
    pub pending_satellite: Option<SatelliteId>,
}

impl App {
    pub fn new() -> Self {
        let root = root::discover_root();
        let theme = theme::detect_theme_mode();
        let mut app = Self {
            root: root.clone(),
            phase: Phase::Home,
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
            last_satellite: None,
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
            pending_satellite: None,
        };
        app.push_line(format!(
            "archy · eagle/TEA · theme={} · Enter run · g brief · ? help",
            app.theme.as_str()
        ));
        app.refresh_grok_context();
        app
    }

    pub fn palette(&self) -> Palette {
        theme::palette(self.theme)
    }

    pub fn menu_items(&self) -> Vec<&'static str> {
        satellites::menu_labels()
    }

    pub fn menu_len() -> usize {
        satellites::menu_len()
    }

    pub fn set_breadcrumb(&mut self, parts: &[&str]) {
        self.breadcrumb = parts.iter().map(|s| (*s).to_string()).collect();
    }

    pub fn push_line(&mut self, line: String) {
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

    /// TEA step: event → transition → effects.
    pub fn dispatch(&mut self, msg: Msg) -> Cmd {
        eagle::update(self, msg)
    }

    /// Execute effects (xstate invoked services / actions with side effects).
    pub fn perform(&mut self, cmd: Cmd) {
        match cmd {
            Cmd::None => {}
            Cmd::Quit => self.should_quit = true,
            Cmd::KillJob => self.kill_job(),
            Cmd::LaunchGrok { fullscreen: _ } => {
                // Flag already set in eagle; main suspends TUI.
                self.pending_grok_launch = true;
            }
            Cmd::FireSatellite(id) => self.fire_satellite(id),
        }
    }

    pub fn dispatch_key(&mut self, key: crossterm::event::KeyEvent) {
        let cmd = self.dispatch(Msg::Key(key));
        self.perform(cmd);
    }

    fn fire_satellite(&mut self, id: SatelliteId) {
        if self.job.is_some() {
            self.status = "Job already running — Ctrl+C to cancel".into();
            return;
        }
        let ctx = self.sat_context();
        let title = satellites::title(id, &ctx);
        let cmd = satellites::build(id, &ctx);
        eagle::assign_running(self, id, &title);
        self.job = Some(RunningJob::spawn(cmd));
    }

    fn kill_job(&mut self) {
        if let Some(mut j) = self.job.take() {
            j.kill();
            self.push_line("■ cancelled".into());
            self.status = "cancelled".into();
            let _ = self.dispatch(Msg::JobFinished {
                code: 1,
                elapsed_ms: 0,
            });
        }
    }

    /// Drain offline satellite channels → Msg (no heartbeats; poll outcome).
    pub fn tick(&mut self) {
        let mut finished: Option<(i32, u128)> = None;
        let mut spawn_fail: Option<String> = None;
        let mut lines_buf = Vec::new();

        if let Some(job) = self.job.as_mut() {
            while let Ok(ev) = job.rx.try_recv() {
                match ev {
                    JobEvent::Line(l) => lines_buf.push(l),
                    JobEvent::SpawnFailed(e) => spawn_fail = Some(e),
                }
            }
            if finished.is_none() {
                if let Some(code) = job.poll_exit() {
                    thread_sleep_drain(job, &mut lines_buf);
                    let elapsed = job.started.elapsed().as_millis();
                    finished = Some((code, elapsed));
                }
            }
        }

        for l in lines_buf {
            let _ = self.dispatch(Msg::JobLine(l));
        }

        if let Some(e) = spawn_fail {
            let cmd = self.dispatch(Msg::JobSpawnFailed(e));
            self.perform(cmd);
            return;
        }

        if let Some((code, elapsed_ms)) = finished {
            let cmd = self.dispatch(Msg::JobFinished { code, elapsed_ms });
            self.perform(cmd);
        }
    }

    pub fn sat_context(&self) -> satellites::SatContext<'_> {
        satellites::SatContext {
            root: &self.root,
            catalog_query: &self.catalog_query,
            project_path: &self.project_path,
            install_profile: &self.install_profile,
            actuate_pkg: &self.actuate_pkg,
        }
    }

    pub fn refresh_grok_context(&mut self) {
        let tail: Vec<&str> = self.lines.iter().rev().take(40).map(|s| s.as_str()).collect();
        let mut t = tail;
        t.reverse();
        let exit = self
            .last_exit
            .map(|c| c.to_string())
            .unwrap_or_else(|| if self.job.is_some() { "…".into() } else { "—".into() });
        let sat = self
            .last_satellite
            .map(|s| s.label())
            .unwrap_or("—");
        self.grok_context = format!(
            "archy phase={} sat={} exit={}\nroot={}\n\n--- stdio tail ---\n{}",
            self.phase.label(),
            sat,
            exit,
            self.root.display(),
            t.join("\n")
        );
    }

    pub fn suggested_grok_ask(&self) -> String {
        let sat = self.last_satellite.or_else(|| {
            self.last_kind.map(SatelliteId::from_job_kind)
        });
        let Some(id) = sat else {
            return "Orient on this arch-machine host; suggest the next dry-run maintenance step."
                .into();
        };
        let tail = self
            .lines
            .iter()
            .rev()
            .take(20)
            .cloned()
            .collect::<Vec<_>>()
            .into_iter()
            .rev()
            .collect::<Vec<_>>()
            .join("\n");
        satellites::grok_ask(id, self.last_exit, &self.sat_context(), &tail)
    }

    /// Build interactive Grok launch with **preloaded** prompt (not bare `grok`).
    /// `fullscreen` → `grok --fullscreen` (menu Launch / `G`).
    pub fn grok_launch_plan(&self, fullscreen: bool) -> Option<crate::grok_launch::GrokLaunchPlan> {
        let grok = which::which("grok").ok()?;
        let ctx = crate::grok_launch::context_file_path(&self.root);
        let ask = self.suggested_grok_ask();
        Some(crate::grok_launch::plan_launch(
            grok,
            &self.root,
            &ask,
            &ctx,
            &self.grok_prompt,
            fullscreen,
            crate::grok_launch::GrokLaunchMode::Interactive,
        ))
    }

    pub fn grok_launch_command(&self, fullscreen: bool) -> Option<std::process::Command> {
        Some(self.grok_launch_plan(fullscreen)?.to_command())
    }
}

fn default_grok_prompt() -> String {
    "You are co-pilot for arch-machine/archy. Prefer dry-run, evidence, and explicit next steps."
        .into()
}

fn short_path(p: &std::path::Path) -> String {
    let s = p.display().to_string();
    if s.len() <= 48 {
        s
    } else {
        format!("…{}", &s[s.len() - 45..])
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

