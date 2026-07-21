//! CLI for keeper. Passphrase via env/file or interactive non-echo prompts (never argv).

use crate::ceremony::{
    change_passphrase, drill, enroll_yubikey, get_secret, get_secret_with_escrow,
    get_secret_yubi_device, get_secret_yubi_escrow, init_vault, list_secret_names, put_secret,
    rebind_device, reset_passphrase_with_escrow, status, try_unlock_yubi_only,
};
use crate::interactive::{
    escrow_under_home, run_interactive_session, run_loop, run_onboard, ScriptedIo, TtyIo,
};
use crate::yubi::{default_backend, DEFAULT_SLOT};
use clap::{Parser, Subcommand};
use serde_json::json;
use std::fs;
use std::io::{self, Write};
use std::path::PathBuf;
use std::process::ExitCode;

#[derive(Parser, Debug)]
#[command(
    name = "keeper",
    about = "Threshold secrets: any 2 of enrolled factors; optional strong YubiKey share\n\
             Default (no subcommand): interactive onboard/loop — secrets never on argv."
)]
pub struct Cli {
    #[command(subcommand)]
    pub cmd: Option<Commands>,
}

#[derive(Subcommand, Debug)]
pub enum Commands {
    /// Interactive step-by-step onboard then command loop (recommended)
    #[command(alias = "onboard")]
    Loop {
        /// Practice vault under a throwaway root (default if root unset: ~/tmp/keeper-practice-vault)
        #[arg(long)]
        practice: bool,
        /// Skip wizard when vault already exists
        #[arg(long)]
        menu_only: bool,
        #[arg(long)]
        escrow: Option<PathBuf>,
        #[arg(long, env = "KEEPER_ROOT")]
        root: Option<PathBuf>,
        /// Non-interactive test harness: path to JSON script
        /// `{ "lines": [...], "secrets": [...], "practice": true }`
        #[arg(long, hide = true)]
        script: Option<PathBuf>,
    },
    /// Create vault (any 2 of 3: passphrase, offline escrow, device)
    Init {
        #[arg(long)]
        escrow: PathBuf,
        #[arg(long, env = "KEEPER_ROOT")]
        root: Option<PathBuf>,
    },
    /// Store a named secret (passphrase + device). Prefer omit --value: prompts non-echo.
    Put {
        name: String,
        /// Deprecated: lands in shell history. Prefer omit (prompt) or --file.
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
    /// Re-bind device share after reimage / new machine (passphrase + escrow)
    Rebind {
        #[arg(long)]
        escrow: PathBuf,
        #[arg(long, env = "KEEPER_ROOT")]
        root: Option<PathBuf>,
        #[arg(long, default_value_t = DEFAULT_SLOT)]
        yubi_slot: u8,
    },
    /// List named secrets (no unlock)
    List {
        #[arg(long, env = "KEEPER_ROOT")]
        root: Option<PathBuf>,
    },
    /// Change passphrase (know current). Secrets + escrow unchanged.
    Passwd {
        #[arg(long, env = "KEEPER_ROOT")]
        root: Option<PathBuf>,
    },
    /// Forgot passphrase: escrow + device → set new passphrase (rewrites escrow)
    #[command(name = "passwd-reset")]
    PasswdReset {
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

fn practice_root() -> PathBuf {
    std::env::var_os("HOME")
        .map(PathBuf::from)
        .unwrap_or_else(|| PathBuf::from("."))
        .join("tmp")
        .join("keeper-practice-vault")
}

fn resolve_root(explicit: Option<PathBuf>) -> PathBuf {
    explicit.unwrap_or_else(default_root)
}

/// Passphrase: env / file first (automation); else non-echo TTY prompt.
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
    // Interactive non-echo (not shell history)
    if atty_stdin() {
        return rpassword::prompt_password("Passphrase (not echoed): ").map_err(|e| e.to_string());
    }
    Err(
        "set KEEPER_PASSPHRASE or KEEPER_PASSPHRASE_FILE, or run in a TTY / `keeper loop`\n\
         forgot passphrase?  get NAME --escrow file   or   get NAME --yubi"
            .into(),
    )
}

fn atty_stdin() -> bool {
    // Avoid extra dep: libc is_terminal on stdin
    std::io::IsTerminal::is_terminal(&io::stdin())
}

fn read_secret_value_interactive() -> Result<String, String> {
    if atty_stdin() {
        let v = rpassword::prompt_password("Secret value (not echoed): ").map_err(|e| e.to_string())?;
        if v.is_empty() {
            return Err("secret value cannot be empty".into());
        }
        return Ok(v);
    }
    Err("put requires --file PATH, interactive TTY prompt, or (discouraged) --value".into())
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
        None => run_loop_cmd(LoopArgs {
            practice: false,
            menu_only: false,
            escrow: None,
            root: None,
            script: None,
        }),
        Some(Commands::Loop {
            practice,
            menu_only,
            escrow,
            root,
            script,
        }) => run_loop_cmd(LoopArgs {
            practice,
            menu_only,
            escrow,
            root,
            script,
        }),
        Some(Commands::Init { escrow, root }) => {
            let root = resolve_root(root);
            if escrow_under_home(&escrow) {
                eprintln!(
                    "warning: escrow is under $HOME — copy OFF this laptop for real recovery"
                );
            }
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
                    "next": "recover --escrow once; prefer: keeper loop",
                    "note": "healthy ≠ vault open — only means drill worked",
                }))
                .unwrap()
            );
            Ok(ExitCode::SUCCESS)
        }
        Some(Commands::Put {
            name,
            value,
            file,
            root,
        }) => {
            let root = resolve_root(root);
            let pass = read_passphrase()?;
            let val = if let Some(v) = value {
                eprintln!(
                    "warning: --value lands in shell history; prefer `keeper put NAME` (prompt) or --file"
                );
                v
            } else if let Some(f) = file {
                fs::read_to_string(f).map_err(|e| e.to_string())?
            } else {
                read_secret_value_interactive()?
            };
            put_secret(&root, &pass, &name, &val).map_err(|e| e.to_string())?;
            println!(
                "{}",
                serde_json::to_string_pretty(&json!({ "ok": true, "name": name })).unwrap()
            );
            Ok(ExitCode::SUCCESS)
        }
        Some(Commands::Get {
            name,
            escrow,
            yubi,
            yubi_slot,
            root,
        }) => {
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
        Some(Commands::Status { root }) => {
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
                m.insert(
                    "note".into(),
                    json!("healthy only means recover drill worked once — vault is not left open"),
                );
            }
            println!("{}", serde_json::to_string_pretty(&obj).unwrap());
            Ok(if st.healthy {
                ExitCode::SUCCESS
            } else {
                ExitCode::from(2)
            })
        }
        Some(Commands::Drill { escrow, root }) | Some(Commands::Recover { escrow, root }) => {
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
        Some(Commands::Rebind {
            escrow,
            root,
            yubi_slot,
        }) => {
            let root = resolve_root(root);
            let pass = read_passphrase()?;
            let yubi = if crate::store::yubi_blob_exists(&root) {
                Some(default_backend(yubi_slot).map_err(|e| e.to_string())?)
            } else {
                None
            };
            let res = rebind_device(
                &root,
                &pass,
                &escrow,
                None,
                yubi.as_ref().map(|b| b.as_ref() as &dyn crate::yubi::YubiChallenge),
            )
            .map_err(|e| e.to_string())?;
            if escrow_under_home(&escrow) {
                eprintln!("warning: rewrite escrow is under $HOME — copy OFF laptop");
            }
            println!("{}", serde_json::to_string_pretty(&res).unwrap());
            Ok(ExitCode::SUCCESS)
        }
        Some(Commands::List { root }) => {
            let root = resolve_root(root);
            let names = list_secret_names(&root).map_err(|e| e.to_string())?;
            for n in names {
                println!("{n}");
            }
            Ok(ExitCode::SUCCESS)
        }
        Some(Commands::Passwd { root }) => {
            let root = resolve_root(root);
            let old = read_passphrase()?;
            // Prefer interactive new passphrase (never on argv)
            let new = if atty_stdin() {
                let a = rpassword::prompt_password("New passphrase (not echoed): ")
                    .map_err(|e| e.to_string())?;
                let b = rpassword::prompt_password("Confirm new passphrase: ")
                    .map_err(|e| e.to_string())?;
                if a != b {
                    return Err("new passphrases do not match".into());
                }
                a
            } else if let Ok(p) = std::env::var("KEEPER_NEW_PASSPHRASE") {
                p
            } else {
                return Err(
                    "set KEEPER_NEW_PASSPHRASE (automation) or run in a TTY for prompts".into(),
                );
            };
            let res = change_passphrase(&root, &old, &new).map_err(|e| e.to_string())?;
            println!("{}", serde_json::to_string_pretty(&res).unwrap());
            Ok(ExitCode::SUCCESS)
        }
        Some(Commands::PasswdReset { escrow, root }) => {
            let root = resolve_root(root);
            let new = if atty_stdin() {
                let a = rpassword::prompt_password("New passphrase (not echoed): ")
                    .map_err(|e| e.to_string())?;
                let b = rpassword::prompt_password("Confirm new passphrase: ")
                    .map_err(|e| e.to_string())?;
                if a != b {
                    return Err("new passphrases do not match".into());
                }
                a
            } else if let Ok(p) = std::env::var("KEEPER_NEW_PASSPHRASE") {
                p
            } else {
                return Err(
                    "set KEEPER_NEW_PASSPHRASE (automation) or run in a TTY for prompts".into(),
                );
            };
            let res =
                reset_passphrase_with_escrow(&root, &escrow, &new).map_err(|e| e.to_string())?;
            if escrow_under_home(&escrow) {
                eprintln!("warning: new escrow is under $HOME — copy OFF laptop");
            }
            println!("{}", serde_json::to_string_pretty(&res).unwrap());
            Ok(ExitCode::SUCCESS)
        }
        Some(Commands::EnrollYubikey { escrow, slot, root }) => {
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
        Some(Commands::YubiProbe { slot, root }) => {
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

struct LoopArgs {
    practice: bool,
    menu_only: bool,
    escrow: Option<PathBuf>,
    root: Option<PathBuf>,
    script: Option<PathBuf>,
}

fn run_loop_cmd(args: LoopArgs) -> Result<ExitCode, String> {
    let practice = args.practice;
    let root = if let Some(r) = args.root {
        r
    } else if practice {
        practice_root()
    } else {
        default_root()
    };
    let escrow = args.escrow.unwrap_or_else(|| {
        if practice {
            std::env::var_os("HOME")
                .map(PathBuf::from)
                .unwrap_or_else(|| PathBuf::from("."))
                .join("tmp")
                .join("keeper-practice-escrow.json")
        } else {
            root.join("escrow-PENDING-copy-to-usb.json")
        }
    });

    if let Some(script_path) = args.script {
        let raw = fs::read_to_string(&script_path).map_err(|e| e.to_string())?;
        let v: serde_json::Value = serde_json::from_str(&raw).map_err(|e| e.to_string())?;
        let lines: Vec<String> = v["lines"]
            .as_array()
            .ok_or("script.lines array")?
            .iter()
            .map(|x| x.as_str().unwrap_or("").to_string())
            .collect();
        let secrets: Vec<String> = v["secrets"]
            .as_array()
            .ok_or("script.secrets array")?
            .iter()
            .map(|x| x.as_str().unwrap_or("").to_string())
            .collect();
        let practice_flag = v["practice"].as_bool().unwrap_or(practice);
        let mut io = ScriptedIo::new(lines, secrets);
        let res = if args.menu_only || root.join("meta.json").exists() {
            run_loop(&mut io, root.clone(), Some(escrow.clone()))?;
            crate::interactive::OnboardResult {
                root: root.clone(),
                escrow: escrow.clone(),
                secret_name: String::new(),
                healthy: status(&root).map(|s| s.healthy).unwrap_or(false),
                drill_proven: status(&root).map(|s| s.drill_proven).unwrap_or(false),
                secret_ok: false,
            }
        } else {
            let onboard = run_onboard(&mut io, root.clone(), escrow.clone(), practice_flag)?;
            // Optional remaining script lines drive the command menu (no forced "enter loop?")
            if io.line_i < io.lines.len() {
                let _ = run_loop(&mut io, root.clone(), Some(escrow.clone()));
            }
            onboard
        };
        println!(
            "{}",
            serde_json::to_string_pretty(&json!({
                "ok": true,
                "mode": "scripted",
                "healthy": res.healthy,
                "drillProven": res.drill_proven,
                "secretOk": res.secret_ok,
                "secretName": res.secret_name,
                "root": res.root,
                "escrow": res.escrow,
                "uiLogLines": io.output.len(),
            }))
            .unwrap()
        );
        return Ok(if res.healthy || res.secret_ok || args.menu_only {
            ExitCode::SUCCESS
        } else {
            ExitCode::from(2)
        });
    }

    let mut io = TtyIo::new();
    if practice {
        let _ = fs::create_dir_all(root.parent().unwrap_or(std::path::Path::new(".")));
    }
    let res = run_interactive_session(
        &mut io,
        root,
        escrow,
        args.menu_only,
        practice,
    )?;
    // Ensure stdout gets a final summary for operators
    let _ = writeln!(
        io::stdout(),
        "{}",
        serde_json::to_string_pretty(&json!({
            "ok": true,
            "healthy": res.healthy,
            "drillProven": res.drill_proven,
            "secretOk": res.secret_ok,
            "root": res.root,
        }))
        .unwrap()
    );
    Ok(ExitCode::SUCCESS)
}
