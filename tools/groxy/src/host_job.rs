//! Offline host jobs — inventory / ping / etc. (satellite domain work).

use std::path::{Path, PathBuf};
use std::process::Command;
use std::time::Instant;

/// Result of one offline host action.
#[derive(Debug, Clone)]
pub struct HostJobResult {
    pub succeeded: bool,
    pub verb: String,
    pub output_text: String,
    pub exit_code: i32,
    pub duration_seconds: f64,
    pub effect_log_path: Option<PathBuf>,
}

fn write_effect_log(effect_directory: &Path, file_name: &str, content: &str) -> PathBuf {
    let _ = std::fs::create_dir_all(effect_directory);
    let path = effect_directory.join(file_name);
    let _ = std::fs::write(&path, content);
    path
}

fn run_shell_command(
    program: &str,
    arguments: &[&str],
    working_directory: &Path,
    timeout_hint_seconds: u64,
) -> (i32, String) {
    let _ = timeout_hint_seconds; // reserved for future timeout crate; subprocess inherits defaults
    match Command::new(program)
        .args(arguments)
        .current_dir(working_directory)
        .output()
    {
        Ok(output) => {
            let mut text = String::from_utf8_lossy(&output.stdout).into_owned();
            let stderr = String::from_utf8_lossy(&output.stderr);
            if !stderr.is_empty() {
                if !text.is_empty() {
                    text.push('\n');
                }
                text.push_str(&stderr);
            }
            (
                output.status.code().unwrap_or(1),
                text.trim().to_string(),
            )
        }
        Err(error) => (127, format!("command failed: {program}: {error}")),
    }
}

