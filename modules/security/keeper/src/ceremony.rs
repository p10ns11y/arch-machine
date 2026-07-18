//! Init / unlock / put / get / status / drill / recover.
//!
//! # Simple model (default, meta.version = 4)
//!
//! **Any 2 of 3:** passphrase · offline escrow · device fingerprint.
//!
//! | Path | What you need |
//! |------|----------------|
//! | Daily get/put | passphrase only (device auto) |
//! | Forgot passphrase | offline file + this machine |
//! | New machine (vault files + escrow) | passphrase + offline |
//!
//! Knowledge factor is **gone** from the default path (it was a second password).
//! Confirmation never KDFs the root alone. Public ISP IP is never a factor.

use crate::crypto::{
    generate_pq_keypair, generate_root, open_hybrid, open_under_root, seal_hybrid, seal_under_root,
    shamir_combine, shamir_split, wrap_with_passphrase, ShareJson, CANARY_PLAINTEXT,
    HYBRID_ALGORITHM,
};
use crate::factors::{
    machine_fingerprint, release_shares_from_confirmations, seal_share_for_device, Confirmation,
    FactorError,
};
// Yubi enroll uses seal_share_for_device + machine_fingerprint above.
use crate::store::{
    ensure_root, read_canary, read_device_blob, read_meta, read_passphrase_wrap, read_pq_dk_wrap,
    read_pq_ek, read_secret, read_yubi_blob, write_canary, write_device_blob, write_escrow,
    write_meta, write_passphrase_wrap, write_pq_dk_wrap, write_pq_ek, write_secret, write_yubi_blob,
    yubi_blob_exists, Meta, StoreError,
};
use crate::yubi::{open_yubi_share_with_backend, seal_share_for_yubi, YubiChallenge, YubiError};
use base64::{engine::general_purpose::STANDARD as B64, Engine};
use serde::Serialize;
use std::path::Path;
use thiserror::Error;

/// Simple protocol: need any 2 of 3 enrolled factors.
pub const DEFAULT_K: u8 = 2;
pub const DEFAULT_N: u8 = 3;
/// Meta schema for simple vaults.
pub const META_VERSION: u32 = 4;

