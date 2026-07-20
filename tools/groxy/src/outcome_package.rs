//! Outcome-first outbound packages for XChat (done bullets + optional PR; no host/cwd noise).

use regex::Regex;
use std::fs;
use std::path::{Path, PathBuf};
use std::sync::OnceLock;

/// One outbound package destined for XChat DM (live or dry-run files).
#[derive(Debug, Clone)]
pub struct OutboundPackage {
    pub summary_text: String,
    pub visual_panel_text: String,
    pub metadata_verb: String,
    pub metadata_ok: bool,
    pub pull_request_url: Option<String>,
}

impl OutboundPackage {
    /// Chat body: summary + visual panel, no system fields.
    pub fn direct_message_body(&self, max_characters: usize) -> String {
        let body = format!(
            "{}\n\n{}",
            self.summary_text.trim(),
            self.visual_panel_text.trim()
        );
        if body.chars().count() <= max_characters {
            body
        } else {
            let truncated: String = body.chars().take(max_characters.saturating_sub(12)).collect();
            format!("{truncated}\n…(more)")
        }
    }

    pub fn write_to_directory(&self, output_directory: &Path) -> std::io::Result<PathBuf> {
        fs::create_dir_all(output_directory)?;
        fs::write(output_directory.join("summary.txt"), &self.summary_text)?;
        fs::write(
            output_directory.join("visual.txt"),
            &self.visual_panel_text,
        )?;
        let body = self.direct_message_body(900);
        fs::write(output_directory.join("dm_payload.txt"), &body)?;
        let package_json = serde_json::json!({
            "verb": self.metadata_verb,
            "ok": self.metadata_ok,
            "pull_request_url": self.pull_request_url,
            "has_visual_panel": true,
        });
        fs::write(
            output_directory.join("package.json"),
            serde_json::to_string_pretty(&package_json).unwrap_or_else(|_| "{}".into()),
        )?;
        // Minimal visual PNG placeholder note (text board is primary for chat)
        fs::write(
            output_directory.join("visual.panel.txt"),
            &self.visual_panel_text,
        )?;
        Ok(output_directory.to_path_buf())
    }
}

fn pull_request_url_regex() -> &'static Regex {
    static RE: OnceLock<Regex> = OnceLock::new();
    RE.get_or_init(|| {
        Regex::new(r"https?://(?:www\.)?github\.com/[\w.-]+/[\w.-]+/pull/\d+")
            .expect("pr url regex")
    })
}

pub fn extract_pull_request_urls(text: &str) -> Vec<String> {
    pull_request_url_regex()
        .find_iter(text)
        .map(|m| m.as_str().trim_end_matches(|c| "),. ".contains(c)).to_string())
        .collect()
}

fn inventory_done_lines(raw_host_output: &str) -> Vec<String> {
    let mut lines = Vec::new();
    let summary_re = Regex::new(
        r"summary:\s*explicit=(\d+)\s+tools_yaml_ok=(\d+)\s+tools_yaml_miss=(\d+)\s+upgradable=(\d+)\s+mise=(\d+)",
    )
    .expect("summary re");
    if let Some(captures) = summary_re.captures(raw_host_output) {
        lines.push(format!(
            "Inventory: {} explicit packages",
            &captures[1]
        ));
        lines.push(format!(
            "tools.yaml ok={} miss={}; upgradable={}",
            &captures[2], &captures[3], &captures[4]
        ));
    }
    let ownership_re =
        Regex::new(r"ownership:\s*arch-machine=(\d+)\s+omarchy=(\d+)\s+user=(\d+)").expect("own re");
    if let Some(captures) = ownership_re.captures(raw_host_output) {
        lines.push(format!(
            "Ownership: arch-machine {} · omarchy {} · user {}",
            &captures[1], &captures[2], &captures[3]
        ));
    }
    if lines.is_empty() && raw_host_output.to_lowercase().contains("inventory") {
        lines.push("Inventory snapshot finished".into());
    }
    lines
}

fn looks_like_system_noise(line: &str) -> bool {
    let lower = line.to_lowercase();
    lower.starts_with("host=")
        || lower.starts_with("host:")
        || lower.starts_with("cwd=")
        || lower.starts_with("cwd:")
        || lower.starts_with("utc=")
        || lower.starts_with("tinfoil inventory")
        || lower.starts_with("=== explicit packages")
        || lower.starts_with("[media]")
        || lower.starts_with("media uploaded")
        || lower.starts_with("pong from ")
}

