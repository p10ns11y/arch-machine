//! Events for the Eagle state machine (xstate-style *events*).
//!
//! All operator and system inputs become a closed set of messages.
//! Runtime adapters (key poll, job drain) produce these; they never mutate Model directly.

use crate::actions::ActionId;
use crate::satellites::SatelliteId;
use crossterm::event::KeyEvent;

/// Closed event set — Eagle's transition table keys on this.
/// High-level intents are for tests/agents; the key adapter emits many of them
/// indirectly via menu activation.
#[derive(Debug, Clone)]
#[allow(dead_code)] // public TEA event API; not all constructed from keyboard path
pub enum Msg {
    /// Raw key from terminal (decoded further inside update by focus/phase).
    Key(KeyEvent),
    /// Offline satellite stdio line.
    JobLine(String),
    /// Offline satellite finished (exit polled; no heartbeat).
    JobFinished { code: i32, elapsed_ms: u128 },
    /// Spawn failed before any lines.
    JobSpawnFailed(String),
    /// Explicit internal intents (tests + high-level menu).
    ActivateMenu(usize),
    RunAction(ActionId),
    FireSatellite(SatelliteId),
    GoHome,
    OpenHelp,
    ToggleBrief,
    LaunchGrok { fullscreen: bool },
    Quit,
}
