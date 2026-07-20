//! Allowlist policy — who may remote-control this host via XChat DM.
//! Identities come from env / local files only; never hardcode operator ids.

use std::collections::BTreeSet;
use std::fs;
use std::path::{Path, PathBuf};

/// Remote-control policy: allowlisted senders + high-blast confirm rule.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct RemoteControlPolicy {
    pub allowlisted_user_ids: BTreeSet<String>,
    pub allowlisted_usernames: BTreeSet<String>,
    pub require_confirm_for_high_blast: bool,
}

impl RemoteControlPolicy {
    pub fn empty() -> Self {
        Self {
            allowlisted_user_ids: BTreeSet::new(),
            allowlisted_usernames: BTreeSet::new(),
            require_confirm_for_high_blast: true,
        }
    }

    pub fn is_empty(&self) -> bool {
        self.allowlisted_user_ids.is_empty() && self.allowlisted_usernames.is_empty()
    }

    pub fn allows_sender(&self, sender_id: Option<&str>, username: Option<&str>) -> bool {
        if let Some(id) = sender_id {
            if self.allowlisted_user_ids.contains(id) {
                return true;
            }
        }
        if let Some(name) = username {
            let normalized = name.trim_start_matches('@').to_lowercase();
            if self.allowlisted_usernames.contains(&normalized) {
                return true;
            }
        }
        false
    }

    pub fn with_authenticated_self(mut self, user_id: &str, username: &str) -> Self {
        if !user_id.is_empty() {
            self.allowlisted_user_ids.insert(user_id.to_string());
        }
        if !username.is_empty() {
            self.allowlisted_usernames
                .insert(username.trim_start_matches('@').to_lowercase());
        }
        self
    }

    pub fn merge_user_id(&mut self, user_id: &str) {
        if !user_id.is_empty() {
            self.allowlisted_user_ids.insert(user_id.to_string());
        }
    }
}

/// Parse simple key=value allowlist text (same shape as Python groxy).
pub fn parse_allowlist_text(text: &str) -> RemoteControlPolicy {
    let mut policy = RemoteControlPolicy::empty();
    for line in text.lines() {
        let line = line.trim();
        if line.is_empty() || line.starts_with('#') {
            continue;
        }
        if let Some((key, value)) = line.split_once('=') {
            let key = key.trim().to_lowercase();
            let value = value.trim();
            match key.as_str() {
                "allowlist_ids" | "ids" => {
                    for part in value.split(|c: char| c.is_whitespace() || c == ',') {
                        if !part.is_empty() {
                            policy.allowlisted_user_ids.insert(part.to_string());
                        }
                    }
                }
                "allowlist_usernames" | "usernames" | "users" => {
                    for part in value.split(|c: char| c.is_whitespace() || c == ',') {
                        if !part.is_empty() {
                            policy
                                .allowlisted_usernames
                                .insert(part.trim_start_matches('@').to_lowercase());
                        }
                    }
                }
                "require_confirm" | "require_confirm_high_blast" => {
                    policy.require_confirm_for_high_blast =
                        !matches!(value, "0" | "false" | "False" | "no");
                }
                _ => {}
            }
        } else if let Some(stripped) = line.strip_prefix('@') {
            policy
                .allowlisted_usernames
                .insert(stripped.to_lowercase());
        } else if line.chars().all(|c| c.is_ascii_digit()) {
            policy.allowlisted_user_ids.insert(line.to_string());
        } else {
            policy.allowlisted_usernames.insert(line.to_lowercase());
        }
    }
    policy
}

pub fn load_policy_from_env() -> RemoteControlPolicy {
    let mut policy = RemoteControlPolicy::empty();
    if let Ok(raw_ids) = std::env::var("GROXY_ALLOWLIST_IDS") {
        for part in raw_ids.split(|c: char| c.is_whitespace() || c == ',') {
            if !part.is_empty() {
                policy.allowlisted_user_ids.insert(part.to_string());
            }
        }
    }
    if let Ok(raw_users) = std::env::var("GROXY_ALLOWLIST_USERNAMES") {
        for part in raw_users.split(|c: char| c.is_whitespace() || c == ',') {
            if !part.is_empty() {
                policy
                    .allowlisted_usernames
                    .insert(part.trim_start_matches('@').to_lowercase());
            }
        }
    }
    if let Ok(require) = std::env::var("GROXY_REQUIRE_CONFIRM") {
        policy.require_confirm_for_high_blast =
            !matches!(require.as_str(), "0" | "false" | "False");
    }
    policy
}

/// Ordered search paths: local/gitignored first, then template.
pub fn policy_search_paths(repository_root: &Path) -> Vec<PathBuf> {
    let mut paths = Vec::new();
    paths.push(
        repository_root
            .join("config")
            .join("groxy")
            .join("allowlist.local.conf"),
    );
    if let Some(home) = std::env::var_os("HOME") {
        let home = PathBuf::from(home);
        paths.push(home.join(".config").join("groxy").join("allowlist.conf"));
        paths.push(
            home.join(".local")
                .join("state")
                .join("groxy")
                .join("allowlist.conf"),
        );
    }
    paths.push(
        repository_root
            .join("config")
            .join("groxy")
            .join("allowlist.conf"),
    );
    paths
}

pub fn load_policy(repository_root: &Path) -> RemoteControlPolicy {
    let mut policy = RemoteControlPolicy::empty();
    for path in policy_search_paths(repository_root) {
        if !path.is_file() {
            continue;
        }
        if let Ok(text) = fs::read_to_string(&path) {
            let file_policy = parse_allowlist_text(&text);
            if !file_policy.is_empty() {
                policy = file_policy;
                break;
            }
            // template with only require_confirm
            policy.require_confirm_for_high_blast =
                parse_allowlist_text(&text).require_confirm_for_high_blast;
        }
    }
    let env_policy = load_policy_from_env();
    policy.allowlisted_user_ids.extend(env_policy.allowlisted_user_ids);
    policy
        .allowlisted_usernames
        .extend(env_policy.allowlisted_usernames);
    if std::env::var("GROXY_REQUIRE_CONFIRM").is_ok() {
        policy.require_confirm_for_high_blast = env_policy.require_confirm_for_high_blast;
    }
    policy
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn rejects_empty_sender() {
        let policy = RemoteControlPolicy::empty();
        assert!(!policy.allows_sender(Some("1"), None));
    }

    #[test]
    fn allows_listed_id() {
        let mut policy = RemoteControlPolicy::empty();
        policy.merge_user_id("100001");
        assert!(policy.allows_sender(Some("100001"), None));
        assert!(!policy.allows_sender(Some("999"), None));
    }

    #[test]
    fn parse_text_has_no_hardcoded_operator() {
        let text = "require_confirm=true\n";
        let policy = parse_allowlist_text(text);
        assert!(policy.allowlisted_user_ids.is_empty());
    }

    #[test]
    fn with_self_adds_runtime_identity() {
        let policy = RemoteControlPolicy::empty().with_authenticated_self("42", "Operator");
        assert!(policy.allows_sender(Some("42"), Some("operator")));
    }
}
