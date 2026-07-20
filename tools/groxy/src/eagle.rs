//! Thin Eagle: route inbound DM events → offline host job → outbound package.
//! Domain work lives in host_job / dm_adapter; Eagle only decides and sequences.

use crate::allowlist::RemoteControlPolicy;
use crate::command_parse::{DirectMessageEvent, ParsedRemoteCommand};
use crate::host_job::{run_host_job, HostJobResult};
use crate::outcome_package::{self, OutboundPackage};
use crate::state_store::GroxyState;
use std::path::Path;

/// Why an event was accepted or rejected.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum DispatchOutcomeKind {
    AlreadySeen,
    PublicPostRejected,
    SenderNotAllowlisted,
    NoCommand,
    PendingConfirm,
    BadConfirm,
    ConfirmSenderMismatch,
    Ok,
    HostFailed,
}

/// Result of processing one DM event through the Eagle.
#[derive(Debug)]
pub struct EventDispatchResult {
    pub accepted: bool,
    pub kind: DispatchOutcomeKind,
    pub event_id: Option<String>,
    pub sender_id: Option<String>,
    pub command: Option<ParsedRemoteCommand>,
    pub host_result: Option<HostJobResult>,
    pub outbound_package: Option<OutboundPackage>,
    pub pending_token: Option<String>,
    pub package_directory: Option<std::path::PathBuf>,
}

