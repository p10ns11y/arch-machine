//! Eagle — thin TEA update + xstate-style transition table.
//!
//! Routes messages; domain work is delegated to satellites via [`Cmd`].
//! Does not spawn processes or touch the terminal.

use crate::actions::ActionId;
use crate::app::{App, Focus, GrokMode, Screen};
use crate::cmd::Cmd;
use crate::fsm::Phase;
use crate::msg::Msg;
use crate::nav::{self, EscEffect};
use crate::satellites::{self, MenuAction, SatelliteId, MENU};
use crossterm::event::{KeyCode, KeyEvent, KeyModifiers};

/// Pure-ish transition: mutate model context, return effects to invoke.
pub fn update(app: &mut App, msg: Msg) -> Cmd {
    match msg {
        Msg::Key(key) => update_key(app, key),
        Msg::JobLine(line) => {
            app.push_line(line);
            Cmd::None
        }
        Msg::JobFinished { code, elapsed_ms } => on_job_finished(app, code, elapsed_ms),
        Msg::JobSpawnFailed(e) => {
            app.push_line(format!("✗ spawn failed: {e}"));
            app.job = None;
            finish_as_review(app, 1);
            Cmd::None
        }
        Msg::ActivateMenu(idx) => activate_menu_idx(app, idx),
        Msg::RunAction(id) => run_action(app, id),
        Msg::FireSatellite(id) => request_fire(app, id),
        Msg::GoHome => {
            go_home(app);
            Cmd::None
        }
        Msg::OpenHelp => {
            app.phase = Phase::Help;
            app.screen = Screen::Help;
            app.set_breadcrumb(&["Home", "Help"]);
            Cmd::None
        }
        Msg::ToggleBrief => {
            toggle_grok_brief(app);
            Cmd::None
        }
        Msg::LaunchGrok { fullscreen } => {
            prepare_grok_launch(app, fullscreen);
            Cmd::LaunchGrok { fullscreen }
        }
        Msg::Quit => Cmd::Quit,
    }
}

fn update_key(app: &mut App, key: KeyEvent) -> Cmd {
    if key.modifiers.contains(KeyModifiers::CONTROL) && key.code == KeyCode::Char('c') {
        if app.job.is_some() {
            return Cmd::KillJob;
        }
        return Cmd::Quit;
    }

    // Global keys (any phase)
    match key.code {
        KeyCode::Char('q')
            if app.phase == Phase::Home && app.focus == Focus::Main && app.job.is_none() =>
        {
            return Cmd::Quit;
        }
        KeyCode::Char('?') => {
            app.phase = Phase::Help;
            app.screen = Screen::Help;
            app.set_breadcrumb(&["Home", "Help"]);
            return Cmd::None;
        }
        KeyCode::Char('g') => {
            toggle_grok_brief(app);
            return Cmd::None;
        }
        KeyCode::Char('G') => {
            prepare_grok_launch(app, true);
            return Cmd::LaunchGrok { fullscreen: true };
        }
        KeyCode::Esc => {
            match nav::esc_effect(app.screen, app.grok_mode) {
                EscEffect::GoHome => go_home(app),
                EscEffect::GrokFullToSplit => app.grok_mode = GrokMode::Split,
                EscEffect::None => {}
            }
            return Cmd::None;
        }
        KeyCode::Tab => {
            app.focus = nav::tab_next_focus(
                app.focus,
                app.grok_mode,
                !app.next_actions.is_empty(),
            );
            return Cmd::None;
        }
        _ => {}
    }

    if app.phase == Phase::Help {
        if matches!(
            key.code,
            KeyCode::Esc | KeyCode::Enter | KeyCode::Char('h')
        ) {
            go_home(app);
        }
        return Cmd::None;
    }

    // Co-pilot brief focused
    if app.focus == Focus::GrokDock {
        if matches!(key.code, KeyCode::Enter | KeyCode::Char(' ')) {
            prepare_grok_launch(app, false);
            return Cmd::LaunchGrok { fullscreen: false };
        }
    }

    // Next-action keys (Review phase or residual bar)
    if !app.next_actions.is_empty() {
        match key.code {
            KeyCode::Left if app.focus == Focus::Actions => {
                app.action_idx = app.action_idx.saturating_sub(1);
                return Cmd::None;
            }
            KeyCode::Right if app.focus == Focus::Actions => {
                if app.action_idx + 1 < app.next_actions.len() {
                    app.action_idx += 1;
                }
                return Cmd::None;
            }
            KeyCode::Enter if app.focus == Focus::Actions => {
                let id = app.next_actions[app.action_idx].id;
                return run_action(app, id);
            }
            KeyCode::Char(c)
                if app.next_actions.iter().any(|a| a.key == c)
                    && !(app.phase == Phase::Home
                        && app.focus == Focus::Main
                        && c.is_ascii_digit()) =>
            {
                if let Some(a) = app.next_actions.iter().find(|a| a.key == c).map(|a| a.id) {
                    return run_action(app, a);
                }
            }
            _ => {}
        }
    }

    // Scroll output when focus is Output (Running / Review stdio).
    if app.focus == Focus::Output {
        match key.code {
            KeyCode::Up | KeyCode::Char('k') => {
                app.auto_scroll = false;
                app.scroll = app.scroll.saturating_sub(1);
                return Cmd::None;
            }
            KeyCode::Down | KeyCode::Char('j') => {
                app.scroll = (app.scroll + 1).min(app.lines.len().saturating_sub(1) as u16);
                return Cmd::None;
            }
            KeyCode::PageUp => {
                app.auto_scroll = false;
                app.scroll = app.scroll.saturating_sub(10);
                return Cmd::None;
            }
            KeyCode::PageDown => {
                app.scroll =
                    (app.scroll + 10).min(app.lines.len().saturating_sub(1) as u16);
                return Cmd::None;
            }
            KeyCode::Char(' ') if app.job.is_none() => {
                app.auto_scroll = true;
                app.scroll = app.lines.len().saturating_sub(1) as u16;
                return Cmd::None;
            }
            _ => {}
        }
    }

    // Home menu
    if app.phase == Phase::Home && app.focus == Focus::Main {
        match key.code {
            KeyCode::Up | KeyCode::Char('k') => {
                app.menu_idx = app.menu_idx.saturating_sub(1);
            }
            KeyCode::Down | KeyCode::Char('j') => {
                if app.menu_idx + 1 < MENU.len() {
                    app.menu_idx += 1;
                }
            }
            KeyCode::Enter | KeyCode::Char(' ') => {
                return activate_menu_idx(app, app.menu_idx);
            }
            KeyCode::Char(c) if c.is_ascii_digit() => {
                let n = c.to_digit(10).unwrap_or(0) as usize;
                if n >= 1 && n <= MENU.len() {
                    app.menu_idx = n - 1;
                    return activate_menu_idx(app, app.menu_idx);
                }
            }
            _ => {}
        }
    }

    Cmd::None
}

