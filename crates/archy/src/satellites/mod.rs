//! Domain satellites — specialized orchestrators under the Eagle.
//!
//! Eagle routes; each satellite owns its offline job build + finish plan.
//! Inspired by Eagle+Satellites: explicit delegation, fault isolation per domain.

use crate::actions::{self, ActionId, JobHints, NextAction};
use crate::jobs::{self, JobKind};
use std::path::Path;
use std::process::Command;

/// Domain identity (also offline job kinds that produce stdio).
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum SatelliteId {
    Inventory,
    Catalog,
    OmarchyStatus,
    AuditGlobal,
    AuditProject,
    InstallDry,
    Evidence,
    ActuateDry,
}

impl SatelliteId {
    pub fn job_kind(self) -> JobKind {
        match self {
            SatelliteId::Inventory => JobKind::Inventory,
            SatelliteId::Catalog => JobKind::Catalog,
            SatelliteId::OmarchyStatus => JobKind::OmarchyStatus,
            SatelliteId::AuditGlobal => JobKind::AuditGlobal,
            SatelliteId::AuditProject => JobKind::AuditProject,
            SatelliteId::InstallDry => JobKind::InstallDryRun,
            SatelliteId::Evidence => JobKind::Evidence,
            SatelliteId::ActuateDry => JobKind::ActuateDry,
        }
    }

    pub fn from_job_kind(k: JobKind) -> Self {
        match k {
            JobKind::Inventory => SatelliteId::Inventory,
            JobKind::Catalog => SatelliteId::Catalog,
            JobKind::OmarchyStatus => SatelliteId::OmarchyStatus,
            JobKind::AuditGlobal => SatelliteId::AuditGlobal,
            JobKind::AuditProject => SatelliteId::AuditProject,
            JobKind::InstallDryRun => SatelliteId::InstallDry,
            JobKind::Evidence => SatelliteId::Evidence,
            JobKind::ActuateDry => SatelliteId::ActuateDry,
        }
    }

    pub fn label(self) -> &'static str {
        self.job_kind().label()
    }
}

/// Menu entries — job satellites + local chrome actions.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum MenuAction {
    Satellite(SatelliteId),
    ToggleBrief,
    LaunchGrok,
    Help,
    Quit,
}

#[derive(Debug, Clone, Copy)]
pub struct MenuEntry {
    pub label: &'static str,
    pub action: MenuAction,
}

/// Ordered registry (menu index = position). Single source of truth.
pub const MENU: &[MenuEntry] = &[
    MenuEntry {
        label: "Inventory",
        action: MenuAction::Satellite(SatelliteId::Inventory),
    },
    MenuEntry {
        label: "Catalog search",
        action: MenuAction::Satellite(SatelliteId::Catalog),
    },
    MenuEntry {
        label: "Omarchy status",
        action: MenuAction::Satellite(SatelliteId::OmarchyStatus),
    },
    MenuEntry {
        label: "Audit system",
        action: MenuAction::Satellite(SatelliteId::AuditGlobal),
    },
    MenuEntry {
        label: "Audit project",
        action: MenuAction::Satellite(SatelliteId::AuditProject),
    },
    MenuEntry {
        label: "Install dry-run",
        action: MenuAction::Satellite(SatelliteId::InstallDry),
    },
    MenuEntry {
        label: "Evidence dry-run",
        action: MenuAction::Satellite(SatelliteId::Evidence),
    },
    MenuEntry {
        label: "Pkg update dry-run",
        action: MenuAction::Satellite(SatelliteId::ActuateDry),
    },
    MenuEntry {
        label: "Co-pilot brief",
        action: MenuAction::ToggleBrief,
    },
    MenuEntry {
        label: "Launch Grok",
        action: MenuAction::LaunchGrok,
    },
    MenuEntry {
        label: "Help",
        action: MenuAction::Help,
    },
    MenuEntry {
        label: "Quit",
        action: MenuAction::Quit,
    },
];

pub fn menu_labels() -> Vec<&'static str> {
    MENU.iter().map(|e| e.label).collect()
}

pub fn menu_len() -> usize {
    MENU.len()
}

/// Context satellites need to build commands (no UI).
pub struct SatContext<'a> {
    pub root: &'a Path,
    pub catalog_query: &'a str,
    pub project_path: &'a str,
    pub install_profile: &'a str,
    pub actuate_pkg: &'a str,
}

/// Finish plan after offline satellite verification (exit + stdio).
#[derive(Debug, Clone)]
pub struct FinishPlan {
    pub next_actions: Vec<NextAction>,
    pub status: String,
}

