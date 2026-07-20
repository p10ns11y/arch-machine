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

/// Job-aware co-pilot ask: include seed commands so Grok returns runnable bash.
pub fn grok_ask(
    id: SatelliteId,
    code: Option<i32>,
    ctx: &SatContext<'_>,
    lines_tail: &str,
) -> String {
    let root = ctx.root.display();
    let exit = code
        .map(|c| c.to_string())
        .unwrap_or_else(|| "unknown".into());
    let tail_note = if lines_tail.trim().is_empty() {
        "(stdio tail empty — still propose safe read-only commands)".into()
    } else {
        format!(
            "Key stdio lines (also full tail in context file):\n{}",
            lines_tail
                .lines()
                .rev()
                .take(12)
                .collect::<Vec<_>>()
                .into_iter()
                .rev()
                .collect::<Vec<_>>()
                .join("\n")
        )
    };

    let seeds = match id {
        SatelliteId::Inventory => format!(
            "Seed commands (adapt after reading summary):\n\
             ```bash\n\
             cd {root}\n\
             bash maintenance/inventory.sh --text\n\
             bash maintenance/security-audit.sh --global --dry-run\n\
             bash maintenance/package-actuate.sh --update jq --dry-run\n\
             ```"
        ),
        SatelliteId::Catalog => format!(
            "Seed commands for query `{q}`:\n\
             ```bash\n\
             cd {root}\n\
             bash maintenance/catalog.sh --text {q}\n\
             bash maintenance/package-actuate.sh --update {q} --dry-run\n\
             ```",
            q = ctx.catalog_query
        ),
        SatelliteId::OmarchyStatus => format!(
            "Seed commands:\n\
             ```bash\n\
             cd {root}\n\
             bash maintenance/omarchy-status.sh --text\n\
             omarchy version 2>/dev/null || true\n\
             omarchy theme current 2>/dev/null || true\n\
             ```"
        ),
        SatelliteId::AuditGlobal => format!(
            "Seed commands (threat areas malware/ports/supply/config):\n\
             ```bash\n\
             cd {root}\n\
             bash maintenance/security-audit.sh --global --dry-run\n\
             bash maintenance/security-audit.sh --global\n\
             # if FAIL on malware and passwordless sudo available:\n\
             sudo -n rkhunter --check --sk --nocolors 2>/dev/null | tail -40\n\
             ss -H -tuln\n\
             ```"
        ),
        SatelliteId::AuditProject => format!(
            "Seed commands for project `{p}`:\n\
             ```bash\n\
             cd {root}\n\
             bash maintenance/security-audit.sh --project {p}\n\
             bash maintenance/security-audit.sh --project {p} --dry-run 2>/dev/null || true\n\
             ```",
            p = ctx.project_path
        ),
        SatelliteId::InstallDry => format!(
            "Seed commands for profile `{prof}`:\n\
             ```bash\n\
             cd {root}\n\
             bash install.sh --profile {prof} --dry-run\n\
             # real apply only after review (consent):\n\
             # bash install.sh --profile {prof}\n\
             ```",
            prof = ctx.install_profile
        ),
        SatelliteId::Evidence => format!(
            "Seed commands:\n\
             ```bash\n\
             cd {root}\n\
             bash maintenance/extract-evidence.sh --dry-run\n\
             ls -lt logs/evidence* 2>/dev/null | head\n\
             ```"
        ),
        SatelliteId::ActuateDry => format!(
            "Seed commands for package `{pkg}`:\n\
             ```bash\n\
             cd {root}\n\
             bash maintenance/package-actuate.sh --update {pkg} --dry-run\n\
             # omarchy alt (if present):\n\
             omarchy pkg present {pkg} 2>/dev/null || true\n\
             ```",
            pkg = ctx.actuate_pkg
        ),
    };

    let focus = match (id, code) {
        (SatelliteId::Inventory, Some(0)) => {
            "Inventory OK: if tools_yaml_miss or upgradable > 0, prioritize install/actuate dry-run; else audit."
        }
        (SatelliteId::Inventory, _) => {
            "Inventory failed/partial: fix spawn/path first, then re-run inventory."
        }
        (SatelliteId::AuditGlobal, Some(0)) | (SatelliteId::AuditProject, Some(0)) => {
            "Audit clean or warn-only: list WARN lines and exact fix commands; evidence dry-run next."
        }
        (SatelliteId::AuditGlobal, _) | (SatelliteId::AuditProject, _) => {
            "Audit non-zero: treat FAIL first (malware/ports/config), then WARN; give exact commands."
        }
        (SatelliteId::InstallDry, _) => {
            "Install dry-run: extract planned packages/risks; only then optional real install command."
        }
        (SatelliteId::ActuateDry, _) => {
            "Actuate dry-run: confirm planned pacman/omarchy command; refuse silent --yes."
        }
        (SatelliteId::Catalog, _) => "Catalog: map hits to actuate/install dry-run commands.",
        (SatelliteId::OmarchyStatus, _) => {
            "Omarchy status: health + theme; concrete omarchy/arch-machine follow-ups."
        }
        (SatelliteId::Evidence, _) => "Evidence: when to run real extract vs stay dry-run.",
    };

    format!(
        "Job={label} exit={exit}. {focus}\n\
         {tail_note}\n\
         \n\
         {seeds}\n\
         \n\
         Produce ### Next actions with copy-paste `bash` blocks (see standing output format).",
        label = id.label(),
        exit = exit,
        focus = focus,
        tail_note = tail_note,
        seeds = seeds,
    )
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

    #[test]
    fn grok_ask_includes_runnable_seed_commands() {
        let root = std::path::Path::new("/home/u/arch-machine");
        let ctx = SatContext {
            root,
            catalog_query: "docker",
            project_path: ".",
            install_profile: "minimal",
            actuate_pkg: "jq",
        };
        let ask = grok_ask(
            SatelliteId::AuditGlobal,
            Some(1),
            &ctx,
            "[!] ports public high ports: 9999\n## SUMMARY\nexit=1",
        );
        assert!(ask.contains("```bash"), "seed bash fence missing: {ask}");
        assert!(
            ask.contains("security-audit.sh"),
            "must name real audit script: {ask}"
        );
        assert!(
            ask.contains("/home/u/arch-machine"),
            "must use real root in commands: {ask}"
        );
        assert!(ask.contains("### Next actions") || ask.contains("Next actions"));
    }
}
