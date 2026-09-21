//! Escrow custody distribute — push opaque offline share bytes to peer holders.
//!
//! ## Laws (fail closed)
//!
//! 1. **Non-leaky peer storage:** holders see only opaque `ShareJson` escrow bytes — never
//!    plaintext secret values, never `passphrase.wrap.json`, never `KEEPER_PASSPHRASE` /
//!    `KEEPER_PASSPHRASE_FILE` on this path.
//! 2. **Distribute gate:** copy runs only when **both** owner and holder endpoints are
//!    reachable, **or** the operator sets `--hitl-approve-offline` for a one-shot transfer.
//! 3. **Escrow is not unlock:** peer escrow alone cannot open named secrets on the holder
//!    machine — unlock still needs a second factor (owner device share after restore/rebind,
//!    or passphrase + escrow on a machine that holds the vault). This module copies bytes
//!    only; it never ships vault ciphertext or decrypts secrets.

use crate::crypto::ShareJson;
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
use std::fs;
use std::io::Write;
use std::path::{Path, PathBuf};
use std::process::{Command, Stdio};
use thiserror::Error;

/// Public host aliases (docs / CLI only — no real hostnames).
pub const ALLOWED_ALIASES: &[&str] = &["laptop-1", "laptop-2", "mac-mini", "grok-bot"];