fn activate_menu_idx(app: &mut App, idx: usize) -> Cmd {
    let Some(entry) = MENU.get(idx) else {
        return Cmd::None;
    };
    match entry.action {
        MenuAction::Satellite(id) => request_fire(app, id),
        MenuAction::ToggleBrief => {
            toggle_grok_brief(app);
            Cmd::None
        }
        MenuAction::LaunchGrok => {
            prepare_grok_launch(app, true);
            Cmd::LaunchGrok { fullscreen: true }
        }
        MenuAction::Help => {
            app.phase = Phase::Help;
            app.screen = Screen::Help;
            app.set_breadcrumb(&["Home", "Help"]);
            Cmd::None
        }
        MenuAction::Quit => Cmd::Quit,
    }
}

fn request_fire(app: &mut App, id: SatelliteId) -> Cmd {
    if app.job.is_some() {
        app.status = "Job already running — Ctrl+C to cancel".into();
        return Cmd::None;
    }
    // Assign context for running; runtime performs spawn.
    app.pending_satellite = Some(id);
    Cmd::FireSatellite(id)
}

/// Runtime calls this after successful spawn setup assignments.
pub fn assign_running(app: &mut App, id: SatelliteId, title: &str) {
    app.lines.clear();
    app.scroll = 0;
    app.auto_scroll = true;
    app.last_exit = None;
    app.next_actions.clear();
    app.phase = Phase::Running { sat: id };
    app.screen = Screen::Output;
    app.focus = Focus::Output;
    app.set_breadcrumb(&["Home", id.label()]);
    app.push_line(format!("▶ starting: {title}"));
    app.push_line(format!(
        "  sat={}  root={}",
        id.label(),
        app.root.display()
    ));
    app.push_line(String::new());
    app.status = format!("running: {title}");
    app.last_kind = Some(id.job_kind());
    app.last_satellite = Some(id);
    app.pending_satellite = None;
    app.refresh_grok_context();
}

fn on_job_finished(app: &mut App, code: i32, elapsed_ms: u128) -> Cmd {
    app.job = None;
    app.push_line(String::new());
    app.push_line(format!("■ finished exit={code} elapsed={elapsed_ms}ms"));
    finish_as_review(app, code);
    Cmd::None
}

fn finish_as_review(app: &mut App, code: i32) {
    app.last_exit = Some(code);
    let sat = app
        .last_satellite
        .or_else(|| app.last_kind.map(SatelliteId::from_job_kind))
        .unwrap_or(SatelliteId::Inventory);
    let plan = satellites::on_finished(sat, code, &app.lines);
    app.next_actions = plan.next_actions;
    app.action_idx = 0;
    app.focus = Focus::Actions;
    app.phase = Phase::Review { sat };
    app.screen = Screen::Output;
    app.status = plan.status;
    app.refresh_grok_context();
}