pub fn run_host_job(
    verb: &str,
    arguments: &str,
    repository_root: &Path,
    effect_directory: &Path,
    confirmed_high_blast: bool,
) -> HostJobResult {
    let started = Instant::now();
    let verb_lower = verb.to_lowercase();

    match verb_lower.as_str() {
        "help" => {
            let text = "Commands:\n• help · ping · status · inventory · audit · omarchy · run <prompt>\n• confirm <token> … for high-blast";
            HostJobResult {
                succeeded: true,
                verb: "help".into(),
                output_text: text.into(),
                exit_code: 0,
                duration_seconds: started.elapsed().as_secs_f64(),
                effect_log_path: None,
            }
        }
        "ping" | "whoami" => {
            let text = "Reachable — ready for next command";
            let path = write_effect_log(effect_directory, "host-effect-ping.txt", &format!("{text}\n"));
            HostJobResult {
                succeeded: true,
                verb: verb_lower,
                output_text: text.into(),
                exit_code: 0,
                duration_seconds: started.elapsed().as_secs_f64(),
                effect_log_path: Some(path),
            }
        }
        "status" | "inventory" => {
            let script = repository_root.join("maintenance").join("inventory.sh");
            let (code, output) = if script.is_file() {
                let text_only = verb_lower == "status";
                if text_only {
                    run_shell_command(
                        script.to_str().unwrap_or("inventory.sh"),
                        &["--text", "--no-write"],
                        repository_root,
                        90,
                    )
                } else {
                    run_shell_command(
                        script.to_str().unwrap_or("inventory.sh"),
                        &["--json", "--no-write"],
                        repository_root,
                        90,
                    )
                }
            } else {
                (1, format!("missing {}", script.display()))
            };
            let path = write_effect_log(
                effect_directory,
                "host-effect-inventory.txt",
                &format!("{output}\n"),
            );
            HostJobResult {
                succeeded: code == 0,
                verb: if verb_lower == "status" {
                    "status".into()
                } else {
                    "inventory".into()
                },
                output_text: if output.is_empty() {
                    format!("(exit {code})")
                } else {
                    output
                },
                exit_code: code,
                duration_seconds: started.elapsed().as_secs_f64(),
                effect_log_path: Some(path),
            }
        }
        "audit" => {
            let script = repository_root.join("maintenance").join("security-audit.sh");
            let (code, output) = if script.is_file() {
                let (help_code, help_out) = run_shell_command(
                    script.to_str().unwrap_or("security-audit.sh"),
                    &["--help"],
                    repository_root,
                    30,
                );
                if help_out.to_lowercase().contains("dry-run") {
                    run_shell_command(
                        script.to_str().unwrap_or("security-audit.sh"),
                        &["--dry-run"],
                        repository_root,
                        180,
                    )
                } else {
                    (help_code, help_out)
                }
            } else {
                (1, format!("missing {}", script.display()))
            };
            let path =
                write_effect_log(effect_directory, "host-effect-audit.txt", &format!("{output}\n"));
            HostJobResult {
                succeeded: code == 0,
                verb: "audit".into(),
                output_text: output.chars().take(4000).collect(),
                exit_code: code,
                duration_seconds: started.elapsed().as_secs_f64(),
                effect_log_path: Some(path),
            }
        }
        "omarchy" => {
            let script = repository_root.join("maintenance").join("omarchy-status.sh");
            let (code, output) = if script.is_file() {
                run_shell_command(
                    script.to_str().unwrap_or("omarchy-status.sh"),
                    &[],
                    repository_root,
                    60,
                )
            } else {
                (1, format!("missing {}", script.display()))
            };
            let path = write_effect_log(
                effect_directory,
                "host-effect-omarchy.txt",
                &format!("{output}\n"),
            );
            HostJobResult {
                succeeded: code == 0,
                verb: "omarchy".into(),
                output_text: output.chars().take(4000).collect(),
                exit_code: code,
                duration_seconds: started.elapsed().as_secs_f64(),
                effect_log_path: Some(path),
            }
        }
        // Operator-local inject path: freeform → grok -p. Not high-blast today;
        // reclassify / tighten tools before inbound DM control (see command_parse).
        "run" => {
            if arguments.trim().is_empty() {
                return HostJobResult {
                    succeeded: false,
                    verb: "run".into(),
                    output_text: "usage: run <prompt>".into(),
                    exit_code: 2,
                    duration_seconds: 0.0,
                    effect_log_path: None,
                };
            }
            let (code, output) = run_shell_command(
                "grok",
                &[
                    "-p",
                    arguments,
                    "--cwd",
                    repository_root.to_str().unwrap_or("."),
                    "--output-format",
                    "plain",
                    "--tools",
                    "read_file,grep,list_dir,run_terminal_cmd",
                    "--deny",
                    "Bash(rm*)",
                    "--deny",
                    "Bash(sudo*)",
                    "--max-turns",
                    "8",
                ],
                repository_root,
                300,
            );
            let path =
                write_effect_log(effect_directory, "host-effect-grok.txt", &format!("{output}\n"));
            HostJobResult {
                succeeded: code == 0,
                verb: "run".into(),
                output_text: output.chars().take(6000).collect(),
                exit_code: code,
                duration_seconds: started.elapsed().as_secs_f64(),
                effect_log_path: Some(path),
            }
        }
        high if matches!(
            high,
            "pkg" | "actuate" | "install" | "expand" | "remediate" | "apply" | "rm" | "delete"
                | "reboot" | "shutdown" | "yolo"
        ) =>
        {
            if !confirmed_high_blast {
                return HostJobResult {
                    succeeded: false,
                    verb: high.into(),
                    output_text: format!(
                        "blocked: `{high}` is high-blast; send `confirm <token> {high} {arguments}`"
                    ),
                    exit_code: 403,
                    duration_seconds: 0.0,
                    effect_log_path: None,
                };
            }
            HostJobResult {
                succeeded: false,
                verb: high.into(),
                output_text: format!(
                    "confirmed but not auto-executed in v1 (manual/archy): {high} {arguments}"
                ),
                exit_code: 501,
                duration_seconds: 0.0,
                effect_log_path: None,
            }
        }
        other => HostJobResult {
            succeeded: false,
            verb: other.into(),
            output_text: format!("unknown command: {other}"),
            exit_code: 2,
            duration_seconds: 0.0,
            effect_log_path: None,
        },
    }
}
