//! groxy — host → XChat outcome DMs (Rust satellite under Eagle discipline).
//!
//! Package path: `tools/groxy`. Binary: **groxy**.
//!
//! **Supported product path:** `inject` (and dry-run inject) — host runs a
//! command and posts an outcome package to XChat via `xurl dm`.
//!
//! **Not supported (removed from CLI):** live `poll` / DM→host control.
//! Operator pings often never appear on `GET /2/dm_events` while inject works;
//! rate limits make poll unsuitable as a production control plane without a
//! push/webhook product (e.g. Account Activity). Revisit only with a proven
//! inbound transport.

mod allowlist;
mod command_parse;
mod dm_adapter;
mod eagle;
mod host_job;
mod outcome_package;
mod state_store;

use allowlist::{load_policy, RemoteControlPolicy};
use clap::{Parser, Subcommand};
use command_parse::DirectMessageEvent;
use dm_adapter::{
    fetch_authenticated_identity, DryRunDirectMessageAdapter, XurlDirectMessageAdapter,
};
use eagle::{process_direct_message_event, DispatchOutcomeKind};
use state_store::{default_state_path, load_state_compatible, save_state};
use std::path::PathBuf;

const BANNER: &str = "\
groxy — host → XChat outcome packages for arch-machine
Supported:  inject  (host job → ✓ Done package → XChat DM)
Not supported: live DM → host poll (deferred; not production-grade on GET dm_events)
";

#[derive(Parser, Debug)]
#[command(
    name = "groxy",
    about = "Host → XChat outcome DMs (inject). Live DM→host poll is not supported.",
    long_about = BANNER,
    version
)]
struct Cli {
    /// Allowlist config path (default: search local/gitignored + template).
    #[arg(long, global = true)]
    config: Option<PathBuf>,

    /// State file for seen event ids (used by inject dedupe).
    #[arg(long, global = true)]
    state: Option<PathBuf>,

    /// Working directory for effects + outbound packages.
    #[arg(long, global = true)]
    work_dir: Option<PathBuf>,

    /// Do not call live xurl send; write packages to disk.
    #[arg(long, global = true, default_value_t = false)]
    dry_run: bool,

    /// Send real XChat DMs via xurl.
    #[arg(long, global = true, default_value_t = false)]
    live: bool,

    /// DM recipient username (default: authenticated self).
    #[arg(long, global = true, env = "GROXY_REPLY_TO")]
    reply_to: Option<String>,

    /// Extra allowlisted sender user id (repeatable).
    #[arg(long = "allow-id", global = true)]
    allow_ids: Vec<String>,

    /// Repository root (default: walk up from CARGO_MANIFEST_DIR).
    #[arg(long, global = true, env = "GROXY_ROOT")]
    repository_root: Option<PathBuf>,

    #[command(subcommand)]
    command: Option<Commands>,
}

#[derive(Subcommand, Debug, Clone)]
enum Commands {
    /// Show product banner (use --help for full CLI).
    About,
    /// Run a host command and post outcome to XChat (or dry-run files).
    ///
    /// This is the supported Grok/host → DM flow.
    Inject {
        /// Command text, e.g. status or ping
        text: String,
        /// Synthetic sender id for dry-run (live uses authenticated self when default).
        #[arg(long, default_value = "100001")]
        sender_id: String,
        #[arg(long)]
        event_id: Option<String>,
    },
    /// Build a demo outbound package without running a host job.
    DemoOutbound {
        #[arg(long, default_value = "status")]
        verb: String,
        #[arg(long, default_value = "demo host status: ok")]
        text: String,
    },
}

fn main() {
    let cli = Cli::parse();
    let exit_code = run(cli);
    std::process::exit(exit_code);
}

fn run(cli: Cli) -> i32 {
    let command = cli.command.clone().unwrap_or(Commands::About);
    match command {
        Commands::About => {
            print!("{BANNER}");
            println!(
                "Use: groxy --help | groxy --dry-run inject \"ping\" | groxy --live inject \"status\""
            );
            println!(
                "Note: live poll / DM→host is intentionally not offered (see docs/groxy.md)."
            );
            0
        }
        Commands::DemoOutbound { verb, text } => {
            let work = resolve_work_dir(&cli);
            let package_dir = work.join("outbound").join("demo");
            let package = outcome_package::build_outbound_package(
                &verb,
                true,
                &text,
                std::env::var("GROXY_PR_URL").ok().as_deref(),
            );
            let _ = package.write_to_directory(&package_dir);
            print!("{BANNER}");
            println!("dry-run outbound → {}", package_dir.display());
            println!("--- dm_payload ---");
            println!("{}", package.direct_message_body(900));
            0
        }
        Commands::Inject {
            text,
            sender_id,
            event_id,
        } => run_inject(&cli, text, sender_id, event_id),
    }
}

fn is_live(cli: &Cli) -> bool {
    if cli.live {
        return true;
    }
    if cli.dry_run {
        return false;
    }
    std::env::var("GROXY_LIVE").ok().as_deref() == Some("1")
}

fn repository_root(cli: &Cli) -> PathBuf {
    if let Some(ref path) = cli.repository_root {
        return path.clone();
    }
    if let Ok(root) = std::env::var("GROXY_ROOT") {
        return PathBuf::from(root);
    }
    if let Ok(root) = std::env::var("TINFOIL_ROOT") {
        return PathBuf::from(root);
    }
    // tools/groxy → repository root
    let manifest = PathBuf::from(env!("CARGO_MANIFEST_DIR"));
    manifest
        .parent()
        .and_then(|p| p.parent())
        .map(|p| p.to_path_buf())
        .unwrap_or_else(|| std::env::current_dir().unwrap_or_else(|_| PathBuf::from(".")))
}

