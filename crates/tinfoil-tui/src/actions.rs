//! Next-action suggestions after a job finishes (keep operator oriented).

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
    #[allow(dead_code)]
    ScrollTop,
}

pub fn suggest(kind: JobKind, exit_code: i32) -> Vec<NextAction> {
    let mut v = Vec::new();
    v.push(NextAction {
        key: 'h',
        label: "Home".into(),
        id: ActionId::BackHome,
    });
    v.push(NextAction {
        key: 'r',
        label: "Re-run".into(),
        id: ActionId::ReRun,
    });
    v.push(NextAction {
        key: 'g',
        label: "Grok (fix / next)".into(),
        id: ActionId::LaunchGrok,
    });

    match kind {
        JobKind::Inventory => {
            v.push(NextAction {
                key: 'a',
                label: "Audit system".into(),
                id: ActionId::RunAudit,
            });
            v.push(NextAction {
                key: 'i',
                label: "Install dry-run".into(),
                id: ActionId::InstallDry,
            });
        }
        JobKind::AuditGlobal | JobKind::AuditProject => {
            v.push(NextAction {
                key: 'e',
                label: "Extract evidence".into(),
                id: ActionId::RunEvidence,
            });
            if exit_code != 0 {
                v.push(NextAction {
                    key: 'g',
                    label: "Grok: explain findings".into(),
                    id: ActionId::LaunchGrok,
                });
            }
        }
        JobKind::InstallDryRun => {
            v.push(NextAction {
                key: 'n',
                label: "Inventory again".into(),
                id: ActionId::OpenInventory,
            });
        }
        JobKind::Evidence | JobKind::Custom => {}
    }

    // de-dupe by key (keep first)
    let mut seen = std::collections::HashSet::new();
    v.retain(|a| seen.insert(a.key));
    v
}