pub fn build(id: SatelliteId, ctx: &SatContext<'_>) -> Command {
    let root = ctx.root.to_path_buf();
    match id {
        SatelliteId::Inventory => jobs::build_inventory(&root),
        SatelliteId::Catalog => jobs::build_catalog(&root, ctx.catalog_query),
        SatelliteId::OmarchyStatus => jobs::build_omarchy_status(&root),
        SatelliteId::AuditGlobal => jobs::build_audit_global(&root),
        SatelliteId::AuditProject => jobs::build_audit_project(&root, ctx.project_path),
        SatelliteId::InstallDry => jobs::build_install_dry(&root, ctx.install_profile),
        SatelliteId::Evidence => jobs::build_evidence(&root),
        SatelliteId::ActuateDry => jobs::build_actuate_update_dry(&root, ctx.actuate_pkg),
    }
}

pub fn title(id: SatelliteId, ctx: &SatContext<'_>) -> String {
    match id {
        SatelliteId::Inventory => "Inventory".into(),
        SatelliteId::Catalog => format!("Catalog search '{}'", ctx.catalog_query),
        SatelliteId::OmarchyStatus => "Omarchy status".into(),
        SatelliteId::AuditGlobal => "Audit global".into(),
        SatelliteId::AuditProject => format!("Audit {}", ctx.project_path),
        SatelliteId::InstallDry => format!("Install {} --dry-run", ctx.install_profile),
        SatelliteId::Evidence => "Evidence dry-run".into(),
        SatelliteId::ActuateDry => format!("Actuate update {} --dry-run", ctx.actuate_pkg),
    }
}

/// Domain finish DAG node: exit + lines → next actions (primary first).
pub fn on_finished(id: SatelliteId, code: i32, lines: &[String]) -> FinishPlan {
    let hints = JobHints::from_lines(lines);
    let next_actions = actions::suggest_with_hints(id.job_kind(), code, &hints);
    let status = format!("done exit={code}");
    FinishPlan {
        next_actions,
        status,
    }
}

pub fn grok_ask(
    id: SatelliteId,
    code: Option<i32>,
    ctx: &SatContext<'_>,
    lines_tail: &str,
) -> String {
    let _ = lines_tail;
    match (id, code) {
        (SatelliteId::Inventory, Some(0)) => {
            "From this inventory: flag drift vs omarchy-baseline and tools.yaml; suggest one dry-run fix."
                .into()
        }
        (SatelliteId::Inventory, _) => {
            "Inventory failed or partial — diagnose the error and propose a safe re-run.".into()
        }
        (SatelliteId::Catalog, _) => format!(
            "Catalog query '{}': interpret hits and next install/actuate dry-run.",
            ctx.catalog_query
        ),
        (SatelliteId::OmarchyStatus, _) => {
            "Omarchy status: summarize host health, theme, and any update path.".into()
        }
        (SatelliteId::AuditGlobal, _) | (SatelliteId::AuditProject, _) => {
            "Explain audit findings; prioritize one remediation with dry-run first.".into()
        }
        (SatelliteId::InstallDry, _) => format!(
            "Review install --profile {} --dry-run plan; call out risks before any apply.",
            ctx.install_profile
        ),
        (SatelliteId::Evidence, _) => {
            "Evidence dry-run finished — what should we include or fix before a real extract?".into()
        }
        (SatelliteId::ActuateDry, _) => format!(
            "Package actuate dry-run for '{}': confirm plan, refuse-list, Omarchy alt path.",
            ctx.actuate_pkg
        ),
    }
}

/// Map next-action ids that fire satellites back to SatelliteId.
pub fn action_to_satellite(id: ActionId) -> Option<SatelliteId> {
    match id {
        ActionId::OpenInventory => Some(SatelliteId::Inventory),
        ActionId::RunAudit => Some(SatelliteId::AuditGlobal),
        ActionId::RunEvidence => Some(SatelliteId::Evidence),
        ActionId::InstallDry => Some(SatelliteId::InstallDry),
        ActionId::ActuateDry => Some(SatelliteId::ActuateDry),
        ActionId::ReRun | ActionId::BackHome | ActionId::LaunchGrok => None,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn menu_has_at_least_five_job_satellites() {
        let n = MENU
            .iter()
            .filter(|e| matches!(e.action, MenuAction::Satellite(_)))
            .count();
        assert!(n >= 5, "expected ≥5 job satellites, got {n}");
    }

    #[test]
    fn inventory_finish_clean_primary_audit() {
        let lines = vec![
            "summary: explicit=1 tools_yaml_ok=1 tools_yaml_miss=0 upgradable=0 mise=0".into(),
        ];
        let plan = on_finished(SatelliteId::Inventory, 0, &lines);
        assert_eq!(plan.next_actions[0].id, ActionId::RunAudit);
    }

    #[test]
    fn inventory_finish_miss_primary_install() {
        let lines = vec![
            "summary: explicit=1 tools_yaml_ok=0 tools_yaml_miss=2 upgradable=0 mise=0".into(),
        ];
        let plan = on_finished(SatelliteId::Inventory, 0, &lines);
        assert_eq!(plan.next_actions[0].id, ActionId::InstallDry);
    }
}
