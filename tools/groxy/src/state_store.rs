//! Persistent seen-event ids + pending high-blast confirms.

use serde::{Deserialize, Serialize};
use std::collections::{BTreeMap, BTreeSet, VecDeque};
use std::fs;
use std::path::{Path, PathBuf};

const MAX_SEEN_EVENTS: usize = 500;

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct PendingConfirmGrant {
    pub token: String,
    pub verb: String,
    pub arguments: String,
    pub sender_id: String,
    pub created_at_unix: i64,
}

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct GroxyState {
    pub seen_event_ids: VecDeque<String>,
    pub pending_confirms: BTreeMap<String, PendingConfirmGrant>,
    // last_poll_at removed with live DM poll (SN-GROXY-1); old JSON keys ignored on load
}

impl GroxyState {
    pub fn has_seen(&self, event_id: &str) -> bool {
        self.seen_event_ids.iter().any(|id| id == event_id)
    }

    pub fn mark_seen(&mut self, event_id: &str) {
        if self.has_seen(event_id) {
            return;
        }
        self.seen_event_ids.push_back(event_id.to_string());
        while self.seen_event_ids.len() > MAX_SEEN_EVENTS {
            self.seen_event_ids.pop_front();
        }
    }

    pub fn add_pending(
        &mut self,
        verb: &str,
        arguments: &str,
        sender_id: &str,
    ) -> String {
        let token = format!("{:x}", chrono::Utc::now().timestamp_nanos_opt().unwrap_or(0) & 0xffff_ffff);
        self.pending_confirms.insert(
            token.clone(),
            PendingConfirmGrant {
                token: token.clone(),
                verb: verb.to_string(),
                arguments: arguments.to_string(),
                sender_id: sender_id.to_string(),
                created_at_unix: chrono::Utc::now().timestamp(),
            },
        );
        token
    }

    pub fn take_pending(&mut self, token: &str) -> Option<PendingConfirmGrant> {
        self.pending_confirms.remove(token)
    }
}

pub fn default_state_path() -> PathBuf {
    let home = std::env::var_os("HOME").map(PathBuf::from).unwrap_or_else(|| PathBuf::from("."));
    home.join(".local").join("state").join("groxy").join("state.json")
}

pub fn load_state(path: &Path) -> GroxyState {
    if !path.is_file() {
        return GroxyState::default();
    }
    match fs::read_to_string(path) {
        Ok(text) => serde_json::from_str(&text).unwrap_or_default(),
        Err(_) => GroxyState::default(),
    }
}

pub fn save_state(path: &Path, state: &GroxyState) -> std::io::Result<()> {
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent)?;
    }
    // Serialize seen as vec for JSON friendliness
    #[derive(Serialize)]
    struct Wire<'a> {
        seen_event_ids: Vec<&'a String>,
        pending: &'a BTreeMap<String, PendingConfirmGrant>,
    }
    let seen: Vec<&String> = state.seen_event_ids.iter().collect();
    let wire = Wire {
        seen_event_ids: seen,
        pending: &state.pending_confirms,
    };
    // Also accept reading old python shape
    let _ = BTreeSet::<String>::new();
    fs::write(path, serde_json::to_string_pretty(&wire)?)
}

/// Load state compatible with Python groxy `state.json` (seen_event_ids + pending).
pub fn load_state_compatible(path: &Path) -> GroxyState {
    if !path.is_file() {
        return GroxyState::default();
    }
    let Ok(text) = fs::read_to_string(path) else {
        return GroxyState::default();
    };
    let Ok(value) = serde_json::from_str::<serde_json::Value>(&text) else {
        return GroxyState::default();
    };
    let mut state = GroxyState::default();
    if let Some(ids) = value.get("seen_event_ids").and_then(|v| v.as_array()) {
        for id in ids {
            if let Some(s) = id.as_str() {
                state.seen_event_ids.push_back(s.to_string());
            }
        }
    }
    if let Some(pending) = value.get("pending").and_then(|v| v.as_object()) {
        for (token, grant) in pending {
            if let Ok(parsed) = serde_json::from_value::<PendingConfirmGrant>(grant.clone()) {
                state.pending_confirms.insert(token.clone(), parsed);
            }
        }
    }
    // Ignore legacy last_poll_at from poll-era state files
    let _ = value.get("last_poll_at");
    state
}
