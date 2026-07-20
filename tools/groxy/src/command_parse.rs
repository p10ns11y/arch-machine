//! Pure inbound DM text → remote command recognition.
//! No network, no process spawn — unit-testable with synthetic fixtures.

use regex::Regex;
use std::sync::OnceLock;

/// Verbs that are safe to run without an extra confirm step.
///
/// **Watch (`run`):** operator-local inject may spawn `grok -p` with
/// `run_terminal_cmd` (deny only `rm*` / `sudo*`). That is acceptable while
/// inject is host-initiated. **Reclassify `run` as high-blast (or tighten tools)
/// before any inbound DM control path returns** (SN-GROXY-3 / review follow-up).
const SAFE_VERBS: &[&str] = &[
    "help", "ping", "status", "inventory", "audit", "omarchy", "run", "confirm", "whoami",
];

/// Verbs that may mutate the host and require confirm-token gating.
const HIGH_BLAST_VERBS: &[&str] = &[
    "pkg", "actuate", "install", "expand", "remediate", "apply", "rm", "delete", "reboot",
    "shutdown", "yolo",
];

/// Normalized remote command extracted from a DM body.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ParsedRemoteCommand {
    pub verb: String,
    pub arguments: String,
    pub raw_body: String,
    pub confirm_token: Option<String>,
}

impl ParsedRemoteCommand {
    pub fn command_line(&self) -> String {
        if self.arguments.is_empty() {
            self.verb.clone()
        } else {
            format!("{} {}", self.verb, self.arguments)
        }
    }

    pub fn is_high_blast(&self) -> bool {
        HIGH_BLAST_VERBS.iter().any(|v| *v == self.verb.as_str())
            || Regex::new(r"\b(rm|reboot|shutdown|format|dd)\b")
                .expect("static regex")
                .is_match(&self.command_line())
    }
}

fn control_prefix_regex() -> &'static Regex {
    static RE: OnceLock<Regex> = OnceLock::new();
    RE.get_or_init(|| {
        Regex::new(r"(?i)^\s*(?:!g(?:roxy)?|groxy|/groxy|@?groxy)\s*[:\s]?\s*")
            .expect("control prefix regex")
    })
}

fn confirm_regex() -> &'static Regex {
    static RE: OnceLock<Regex> = OnceLock::new();
    RE.get_or_init(|| {
        Regex::new(r"(?i)^\s*confirm\s+([A-Za-z0-9_-]+)\s*(.*)$").expect("confirm regex")
    })
}

/// True for packages we already sent back (must not re-enter as commands).
pub fn is_outbound_noise(text: &str) -> bool {
    let trimmed = text.trim();
    if trimmed.is_empty() {
        return true;
    }
    if trimmed.starts_with("groxy OK:") || trimmed.starts_with("groxy FAIL:") {
        return true;
    }
    if trimmed.starts_with("✓ Done:") || trimmed.starts_with("✗ Failed:") {
        return true;
    }
    if trimmed.starts_with("── visual ──") || trimmed.contains('╔') {
        return true;
    }
    if trimmed.starts_with("[media]") || trimmed.starts_with("PR: https://") {
        return true;
    }
    false
}

pub fn has_control_prefix(text: &str) -> bool {
    let without_emoji = text.trim().trim_start_matches('🤖').trim_start();
    control_prefix_regex().is_match(without_emoji)
}

pub fn strip_control_prefix(text: &str) -> String {
    let without_emoji = text.trim().trim_start_matches('🤖').trim_start();
    control_prefix_regex()
        .replace(without_emoji, "")
        .trim()
        .to_string()
}

fn alias_verb(verb: &str) -> &str {
    match verb {
        "inv" => "inventory",
        "?" => "help",
        other => other,
    }
}

fn is_known_verb(verb: &str) -> bool {
    SAFE_VERBS.iter().any(|v| *v == verb) || HIGH_BLAST_VERBS.iter().any(|v| *v == verb)
}