/// Distill raw host output into short "what got done" bullets.
pub fn distill_done_lines(verb: &str, succeeded: bool, raw_host_output: &str) -> Vec<String> {
    let verb = verb.to_lowercase();
    match verb.as_str() {
        "status" | "inventory" => {
            let lines = inventory_done_lines(raw_host_output);
            if lines.is_empty() {
                vec![if succeeded {
                    "Inventory finished".into()
                } else {
                    "Inventory failed".into()
                }]
            } else {
                lines
            }
        }
        "ping" => vec![if succeeded {
            "Reachable — ready for next command".into()
        } else {
            "Unreachable".into()
        }],
        "help" => {
            vec!["Command list ready (help / status / inventory / audit / run …)".into()]
        }
        other => {
            let mut lines: Vec<String> = raw_host_output
                .lines()
                .map(str::trim)
                .filter(|line| !line.is_empty() && !looks_like_system_noise(line))
                .take(4)
                .map(|line| {
                    if line.len() > 120 {
                        format!("{}…", &line[..117])
                    } else {
                        line.to_string()
                    }
                })
                .collect();
            if lines.is_empty() {
                lines.push(if succeeded {
                    format!("`{other}` done")
                } else {
                    format!("`{other}` failed")
                });
            }
            lines
        }
    }
}

pub fn build_visual_panel(
    verb: &str,
    succeeded: bool,
    done_lines: &[String],
    pull_request_url: Option<&str>,
) -> String {
    let status = if succeeded { "OK" } else { "FAIL" };
    let bar = "═".repeat(32);
    let mut rows: Vec<String> = Vec::new();
    rows.push(format!("╔{bar}╗"));
    rows.push(format!("║ {status:<4}  {verb:<20}          ║"));
    rows.push(format!("╠{bar}╣"));
    for line in done_lines.iter().take(5) {
        let clipped: String = line.chars().take(36).collect();
        rows.push(format!("│ {clipped:<36} │"));
    }
    if let Some(url) = pull_request_url {
        let short = url
            .rsplit('/')
            .take(2)
            .collect::<Vec<_>>()
            .into_iter()
            .rev()
            .collect::<Vec<_>>()
            .join("/");
        let clipped: String = short.chars().take(33).collect();
        rows.push(format!("│ PR {clipped:<33} │"));
    }
    if rows.len() == 3 {
        rows.push(format!("│ {:<36} │", "(no outcomes)"));
    }
    rows.push(format!("╚{bar}╝"));
    rows.join("\n")
}

/// Resolve PR URL: explicit arg, then GROXY_PR_URL env, then URLs in host output.
pub fn resolve_pull_request_url(
    explicit: Option<&str>,
    host_output: &str,
) -> Option<String> {
    if let Some(url) = explicit.filter(|u| !u.is_empty()) {
        return Some(url.to_string());
    }
    if let Ok(from_env) = std::env::var("GROXY_PR_URL") {
        if !from_env.trim().is_empty() {
            return Some(from_env.trim().to_string());
        }
    }
    extract_pull_request_urls(host_output).into_iter().next()
}

pub fn build_outbound_package(
    verb: &str,
    succeeded: bool,
    raw_host_output: &str,
    explicit_pull_request_url: Option<&str>,
) -> OutboundPackage {
    let pull_request_url = resolve_pull_request_url(explicit_pull_request_url, raw_host_output);
    let done_lines = distill_done_lines(verb, succeeded, raw_host_output);
    let mark = if succeeded { "✓" } else { "✗" };
    let title = if succeeded {
        format!("{mark} Done: {verb}")
    } else {
        format!("{mark} Failed: {verb}")
    };
    let mut summary_lines = vec![title];
    for line in &done_lines {
        if line.starts_with('•') || line.starts_with('-') {
            summary_lines.push(line.clone());
        } else {
            summary_lines.push(format!("• {line}"));
        }
    }
    if let Some(ref url) = pull_request_url {
        summary_lines.push(format!("PR: {url}"));
    }
    let visual_panel_text =
        build_visual_panel(verb, succeeded, &done_lines, pull_request_url.as_deref());
    OutboundPackage {
        summary_text: summary_lines.join("\n"),
        visual_panel_text,
        metadata_verb: verb.to_string(),
        metadata_ok: succeeded,
        pull_request_url,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn status_summary_has_done_and_pr_without_host_noise() {
        let inventory_output = r#"
tinfoil inventory (tinfoil.inventory.v1)
host: example-host  time: 2026-07-20
summary: explicit=236 tools_yaml_ok=18 tools_yaml_miss=0 upgradable=0 mise=13
ownership: arch-machine=14 omarchy=157 user=65
=== Explicit packages (pacman -Qe) — first 40 ===
pkg-a  1.0
"#;
        let package = build_outbound_package(
            "status",
            true,
            inventory_output,
            Some("https://github.com/example/arch-machine/pull/31"),
        );
        let body = package.direct_message_body(900);
        assert!(body.contains("Done: status"));
        assert!(body.contains("236 explicit"));
        assert!(body.contains("PR: https://github.com/example/arch-machine/pull/31"));
        assert!(!body.to_lowercase().contains("host="));
        assert!(!body.contains("example-host"));
        assert!(!body.contains("pkg-a"));
        assert!(body.contains('╔'));
    }

    #[test]
    fn write_package_files() {
        let dir = tempfile::tempdir().unwrap();
        let package = build_outbound_package("ping", true, "Reachable", None);
        package.write_to_directory(dir.path()).unwrap();
        let payload = fs::read_to_string(dir.path().join("dm_payload.txt")).unwrap();
        assert!(payload.contains("Done: ping"));
    }
}
