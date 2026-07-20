//! Pure focus / job-state helpers (unit-tested; no terminal I/O).

use crate::app::{Focus, GrokMode, Screen};

/// Short job state for header chrome (at-a-glance).
/// Exit codes align with security-audit policy: 0 clean, 1 warn, ≥2 fail.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum JobState {
    Idle,
    Running,
    Ok,
    /// Soft non-zero (e.g. audit WARN-only exit=1).
    Warn,
    Fail,
}

impl JobState {
    pub fn from_runtime(job_running: bool, last_exit: Option<i32>) -> Self {
        if job_running {
            JobState::Running
        } else if let Some(c) = last_exit {
            match c {
                0 => JobState::Ok,
                1 => JobState::Warn,
                _ => JobState::Fail,
            }
        } else {
            JobState::Idle
        }
    }

    /// Compact glyph + word for header (no prose).
    pub fn label(self) -> &'static str {
        match self {
            JobState::Idle => "○ idle",
            JobState::Running => "● RUN",
            JobState::Ok => "✓ ok",
            JobState::Warn => "! warn",
            JobState::Fail => "✗ fail",
        }
    }
}

/// Tab focus cycle — pure transition table.
pub fn tab_next_focus(
    current: Focus,
    grok_mode: GrokMode,
    has_actions: bool,
) -> Focus {
    let grok = grok_mode != GrokMode::Hidden;
    match current {
        Focus::Main => Focus::Output,
        Focus::Output => {
            if grok {
                Focus::GrokDock
            } else if has_actions {
                Focus::Actions
            } else {
                Focus::Main
            }
        }
        Focus::GrokDock => {
            if has_actions {
                Focus::Actions
            } else {
                Focus::Main
            }
        }
        Focus::Actions => Focus::Main,
    }
}

/// Esc behavior: leave Help/Output → Home; Full co-pilot → Split.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum EscEffect {
    GoHome,
    GrokFullToSplit,
    None,
}

pub fn esc_effect(screen: Screen, grok_mode: GrokMode) -> EscEffect {
    if screen != Screen::Home {
        EscEffect::GoHome
    } else if grok_mode == GrokMode::Full {
        EscEffect::GrokFullToSplit
    } else {
        EscEffect::None
    }
}

/// g-key: cycle Hidden ↔ Split; Full → Split.
pub fn toggle_grok_mode(mode: GrokMode) -> GrokMode {
    match mode {
        GrokMode::Hidden => GrokMode::Split,
        GrokMode::Split => GrokMode::Hidden,
        GrokMode::Full => GrokMode::Split,
    }
}

/// Compact one-line status for footer (no key legend wall).
pub fn footer_status(
    status: &str,
    focus: Focus,
    theme_label: &str,
) -> String {
    let focus_s = match focus {
        Focus::Main => "menu",
        Focus::Output => "stdio",
        Focus::GrokDock => "brief",
        Focus::Actions => "next",
    };
    // Keep status short
    let st = if status.len() > 40 {
        format!("{}…", &status[..39])
    } else {
        status.to_string()
    };
    format!("{st}  ·  {focus_s}  ·  {theme_label}")
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn job_state_labels() {
        assert_eq!(JobState::from_runtime(true, None), JobState::Running);
        assert_eq!(JobState::from_runtime(false, Some(0)), JobState::Ok);
        assert_eq!(JobState::from_runtime(false, Some(1)), JobState::Warn);
        assert_eq!(JobState::from_runtime(false, Some(2)), JobState::Fail);
        assert_eq!(JobState::from_runtime(false, None), JobState::Idle);
        assert_eq!(JobState::Running.label(), "● RUN");
        assert_eq!(JobState::Warn.label(), "! warn");
    }

    #[test]
    fn tab_cycle_without_grok_or_actions() {
        assert_eq!(
            tab_next_focus(Focus::Main, GrokMode::Hidden, false),
            Focus::Output
        );
        assert_eq!(
            tab_next_focus(Focus::Output, GrokMode::Hidden, false),
            Focus::Main
        );
    }

    #[test]
    fn tab_cycle_with_grok_and_actions() {
        assert_eq!(
            tab_next_focus(Focus::Output, GrokMode::Split, true),
            Focus::GrokDock
        );
        assert_eq!(
            tab_next_focus(Focus::GrokDock, GrokMode::Split, true),
            Focus::Actions
        );
        assert_eq!(
            tab_next_focus(Focus::Actions, GrokMode::Split, true),
            Focus::Main
        );
    }

    #[test]
    fn esc_and_toggle() {
        assert_eq!(
            esc_effect(Screen::Output, GrokMode::Hidden),
            EscEffect::GoHome
        );
        assert_eq!(
            esc_effect(Screen::Home, GrokMode::Full),
            EscEffect::GrokFullToSplit
        );
        assert_eq!(
            esc_effect(Screen::Home, GrokMode::Split),
            EscEffect::None
        );
        assert_eq!(toggle_grok_mode(GrokMode::Hidden), GrokMode::Split);
        assert_eq!(toggle_grok_mode(GrokMode::Split), GrokMode::Hidden);
        assert_eq!(toggle_grok_mode(GrokMode::Full), GrokMode::Split);
    }
}