/// Parse DM body into a command. Free-form chat without `!g` / known verb → `None`.
pub fn parse_dm_text(text: &str) -> Option<ParsedRemoteCommand> {
    if is_outbound_noise(text) {
        return None;
    }
    let prefixed = has_control_prefix(text);
    let body = strip_control_prefix(text);
    if body.is_empty() || is_outbound_noise(&body) {
        return None;
    }
    if body.starts_with("http://") || body.starts_with("https://") {
        return None;
    }

    if let Some(captures) = confirm_regex().captures(&body) {
        let token = captures.get(1)?.as_str().to_string();
        let rest = captures.get(2).map(|m| m.as_str().trim()).unwrap_or("");
        if rest.is_empty() {
            return Some(ParsedRemoteCommand {
                verb: "confirm".into(),
                arguments: String::new(),
                raw_body: body,
                confirm_token: Some(token),
            });
        }
        let mut parts = rest.splitn(2, char::is_whitespace);
        let verb = alias_verb(parts.next()?.to_lowercase().trim_start_matches('/')).to_string();
        let arguments = parts.next().unwrap_or("").trim().to_string();
        return Some(ParsedRemoteCommand {
            verb,
            arguments,
            raw_body: body,
            confirm_token: Some(token),
        });
    }

    let mut parts = body.splitn(2, char::is_whitespace);
    let first = parts.next()?.to_lowercase();
    let verb = alias_verb(first.trim_start_matches('/')).to_string();
    let arguments = parts.next().unwrap_or("").trim().to_string();

    if is_known_verb(&verb) {
        return Some(ParsedRemoteCommand {
            verb,
            arguments,
            raw_body: body,
            confirm_token: None,
        });
    }

    // Free-form → run only with explicit control prefix
    if prefixed {
        return Some(ParsedRemoteCommand {
            verb: "run".into(),
            arguments: body.clone(),
            raw_body: body,
            confirm_token: None,
        });
    }

    None
}

/// One X API dm_event shaped as JSON-friendly fields.
#[derive(Debug, Clone, serde::Deserialize, serde::Serialize)]
pub struct DirectMessageEvent {
    pub id: Option<String>,
    pub text: Option<String>,
    #[serde(default)]
    pub event_type: Option<String>,
    pub sender_id: Option<String>,
    pub dm_conversation_id: Option<String>,
    #[serde(default)]
    pub is_public_post: bool,
    #[serde(default)]
    pub source: Option<String>,
}

impl DirectMessageEvent {
    pub fn event_id(&self) -> Option<&str> {
        self.id.as_deref()
    }

    pub fn sender_id_str(&self) -> Option<&str> {
        self.sender_id.as_deref()
    }

    pub fn is_public_shaped(&self) -> bool {
        self.is_public_post || self.source.as_deref() == Some("tweet")
    }

    pub fn parse_command(&self) -> Option<ParsedRemoteCommand> {
        parse_dm_text(self.text.as_deref().unwrap_or(""))
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_status_with_prefix() {
        let command = parse_dm_text("!g status").expect("command");
        assert_eq!(command.verb, "status");
    }

    #[test]
    fn free_chat_is_not_a_command() {
        assert!(parse_dm_text("I have lost MFA for Grok not for X").is_none());
    }

    #[test]
    fn prefixed_freeform_becomes_run() {
        let command = parse_dm_text("!g how much disk free").expect("command");
        assert_eq!(command.verb, "run");
        assert!(command.arguments.contains("disk"));
    }

    #[test]
    fn outbound_noise_ignored() {
        assert!(parse_dm_text("✓ Done: ping\n• Reachable").is_none());
    }

    #[test]
    fn confirm_token_parsed() {
        let command = parse_dm_text("confirm deadbeef pkg install foo").expect("command");
        assert_eq!(command.confirm_token.as_deref(), Some("deadbeef"));
        assert_eq!(command.verb, "pkg");
    }
}
