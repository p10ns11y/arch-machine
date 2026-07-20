//! Eagle finite-state machine (xstate-inspired).
//!
//! - **States** = [`Phase`] (finite, named)
//! - **Context** = remaining `App` fields (lines, menu_idx, theme, …)
//! - **Events** = [`crate::msg::Msg`]
//! - **Actions / services** = [`crate::cmd::Cmd`] (invoked actors for offline jobs)
//! - **Guards** = phase + focus + job presence checks inside transitions
//!
//! Hierarchical flavor: co-pilot brief is orthogonal layout (`GrokMode`), not a phase.
//! Job lifecycle is a child region: Home → Running → Review (DAG edge on finished).

use crate::satellites::SatelliteId;

/// Named control-plane states (xstate `states`).
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Phase {
    /// Menu / idle operator surface.
    Home,
    /// Help overlay (teaching text only here).
    Help,
    /// Offline satellite invoked; streaming stdio.
    Running { sat: SatelliteId },
    /// Job finished; primary NEXT bar active.
    Review { sat: SatelliteId },
}

impl Phase {
    pub fn label(self) -> &'static str {
        match self {
            Phase::Home => "home",
            Phase::Help => "help",
            Phase::Running { .. } => "running",
            Phase::Review { .. } => "review",
        }
    }

    #[cfg(test)]
    pub fn satellite(self) -> Option<SatelliteId> {
        match self {
            Phase::Running { sat } | Phase::Review { sat } => Some(sat),
            _ => None,
        }
    }
}

/// Transition table documentation (guards are code in `eagle::update`).
///
/// | From \ Event        | FireSat | JobFinished | Cancel | Esc/Home | Help | Quit |
/// |---------------------|---------|-------------|--------|----------|------|------|
/// | Home                | →Run    | —           | —      | stay     | →Help| exit |
/// | Running             | guard   | →Review     | →Review| →Home    | —    | —    |
/// | Review              | →Run    | —           | —      | →Home    | →Help| —    |
/// | Help                | —       | —           | —      | →Home    | stay | —    |
///
/// Offline satellite DAG (per fire):
/// `Fire → spawn → (JobLine)* → JobFinished → Review(next_actions) → optional re-Fire`

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn phase_labels_stable() {
        assert_eq!(Phase::Home.label(), "home");
        assert_eq!(
            Phase::Running {
                sat: SatelliteId::Inventory
            }
            .satellite(),
            Some(SatelliteId::Inventory)
        );
    }
}
