//! Init / unlock / put / get / status / drill / recover (multi-factor).

use crate::crypto::{
    generate_pq_keypair, generate_root, open_hybrid, open_under_root, seal_hybrid, seal_under_root,
    shamir_combine, shamir_split, wrap_with_passphrase, ShareJson, CANARY_PLAINTEXT,
    HYBRID_ALGORITHM,
};
use crate::factors::{
    machine_fingerprint, release_shares_from_confirmations, seal_share_for_device,
    seal_share_for_knowledge, Confirmation, FactorError,
};
use crate::store::{
    ensure_root, read_canary, read_device_blob, read_knowledge_blob, read_meta, read_passphrase_wrap,
    read_pq_dk_wrap, read_pq_ek, read_secret, write_canary, write_device_blob, write_escrow,
    write_knowledge_blob, write_meta, write_passphrase_wrap, write_pq_dk_wrap, write_pq_ek,
    write_secret, Meta, StoreError,
};
use base64::{engine::general_purpose::STANDARD as B64, Engine};
use serde::Serialize;
use std::path::Path;
use thiserror::Error;

/// Default threshold: need 3 of 4 enrolled factors (passphrase, offline, device, knowledge).
pub const DEFAULT_K: u8 = 3;
pub const DEFAULT_N: u8 = 4;