fn go_home(app: &mut App) {
    app.phase = Phase::Home;
    app.screen = Screen::Home;
    app.focus = Focus::Main;
    app.set_breadcrumb(&["Home"]);
    app.status = format!("ready · {}", short_path(&app.root));
}

fn toggle_grok_brief(app: &mut App) {
    app.grok_mode = nav::toggle_grok_mode(app.grok_mode);
    app.refresh_grok_context();
    match app.grok_mode {
        GrokMode::Hidden => {
            if app.focus == Focus::GrokDock {
                app.focus = Focus::Main;
            }
            app.status = "brief:off".into();
        }
        GrokMode::Split | GrokMode::Full => {
            app.focus = Focus::GrokDock;
            app.status = "brief:on · Enter=launch".into();
        }
    }
}

fn prepare_grok_launch(app: &mut App, fullscreen: bool) {
    app.refresh_grok_context();
    if fullscreen {
        app.grok_mode = GrokMode::Full;
    } else if app.grok_mode == GrokMode::Hidden {
        app.grok_mode = GrokMode::Split;
    }
    app.pending_grok_launch = true;
    app.status = "launching Grok (TUI suspends)…".into();
}

fn run_action(app: &mut App, id: ActionId) -> Cmd {
    match id {
        ActionId::BackHome => {
            go_home(app);
            Cmd::None
        }
        ActionId::ReRun => {
            if let Some(sat) = app.last_satellite {
                return request_fire(app, sat);
            }
            if let Some(kind) = app.last_kind {
                return request_fire(app, SatelliteId::from_job_kind(kind));
            }
            Cmd::None
        }
        ActionId::LaunchGrok => {
            prepare_grok_launch(app, false);
            Cmd::LaunchGrok { fullscreen: false }
        }
        ActionId::OpenInventory
        | ActionId::RunAudit
        | ActionId::RunEvidence
        | ActionId::InstallDry
        | ActionId::ActuateDry => {
            if let Some(sat) = satellites::action_to_satellite(id) {
                request_fire(app, sat)
            } else {
                Cmd::None
            }
        }
    }
}

fn short_path(p: &std::path::Path) -> String {
    let s = p.display().to_string();
    if s.len() <= 48 {
        s
    } else {
        format!("…{}", &s[s.len() - 45..])
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::msg::Msg;
    use crossterm::event::{KeyCode, KeyEvent, KeyEventKind, KeyEventState, KeyModifiers};

    fn key(c: char) -> KeyEvent {
        KeyEvent {
            code: KeyCode::Char(c),
            modifiers: KeyModifiers::NONE,
            kind: KeyEventKind::Press,
            state: KeyEventState::NONE,
        }
    }

    #[test]
    fn quit_from_home() {
        let mut app = App::new();
        app.phase = Phase::Home;
        app.focus = Focus::Main;
        let cmd = update(&mut app, Msg::Key(key('q')));
        assert_eq!(cmd, Cmd::Quit);
    }

    #[test]
    fn help_transition() {
        let mut app = App::new();
        let cmd = update(&mut app, Msg::Key(key('?')));
        assert!(cmd.is_none());
        assert_eq!(app.phase, Phase::Help);
        assert_eq!(app.screen, Screen::Help);
    }

    #[test]
    fn fire_inventory_from_menu() {
        let mut app = App::new();
        app.menu_idx = 0;
        let cmd = update(&mut app, Msg::ActivateMenu(0));
        assert_eq!(cmd, Cmd::FireSatellite(SatelliteId::Inventory));
    }

    #[test]
    fn job_finished_to_review() {
        let mut app = App::new();
        app.last_satellite = Some(SatelliteId::Inventory);
        app.last_kind = Some(crate::jobs::JobKind::Inventory);
        app.push_line(
            "summary: explicit=1 tools_yaml_ok=1 tools_yaml_miss=0 upgradable=0 mise=0".into(),
        );
        let cmd = update(
            &mut app,
            Msg::JobFinished {
                code: 0,
                elapsed_ms: 10,
            },
        );
        assert!(cmd.is_none());
        assert!(matches!(app.phase, Phase::Review { sat: SatelliteId::Inventory }));
        assert!(!app.next_actions.is_empty());
        assert_eq!(app.next_actions[0].id, ActionId::RunAudit);
    }

    #[test]
    fn esc_from_help_home() {
        let mut app = App::new();
        app.phase = Phase::Help;
        app.screen = Screen::Help;
        let _ = update(&mut app, Msg::Key(KeyEvent {
            code: KeyCode::Esc,
            modifiers: KeyModifiers::NONE,
            kind: KeyEventKind::Press,
            state: KeyEventState::NONE,
        }));
        assert_eq!(app.phase, Phase::Home);
    }
}
