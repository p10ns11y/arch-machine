//! DM I/O adapters: dry-run file sinks and live `xurl` transport.

use crate::command_parse::DirectMessageEvent;
use serde::Deserialize;
use std::fs;
use std::path::{Path, PathBuf};
use std::process::Command;
use thiserror::Error;

#[derive(Debug, Error)]
pub enum DirectMessageError {
    #[error("xurl not found on PATH")]
    XurlMissing,
    #[error("xurl dm_events failed: {0}")]
    ListFailed(String),
    #[error("xurl rate limited (429); wait ~{sleep_seconds}s")]
    RateLimited { sleep_seconds: u64 },
    #[error("json error: {0}")]
    Json(#[from] serde_json::Error),
    #[error("io error: {0}")]
    Io(#[from] std::io::Error),
}

#[derive(Debug, Deserialize)]
struct DmEventsResponse {
    data: Option<Vec<DirectMessageEvent>>,
}

/// Authenticated X account (runtime only — never committed).
#[derive(Debug, Clone)]
pub struct AuthenticatedIdentity {
    pub user_id: String,
    pub username: String,
}

pub fn resolve_xurl_binary() -> Option<PathBuf> {
    which_binary("xurl")
}

fn which_binary(name: &str) -> Option<PathBuf> {
    if let Ok(custom) = std::env::var("XURL_BIN") {
        let path = PathBuf::from(&custom);
        if path.is_file() {
            return Some(path);
        }
    }
    let path_var = std::env::var_os("PATH")?;
    for directory in std::env::split_paths(&path_var) {
        let candidate = directory.join(name);
        if candidate.is_file() {
            return Some(candidate);
        }
    }
    None
}

pub fn fetch_authenticated_identity() -> Option<AuthenticatedIdentity> {
    let xurl = resolve_xurl_binary()?;
    let output = Command::new(xurl)
        .arg("/2/users/me")
        .output()
        .ok()?;
    if !output.status.success() {
        return None;
    }
    let text = String::from_utf8_lossy(&output.stdout);
    let json_start = text.find('{')?;
    let value: serde_json::Value = serde_json::from_str(&text[json_start..]).ok()?;
    let data = value.get("data")?;
    let user_id = data.get("id")?.as_str()?.to_string();
    let username = data.get("username")?.as_str()?.to_string();
    if user_id.is_empty() || username.is_empty() {
        return None;
    }
    Some(AuthenticatedIdentity { user_id, username })
}

/// Dry-run: read fixture events; write outbound sends to a directory.
pub struct DryRunDirectMessageAdapter {
    pub fixture_path: Option<PathBuf>,
    pub send_directory: PathBuf,
    pub send_count: usize,
}

impl DryRunDirectMessageAdapter {
    pub fn new(fixture_path: Option<PathBuf>, send_directory: PathBuf) -> Self {
        let _ = fs::create_dir_all(&send_directory);
        Self {
            fixture_path,
            send_directory,
            send_count: 0,
        }
    }

    pub fn list_events(&self, max_results: usize) -> Result<Vec<DirectMessageEvent>, DirectMessageError> {
        let Some(path) = &self.fixture_path else {
            return Ok(Vec::new());
        };
        if !path.is_file() {
            return Ok(Vec::new());
        }
        let text = fs::read_to_string(path)?;
        let response: DmEventsResponse = serde_json::from_str(&text)?;
        let mut events = response.data.unwrap_or_default();
        events.truncate(max_results.max(1));
        Ok(events)
    }

    pub fn send_text(
        &mut self,
        recipient: &str,
        text: &str,
    ) -> Result<serde_json::Value, DirectMessageError> {
        let index = self.send_count;
        self.send_count += 1;
        let entry = serde_json::json!({
            "recipient": recipient,
            "text": text,
            "mode": "dry-run",
        });
        fs::write(
            self.send_directory.join(format!("send-{index:04}.json")),
            serde_json::to_string_pretty(&entry)?,
        )?;
        fs::write(
            self.send_directory.join(format!("send-{index:04}.txt")),
            text,
        )?;
        Ok(entry)
    }
}

/// Live DM I/O via `xurl`.
pub struct XurlDirectMessageAdapter {
    pub xurl_binary: PathBuf,
}

impl XurlDirectMessageAdapter {
    pub fn new() -> Result<Self, DirectMessageError> {
        let xurl_binary = resolve_xurl_binary().ok_or(DirectMessageError::XurlMissing)?;
        Ok(Self { xurl_binary })
    }

    pub fn list_events(
        &self,
        max_results: usize,
    ) -> Result<Vec<DirectMessageEvent>, DirectMessageError> {
        let max_results = max_results.clamp(1, 25);
        let url = format!(
            "/2/dm_events?dm_event.fields=id,text,event_type,created_at,sender_id,dm_conversation_id&max_results={max_results}"
        );
        let output = Command::new(&self.xurl_binary)
            .args(["-v", &url])
            .output()
            .map_err(|error| DirectMessageError::ListFailed(error.to_string()))?;
        let stdout = String::from_utf8_lossy(&output.stdout);
        let stderr = String::from_utf8_lossy(&output.stderr);
        let combined = format!("{stderr}\n{stdout}");
        if !output.status.success() {
            if combined.contains("429") || combined.contains("Too Many Requests") {
                let sleep_seconds = parse_rate_limit_sleep_seconds(&combined).unwrap_or(90);
                return Err(DirectMessageError::RateLimited { sleep_seconds });
            }
            return Err(DirectMessageError::ListFailed(
                stderr.trim().to_string().if_empty(|| stdout.trim().to_string()),
            ));
        }
        let json_slice = extract_json_object(&stdout).ok_or_else(|| {
            DirectMessageError::ListFailed("no JSON in xurl stdout".into())
        })?;
        let response: DmEventsResponse = serde_json::from_str(json_slice)?;
        Ok(response.data.unwrap_or_default())
    }

    pub fn send_text(
        &self,
        recipient: &str,
        text: &str,
    ) -> Result<serde_json::Value, DirectMessageError> {
        let output = Command::new(&self.xurl_binary)
            .args(["dm", recipient, text])
            .output()
            .map_err(|error| DirectMessageError::ListFailed(error.to_string()))?;
        let combined = format!(
            "{}{}",
            String::from_utf8_lossy(&output.stdout),
            String::from_utf8_lossy(&output.stderr)
        );
        Ok(serde_json::json!({
            "ok": output.status.success(),
            "exit_code": output.status.code(),
            "output": combined.trim(),
            "recipient": recipient,
            "dry_run": false,
        }))
    }
}

fn extract_json_object(text: &str) -> Option<&str> {
    let start = text.find('{')?;
    Some(&text[start..])
}

fn parse_rate_limit_sleep_seconds(blob: &str) -> Option<u64> {
    for line in blob.lines() {
        if let Some(rest) = line
            .split_once("X-Rate-Limit-Reset:")
            .map(|(_, r)| r.trim())
        {
            if let Ok(reset_unix) = rest.parse::<i64>() {
                let now = chrono::Utc::now().timestamp();
                let wait = (reset_unix - now + 3).max(5) as u64;
                return Some(wait);
            }
        }
    }
    None
}

trait IfEmpty {
    fn if_empty(self, f: impl FnOnce() -> String) -> String;
}

impl IfEmpty for String {
    fn if_empty(self, f: impl FnOnce() -> String) -> String {
        if self.is_empty() {
            f()
        } else {
            self
        }
    }
}

/// Write a copy of outbound payload under work dir for evidence.
pub fn archive_outbound_payload(
    package_directory: &Path,
    body: &str,
) -> std::io::Result<PathBuf> {
    fs::create_dir_all(package_directory)?;
    let path = package_directory.join("dm_payload.txt");
    fs::write(&path, body)?;
    Ok(path)
}
