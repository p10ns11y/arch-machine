//! CLI for keeper. Passphrase via env/file only (never argv).

use crate::ceremony::{
    drill, get_secret, get_secret_with_escrow, init_vault, put_secret, status,
};
use clap::{Parser, Subcommand};
use serde_json::json;
use std::fs;
use std::path::PathBuf;
use std::process::ExitCode;

#[derive(Parser, Debug)]
#[command(
    name = "keeper",
    about = "Simple threshold secrets: any 2 of {passphrase, offline, device} — hybrid PQ seal"
)]
pub struct Cli {
    #[command(subcommand)]
    pub cmd: Commands,
}

#[derive(Subcommand, Debug)]
pub enum Commands {
    /// Create vault (any 2 of 3: passphrase, offline escrow, device)
    Init {
        /// Path to write the ONE offline escrow file (keep OFF this laptop)
        #[arg(long)]
        escrow: PathBuf,
        #[arg(long, env = "KEEPER_ROOT")]
        root: Option<PathBuf>,
    },
    /// Store a named secret (needs passphrase + this machine)
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
    ///
    /// Default: passphrase + device.  
    /// With `--escrow`: offline file + device (no passphrase — forgot-password path).
    Get {
        name: String,
        /// Offline escrow file (unlock without passphrase)
        #[arg(long)]
        escrow: Option<PathBuf>,
        #[arg(long, env = "KEEPER_ROOT")]
        root: Option<PathBuf>,
    },
    /// Health + mental model card (remember / store / free)
    Status {
        #[arg(long, env = "KEEPER_ROOT")]
        root: Option<PathBuf>,
    },
    /// Prove recover works (offline + device). Marks healthy.
    Drill {
        #[arg(long)]
        escrow: PathBuf,
        #[arg(long, env = "KEEPER_ROOT")]
        root: Option<PathBuf>,
    },
    /// Same as drill
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
    Err(
        "set KEEPER_PASSPHRASE or KEEPER_PASSPHRASE_FILE\n\
         (daily path: one passphrase only — device is automatic)\n\
         forgot passphrase?  get NAME --escrow /path/to/escrow.json"
            .into(),
    )
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
            let res = init_vault(&root, &pass, &escrow).map_err(|e| e.to_string())?;
            println!(
                "{}",
                serde_json::to_string_pretty(&json!({
                    "ok": true,
                    "root": root,
                    "k": res.k,
                    "n": res.n,
                    "model": res.model,
                    "escrow": escrow,
                    "drillProven": false,
                    "healthy": false,
                    "sealAlgorithm": res.seal_algorithm,
                    "factors": res.factors,
                    "remember": "ONE passphrase (head or password manager)",
                    "storeOffline": "copy escrow file OFF this laptop now",
                    "free": "device (automatic)",
                    "next": "recover --escrow <file> once to prove drill; then get needs only passphrase",
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
            let val = if let Some(v) = value {
                v
            } else if let Some(f) = file {
                fs::read_to_string(f).map_err(|e| e.to_string())?
            } else {
                return Err("put requires --value or --file".into());
            };
            put_secret(&root, &pass, &name, &val).map_err(|e| e.to_string())?;
            println!(
                "{}",
                serde_json::to_string_pretty(&json!({ "ok": true, "name": name })).unwrap()
            );
            Ok(ExitCode::SUCCESS)
        }
        Commands::Get { name, escrow, root } => {
            let root = resolve_root(root);
            let v = if let Some(esc) = escrow {
                get_secret_with_escrow(&root, &esc, &name).map_err(|e| e.to_string())?
            } else {
                let pass = read_passphrase()?;
                get_secret(&root, &pass, &name).map_err(|e| e.to_string())?
            };
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
            let dr = drill(&root, &escrow).map_err(|e| e.to_string())?;
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
                    "hint": "forgot passphrase later? get NAME --escrow <same file>",
                }))
                .unwrap()
            );
            Ok(ExitCode::SUCCESS)
        }
    }
}