/// Process one DM event (pure policy + offline host job + package write).
pub fn process_direct_message_event(
    event: &DirectMessageEvent,
    policy: &RemoteControlPolicy,
    state: &mut GroxyState,
    repository_root: &Path,
    effect_directory: &Path,
    package_directory_root: &Path,
    pull_request_url: Option<&str>,
    session_label: Option<&str>,
) -> EventDispatchResult {
    let event_id = event.event_id().map(str::to_string);
    let sender_id = event.sender_id_str().map(str::to_string);

    if let Some(ref id) = event_id {
        if state.has_seen(id) {
            return EventDispatchResult {
                accepted: false,
                kind: DispatchOutcomeKind::AlreadySeen,
                event_id,
                sender_id,
                command: None,
                host_result: None,
                outbound_package: None,
                pending_token: None,
                package_directory: None,
            };
        }
    }

    if event.is_public_shaped() {
        if let Some(ref id) = event_id {
            state.mark_seen(id);
        }
        return EventDispatchResult {
            accepted: false,
            kind: DispatchOutcomeKind::PublicPostRejected,
            event_id,
            sender_id,
            command: None,
            host_result: None,
            outbound_package: None,
            pending_token: None,
            package_directory: None,
        };
    }

    if !policy.allows_sender(sender_id.as_deref(), None) {
        if let Some(ref id) = event_id {
            state.mark_seen(id);
        }
        return EventDispatchResult {
            accepted: false,
            kind: DispatchOutcomeKind::SenderNotAllowlisted,
            event_id,
            sender_id,
            command: None,
            host_result: None,
            outbound_package: None,
            pending_token: None,
            package_directory: None,
        };
    }

    let Some(mut command) = event.parse_command() else {
        if let Some(ref id) = event_id {
            state.mark_seen(id);
        }
        return EventDispatchResult {
            accepted: false,
            kind: DispatchOutcomeKind::NoCommand,
            event_id,
            sender_id,
            command: None,
            host_result: None,
            outbound_package: None,
            pending_token: None,
            package_directory: None,
        };
    };

    // High-blast without confirm token → hold
    if policy.require_confirm_for_high_blast
        && command.is_high_blast()
        && command.confirm_token.is_none()
    {
        let token = state.add_pending(
            &command.verb,
            &command.arguments,
            sender_id.as_deref().unwrap_or(""),
        );
        if let Some(ref id) = event_id {
            state.mark_seen(id);
        }
        let message = format!(
            "high-blast `{}` held.\nReply: confirm {token} {} {}",
            command.verb, command.verb, command.arguments
        );
        let host_result = HostJobResult {
            succeeded: false,
            verb: command.verb.clone(),
            output_text: message.clone(),
            exit_code: 403,
            duration_seconds: 0.0,
            effect_log_path: None,
        };
        let package = outcome_package::build_outbound_package_with_session(
            &command.verb,
            false,
            &message,
            pull_request_url,
            session_label,
        );
        let package_dir = package_directory_root.join(format!(
            "evt-{}",
            event_id.as_deref().unwrap_or("pending")
        ));
        let _ = package.write_to_directory(&package_dir);
        return EventDispatchResult {
            accepted: true,
            kind: DispatchOutcomeKind::PendingConfirm,
            event_id,
            sender_id,
            command: Some(command),
            host_result: Some(host_result),
            outbound_package: Some(package),
            pending_token: Some(token),
            package_directory: Some(package_dir),
        };
    }

    let mut confirmed = false;
    if let Some(ref token) = command.confirm_token {
        match state.take_pending(token) {
            None => {
                if let Some(ref id) = event_id {
                    state.mark_seen(id);
                }
                let message = format!("unknown or expired token {token}");
                let package = outcome_package::build_outbound_package_with_session(
                    "confirm",
                    false,
                    &message,
                    pull_request_url,
                    session_label,
                );
                let package_dir = package_directory_root
                    .join(format!("evt-{}", event_id.as_deref().unwrap_or("bad-confirm")));
                let _ = package.write_to_directory(&package_dir);
                return EventDispatchResult {
                    accepted: true,
                    kind: DispatchOutcomeKind::BadConfirm,
                    event_id,
                    sender_id,
                    command: Some(command),
                    host_result: Some(HostJobResult {
                        succeeded: false,
                        verb: "confirm".into(),
                        output_text: message,
                        exit_code: 404,
                        duration_seconds: 0.0,
                        effect_log_path: None,
                    }),
                    outbound_package: Some(package),
                    pending_token: None,
                    package_directory: Some(package_dir),
                };
            }
            Some(grant) => {
                if !grant.sender_id.is_empty()
                    && sender_id.as_deref() != Some(grant.sender_id.as_str())
                {
                    if let Some(ref id) = event_id {
                        state.mark_seen(id);
                    }
                    let message = "token sender mismatch".to_string();
                    let package = outcome_package::build_outbound_package_with_session(
                        "confirm",
                        false,
                        &message,
                        pull_request_url,
                        session_label,
                    );
                    return EventDispatchResult {
                        accepted: true,
                        kind: DispatchOutcomeKind::ConfirmSenderMismatch,
                        event_id,
                        sender_id,
                        command: Some(command),
                        host_result: Some(HostJobResult {
                            succeeded: false,
                            verb: "confirm".into(),
                            output_text: message,
                            exit_code: 403,
                            duration_seconds: 0.0,
                            effect_log_path: None,
                        }),
                        outbound_package: Some(package),
                        pending_token: None,
                        package_directory: None,
                    };
                }
                if command.verb == "confirm" || command.arguments.is_empty() {
                    command = ParsedRemoteCommand {
                        verb: grant.verb,
                        arguments: grant.arguments,
                        raw_body: command.raw_body,
                        confirm_token: command.confirm_token,
                    };
                }
                confirmed = true;
            }
        }
    }

    if let Some(ref id) = event_id {
        state.mark_seen(id);
    }

    let _ = std::fs::create_dir_all(effect_directory);
    let host_result = run_host_job(
        &command.verb,
        &command.arguments,
        repository_root,
        effect_directory,
        confirmed,
    );
    let package = outcome_package::build_outbound_package_with_session(
        &command.verb,
        host_result.succeeded,
        &host_result.output_text,
        pull_request_url,
        session_label,
    );
    let package_dir = package_directory_root.join(format!(
        "evt-{}",
        event_id
            .clone()
            .unwrap_or_else(|| chrono::Utc::now().timestamp().to_string())
    ));
    let _ = package.write_to_directory(&package_dir);

    let kind = if host_result.succeeded {
        DispatchOutcomeKind::Ok
    } else {
        DispatchOutcomeKind::HostFailed
    };

    EventDispatchResult {
        accepted: true,
        kind,
        event_id,
        sender_id,
        command: Some(command),
        host_result: Some(host_result),
        outbound_package: Some(package),
        pending_token: None,
        package_directory: Some(package_dir),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::allowlist::RemoteControlPolicy;
    use crate::state_store::GroxyState;
    use std::collections::BTreeSet;

    #[test]
    fn rejects_untrusted_sender() {
        let policy = RemoteControlPolicy {
            allowlisted_user_ids: BTreeSet::from(["100001".into()]),
            allowlisted_usernames: BTreeSet::new(),
            require_confirm_for_high_blast: true,
        };
        let mut state = GroxyState::default();
        let event = DirectMessageEvent {
            id: Some("e1".into()),
            text: Some("status".into()),
            event_type: Some("MessageCreate".into()),
            sender_id: Some("999".into()),
            dm_conversation_id: None,
            is_public_post: false,
            source: None,
        };
        let dir = tempfile::tempdir().unwrap();
        let result = process_direct_message_event(
            &event,
            &policy,
            &mut state,
            Path::new("."),
            dir.path(),
            dir.path(),
            None,
            None,
        );
        assert!(!result.accepted);
        assert_eq!(result.kind, DispatchOutcomeKind::SenderNotAllowlisted);
    }

    #[test]
    fn allowlisted_ping_produces_package() {
        let policy = RemoteControlPolicy {
            allowlisted_user_ids: BTreeSet::from(["100001".into()]),
            allowlisted_usernames: BTreeSet::new(),
            require_confirm_for_high_blast: true,
        };
        let mut state = GroxyState::default();
        let event = DirectMessageEvent {
            id: Some("e-ping".into()),
            text: Some("!g ping".into()),
            event_type: Some("MessageCreate".into()),
            sender_id: Some("100001".into()),
            dm_conversation_id: Some("c1".into()),
            is_public_post: false,
            source: None,
        };
        let dir = tempfile::tempdir().unwrap();
        // repository root: walk up from CARGO_MANIFEST_DIR to arch-machine
        let repo = Path::new(env!("CARGO_MANIFEST_DIR"))
            .parent()
            .and_then(|p| p.parent())
            .unwrap_or(Path::new("."));
        let result = process_direct_message_event(
            &event,
            &policy,
            &mut state,
            repo,
            &dir.path().join("effects"),
            &dir.path().join("outbound"),
            Some("https://github.com/example/repo/pull/1"),
            Some("test-session"),
        );
        assert!(result.accepted);
        assert_eq!(result.kind, DispatchOutcomeKind::Ok);
        let package = result.outbound_package.expect("package");
        let body = package.direct_message_body(900);
        assert!(body.contains("Done: ping"));
        assert!(!body.to_lowercase().contains("host="));
        assert!(result.package_directory.unwrap().join("dm_payload.txt").is_file());
    }
}
