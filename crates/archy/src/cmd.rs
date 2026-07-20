//! Effects / side-effects descriptors (xstate-style *actions* that invoke services).
//!
//! `eagle::update` is pure wrt process I/O: it only returns [`Cmd`].
//! The runtime (`main` / `App::perform`) executes them.

use crate::satellites::SatelliteId;

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum Cmd {
    None,
    /// Fire offline satellite: spawn shell backend, stream lines, later verify exit.
    FireSatellite(SatelliteId),
    /// Cancel running offline job.
    KillJob,
    /// Suspend TUI and run interactive Grok (side path).
    LaunchGrok { fullscreen: bool },
    Quit,
}

impl Cmd {
    pub fn is_none(&self) -> bool {
        matches!(self, Cmd::None)
    }
}