#[derive(Debug, Error)]
pub enum CustodyError {
    #[error("io: {0}")]
    Io(#[from] std::io::Error),
    #[error("json: {0}")]
    Json(#[from] serde_json::Error),
    #[error("{0}")]
    Msg(String),
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct CustodyMap {
    pub owners: std::collections::BTreeMap<String, OwnerEntry>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct OwnerEntry {
    pub holders: Vec<HolderSpec>,
}

/// Holder transport: `local:/base/home` or `ssh:user@host`.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct HolderSpec {
    pub alias: String,
    pub transport: String,
    pub target: String,
}

#[derive(Debug, Clone)]
pub struct DistributeOpts {
    pub escrow_path: PathBuf,
    pub owner_alias: String,
    pub holders: Vec<HolderSpec>,
    pub hitl_approve_offline: bool,
    pub verify_complete: bool,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct DistributeResult {
    pub ok: bool,
    pub owner_alias: String,
    pub escrow_sha256: String,
    pub copied: Vec<CopiedPeer>,
    pub skipped: Vec<SkippedPeer>,
    pub verify_complete: Option<bool>,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct CopiedPeer {
    pub holder_alias: String,
    pub dest: String,
    pub bytes: usize,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct SkippedPeer {
    pub holder_alias: String,
    pub reason: String,
}

/// Destination path on a holder for vault owner `owner_alias`.
pub fn peer_escrow_path(holder_home: &Path, owner_alias: &str) -> PathBuf {
    holder_home
        .join("keeper-escrow")
        .join("peers")
        .join(owner_alias)
        .join("keeper-escrow.json")
}

pub fn validate_alias(alias: &str) -> Result<(), CustodyError> {
    if ALLOWED_ALIASES.contains(&alias) {
        Ok(())
    } else {
        Err(CustodyError::Msg(format!(
            "unknown alias '{alias}' — allowed: {}",
            ALLOWED_ALIASES.join(", ")
        )))
    }
}

/// Parse `alias=local:/path` or `alias=ssh:user@host`.
pub fn parse_holder_spec(raw: &str) -> Result<HolderSpec, CustodyError> {
    let (alias, rest) = raw
        .split_once('=')
        .ok_or_else(|| CustodyError::Msg(format!("holder spec must be alias=transport:target, got: {raw}")))?;
    validate_alias(alias)?;
    let (transport, target) = rest
        .split_once(':')
        .ok_or_else(|| CustodyError::Msg(format!("holder transport must be local:PATH or ssh:USER@HOST, got: {rest}")))?;
    if transport != "local" && transport != "ssh" {
        return Err(CustodyError::Msg(format!(
            "unsupported transport '{transport}' — use local or ssh"
        )));
    }
    if target.is_empty() {
        return Err(CustodyError::Msg("holder target cannot be empty".into()));
    }
    Ok(HolderSpec {
        alias: alias.to_string(),
        transport: transport.to_string(),
        target: target.to_string(),
    })
}

/// Refuse if passphrase material would co-ship with escrow (law 8).
pub fn assert_no_passphrase_co_ship(escrow_path: &Path, extra_paths: &[PathBuf]) -> Result<(), CustodyError> {
    if std::env::var("KEEPER_PASSPHRASE").is_ok() {
        return Err(CustodyError::Msg(
            "refusing distribute: unset KEEPER_PASSPHRASE — passphrase must not travel with escrow".into(),
        ));
    }
    if let Ok(pf) = std::env::var("KEEPER_PASSPHRASE_FILE") {
        return Err(CustodyError::Msg(format!(
            "refusing distribute: unset KEEPER_PASSPHRASE_FILE ({pf}) — passphrase must not travel with escrow"
        )));
    }
    let mut paths: Vec<&Path> = vec![escrow_path];
    paths.extend(extra_paths.iter().map(|p| p.as_path()));
    for p in paths {
        let name = p
            .file_name()
            .map(|n| n.to_string_lossy().to_lowercase())
            .unwrap_or_default();
        if name.contains("passphrase") {
            return Err(CustodyError::Msg(format!(
                "refusing distribute: path looks like passphrase material: {}",
                p.display()
            )));
        }
        if name == "passphrase.wrap.json" {
            return Err(CustodyError::Msg(format!(
                "refusing distribute: vault passphrase wrap must not co-ship: {}",
                p.display()
            )));
        }
    }
    Ok(())
}

/// Read escrow as opaque bytes; validate ShareJson shape only (no secret fields).
pub fn read_opaque_escrow(path: &Path) -> Result<(Vec<u8>, ShareJson), CustodyError> {
    let bytes = fs::read(path)?;
    let v: serde_json::Value = serde_json::from_slice(&bytes)?;
    if !v.is_object() {
        return Err(CustodyError::Msg("escrow must be a JSON object (ShareJson)".into()));
    }
    let obj = v.as_object().unwrap();
    let allowed = ["id", "data"];
    for key in obj.keys() {
        if !allowed.contains(&key.as_str()) {
            return Err(CustodyError::Msg(format!(
                "escrow contains unexpected field '{key}' — refuse to distribute non-escrow JSON"
            )));
        }
    }
    let share: ShareJson = serde_json::from_value(v)?;
    if share.data.is_empty() {
        return Err(CustodyError::Msg("escrow share data is empty".into()));
    }
    Ok((bytes, share))
}

fn sha256_hex(bytes: &[u8]) -> String {
    let mut h = Sha256::new();
    h.update(bytes);
    hex::encode(h.finalize())
}

/// Owner endpoint alive: escrow file readable.
pub fn owner_reachable(escrow_path: &Path) -> bool {
    escrow_path.is_file()
}

/// Holder endpoint alive check (law 9).
pub fn holder_reachable(spec: &HolderSpec) -> bool {
    match spec.transport.as_str() {
        "local" => PathBuf::from(&spec.target).is_dir(),
        "ssh" => {
            Command::new("ssh")
                .args([
                    "-o",
                    "BatchMode=yes",
                    "-o",
                    "ConnectTimeout=5",
                    "-o",
                    "StrictHostKeyChecking=accept-new",
                    &spec.target,
                    "true",
                ])
                .stdout(Stdio::null())
                .stderr(Stdio::null())
                .status()
                .map(|s| s.success())
                .unwrap_or(false)
        }
        _ => false,
    }
}

fn write_peer_escrow_local(dest: &Path, bytes: &[u8]) -> Result<(), CustodyError> {
    if let Some(parent) = dest.parent() {
        fs::create_dir_all(parent)?;
        #[cfg(unix)]
        {
            use std::os::unix::fs::PermissionsExt;
            let _ = fs::set_permissions(parent, fs::Permissions::from_mode(0o700));
            // peers/<alias>/ dir
            if let Some(peers) = parent.parent() {
                let _ = fs::set_permissions(peers, fs::Permissions::from_mode(0o700));
            }
            if let Some(root) = parent.parent().and_then(|p| p.parent()) {
                let _ = fs::set_permissions(root, fs::Permissions::from_mode(0o700));
            }
        }
    }
    fs::write(dest, bytes)?;
    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt;
        let _ = fs::set_permissions(dest, fs::Permissions::from_mode(0o600));
    }
    Ok(())
}

fn write_peer_escrow_ssh(spec: &HolderSpec, dest_remote: &str, bytes: &[u8]) -> Result<(), CustodyError> {
    let remote_dir = Path::new(dest_remote)
        .parent()
        .map(|p| p.display().to_string())
        .unwrap_or_else(|| "~/keeper-escrow".to_string());
    let mkdir = Command::new("ssh")
        .args([
            "-o",
            "BatchMode=yes",
            "-o",
            "ConnectTimeout=10",
            "-o",
            "StrictHostKeyChecking=accept-new",
            &spec.target,
            "mkdir",
            "-p",
            &remote_dir,
        ])
        .status()
        .map_err(CustodyError::Io)?;
    if !mkdir.success() {
        return Err(CustodyError::Msg(format!(
            "ssh mkdir failed for holder {}",
            spec.alias
        )));
    }
    let mut child = Command::new("ssh")
        .args([
            "-o",
            "BatchMode=yes",
            "-o",
            "ConnectTimeout=10",
            "-o",
            "StrictHostKeyChecking=accept-new",
            &spec.target,
            "cat",
            ">",
            dest_remote,
        ])
        .stdin(Stdio::piped())
        .spawn()
        .map_err(CustodyError::Io)?;
    if let Some(mut stdin) = child.stdin.take() {
        stdin.write_all(bytes).map_err(CustodyError::Io)?;
    }
    let status = child.wait().map_err(CustodyError::Io)?;
    if !status.success() {
        return Err(CustodyError::Msg(format!(
            "ssh copy failed for holder {}",
            spec.alias
        )));
    }
    Ok(())
}

pub fn load_custody_map(path: &Path) -> Result<CustodyMap, CustodyError> {
    let raw = fs::read_to_string(path)?;
    Ok(serde_json::from_str(&raw)?)
}

/// Verify every holder in the map has a peer copy matching owner escrow hash.
pub fn verify_custody_complete(
    escrow_path: &Path,
    owner_alias: &str,
    holders: &[HolderSpec],
) -> Result<bool, CustodyError> {
    let (bytes, _) = read_opaque_escrow(escrow_path)?;
    let expected = sha256_hex(&bytes);
    for h in holders {
        validate_alias(&h.alias)?;
        let dest = resolve_holder_dest(h, owner_alias)?;
        let on_disk = match h.transport.as_str() {
            "local" => {
                if !dest.is_file() {
                    return Ok(false);
                }
                fs::read(&dest).map_err(CustodyError::Io)?
            }
            "ssh" => {
                let child = Command::new("ssh")
                    .args([
                        "-o",
                        "BatchMode=yes",
                        "-o",
                        "ConnectTimeout=5",
                        &h.target,
                        "cat",
                        dest.display().to_string().as_str(),
                    ])
                    .stdout(Stdio::piped())
                    .stderr(Stdio::null())
                    .spawn()
                    .map_err(CustodyError::Io)?;
                let out = child.wait_with_output().map_err(CustodyError::Io)?;
                if !out.status.success() {
                    return Ok(false);
                }
                out.stdout
            }
            _ => return Err(CustodyError::Msg(format!("unknown transport {}", h.transport))),
        };
        if sha256_hex(&on_disk) != expected {
            return Ok(false);
        }
    }
    Ok(true)
}

fn resolve_holder_dest(spec: &HolderSpec, owner_alias: &str) -> Result<PathBuf, CustodyError> {
    match spec.transport.as_str() {
        "local" => Ok(peer_escrow_path(Path::new(&spec.target), owner_alias)),
        "ssh" => Ok(PathBuf::from(format!(
            "~/keeper-escrow/peers/{}/keeper-escrow.json",
            owner_alias
        ))),
        _ => Err(CustodyError::Msg(format!("unknown transport {}", spec.transport))),
    }
}

/// Push opaque escrow bytes to listed holders.
pub fn distribute_escrow(opts: &DistributeOpts) -> Result<DistributeResult, CustodyError> {
    validate_alias(&opts.owner_alias)?;
    assert_no_passphrase_co_ship(&opts.escrow_path, &[])?;

    if !owner_reachable(&opts.escrow_path) {
        return Err(CustodyError::Msg(format!(
            "owner escrow not reachable: {}",
            opts.escrow_path.display()
        )));
    }

    let (bytes, _share) = read_opaque_escrow(&opts.escrow_path)?;
    let digest = sha256_hex(&bytes);

    let mut copied = Vec::new();
    let mut skipped = Vec::new();

    for spec in &opts.holders {
        validate_alias(&spec.alias)?;
        let reachable = holder_reachable(spec);
        if !reachable && !opts.hitl_approve_offline {
            skipped.push(SkippedPeer {
                holder_alias: spec.alias.clone(),
                reason:
                    "holder offline — skipped (use --hitl-approve-offline for one-shot operator approval)"
                        .into(),
            });
            continue;
        }

        match spec.transport.as_str() {
            "local" => {
                let dest = peer_escrow_path(Path::new(&spec.target), &opts.owner_alias);
                match write_peer_escrow_local(&dest, &bytes) {
                    Ok(()) => {
                        copied.push(CopiedPeer {
                            holder_alias: spec.alias.clone(),
                            dest: dest.display().to_string(),
                            bytes: bytes.len(),
                        });
                    }
                    Err(e) => {
                        skipped.push(SkippedPeer {
                            holder_alias: spec.alias.clone(),
                            reason: format!("local write failed: {e}"),
                        });
                    }
                }
            }
            "ssh" => {
                let remote = format!(
                    "~/keeper-escrow/peers/{}/keeper-escrow.json",
                    opts.owner_alias
                );
                match write_peer_escrow_ssh(spec, &remote, &bytes) {
                    Ok(()) => {
                        copied.push(CopiedPeer {
                            holder_alias: spec.alias.clone(),
                            dest: format!("{}:{}", spec.target, remote),
                            bytes: bytes.len(),
                        });
                    }
                    Err(e) => {
                        skipped.push(SkippedPeer {
                            holder_alias: spec.alias.clone(),
                            reason: format!("ssh copy failed: {e}"),
                        });
                    }
                }
            }
            _ => {
                skipped.push(SkippedPeer {
                    holder_alias: spec.alias.clone(),
                    reason: format!("unsupported transport {}", spec.transport),
                });
            }
        }
    }

    let verify_complete = if opts.verify_complete {
        Some(verify_custody_complete(&opts.escrow_path, &opts.owner_alias, &opts.holders)?)
    } else {
        None
    };

    let ok = !copied.is_empty() && skipped.is_empty() && verify_complete.unwrap_or(true);

    Ok(DistributeResult {
        ok,
        owner_alias: opts.owner_alias.clone(),
        escrow_sha256: digest,
        copied,
        skipped,
        verify_complete,
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::crypto::{generate_root, shamir_split, ShareJson};
    use tempfile::tempdir;

    fn sample_escrow(path: &Path) {
        let root = generate_root();
        let shares = shamir_split(&root, 2, 3).unwrap();
        let sj = ShareJson::from(&shares[1]);
        fs::write(path, serde_json::to_vec_pretty(&sj).unwrap()).unwrap();
    }

    #[test]
    fn peer_escrow_path_layout() {
        let p = peer_escrow_path(Path::new("/home/holder"), "grok-bot");
        assert_eq!(
            p,
            PathBuf::from("/home/holder/keeper-escrow/peers/grok-bot/keeper-escrow.json")
        );
    }

    #[test]
    fn refuse_passphrase_env_co_ship() {
        let dir = tempdir().unwrap();
        let escrow = dir.path().join("escrow.json");
        sample_escrow(&escrow);
        std::env::set_var("KEEPER_PASSPHRASE", "secret");
        let err = assert_no_passphrase_co_ship(&escrow, &[]).unwrap_err();
        assert!(err.to_string().contains("KEEPER_PASSPHRASE"));
        std::env::remove_var("KEEPER_PASSPHRASE");
    }

    #[test]
    fn refuse_passphrase_filename_co_ship() {
        let dir = tempdir().unwrap();
        let bad = dir.path().join("my-passphrase.secret");
        fs::write(&bad, "x").unwrap();
        let err = assert_no_passphrase_co_ship(&bad, &[]).unwrap_err();
        assert!(err.to_string().contains("passphrase"));
    }

    #[test]
    fn read_opaque_escrow_rejects_secret_json() {
        let dir = tempdir().unwrap();
        let path = dir.path().join("not-escrow.json");
        fs::write(
            &path,
            r#"{"algorithm":"AES","ciphertext":"abc","nonce":"x"}"#,
        )
        .unwrap();
        let err = read_opaque_escrow(&path).unwrap_err();
        assert!(err.to_string().contains("unexpected field"));
    }

    #[test]
    fn distribute_happy_path_opaque_bytes_only() {
        let dir = tempdir().unwrap();
        let escrow = dir.path().join("owner-escrow.json");
        sample_escrow(&escrow);
        let raw = fs::read(&escrow).unwrap();

        let holder_home = dir.path().join("holder-laptop-1");
        fs::create_dir_all(&holder_home).unwrap();

        let res = distribute_escrow(&DistributeOpts {
            escrow_path: escrow.clone(),
            owner_alias: "grok-bot".into(),
            holders: vec![HolderSpec {
                alias: "laptop-1".into(),
                transport: "local".into(),
                target: holder_home.display().to_string(),
            }],
            hitl_approve_offline: false,
            verify_complete: true,
        })
        .unwrap();

        assert_eq!(res.copied.len(), 1);
        assert!(res.skipped.is_empty());
        assert!(res.verify_complete == Some(true));

        let dest = peer_escrow_path(&holder_home, "grok-bot");
        let on_holder = fs::read(&dest).unwrap();
        assert_eq!(on_holder, raw);
        // Escrow alone is ShareJson — not a named secret plaintext
        let sj: ShareJson = serde_json::from_slice(&on_holder).unwrap();
        assert!(!sj.data.is_empty());
    }

    #[test]
    fn distribute_skips_offline_without_hitl() {
        let dir = tempdir().unwrap();
        let escrow = dir.path().join("escrow.json");
        sample_escrow(&escrow);

        let res = distribute_escrow(&DistributeOpts {
            escrow_path: escrow,
            owner_alias: "grok-bot".into(),
            holders: vec![HolderSpec {
                alias: "mac-mini".into(),
                transport: "local".into(),
                target: dir.path().join("nonexistent-holder").display().to_string(),
            }],
            hitl_approve_offline: false,
            verify_complete: false,
        })
        .unwrap();

        assert!(res.copied.is_empty());
        assert_eq!(res.skipped.len(), 1);
        assert!(res.skipped[0].reason.contains("offline"));
        assert!(!res.ok);
    }

    #[test]
    fn distribute_offline_with_hitl_creates_local_peer_path() {
        let dir = tempdir().unwrap();
        let escrow = dir.path().join("escrow.json");
        sample_escrow(&escrow);
        let holder_base = dir.path().join("new-holder-root");

        let res = distribute_escrow(&DistributeOpts {
            escrow_path: escrow.clone(),
            owner_alias: "grok-bot".into(),
            holders: vec![HolderSpec {
                alias: "laptop-2".into(),
                transport: "local".into(),
                target: holder_base.display().to_string(),
            }],
            hitl_approve_offline: true,
            verify_complete: true,
        })
        .unwrap();

        assert_eq!(res.copied.len(), 1);
        assert!(res.skipped.is_empty());
        assert!(peer_escrow_path(&holder_base, "grok-bot").is_file());
    }

    #[test]
    fn verify_complete_fails_when_peer_missing() {
        let dir = tempdir().unwrap();
        let escrow = dir.path().join("escrow.json");
        sample_escrow(&escrow);
        let holder_home = dir.path().join("holder");
        fs::create_dir_all(&holder_home).unwrap();

        let ok = verify_custody_complete(
            &escrow,
            "grok-bot",
            &[HolderSpec {
                alias: "laptop-1".into(),
                transport: "local".into(),
                target: holder_home.display().to_string(),
            }],
        )
        .unwrap();
        assert!(!ok);
    }
}
