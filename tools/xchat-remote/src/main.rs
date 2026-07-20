//! groxy — XChat DM remote control (Rust satellite under Eagle discipline).
//!
//! Package path: `tools/xchat-remote` (not a vague dump). Binary name: **groxy**.
//! Thin CLI → Eagle process_direct_message_event → offline host job → outcome DM.

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
use std::thread;
use std::time::Duration;

const BANNER: &str = "\
groxy (xchat-remote) — XChat DM remote control for arch-machine hosts
Eagle routes DM events; host jobs run offline; outcome packages go back to XChat.
Inbound:  allowlisted DM → host action
Outbound: ✓ Done bullets + visual panel (+ PR when set)
";

#[derive(Parser, Debug)]
#[command(
    name = "groxy",
    about = "XChat DM remote control (Rust satellite)",
    long_about = BANNER,
    version
)]
struct Cli {
    /// Allowlist config path (default: search local/gitignored + template).
    #[arg(long, global = true)]
    config: Option<PathBuf>,

    /// State file for seen DM event ids.
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

    /// Repository root (default: walk up from cwd / CARGO_MANIFEST_DIR).
    #[arg(long, global = true, env = "GROXY_ROOT")]
    repository_root: Option<PathBuf>,

    #[command(subcommand)]
    command: Option<Commands>,
}

#[derive(Subcommand, Debug, Clone)]
enum Commands {
    /// Show product banner (use --help for full CLI).
    About,
    /// Poll DM events once and process.
    Once {
        /// JSON dm_events fixture (dry-run).
        #[arg(long)]
        fixture: Option<PathBuf>,
        /// Max events to fetch.
        #[arg(long, default_value_t = 15)]
        max: usize,
    },
    /// Poll DM events in a loop (one process only; prefer --interval 90+).
    Poll {
        /// Seconds between polls (X dm_events ≈ 15 req/window).
        #[arg(long, default_value_t = 90.0)]
        interval: f64,
        #[arg(long)]
        fixture: Option<PathBuf>,
        #[arg(long, default_value_t = 15)]
        max: usize,
        /// Stop after N loops (0 = forever).
        #[arg(long, default_value_t = 0)]
        count: u64,
    },
    /// Inject one synthetic DM command (local E2E / live one-shot).
    Inject {
        /// Command text, e.g. status or !g ping
        text: String,
        /// Synthetic sender id for dry-run (live uses authenticated self when default).
        #[arg(long, default_value = "100001")]
        sender_id: String,
        #[arg(long)]
        event_id: Option<String>,
    },
    /// Build a demo outbound package without inbound.
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
            println!("Use: groxy --help | groxy --dry-run inject \"ping\" | groxy --live poll --interval 90");
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
        Commands::Once { fixture, max } => run_poll_loop(&cli, fixture, max, 1, 0.0),
        Commands::Poll {
            interval,
            fixture,
            max,
            count,
        } => {
            let loops = if count == 0 { u64::MAX } else { count };
            if !is_live(&cli) && fixture.is_none() {
                // dry-run poll without fixture is empty; still ok
            }
            if is_live(&cli) && interval < 60.0 {
                eprintln!(
                    "warn: interval < 60s can hit X DM rate limits (~15/window); prefer 90+"
                );
            }
            run_poll_loop(&cli, fixture, max, loops, interval)
        }
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
    // tools/xchat-remote → repo root
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

    // Send outbound
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
            let mut dry = DryRunDirectMessageAdapter::new(None, work.join("outbound").join("sends"));
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

fn run_poll_loop(
    cli: &Cli,
    fixture: Option<PathBuf>,
    max_results: usize,
    loops: u64,
    interval_seconds: f64,
) -> i32 {
    let live = is_live(cli) && fixture.is_none();
    let policy = resolve_policy(cli, live);
    let work = resolve_work_dir(cli);
    let state_path = cli.state.clone().unwrap_or_else(default_state_path);
    let mut state = load_state_compatible(&state_path);
    let repository_root = repository_root(cli);
    let mut reply_to = resolve_reply_to(cli, live);
    if !live && reply_to.is_empty() {
        reply_to = "dry-run-recipient".into();
    }
    let pr = std::env::var("GROXY_PR_URL").ok();

    print!("{BANNER}");
    println!(
        "mode={} work={} interval={}s",
        if live { "live" } else { "dry-run" },
        work.display(),
        interval_seconds
    );

    let mut dry_adapter = DryRunDirectMessageAdapter::new(
        fixture.clone(),
        work.join("outbound").join("sends"),
    );
    let live_adapter = if live {
        Some(XurlDirectMessageAdapter::new())
    } else {
        None
    };

    for iteration in 1..=loops {
        let events = if live {
            match live_adapter.as_ref().unwrap() {
                Ok(adapter) => match adapter.list_events(max_results) {
                    Ok(events) => events,
                    Err(dm_adapter::DirectMessageError::RateLimited { sleep_seconds }) => {
                        eprintln!(
                            "[{iteration}] rate limited — sleeping {sleep_seconds}s (one poller only)"
                        );
                        if loops == 1 {
                            return 1;
                        }
                        thread::sleep(Duration::from_secs(sleep_seconds));
                        continue;
                    }
                    Err(error) => {
                        eprintln!("[{iteration}] poll error: {error}");
                        if loops == 1 {
                            return 1;
                        }
                        thread::sleep(Duration::from_secs(interval_seconds.max(60.0) as u64));
                        continue;
                    }
                },
                Err(error) => {
                    eprintln!("xurl: {error}");
                    return 2;
                }
            }
        } else {
            match dry_adapter.list_events(max_results) {
                Ok(events) => events,
                Err(error) => {
                    eprintln!("fixture error: {error}");
                    return 1;
                }
            }
        };

        let mut accepted = 0u32;
        let mut rejected = 0u32;
        let mut skipped = 0u32;
        // Process oldest first
        for event in events.iter().rev() {
            let result = process_direct_message_event(
                event,
                &policy,
                &mut state,
                &repository_root,
                &work.join("effects"),
                &work.join("outbound"),
                pr.as_deref(),
            );
            match result.kind {
                DispatchOutcomeKind::AlreadySeen | DispatchOutcomeKind::NoCommand => skipped += 1,
                DispatchOutcomeKind::SenderNotAllowlisted
                | DispatchOutcomeKind::PublicPostRejected => rejected += 1,
                DispatchOutcomeKind::Ok
                | DispatchOutcomeKind::HostFailed
                | DispatchOutcomeKind::PendingConfirm
                | DispatchOutcomeKind::BadConfirm
                | DispatchOutcomeKind::ConfirmSenderMismatch => {
                    accepted += 1;
                    if let Some(ref package) = result.outbound_package {
                        let body = package.direct_message_body(900);
                        if live {
                            if let Ok(adapter) = live_adapter.as_ref().unwrap() {
                                let _ = adapter.send_text(&reply_to, &body);
                            }
                        } else {
                            let _ = dry_adapter.send_text(&reply_to, &body);
                        }
                        println!(
                            "  - {:?} event={:?} verb={:?}",
                            result.kind,
                            result.event_id,
                            result.command.as_ref().map(|c| &c.verb)
                        );
                    }
                }
            }
        }
        state.last_poll_at_unix = Some(chrono::Utc::now().timestamp() as f64);
        let _ = save_state(&state_path, &state);
        println!(
            "[{iteration}] processed batch accepted≈{accepted} rejected={rejected} skipped={skipped}"
        );

        if loops == 1 || iteration == loops {
            break;
        }
        thread::sleep(Duration::from_secs_f64(interval_seconds.max(1.0)));
    }
    0
}