#[derive(Debug, Error)]
pub enum CeremonyError {
    #[error(transparent)]
    Store(#[from] StoreError),
    #[error(transparent)]
    Crypto(#[from] crate::crypto::CryptoError),
    #[error(transparent)]
    Factor(#[from] FactorError),
    #[error(transparent)]
    Yubi(#[from] YubiError),
    #[error("{0}")]
    Msg(String),
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct EnrollYubiResult {
    pub ok: bool,
    pub k: u8,
    pub n: u8,
    pub slot: u8,
    pub factors: Vec<&'static str>,
    pub model: &'static str,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct InitResult {
    pub k: u8,
    pub n: u8,
    pub drill_proven: bool,
    pub seal_algorithm: String,
    pub factors: Vec<&'static str>,
    pub model: &'static str,
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
    #[serde(skip_serializing_if = "Option::is_none")]
    pub model: Option<&'static str>,
    pub reason: String,
    /// Operator-facing mental model (one card).
    #[serde(skip_serializing_if = "Option::is_none")]
    pub remember: Option<&'static str>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub store_offline: Option<&'static str>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub free: Option<&'static str>,
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

/// Init simple vault: k=2 n=3 (passphrase, offline, device). No knowledge factor.
pub fn init_vault(
    root: &Path,
    passphrase: &str,
    escrow_path: &Path,
) -> Result<InitResult, CeremonyError> {
    let k = DEFAULT_K;
    let n = DEFAULT_N;
    if passphrase.is_empty() {
        return Err(CeremonyError::Msg("init: passphrase required".into()));
    }
    if root.join("meta.json").exists() {
        return Err(CeremonyError::Msg("init: vault already exists at root".into()));
    }
    ensure_root(root)?;

    let r = generate_root();
    let shares = shamir_split(&r, k, n)?;
    let pass_share = &shares[0];
    let offline_share = &shares[1];
    let device_share = &shares[2];

    let wrap = wrap_with_passphrase(&pass_share.data, pass_share.id, passphrase)?;
    write_passphrase_wrap(root, &wrap)?;
    write_escrow(escrow_path, &ShareJson::from(offline_share))?;

    let fp = machine_fingerprint();
    let dev_blob = seal_share_for_device(device_share, &fp)?;
    write_device_blob(root, &dev_blob)?;

    let (pq_seed, pq_ek) = generate_pq_keypair();
    write_pq_ek(root, &B64.encode(&pq_ek), HYBRID_ALGORITHM)?;
    write_pq_dk_wrap(root, &seal_under_root(&r, &pq_seed)?)?;

    let canary = seal_hybrid(&pq_ek, CANARY_PLAINTEXT.as_bytes())?;
    write_canary(root, &canary)?;

    let meta = Meta {
        version: META_VERSION,
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
        ],
        last_drill_at: None,
    };
    write_meta(root, &meta)?;

    Ok(InitResult {
        k,
        n,
        drill_proven: false,
        seal_algorithm: HYBRID_ALGORITHM.into(),
        factors: vec!["passphrase", "offline", "device"],
        model: "any-2-of-3",
    })
}

/// Floor k so disk cannot weaken policy below protocol default for this vault shape.
pub fn effective_threshold(meta_k: u8, meta_n: u8) -> Result<u8, CeremonyError> {
    if meta_n < DEFAULT_N {
        return Err(CeremonyError::Msg(format!(
            "policy n={meta_n} below protocol DEFAULT_N={DEFAULT_N}"
        )));
    }
    let k = meta_k.max(DEFAULT_K);
    if k > meta_n {
        return Err(CeremonyError::Msg(format!(
            "invalid policy k={k} > n={meta_n}"
        )));
    }
    Ok(k)
}

fn reconstruct_root(
    root: &Path,
    confirmations: &[Confirmation],
    fingerprint_override: Option<&[u8]>,
) -> Result<Vec<u8>, CeremonyError> {
    let meta = read_meta(root)?.ok_or_else(|| CeremonyError::Msg("no vault".into()))?;
    let k = effective_threshold(meta.k, meta.n)?;
    let wrap = read_passphrase_wrap(root).ok();
    let device_blob = read_device_blob(root).ok();
    let yubi_blob = read_yubi_blob(root).ok();

    let released = release_shares_from_confirmations(
        confirmations,
        wrap.as_ref(),
        None,
        device_blob.as_ref(),
        None, // knowledge unused in simple model
        yubi_blob.as_ref(),
        fingerprint_override,
    )?;

    if released.len() < k as usize {
        return Err(CeremonyError::Msg(format!(
            "insufficient shares: got {} need {} (any 2 of enrolled factors; yubikey alone never enough)",
            released.len(),
            k
        )));
    }
    Ok(shamir_combine(&released, k)?)
}

fn yubi_response_for_root(
    root: &Path,
    backend: &dyn YubiChallenge,
) -> Result<Vec<u8>, CeremonyError> {
    let blob = read_yubi_blob(root)?;
    let challenge = B64
        .decode(&blob.challenge_b64)
        .map_err(|e| CeremonyError::Msg(format!("yubi challenge: {e}")))?;
    Ok(backend.challenge_response(&challenge)?)
}

/// Strong path: YubiKey + device (no passphrase).
pub fn unlock_yubi_device(
    root: &Path,
    backend: &dyn YubiChallenge,
) -> Result<Vec<u8>, CeremonyError> {
    let response = yubi_response_for_root(root, backend)?;
    reconstruct_root(
        root,
        &[
            Confirmation::YubiKey { response },
            Confirmation::Device,
        ],
        None,
    )
}

/// Strong path: YubiKey + offline escrow.
pub fn unlock_yubi_escrow(
    root: &Path,
    escrow_path: &Path,
    backend: &dyn YubiChallenge,
) -> Result<Vec<u8>, CeremonyError> {
    let response = yubi_response_for_root(root, backend)?;
    reconstruct_root(
        root,
        &[
            Confirmation::YubiKey { response },
            Confirmation::OfflineFile {
                path: escrow_path.to_path_buf(),
            },
        ],
        None,
    )
}

/// Strong path: YubiKey + passphrase.
pub fn unlock_yubi_passphrase(
    root: &Path,
    passphrase: &str,
    backend: &dyn YubiChallenge,
) -> Result<Vec<u8>, CeremonyError> {
    let response = yubi_response_for_root(root, backend)?;
    reconstruct_root(
        root,
        &[
            Confirmation::YubiKey { response },
            Confirmation::Passphrase(passphrase.into()),
        ],
        None,
    )
}

/// Enroll YubiKey as 4th share; re-split k=2 n=4. Requires passphrase + rewrite of offline escrow.
pub fn enroll_yubikey(
    root: &Path,
    passphrase: &str,
    escrow_path: &Path,
    backend: &dyn YubiChallenge,
) -> Result<EnrollYubiResult, CeremonyError> {
    if yubi_blob_exists(root) {
        return Err(CeremonyError::Msg(
            "yubikey already enrolled (re-enroll not supported in this release)".into(),
        ));
    }
    let r = unlock_daily(root, passphrase)?;
    let k = DEFAULT_K;
    let n = 4u8;
    let shares = shamir_split(&r, k, n)?;
    let pass_share = &shares[0];
    let offline_share = &shares[1];
    let device_share = &shares[2];
    let yubi_share = &shares[3];

    let wrap = wrap_with_passphrase(&pass_share.data, pass_share.id, passphrase)?;
    write_passphrase_wrap(root, &wrap)?;
    write_escrow(escrow_path, &ShareJson::from(offline_share))?;

    let fp = machine_fingerprint();
    let dev_blob = seal_share_for_device(device_share, &fp)?;
    write_device_blob(root, &dev_blob)?;

    let yubi_blob = seal_share_for_yubi(yubi_share, backend)?;
    write_yubi_blob(root, &yubi_blob)?;

    // Prove solo Yubi cannot open (defensive: open share only, not root)
    let _opened = open_yubi_share_with_backend(&yubi_blob, backend)?;

    let mut meta = read_meta(root)?.ok_or_else(|| CeremonyError::Msg("no vault".into()))?;
    meta.k = k;
    meta.n = n;
    meta.factors = vec![
        "passphrase".into(),
        "offline".into(),
        "device".into(),
        "yubikey".into(),
    ];
    write_meta(root, &meta)?;

    Ok(EnrollYubiResult {
        ok: true,
        k,
        n,
        slot: backend.slot(),
        factors: vec!["passphrase", "offline", "device", "yubikey"],
        model: "any-2-of-4-strong-yubi",
    })
}

/// Daily unlock: passphrase + this machine (k=2).
pub fn unlock_daily(root: &Path, passphrase: &str) -> Result<Vec<u8>, CeremonyError> {
    reconstruct_root(
        root,
        &[
            Confirmation::Passphrase(passphrase.into()),
            Confirmation::Device,
        ],
        None,
    )
}

/// Forgot-passphrase / recover unlock: offline escrow + this machine.
pub fn unlock_with_escrow(root: &Path, escrow_path: &Path) -> Result<Vec<u8>, CeremonyError> {
    reconstruct_root(
        root,
        &[
            Confirmation::OfflineFile {
                path: escrow_path.to_path_buf(),
            },
            Confirmation::Device,
        ],
        None,
    )
}

/// New machine (or no device blob): passphrase + offline escrow.
pub fn unlock_passphrase_and_escrow(
    root: &Path,
    passphrase: &str,
    escrow_path: &Path,
) -> Result<Vec<u8>, CeremonyError> {
    reconstruct_root(
        root,
        &[
            Confirmation::Passphrase(passphrase.into()),
            Confirmation::OfflineFile {
                path: escrow_path.to_path_buf(),
            },
        ],
        None,
    )
}

fn open_named(root: &Path, r: &[u8], name: &str) -> Result<String, CeremonyError> {
    let seed = pq_seed_from_root(root, r)?;
    let sealed = read_secret(root, name)?;
    let plain = open_hybrid(&seed, &sealed)?;
    Ok(String::from_utf8(plain).map_err(|e| CeremonyError::Msg(e.to_string()))?)
}

pub fn put_secret(root: &Path, passphrase: &str, name: &str, value: &str) -> Result<(), CeremonyError> {
    let r = unlock_daily(root, passphrase)?;
    let _seed = pq_seed_from_root(root, &r)?;
    let ek = ek_bytes(root)?;
    let sealed = seal_hybrid(&ek, value.as_bytes())?;
    write_secret(root, name, &sealed)?;
    Ok(())
}

/// Get via daily path (passphrase + device).
pub fn get_secret(root: &Path, passphrase: &str, name: &str) -> Result<String, CeremonyError> {
    let r = unlock_daily(root, passphrase)?;
    open_named(root, &r, name)
}

/// Get without passphrase: offline escrow + device (same as recover path).
pub fn get_secret_with_escrow(
    root: &Path,
    escrow_path: &Path,
    name: &str,
) -> Result<String, CeremonyError> {
    let r = unlock_with_escrow(root, escrow_path)?;
    open_named(root, &r, name)
}

/// Get via strong path: YubiKey + device.
pub fn get_secret_yubi_device(
    root: &Path,
    name: &str,
    backend: &dyn YubiChallenge,
) -> Result<String, CeremonyError> {
    let r = unlock_yubi_device(root, backend)?;
    open_named(root, &r, name)
}

/// Get via strong path: YubiKey + escrow.
pub fn get_secret_yubi_escrow(
    root: &Path,
    escrow_path: &Path,
    name: &str,
    backend: &dyn YubiChallenge,
) -> Result<String, CeremonyError> {
    let r = unlock_yubi_escrow(root, escrow_path, backend)?;
    open_named(root, &r, name)
}

/// Attempt unlock with **only** YubiKey (must fail for k=2).
pub fn try_unlock_yubi_only(
    root: &Path,
    backend: &dyn YubiChallenge,
) -> Result<Vec<u8>, CeremonyError> {
    let response = yubi_response_for_root(root, backend)?;
    reconstruct_root(root, &[Confirmation::YubiKey { response }], None)
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
            model: None,
            reason: "no vault".into(),
            remember: None,
            store_offline: None,
            free: None,
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
                model: Some("any-2-of-3"),
                reason: if healthy {
                    "drill-proven".into()
                } else {
                    "drill required once: recover --escrow <file> (offline + this machine; no passphrase)"
                        .into()
                },
                remember: Some("ONE passphrase (head or password manager)"),
                store_offline: Some("ONE escrow file OFF this laptop (USB / other house)"),
                free: Some(if yubi_blob_exists(root) {
                    "device + optional YubiKey (strong hardware share; never 1FA)"
                } else {
                    "device fingerprint (automatic); optional: enroll-yubikey for strong path"
                }),
            })
        }
    }
}

/// No-passphrase recovery + mark drill proven: offline + device.
pub fn recover_without_passphrase(
    root: &Path,
    escrow_path: &Path,
) -> Result<DrillResult, CeremonyError> {
    let mut meta = read_meta(root)?.ok_or_else(|| CeremonyError::Msg("drill: no vault".into()))?;
    let r = unlock_with_escrow(root, escrow_path)?;
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
        path: "offline+device".into(),
    })
}