#[derive(Debug, Error)]
pub enum CeremonyError {
    #[error(transparent)]
    Store(#[from] StoreError),
    #[error(transparent)]
    Crypto(#[from] crate::crypto::CryptoError),
    #[error(transparent)]
    Factor(#[from] FactorError),
    #[error("{0}")]
    Msg(String),
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct InitResult {
    pub k: u8,
    pub n: u8,
    pub drill_proven: bool,
    pub seal_algorithm: String,
    pub factors: Vec<&'static str>,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct Status {
    pub exists: bool,
    pub healthy: bool,
    pub drill_proven: bool,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub k: Option<u8>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub n: Option<u8>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub created_at: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub seal_algorithm: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub factors: Option<Vec<String>>,
    pub reason: String,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct DrillResult {
    pub ok: bool,
    pub canary_ok: bool,
    pub drill_proven: bool,
    pub path: String,
}

fn now_secs() -> String {
    use std::time::{SystemTime, UNIX_EPOCH};
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_secs().to_string())
        .unwrap_or_else(|_| "0".into())
}

fn pq_seed_from_root(root_path: &Path, r: &[u8]) -> Result<Vec<u8>, CeremonyError> {
    let wrap = read_pq_dk_wrap(root_path)?;
    Ok(open_under_root(r, &wrap)?)
}

fn ek_bytes(root_path: &Path) -> Result<Vec<u8>, CeremonyError> {
    let ek = read_pq_ek(root_path)?;
    B64.decode(&ek.encapsulation_key)
        .map_err(|e| CeremonyError::Msg(format!("ek b64: {e}")))
}

/// Init with k=3, n=4: passphrase, offline escrow, device-bound, knowledge-bound.
pub fn init_vault(
    root: &Path,
    passphrase: &str,
    escrow_path: &Path,
    knowledge_answer: &str,
) -> Result<InitResult, CeremonyError> {
    let k = DEFAULT_K;
    let n = DEFAULT_N;
    if passphrase.is_empty() {
        return Err(CeremonyError::Msg("init: passphrase required".into()));
    }
    if knowledge_answer.is_empty() {
        return Err(CeremonyError::Msg("init: knowledge answer required".into()));
    }
    if root.join("meta.json").exists() {
        return Err(CeremonyError::Msg("init: vault already exists at root".into()));
    }
    ensure_root(root)?;

    let r = generate_root();
    let shares = shamir_split(&r, k, n)?;
    // ids 1..4
    let pass_share = &shares[0];
    let offline_share = &shares[1];
    let device_share = &shares[2];
    let knowledge_share = &shares[3];

    let wrap = wrap_with_passphrase(&pass_share.data, pass_share.id, passphrase)?;
    write_passphrase_wrap(root, &wrap)?;
    write_escrow(escrow_path, &ShareJson::from(offline_share))?;

    let fp = machine_fingerprint();
    let dev_blob = seal_share_for_device(device_share, &fp)?;
    write_device_blob(root, &dev_blob)?;

    let know_blob = seal_share_for_knowledge(knowledge_share, knowledge_answer)?;
    write_knowledge_blob(root, &know_blob)?;

    let (pq_seed, pq_ek) = generate_pq_keypair();
    write_pq_ek(root, &B64.encode(&pq_ek), HYBRID_ALGORITHM)?;
    write_pq_dk_wrap(root, &seal_under_root(&r, &pq_seed)?)?;

    let canary = seal_hybrid(&pq_ek, CANARY_PLAINTEXT.as_bytes())?;
    write_canary(root, &canary)?;

    let meta = Meta {
        version: 3,
        k,
        n,
        drill_proven: false,
        created_at: now_secs(),
        kdf: "scrypt".into(),
        seal_algorithm: HYBRID_ALGORITHM.into(),
        factors: vec![
            "passphrase".into(),
            "offline".into(),
            "device".into(),
            "knowledge".into(),
        ],
        last_drill_at: None,
    };
    write_meta(root, &meta)?;

    Ok(InitResult {
        k,
        n,
        drill_proven: false,
        seal_algorithm: HYBRID_ALGORITHM.into(),
        factors: vec!["passphrase", "offline", "device", "knowledge"],
    })
}

fn reconstruct_root(
    root: &Path,
    confirmations: &[Confirmation],
    fingerprint_override: Option<&[u8]>,
) -> Result<Vec<u8>, CeremonyError> {
    let meta = read_meta(root)?.ok_or_else(|| CeremonyError::Msg("no vault".into()))?;
    let wrap = read_passphrase_wrap(root).ok();
    let device_blob = read_device_blob(root).ok();
    let knowledge_blob = read_knowledge_blob(root).ok();

    let released = release_shares_from_confirmations(
        confirmations,
        wrap.as_ref(),
        None,
        device_blob.as_ref(),
        knowledge_blob.as_ref(),
        fingerprint_override,
    )?;

    if released.len() < meta.k as usize {
        return Err(CeremonyError::Msg(format!(
            "insufficient shares: got {} need {}",
            released.len(),
            meta.k
        )));
    }
    Ok(shamir_combine(&released, meta.k)?)
}

/// Daily unlock: passphrase + device + knowledge (k=3).
pub fn unlock_with_passphrase_factors(
    root: &Path,
    passphrase: &str,
    knowledge: &str,
) -> Result<Vec<u8>, CeremonyError> {
    reconstruct_root(
        root,
        &[
            Confirmation::Passphrase(passphrase.into()),
            Confirmation::Device,
            Confirmation::Knowledge(knowledge.into()),
        ],
        None,
    )
}

pub fn put_secret(
    root: &Path,
    passphrase: &str,
    knowledge: &str,
    name: &str,
    value: &str,
) -> Result<(), CeremonyError> {
    let r = unlock_with_passphrase_factors(root, passphrase, knowledge)?;
    let _seed = pq_seed_from_root(root, &r)?;
    let ek = ek_bytes(root)?;
    let sealed = seal_hybrid(&ek, value.as_bytes())?;
    write_secret(root, name, &sealed)?;
    Ok(())
}

pub fn get_secret(
    root: &Path,
    passphrase: &str,
    knowledge: &str,
    name: &str,
) -> Result<String, CeremonyError> {
    let r = unlock_with_passphrase_factors(root, passphrase, knowledge)?;
    let seed = pq_seed_from_root(root, &r)?;
    let sealed = read_secret(root, name)?;
    let plain = open_hybrid(&seed, &sealed)?;
    Ok(String::from_utf8(plain).map_err(|e| CeremonyError::Msg(e.to_string()))?)
}

pub fn status(root: &Path) -> Result<Status, CeremonyError> {
    match read_meta(root)? {
        None => Ok(Status {
            exists: false,
            healthy: false,
            drill_proven: false,
            k: None,
            n: None,
            created_at: None,
            seal_algorithm: None,
            factors: None,
            reason: "no vault".into(),
        }),
        Some(meta) => {
            let healthy = meta.drill_proven;
            Ok(Status {
                exists: true,
                healthy,
                drill_proven: meta.drill_proven,
                k: Some(meta.k),
                n: Some(meta.n),
                created_at: Some(meta.created_at),
                seal_algorithm: Some(meta.seal_algorithm),
                factors: Some(meta.factors),
                reason: if healthy {
                    "drill-proven".into()
                } else {
                    "drill required (recover without primary passphrase using offline+device+knowledge)"
                        .into()
                },
            })
        }
    }
}

/// No-passphrase recovery: offline + device + knowledge (k=3).
pub fn recover_without_passphrase(
    root: &Path,
    escrow_path: &Path,
    knowledge: &str,
) -> Result<DrillResult, CeremonyError> {
    let mut meta = read_meta(root)?.ok_or_else(|| CeremonyError::Msg("drill: no vault".into()))?;
    let r = reconstruct_root(
        root,
        &[
            Confirmation::OfflineFile {
                path: escrow_path.to_path_buf(),
            },
            Confirmation::Device,
            Confirmation::Knowledge(knowledge.into()),
        ],
        None,
    )?;
    let seed = pq_seed_from_root(root, &r)?;
    let canary = read_canary(root)?;
    let plain = open_hybrid(&seed, &canary)?;
    if plain != CANARY_PLAINTEXT.as_bytes() {
        return Err(CeremonyError::Msg("drill: canary mismatch".into()));
    }
    meta.drill_proven = true;
    meta.last_drill_at = Some(now_secs());
    write_meta(root, &meta)?;
    Ok(DrillResult {
        ok: true,
        canary_ok: true,
        drill_proven: true,
        path: "offline+device+knowledge".into(),
    })
}

/// Alias for recover_without_passphrase (ceremony health gate).
pub fn drill(root: &Path, escrow_path: &Path, knowledge: &str) -> Result<DrillResult, CeremonyError> {
    recover_without_passphrase(root, escrow_path, knowledge)
}

/// Attempt reconstruct with explicit confirmations (library / tests).
pub fn recover_with_confirmations(
    root: &Path,
    confirmations: &[Confirmation],
    fingerprint_override: Option<&[u8]>,
) -> Result<Vec<u8>, CeremonyError> {
    reconstruct_root(root, confirmations, fingerprint_override)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::factors::Confirmation;
    use tempfile::tempdir;

    #[test]
    fn multifactor_no_passphrase_drill() {
        let dir = tempdir().unwrap();
        let root = dir.path().join("vault");
        let escrow = dir.path().join("off.json");
        let pass = "unit-passphrase-long";
        let knowledge = "ci knowledge answer one";

        let init = init_vault(&root, pass, &escrow, knowledge).unwrap();
        assert_eq!(init.k, 3);
        assert_eq!(init.n, 4);
        assert!(init.seal_algorithm.contains("ML-KEM-768"));

        let st0 = status(&root).unwrap();
        assert!(!st0.healthy);

        put_secret(&root, pass, knowledge, "demo", "hello-mfa").unwrap();
        assert_eq!(get_secret(&root, pass, knowledge, "demo").unwrap(), "hello-mfa");
        assert!(put_secret(&root, "wrong", knowledge, "x", "y").is_err());
        assert!(get_secret(&root, pass, "wrong-knowledge", "demo").is_err());

        // No-passphrase path
        let dr = drill(&root, &escrow, knowledge).unwrap();
        assert!(dr.canary_ok);
        assert_eq!(dr.path, "offline+device+knowledge");
        assert!(status(&root).unwrap().healthy);
    }

    #[test]
    fn insufficient_factors_fail() {
        let dir = tempdir().unwrap();
        let root = dir.path().join("vault");
        let escrow = dir.path().join("off.json");
        init_vault(&root, "pass-aaaa", &escrow, "know-bbbb").unwrap();

        // only offline + device (2 < k=3)
        let err = recover_with_confirmations(
            &root,
            &[
                Confirmation::OfflineFile {
                    path: escrow.clone(),
                },
                Confirmation::Device,
            ],
            None,
        );
        assert!(err.is_err());
    }

    #[test]
    fn public_ip_cannot_unlock() {
        let dir = tempdir().unwrap();
        let root = dir.path().join("vault");
        let escrow = dir.path().join("off.json");
        init_vault(&root, "pass-cccc", &escrow, "know-dddd").unwrap();
        let err = recover_with_confirmations(
            &root,
            &[
                Confirmation::OfflineFile {
                    path: escrow.clone(),
                },
                Confirmation::Device,
                Confirmation::PublicIp("203.0.113.9".into()),
            ],
            None,
        );
        assert!(matches!(err, Err(CeremonyError::Factor(FactorError::IpTrustForbidden))));
    }
}
