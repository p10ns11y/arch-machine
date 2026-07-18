//! CLI for keeper. Secrets via env only (never argv for passphrase/knowledge).

use crate::ceremony::{drill, get_secret, init_vault, put_secret, status};
use clap::{Parser, Subcommand};
use serde_json::json;
use std::fs;
use std::path::PathBuf;
use std::process::ExitCode;

#[derive(Parser, Debug)]
#[command(
    name = "keeper",
    about = "Multi-factor threshold secrets holder (arch-machine) — hybrid PQ seal"
)]
pub struct Cli {
    #[command(subcommand)]
    pub cmd: Commands,
}

#[derive(Subcommand, Debug)]
pub enum Commands {
    /// Create vault (k=3 of 4: passphrase, offline, device, knowledge)
    Init {
        #[arg(long)]
        escrow: PathBuf,
        #[arg(long, env = "KEEPER_ROOT")]
        root: Option<PathBuf>,
    },
    /// Store a named secret
    Put {
        name: String,
        #[arg(long, conflicts_with = "file")]
        value: Option<String>,
        #[arg(long)]
        file: Option<PathBuf>,
        #[arg(long, env = "KEEPER_ROOT")]
        root: Option<PathBuf>,
    },
    /// Read a named secret
    Get {
        name: String,
        #[arg(long, env = "KEEPER_ROOT")]
        root: Option<PathBuf>,
    },
    /// Health + drillProven + factors
    Status {
        #[arg(long, env = "KEEPER_ROOT")]
        root: Option<PathBuf>,
    },
    /// Recover without primary passphrase (offline + device + knowledge)
    Drill {
        #[arg(long)]
        escrow: PathBuf,
        #[arg(long, env = "KEEPER_ROOT")]
        root: Option<PathBuf>,
    },
    /// Alias for drill (multi-factor recover)
    Recover {
        #[arg(long)]
        escrow: PathBuf,
        #[arg(long, env = "KEEPER_ROOT")]
        root: Option<PathBuf>,
    },
}

fn default_root() -> PathBuf {
    if let Ok(r) = std::env::var("KEEPER_ROOT") {
        return PathBuf::from(r);
    }
    std::env::var_os("HOME")
        .map(PathBuf::from)
        .unwrap_or_else(|| PathBuf::from("."))
        .join(".local/share/keeper")
}

fn resolve_root(explicit: Option<PathBuf>) -> PathBuf {
    explicit.unwrap_or_else(default_root)
}

fn read_passphrase() -> Result<String, String> {
    if let Ok(p) = std::env::var("KEEPER_PASSPHRASE") {
        if !p.is_empty() {
            return Ok(p);
        }
    }
    if let Ok(file) = std::env::var("KEEPER_PASSPHRASE_FILE") {
        let s = fs::read_to_string(&file).map_err(|e| format!("passphrase file: {e}"))?;
        return Ok(s.trim_end_matches('\n').to_string());
    }
    Err("set KEEPER_PASSPHRASE or KEEPER_PASSPHRASE_FILE".into())
}

fn read_knowledge() -> Result<String, String> {
    if let Ok(p) = std::env::var("KEEPER_KNOWLEDGE") {
        if !p.is_empty() {
            return Ok(p);
        }
    }
    if let Ok(file) = std::env::var("KEEPER_KNOWLEDGE_FILE") {
        let s = fs::read_to_string(&file).map_err(|e| format!("knowledge file: {e}"))?;
        return Ok(s.trim_end_matches('\n').to_string());
    }
    Err("set KEEPER_KNOWLEDGE or KEEPER_KNOWLEDGE_FILE (knowledge factor)".into())
}

pub fn run(cli: Cli) -> ExitCode {
    match run_inner(cli) {
        Ok(code) => code,
        Err(e) => {
            eprintln!("{e}");
            ExitCode::from(1)
        }
    }
}

fn run_inner(cli: Cli) -> Result<ExitCode, String> {
    match cli.cmd {
        Commands::Init { escrow, root } => {
            let root = resolve_root(root);
            let pass = read_passphrase()?;
            let knowledge = read_knowledge()?;
            let res = init_vault(&root, &pass, &escrow, &knowledge).map_err(|e| e.to_string())?;
            println!(
                "{}",
                serde_json::to_string_pretty(&json!({
                    "ok": true,
                    "root": root,
                    "k": res.k,
                    "n": res.n,
                    "escrow": escrow,
                    "drillProven": false,
                    "healthy": false,
                    "sealAlgorithm": res.seal_algorithm,
                    "factors": res.factors,
                    "hint": "drill/recover needs offline escrow + this machine + knowledge (no passphrase)",
                }))
                .unwrap()
            );
            Ok(ExitCode::SUCCESS)
        }
        Commands::Put {
            name,
            value,
            file,
            root,
        } => {
            let root = resolve_root(root);
            let pass = read_passphrase()?;
            let knowledge = read_knowledge()?;
            let val = if let Some(v) = value {
                v
            } else if let Some(f) = file {
                fs::read_to_string(f).map_err(|e| e.to_string())?
            } else {
                return Err("put requires --value or --file".into());
            };
            put_secret(&root, &pass, &knowledge, &name, &val).map_err(|e| e.to_string())?;
            println!(
                "{}",
                serde_json::to_string_pretty(&json!({ "ok": true, "name": name })).unwrap()
            );
            Ok(ExitCode::SUCCESS)
        }
        Commands::Get { name, root } => {
            let root = resolve_root(root);
            let pass = read_passphrase()?;
            let knowledge = read_knowledge()?;
            let v = get_secret(&root, &pass, &knowledge, &name).map_err(|e| e.to_string())?;
            println!("{v}");
            Ok(ExitCode::SUCCESS)
        }
        Commands::Status { root } => {
            let root = resolve_root(root);
            let st = status(&root).map_err(|e| e.to_string())?;
            let mut obj = serde_json::to_value(&st).unwrap();
            if let Some(m) = obj.as_object_mut() {
                m.insert("root".into(), json!(root));
                m.insert(
                    "ipTrust".into(),
                    json!("forbidden (public ISP IP / GeoIP weight=0)"),
                );
            }
            println!("{}", serde_json::to_string_pretty(&obj).unwrap());
            Ok(if st.healthy {
                ExitCode::SUCCESS
            } else {
                ExitCode::from(2)
            })
        }
        Commands::Drill { escrow, root } | Commands::Recover { escrow, root } => {
            let root = resolve_root(root);
            let knowledge = read_knowledge()?;
            let dr = drill(&root, &escrow, &knowledge).map_err(|e| e.to_string())?;
            let st = status(&root).map_err(|e| e.to_string())?;
            println!(
                "{}",
                serde_json::to_string_pretty(&json!({
                    "ok": dr.ok,
                    "canaryOk": dr.canary_ok,
                    "drillProven": st.drill_proven,
                    "healthy": st.healthy,
                    "path": dr.path,
                    "reason": st.reason,
                }))
                .unwrap()
            );
            Ok(ExitCode::SUCCESS)
        }
    }
}