pub fn drill(root: &Path, escrow_path: &Path) -> Result<DrillResult, CeremonyError> {
    recover_without_passphrase(root, escrow_path)
}

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
    fn simple_daily_and_escrow_recover() {
        let dir = tempdir().unwrap();
        let root = dir.path().join("vault");
        let escrow = dir.path().join("off.json");
        let pass = "unit-passphrase-long";

        let init = init_vault(&root, pass, &escrow).unwrap();
        assert_eq!(init.k, 2);
        assert_eq!(init.n, 3);
        assert_eq!(init.model, "any-2-of-3");
        assert!(init.seal_algorithm.contains("ML-KEM-768"));

        let st0 = status(&root).unwrap();
        assert!(!st0.healthy);
        assert!(st0.remember.is_some());

        put_secret(&root, pass, "demo", "hello-mfa").unwrap();
        assert_eq!(get_secret(&root, pass, "demo").unwrap(), "hello-mfa");
        assert!(put_secret(&root, "wrong", "x", "y").is_err());

        // No passphrase: escrow + device
        assert_eq!(
            get_secret_with_escrow(&root, &escrow, "demo").unwrap(),
            "hello-mfa"
        );

        let dr = drill(&root, &escrow).unwrap();
        assert!(dr.canary_ok);
        assert_eq!(dr.path, "offline+device");
        assert!(status(&root).unwrap().healthy);
    }

    #[test]
    fn passphrase_plus_offline_without_device_confirm() {
        // New machine path: P + O (device confirmation omitted)
        let dir = tempdir().unwrap();
        let root = dir.path().join("vault");
        let escrow = dir.path().join("off.json");
        init_vault(&root, "pass-new-machine-xx", &escrow).unwrap();
        put_secret(&root, "pass-new-machine-xx", "s", "val").unwrap();

        let r = unlock_passphrase_and_escrow(&root, "pass-new-machine-xx", &escrow).unwrap();
        assert_eq!(r.len(), 32);
    }

    #[test]
    fn single_factor_fails() {
        let dir = tempdir().unwrap();
        let root = dir.path().join("vault");
        let escrow = dir.path().join("off.json");
        init_vault(&root, "pass-aaaa", &escrow).unwrap();

        let err = recover_with_confirmations(
            &root,
            &[Confirmation::Device],
            None,
        );
        assert!(err.is_err());

        let err2 = recover_with_confirmations(
            &root,
            &[Confirmation::Passphrase("pass-aaaa".into())],
            None,
        );
        assert!(err2.is_err());
    }

    #[test]
    fn public_ip_cannot_unlock() {
        let dir = tempdir().unwrap();
        let root = dir.path().join("vault");
        let escrow = dir.path().join("off.json");
        init_vault(&root, "pass-cccc", &escrow).unwrap();
        let err = recover_with_confirmations(
            &root,
            &[
                Confirmation::OfflineFile {
                    path: escrow.clone(),
                },
                Confirmation::PublicIp("203.0.113.9".into()),
            ],
            None,
        );
        assert!(matches!(
            err,
            Err(CeremonyError::Factor(FactorError::IpTrustForbidden))
        ));
    }

    #[test]
    fn meta_k_one_cannot_unlock_with_device_only() {
        let dir = tempdir().unwrap();
        let root = dir.path().join("vault");
        let escrow = dir.path().join("off.json");
        init_vault(&root, "pass-eeee-long", &escrow).unwrap();

        let meta_path = root.join("meta.json");
        let mut meta: serde_json::Value =
            serde_json::from_str(&std::fs::read_to_string(&meta_path).unwrap()).unwrap();
        meta["k"] = serde_json::json!(1);
        std::fs::write(&meta_path, serde_json::to_string_pretty(&meta).unwrap()).unwrap();

        assert_eq!(effective_threshold(1, 3).unwrap(), DEFAULT_K);

        let err = recover_with_confirmations(&root, &[Confirmation::Device], None);
        assert!(err.is_err(), "device alone must fail; err={err:?}");
        assert!(drill(&root, &escrow).is_ok());
    }

    #[test]
    fn effective_threshold_floors() {
        assert_eq!(effective_threshold(1, 3).unwrap(), 2);
        assert_eq!(effective_threshold(2, 3).unwrap(), 2);
        assert_eq!(effective_threshold(3, 4).unwrap(), 3);
        assert!(effective_threshold(2, 2).is_err());
    }

    #[test]
    fn yubi_plus_device_opens_yubi_alone_fails() {
        use crate::yubi::MockYubi;
        let dir = tempdir().unwrap();
        let root = dir.path().join("vault");
        let escrow = dir.path().join("off.json");
        let pass = "yubi-enroll-pass-xx";
        init_vault(&root, pass, &escrow).unwrap();
        put_secret(&root, pass, "tok", "secret-value-42").unwrap();

        let y = MockYubi::from_seed("hardware-mock-seed");
        let er = enroll_yubikey(&root, pass, &escrow, &y).unwrap();
        assert_eq!(er.n, 4);
        assert!(er.factors.contains(&"yubikey"));

        // Solo YubiKey fails
        assert!(try_unlock_yubi_only(&root, &y).is_err());

        // Strong path: Y + device
        assert_eq!(
            get_secret_yubi_device(&root, "tok", &y).unwrap(),
            "secret-value-42"
        );
        // Y + escrow
        assert_eq!(
            get_secret_yubi_escrow(&root, &escrow, "tok", &y).unwrap(),
            "secret-value-42"
        );
        // Daily still works
        assert_eq!(get_secret(&root, pass, "tok").unwrap(), "secret-value-42");
    }
}