fn resolve_work_dir(cli: &Cli) -> PathBuf {
    if let Some(ref path) = cli.work_dir {
        let _ = std::fs::create_dir_all(path);
        return path.clone();
    }
    let home = std::env::var_os("HOME")
        .map(PathBuf::from)
        .unwrap_or_else(|| PathBuf::from("."));
    let work = home.join(".local").join("state").join("groxy");
    let _ = std::fs::create_dir_all(&work);
    work
}

fn resolve_policy(cli: &Cli, live: bool) -> RemoteControlPolicy {
    let root = repository_root(cli);
    let mut policy = if let Some(ref config) = cli.config {
        if config.is_file() {
            let text = std::fs::read_to_string(config).unwrap_or_default();
            allowlist::parse_allowlist_text(&text)
        } else {
            load_policy(&root)
        }
    } else {
        load_policy(&root)
    };
    for id in &cli.allow_ids {
        policy.merge_user_id(id);
    }

    let allow_self_env = std::env::var("GROXY_ALLOW_SELF").unwrap_or_default();
    let allow_self = matches!(allow_self_env.as_str(), "1" | "true" | "yes")
        || (live
            && policy.is_empty()
            && !matches!(allow_self_env.as_str(), "0" | "false" | "no"));

    if allow_self || live {
        if let Some(identity) = fetch_authenticated_identity() {
            if allow_self {
                policy = policy.with_authenticated_self(&identity.user_id, &identity.username);
                eprintln!(
                    "policy: allowlist includes authenticated self (@{}) — runtime only",
                    identity.username
                );
            }
        }
    }
    if live && policy.is_empty() {
        eprintln!(
            "error: empty allowlist. Set GROXY_ALLOW_SELF=1 or allowlist.local.conf (gitignored)."
        );
    }
    policy
}

fn resolve_reply_to(cli: &Cli, live: bool) -> String {
    if let Some(ref reply) = cli.reply_to {
        if !reply.is_empty() {
            return reply.trim_start_matches('@').to_string();
        }
    }
    if live {
        if let Some(identity) = fetch_authenticated_identity() {
            eprintln!(
                "reply-to: defaulting to authenticated self @{}",
                identity.username
            );
            return identity.username;
        }
    }
    String::new()
}

fn run_inject(
    cli: &Cli,
    text: String,
    sender_id: String,
    event_id: Option<String>,
) -> i32 {
    let live = is_live(cli);
    let mut policy = resolve_policy(cli, live);
    let work = resolve_work_dir(cli);
    let state_path = cli.state.clone().unwrap_or_else(default_state_path);
    let mut state = load_state_compatible(&state_path);
    let repository_root = repository_root(cli);
    let mut reply_to = resolve_reply_to(cli, live);
    if !live && reply_to.is_empty() {
        reply_to = "dry-run-recipient".into();
    }

    let mut resolved_sender = sender_id.clone();
    if live && (resolved_sender == "100001" || resolved_sender.is_empty()) {
        if let Some(identity) = fetch_authenticated_identity() {
            resolved_sender = identity.user_id;
        }
    }
    if !policy.allows_sender(Some(&resolved_sender), None) {
        policy.merge_user_id(&resolved_sender);
    }

    let event = DirectMessageEvent {
        id: Some(
            event_id.unwrap_or_else(|| format!("inject-{}", chrono::Utc::now().timestamp())),
        ),
        text: Some(text),
        event_type: Some("MessageCreate".into()),
        sender_id: Some(resolved_sender),
        dm_conversation_id: Some("local-inject".into()),
        is_public_post: false,
        source: None,
    };

    let pr = std::env::var("GROXY_PR_URL").ok();
    let result = process_direct_message_event(
        &event,
        &policy,
        &mut state,
        &repository_root,
        &work.join("effects"),
        &work.join("outbound"),
        pr.as_deref(),
    );
    let _ = save_state(&state_path, &state);

    if let Some(ref package) = result.outbound_package {
        let body = package.direct_message_body(900);
        if live {
            match XurlDirectMessageAdapter::new() {
                Ok(adapter) => match adapter.send_text(&reply_to, &body) {
                    Ok(send_result) => {
                        print!("{BANNER}");
                        println!(
                            "{}",
                            serde_json::json!({
                                "accepted": result.accepted,
                                "kind": format!("{:?}", result.kind),
                                "event_id": result.event_id,
                                "send_result": send_result,
                                "package_directory": result.package_directory,
                            })
                        );
                        println!("--- dm_payload ---");
                        println!("{body}");
                    }
                    Err(error) => {
                        eprintln!("send failed: {error}");
                        return 1;
                    }
                },
                Err(error) => {
                    eprintln!("xurl adapter: {error}");
                    return 2;
                }
            }
        } else {
            let mut dry =
                DryRunDirectMessageAdapter::new(None, work.join("outbound").join("sends"));
            let _ = dry.send_text(&reply_to, &body);
            print!("{BANNER}");
            println!(
                "{}",
                serde_json::json!({
                    "accepted": result.accepted,
                    "kind": format!("{:?}", result.kind),
                    "event_id": result.event_id,
                    "package_directory": result.package_directory,
                    "dry_run": true,
                })
            );
            println!("--- dm_payload ---");
            println!("{body}");
        }
    }

    if result.accepted
        && matches!(
            result.kind,
            DispatchOutcomeKind::Ok
                | DispatchOutcomeKind::HostFailed
                | DispatchOutcomeKind::PendingConfirm
        )
    {
        0
    } else if result.accepted {
        0
    } else {
        1
    }
}
