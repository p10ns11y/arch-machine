//! CLI for keeper. Passphrase via env/file only (never argv).

use crate::ceremony::{
    drill, enroll_yubikey, get_secret, get_secret_with_escrow, get_secret_yubi_device,
    get_secret_yubi_escrow, init_vault, put_secret, status, try_unlock_yubi_only,
};
use crate::yubi::{default_backend, DEFAULT_SLOT};
use clap::{Parser, Subcommand};
use serde_json::json;
use std::fs;
use std::path::PathBuf;
use std::process::ExitCode;

#[derive(Parser, Debug)]
#[command(
    name = "keeper",
    about = "Threshold secrets: any 2 of enrolled factors; optional strong YubiKey share"
)]
pub struct Cli {
    #[command(subcommand)]
    pub cmd: Commands,
}

#[derive(Subcommand, Debug)]
pub enum Commands {
    /// Create vault (any 2 of 3: passphrase, offline escrow, device)
    Init {
        #[arg(long)]
        escrow: PathBuf,
        #[arg(long, env = "KEEPER_ROOT")]
        root: Option<PathBuf>,
    },
    /// Store a named secret (passphrase + device)
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
    /// `--escrow`: offline + device.  
    /// `--yubi`: strong path (YubiKey + device, or YubiKey + `--escrow`).
    Get {
        name: String,
        #[arg(long)]
        escrow: Option<PathBuf>,
        /// Use YubiKey challenge-response (strong factor; needs second factor)
        #[arg(long)]
        yubi: bool,
        #[arg(long, default_value_t = DEFAULT_SLOT)]
        yubi_slot: u8,
        #[arg(long, env = "KEEPER_ROOT")]
        root: Option<PathBuf>,
    },
    /// Health + one-card model
    Status {
        #[arg(long, env = "KEEPER_ROOT")]
        root: Option<PathBuf>,
    },
    /// Prove recover (offline + device)
    Drill {
        #[arg(long)]
        escrow: PathBuf,
        #[arg(long, env = "KEEPER_ROOT")]
        root: Option<PathBuf>,
    },
    Recover {
        #[arg(long)]
        escrow: PathBuf,
        #[arg(long, env = "KEEPER_ROOT")]
        root: Option<PathBuf>,
    },
    /// Enroll YubiKey as strong hardware share (re-splits to any-2-of-4; rewrites escrow)
    EnrollYubikey {
        #[arg(long)]
        escrow: PathBuf,
        #[arg(long, default_value_t = DEFAULT_SLOT)]
        slot: u8,
        #[arg(long, env = "KEEPER_ROOT")]
        root: Option<PathBuf>,
    },
    /// Prove YubiKey alone cannot open (exit 1 = good)
    YubiProbe {
        #[arg(long, default_value_t = DEFAULT_SLOT)]
        slot: u8,
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
         forgot passphrase?  get NAME --escrow file   or   get NAME --yubi"
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
                    "remember": "ONE passphrase",
                    "storeOffline": "copy escrow OFF this laptop",
                    "free": "device; later: enroll-yubikey for strong hardware share",
                    "next": "optional: enroll-yubikey --escrow <file>; then get --yubi",
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
        Commands::Get {
            name,
            escrow,
            yubi,
            yubi_slot,
            root,
        } => {
            let root = resolve_root(root);
            let v = if yubi {
                let backend = default_backend(yubi_slot).map_err(|e| e.to_string())?;
                if let Some(esc) = escrow {
                    get_secret_yubi_escrow(&root, &esc, &name, backend.as_ref())
                        .map_err(|e| e.to_string())?
                } else {
                    get_secret_yubi_device(&root, &name, backend.as_ref())
                        .map_err(|e| e.to_string())?
                }
            } else if let Some(esc) = escrow {
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
                m.insert(
                    "yubiEnrolled".into(),
                    json!(crate::store::yubi_blob_exists(&root)),
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
                }))
                .unwrap()
            );
            Ok(ExitCode::SUCCESS)
        }
        Commands::EnrollYubikey { escrow, slot, root } => {
            let root = resolve_root(root);
            let pass = read_passphrase()?;
            let backend = default_backend(slot).map_err(|e| e.to_string())?;
            let res = enroll_yubikey(&root, &pass, &escrow, backend.as_ref())
                .map_err(|e| e.to_string())?;
            println!(
                "{}",
                serde_json::to_string_pretty(&json!({
                    "ok": res.ok,
                    "k": res.k,
                    "n": res.n,
                    "slot": res.slot,
                    "model": res.model,
                    "factors": res.factors,
                    "hint": "strong get: get NAME --yubi  (YubiKey + device); solo yubi is refused",
                    "mock": std::env::var("KEEPER_YUBI_MOCK_SECRET").is_ok(),
                }))
                .unwrap()
            );
            Ok(ExitCode::SUCCESS)
        }
        Commands::YubiProbe { slot, root } => {
            let root = resolve_root(root);
            let backend = default_backend(slot).map_err(|e| e.to_string())?;
            match try_unlock_yubi_only(&root, backend.as_ref()) {
                Ok(_) => {
                    eprintln!("SECURITY_FAIL: yubikey alone opened root");
                    Ok(ExitCode::from(3))
                }
                Err(e) => {
                    println!(
                        "{}",
                        serde_json::to_string_pretty(&json!({
                            "ok": true,
                            "soloYubiRejected": true,
                            "detail": e.to_string(),
                        }))
                        .unwrap()
                    );
                    Ok(ExitCode::SUCCESS)
                }
            }
        }
    }
}
