//! Next-action suggestions after a job finishes (keep operator oriented).
//!
//! First item is always the **primary** next step (visually dominant in UI).
//! Keys are unique; co-pilot launch uses `p` so global `g` (toggle brief) never collides.
//!
//! Primaries use job kind + exit code, and for inventory also parse the summary line
//! (`tools_yaml_miss=N upgradable=N`) so the bar points at the real fix path.

use crate::jobs::JobKind;

#[derive(Debug, Clone)]
pub struct NextAction {
    pub key: char,
    pub label: String,
    pub id: ActionId,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ActionId {
    BackHome,
    ReRun,
    OpenInventory,
    RunAudit,
    RunEvidence,
    InstallDry,
    LaunchGrok,
    ActuateDry,
}

/// Hints scraped from job stdio (optional; empty = exit-code only heuristics).
#[derive(Debug, Clone, Default)]
pub struct JobHints {
    pub tools_yaml_miss: Option<u32>,
    pub upgradable: Option<u32>,
    pub omarchy_update_available: bool,
    pub catalog_hits: Option<u32>,
}

impl JobHints {
    /// Best-effort parse of inventory / omarchy / catalog text output.
    pub fn from_lines(lines: &[String]) -> Self {
        let mut h = JobHints::default();
        for line in lines {
            let l = line.as_str();
            if l.contains("tools_yaml_miss=") || l.contains("tools_yaml_missing") {
                if let Some(n) = parse_kv_u32(l, "tools_yaml_miss") {
                    h.tools_yaml_miss = Some(n);
                } else if let Some(n) = parse_kv_u32(l, "tools_yaml_missing") {
                    h.tools_yaml_miss = Some(n);
                }
            }
            if l.contains("upgradable=") {
                if let Some(n) = parse_kv_u32(l, "upgradable") {
                    h.upgradable = Some(n);
                }
            }
            // omarchy-status: "Omarchy is up to date" vs update available wording
            let lower = l.to_ascii_lowercase();
            if lower.contains("update available")
                || lower.contains("updates available")
                || (lower.contains("omarchy") && lower.contains("behind"))
            {
                h.omarchy_update_available = true;
            }
            if l.starts_with("hits:") || l.contains("hits:") {
                if let Some(n) = parse_kv_u32(l, "hits") {
                    h.catalog_hits = Some(n);
                }
            }
        }
        h
    }
}

fn parse_kv_u32(line: &str, key: &str) -> Option<u32> {
    let needle = format!("{key}=");
    let idx = line.find(&needle)?;
    let rest = &line[idx + needle.len()..];
    let num: String = rest
        .chars()
        .take_while(|c| c.is_ascii_digit())
        .collect();
    if num.is_empty() {
        None
    } else {
        num.parse().ok()
    }
}

/// Suggest next steps using optional output hints (inventory summary, etc.).
/// Index 0 is always the primary next action.
pub fn suggest_with_hints(kind: JobKind, exit_code: i32, hints: &JobHints) -> Vec<NextAction> {
    let mut v = Vec::new();

    // --- primary (job + content aware) ---
    match (kind, exit_code) {
        (JobKind::Inventory, 0) => {
            // Prefer the concrete repair path over a generic audit.
            if hints.tools_yaml_miss.unwrap_or(0) > 0 {
                v.push(na(
                    'i',
                    format!(
                        "Install dry-run ({} missing)",
                        hints.tools_yaml_miss.unwrap_or(0)
                    ),
                    ActionId::InstallDry,
                ));
            } else if hints.upgradable.unwrap_or(0) > 0 {
                v.push(na(
                    'u',
                    format!(
                        "Pkg update dry-run ({} upgradable)",
                        hints.upgradable.unwrap_or(0)
                    ),
                    ActionId::ActuateDry,
                ));
            } else {
                v.push(na('a', "Audit system", ActionId::RunAudit));
            }
        }
        (JobKind::Inventory, _) => v.push(na('r', "Re-run inventory", ActionId::ReRun)),
        (JobKind::Catalog, 0) => {
            if hints.catalog_hits == Some(0) {
                v.push(na('n', "Inventory", ActionId::OpenInventory));
            } else {
                // Hit(s) found → preview update path for the default/search target.
                v.push(na('u', "Pkg update dry-run", ActionId::ActuateDry));
            }
        }
        (JobKind::Catalog, _) => v.push(na('r', "Re-run catalog", ActionId::ReRun)),
        (JobKind::OmarchyStatus, 0) if hints.omarchy_update_available => {
            v.push(na('p', "Grok: omarchy update plan", ActionId::LaunchGrok));
        }
        (JobKind::OmarchyStatus, _) => v.push(na('n', "Inventory", ActionId::OpenInventory)),
        (JobKind::AuditGlobal | JobKind::AuditProject, 0) => {
            v.push(na('e', "Extract evidence", ActionId::RunEvidence));
        }
        (JobKind::AuditGlobal | JobKind::AuditProject, _) => {
            v.push(na('p', "Grok: explain", ActionId::LaunchGrok));
        }
        (JobKind::InstallDryRun, 0) => {
            v.push(na('n', "Inventory again", ActionId::OpenInventory));
        }
        (JobKind::InstallDryRun, _) => {
            v.push(na('p', "Grok: explain install", ActionId::LaunchGrok));
        }
        (JobKind::Evidence, 0) => v.push(na('h', "Home", ActionId::BackHome)),
        (JobKind::Evidence, _) => v.push(na('r', "Re-run evidence", ActionId::ReRun)),
        (JobKind::ActuateDry, 0) => v.push(na('n', "Inventory", ActionId::OpenInventory)),
        (JobKind::ActuateDry, _) => v.push(na('r', "Re-run actuate", ActionId::ReRun)),
    }

    // --- secondaries (never steal primary key) ---
    let push_if = |v: &mut Vec<NextAction>, key: char, label: &str, id: ActionId| {
        if v.iter().any(|a| a.key == key) {
            return;
        }
        v.push(na(key, label, id));
    };

    push_if(&mut v, 'r', "Re-run", ActionId::ReRun);
    push_if(&mut v, 'h', "Home", ActionId::BackHome);
    // `p` = co-pilot launch (not `g` — global g toggles brief)
    push_if(&mut v, 'p', "Grok co-pilot", ActionId::LaunchGrok);

    match kind {
        JobKind::Inventory => {
            push_if(&mut v, 'a', "Audit system", ActionId::RunAudit);
            push_if(&mut v, 'i', "Install dry-run", ActionId::InstallDry);
            push_if(&mut v, 'u', "Pkg update dry-run", ActionId::ActuateDry);
        }
        JobKind::Catalog | JobKind::ActuateDry | JobKind::OmarchyStatus => {
            push_if(&mut v, 'i', "Install dry-run", ActionId::InstallDry);
            push_if(&mut v, 'u', "Pkg update dry-run", ActionId::ActuateDry);
        }
        JobKind::AuditGlobal | JobKind::AuditProject => {
            push_if(&mut v, 'e', "Extract evidence", ActionId::RunEvidence);
        }
        JobKind::InstallDryRun => {
            push_if(&mut v, 'n', "Inventory", ActionId::OpenInventory);
        }
        _ => {}
    }

    // final de-dupe by key (keep first = primary wins)
    let mut seen = std::collections::HashSet::new();
    v.retain(|a| seen.insert(a.key));
    v
}

fn na(key: char, label: impl Into<String>, id: ActionId) -> NextAction {
    NextAction {
        key,
        label: label.into(),
        id,
    }
}

/// Primary next action (first entry), if any.
pub fn primary(actions: &[NextAction]) -> Option<&NextAction> {
    actions.first()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn inventory_ok_primary_is_audit_when_clean() {
        let v = suggest_with_hints(JobKind::Inventory, 0, &JobHints::default());
        assert_eq!(v[0].key, 'a');
        assert_eq!(v[0].id, ActionId::RunAudit);
        assert!(keys_unique(&v));
    }

    #[test]
    fn inventory_miss_primary_is_install_dry() {
        let hints = JobHints {
            tools_yaml_miss: Some(3),
            ..Default::default()
        };
        let v = suggest_with_hints(JobKind::Inventory, 0, &hints);
        assert_eq!(v[0].id, ActionId::InstallDry);
        assert!(v[0].label.contains("3 missing"));
        assert!(keys_unique(&v));
    }

    #[test]
    fn inventory_upgradable_primary_is_actuate() {
        let hints = JobHints {
            tools_yaml_miss: Some(0),
            upgradable: Some(12),
            ..Default::default()
        };
        let v = suggest_with_hints(JobKind::Inventory, 0, &hints);
        assert_eq!(v[0].id, ActionId::ActuateDry);
        assert!(v[0].label.contains("12"));
        assert!(keys_unique(&v));
    }

    #[test]
    fn parse_inventory_summary_line() {
        let lines = vec![
            "summary: explicit=236 tools_yaml_ok=18 tools_yaml_miss=2 upgradable=5 mise=13"
                .into(),
        ];
        let h = JobHints::from_lines(&lines);
        assert_eq!(h.tools_yaml_miss, Some(2));
        assert_eq!(h.upgradable, Some(5));
    }

    #[test]
    fn inventory_fail_primary_is_rerun() {
        let v = suggest_with_hints(JobKind::Inventory, 1, &JobHints::default());
        assert_eq!(v[0].id, ActionId::ReRun);
        assert!(keys_unique(&v));
    }

    #[test]
    fn audit_fail_primary_grok_uses_p_not_g() {
        let v = suggest_with_hints(JobKind::AuditGlobal, 2, &JobHints::default());
        assert_eq!(v[0].key, 'p');
        assert_eq!(v[0].id, ActionId::LaunchGrok);
        assert!(!v.iter().any(|a| a.key == 'g'));
        assert!(keys_unique(&v));
    }

    #[test]
    fn actuate_ok_has_primary_and_secondaries() {
        let v = suggest_with_hints(JobKind::ActuateDry, 0, &JobHints::default());
        assert!(!v.is_empty());
        assert_eq!(primary(&v).unwrap().id, ActionId::OpenInventory);
        assert!(v.len() >= 2);
        assert!(keys_unique(&v));
    }

    #[test]
    fn catalog_hit_primary_actuate() {
        let hints = JobHints {
            catalog_hits: Some(1),
            ..Default::default()
        };
        let v = suggest_with_hints(JobKind::Catalog, 0, &hints);
        assert_eq!(v[0].id, ActionId::ActuateDry);
        assert!(keys_unique(&v));
    }

    fn keys_unique(v: &[NextAction]) -> bool {
        let mut s = std::collections::HashSet::new();
        v.iter().all(|a| s.insert(a.key))
    }
}
