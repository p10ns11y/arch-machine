//! Confirmation-gated share release.
//!
//! Confirmation proves *authorization to release a stored share*.
//! It must **never** be used alone to derive the vault root secret.
//! Public ISP IP / GeoIP confirmations are rejected with weight 0.

use crate::crypto::{unwrap_with_passphrase, CryptoError, PassphraseWrap, Share};
use aes_gcm::aead::{Aead, KeyInit};
use aes_gcm::{Aes256Gcm, Nonce};
use base64::{engine::general_purpose::STANDARD as B64, Engine};
use hkdf::Hkdf;
use rand::RngCore;
use scrypt::{scrypt, Params as ScryptParams};
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
use std::fs;
use std::path::Path;
use thiserror::Error;
use zeroize::Zeroize;

pub const DEVICE_HKDF_SALT: &[u8] = b"keeper-device-v1";
pub const DEVICE_HKDF_INFO: &[u8] = b"share-seal";
pub const KNOWLEDGE_SALT_INFO: &[u8] = b"keeper-knowledge-v1";

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum ShareRole {
    Passphrase,
    Offline,
    Device,
    Knowledge,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum Confirmation {
    /// Unlock passphrase-wrapped share.
    Passphrase(String),
    /// Load offline share from a file path (operator presents escrow).
    OfflineFile { path: std::path::PathBuf },
    /// Recompute local machine fingerprint and open device-sealed share.
    Device,
    /// Knowledge answer (normalized) to open knowledge-sealed share.
    Knowledge(String),
    /// Explicitly rejected — never contributes trust.
    PublicIp(String),
    GeoIp { country: String, city: String },
}

#[derive(Debug, Error)]
pub enum FactorError {
    #[error(transparent)]
    Crypto(#[from] CryptoError),
    #[error("confirmation cannot unlock any share: {0}")]
    Denied(String),
    #[error("public ISP IP / GeoIP must not be used as trust (weight=0)")]
    IpTrustForbidden,
    #[error("io: {0}")]
    Io(#[from] std::io::Error),
    #[error("json: {0}")]
    Json(#[from] serde_json::Error),
    #[error("{0}")]
    Msg(String),
}

/// Weight of a confirmation type for documentation/status (not a root KDF).
pub fn confirmation_weight(c: &Confirmation) -> u8 {
    match c {
        Confirmation::Passphrase(_) => 1,
        Confirmation::OfflineFile { .. } => 1,
        Confirmation::Device => 1,
        Confirmation::Knowledge(_) => 1,
        Confirmation::PublicIp(_) | Confirmation::GeoIp { .. } => 0,
    }
}

pub fn reject_if_ip_trust(c: &Confirmation) -> Result<(), FactorError> {
    match c {
        Confirmation::PublicIp(_) | Confirmation::GeoIp { .. } => Err(FactorError::IpTrustForbidden),
        _ => Ok(()),
    }
}

/// Stable-ish local machine fingerprint material (hashed). Not a root secret.
pub fn machine_fingerprint() -> Vec<u8> {
    let mut h = Sha256::new();
    h.update(b"keeper-machine-fp-v1");
    if let Ok(id) = fs::read_to_string("/etc/machine-id") {
        h.update(id.trim().as_bytes());
    }
    if let Ok(host) = fs::read_to_string("/etc/hostname") {
        h.update(host.trim().as_bytes());
    }
    // CPU model (best-effort)
    if let Ok(cpu) = fs::read_to_string("/proc/cpuinfo") {
        for line in cpu.lines() {
            if line.starts_with("model name") || line.starts_with("Hardware") {
                h.update(line.as_bytes());
                break;
            }
        }
    }
    h.finalize().to_vec()
}

/// Fingerprint from explicit components (for tests / pure confirmation≠key demos).
pub fn fingerprint_from_components(parts: &[&[u8]]) -> Vec<u8> {
    let mut h = Sha256::new();
    h.update(b"keeper-machine-fp-v1");
    for p in parts {
        h.update(p);
    }
    h.finalize().to_vec()
}

fn device_seal_key(fingerprint: &[u8]) -> Result<[u8; 32], FactorError> {
    let hk = Hkdf::<Sha256>::new(Some(DEVICE_HKDF_SALT), fingerprint);
    let mut okm = [0u8; 32];
    hk.expand(DEVICE_HKDF_INFO, &mut okm)
        .map_err(|_| FactorError::Msg("device hkdf failed".into()))?;
    Ok(okm)
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct SealedShareBlob {
    pub v: u32,
    pub role: ShareRole,
    pub share_id: u8,
    pub nonce: String,
    pub ct: String,
    /// For knowledge: scrypt salt (base64).
    #[serde(skip_serializing_if = "Option::is_none")]
    pub salt: Option<String>,
}

fn aead_seal(key: &[u8; 32], plain: &[u8]) -> Result<(Vec<u8>, Vec<u8>), FactorError> {
    let mut nonce = [0u8; 12];
    rand::thread_rng().fill_bytes(&mut nonce);
    let cipher = Aes256Gcm::new_from_slice(key).map_err(|_| FactorError::Msg("aead key".into()))?;
    let n = Nonce::from_slice(&nonce);
    let ct = cipher
        .encrypt(n, plain)
        .map_err(|_| FactorError::Msg("aead encrypt".into()))?;
    Ok((nonce.to_vec(), ct))
}

fn aead_open(key: &[u8; 32], nonce: &[u8], ct: &[u8]) -> Result<Vec<u8>, FactorError> {
    if nonce.len() != 12 {
        return Err(FactorError::Msg("bad nonce".into()));
    }
    let cipher = Aes256Gcm::new_from_slice(key).map_err(|_| FactorError::Msg("aead key".into()))?;
    let n = Nonce::from_slice(nonce);
    cipher
        .decrypt(n, ct)
        .map_err(|_| FactorError::Denied("failed to open sealed share".into()))
}

/// Seal a Shamir share to the local device fingerprint.
pub fn seal_share_for_device(share: &Share, fingerprint: &[u8]) -> Result<SealedShareBlob, FactorError> {
    let mut key = device_seal_key(fingerprint)?;
    let payload = bincode_share(share);
    let (nonce, ct) = aead_seal(&key, &payload)?;
    key.zeroize();
    Ok(SealedShareBlob {
        v: 1,
        role: ShareRole::Device,
        share_id: share.id,
        nonce: B64.encode(nonce),
        ct: B64.encode(ct),
        salt: None,
    })
}

pub fn open_share_for_device(
    blob: &SealedShareBlob,
    fingerprint: &[u8],
) -> Result<Share, FactorError> {
    if blob.role != ShareRole::Device {
        return Err(FactorError::Denied("not a device share".into()));
    }
    let mut key = device_seal_key(fingerprint)?;
    let nonce = B64.decode(&blob.nonce).map_err(|e| FactorError::Msg(e.to_string()))?;
    let ct = B64.decode(&blob.ct).map_err(|e| FactorError::Msg(e.to_string()))?;
    let plain = aead_open(&key, &nonce, &ct)?;
    key.zeroize();
    decode_share_payload(&plain, blob.share_id)
}

fn knowledge_key(answer: &str, salt: &[u8]) -> Result<[u8; 32], FactorError> {
    let norm = normalize_knowledge(answer);
    let params = ScryptParams::new(14, 8, 1, 32).map_err(|e| FactorError::Msg(e.to_string()))?;
    let mut key = [0u8; 32];
    scrypt(norm.as_bytes(), salt, &params, &mut key).map_err(|e| FactorError::Msg(e.to_string()))?;
    Ok(key)
}

pub fn normalize_knowledge(answer: &str) -> String {
    answer.trim().to_lowercase().split_whitespace().collect::<Vec<_>>().join(" ")
}

/// Seal share under knowledge-derived key.
pub fn seal_share_for_knowledge(share: &Share, answer: &str) -> Result<SealedShareBlob, FactorError> {
    let mut salt = [0u8; 16];
    rand::thread_rng().fill_bytes(&mut salt);
    let mut key = knowledge_key(answer, &salt)?;
    let payload = bincode_share(share);
    let (nonce, ct) = aead_seal(&key, &payload)?;
    key.zeroize();
    Ok(SealedShareBlob {
        v: 1,
        role: ShareRole::Knowledge,
        share_id: share.id,
        nonce: B64.encode(nonce),
        ct: B64.encode(ct),
        salt: Some(B64.encode(salt)),
    })
}

pub fn open_share_for_knowledge(blob: &SealedShareBlob, answer: &str) -> Result<Share, FactorError> {
    if blob.role != ShareRole::Knowledge {
        return Err(FactorError::Denied("not a knowledge share".into()));
    }
    let salt_b64 = blob
        .salt
        .as_ref()
        .ok_or_else(|| FactorError::Msg("knowledge salt missing".into()))?;
    let salt = B64.decode(salt_b64).map_err(|e| FactorError::Msg(e.to_string()))?;
    let mut key = knowledge_key(answer, &salt)?;
    let nonce = B64.decode(&blob.nonce).map_err(|e| FactorError::Msg(e.to_string()))?;
    let ct = B64.decode(&blob.ct).map_err(|e| FactorError::Msg(e.to_string()))?;
    let plain = aead_open(&key, &nonce, &ct)?;
    key.zeroize();
    decode_share_payload(&plain, blob.share_id)
}

fn bincode_share(share: &Share) -> Vec<u8> {
    // id || data
    let mut v = Vec::with_capacity(1 + share.data.len());
    v.push(share.id);
    v.extend_from_slice(&share.data);
    v
}

fn decode_share_payload(plain: &[u8], expected_id: u8) -> Result<Share, FactorError> {
    if plain.is_empty() {
        return Err(FactorError::Msg("empty share payload".into()));
    }
    let id = plain[0];
    if id != expected_id {
        return Err(FactorError::Msg("share id mismatch".into()));
    }
    Ok(Share {
        id,
        data: plain[1..].to_vec(),
    })
}

/// Pure multi-confirm release: collect released shares; never derive root from confirmations alone.
pub fn release_shares_from_confirmations(
    confirmations: &[Confirmation],
    passphrase_wrap: Option<&PassphraseWrap>,
    _offline_share_json: Option<&crate::crypto::ShareJson>,
    device_blob: Option<&SealedShareBlob>,
    knowledge_blob: Option<&SealedShareBlob>,
    // Override fingerprint for tests; None = live machine fingerprint.
    fingerprint_override: Option<&[u8]>,
) -> Result<Vec<Share>, FactorError> {
    let mut out = Vec::new();
    let live_fp;
    let fp: &[u8] = if let Some(f) = fingerprint_override {
        f
    } else {
        live_fp = machine_fingerprint();
        &live_fp
    };

    for c in confirmations {
        reject_if_ip_trust(c)?;
        if confirmation_weight(c) == 0 {
            return Err(FactorError::IpTrustForbidden);
        }
        match c {
            Confirmation::Passphrase(p) => {
                let wrap = passphrase_wrap
                    .ok_or_else(|| FactorError::Denied("no passphrase wrap enrolled".into()))?;
                let data = unwrap_with_passphrase(wrap, p)?;
                out.push(Share {
                    id: wrap.share_id,
                    data,
                });
            }
            Confirmation::OfflineFile { path } => {
                // Offline share is carried by the confirmation path itself (file contents).
                let raw = fs::read_to_string(path)?;
                let sj: crate::crypto::ShareJson = serde_json::from_str(&raw)?;
                out.push(Share::try_from(sj)?);
            }
            Confirmation::Device => {
                let blob = device_blob
                    .ok_or_else(|| FactorError::Denied("no device share enrolled".into()))?;
                out.push(open_share_for_device(blob, fp)?);
            }
            Confirmation::Knowledge(ans) => {
                let blob = knowledge_blob
                    .ok_or_else(|| FactorError::Denied("no knowledge share enrolled".into()))?;
                out.push(open_share_for_knowledge(blob, ans)?);
            }
            Confirmation::PublicIp(_) | Confirmation::GeoIp { .. } => {
                return Err(FactorError::IpTrustForbidden);
            }
        }
    }

    // Dedup by share id (last wins)
    let mut map = std::collections::BTreeMap::new();
    for s in out {
        map.insert(s.id, s);
    }
    Ok(map.into_values().collect())
}

/// Load offline share from path (helper).
pub fn load_offline_share(path: &Path) -> Result<Share, FactorError> {
    let raw = fs::read_to_string(path)?;
    let sj: crate::crypto::ShareJson = serde_json::from_str(&raw)?;
    Ok(Share::try_from(sj)?)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::crypto::{generate_root, shamir_combine, shamir_split};

    #[test]
    fn ip_confirmation_forbidden() {
        let c = Confirmation::PublicIp("1.2.3.4".into());
        assert_eq!(confirmation_weight(&c), 0);
        assert!(matches!(
            reject_if_ip_trust(&c),
            Err(FactorError::IpTrustForbidden)
        ));
        let c2 = Confirmation::GeoIp {
            country: "IN".into(),
            city: "Chennai".into(),
        };
        assert_eq!(confirmation_weight(&c2), 0);
    }

    #[test]
    fn device_and_knowledge_release_two_shares_not_root() {
        let secret = generate_root();
        let shares = shamir_split(&secret, 3, 4).unwrap();
        let fp = fingerprint_from_components(&[b"test-machine-a"]);
        let dev_blob = seal_share_for_device(&shares[2], &fp).unwrap();
        let know_blob = seal_share_for_knowledge(&shares[3], "My Private Answer").unwrap();

        // Wrong fingerprint fails
        let fp_bad = fingerprint_from_components(&[b"other-machine"]);
        assert!(open_share_for_device(&dev_blob, &fp_bad).is_err());

        // Wrong knowledge fails
        assert!(open_share_for_knowledge(&know_blob, "wrong").is_err());

        let released = release_shares_from_confirmations(
            &[Confirmation::Device, Confirmation::Knowledge("My Private Answer".into())],
            None,
            None,
            Some(&dev_blob),
            Some(&know_blob),
            Some(&fp),
        )
        .unwrap();
        assert_eq!(released.len(), 2);

        // Two shares insufficient for k=3
        assert!(shamir_combine(&released, 3).is_err());
    }

    #[test]
    fn three_non_passphrase_shares_reconstruct() {
        let secret = generate_root();
        let shares = shamir_split(&secret, 3, 4).unwrap();
        let fp = fingerprint_from_components(&[b"ci-machine"]);
        // share0 passphrase unused; 1 offline raw; 2 device; 3 knowledge
        let offline = &shares[1];
        let dev_blob = seal_share_for_device(&shares[2], &fp).unwrap();
        let know_blob = seal_share_for_knowledge(&shares[3], "ci-knowledge-answer").unwrap();

        // Write offline to temp via serialize
        let offline_json = crate::crypto::ShareJson::from(offline);
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("off.json");
        std::fs::write(&path, serde_json::to_string(&offline_json).unwrap()).unwrap();

        let released = release_shares_from_confirmations(
            &[
                Confirmation::OfflineFile { path: path.clone() },
                Confirmation::Device,
                Confirmation::Knowledge("ci-knowledge-answer".into()),
            ],
            None,
            None,
            Some(&dev_blob),
            Some(&know_blob),
            Some(&fp),
        )
        .unwrap();
        assert_eq!(released.len(), 3);
        let rec = shamir_combine(&released, 3).unwrap();
        assert_eq!(rec, secret);
    }

    #[test]
    fn release_rejects_ip_even_with_other_factors() {
        let secret = generate_root();
        let shares = shamir_split(&secret, 2, 3).unwrap();
        let fp = fingerprint_from_components(&[b"m"]);
        let dev_blob = seal_share_for_device(&shares[1], &fp).unwrap();
        let err = release_shares_from_confirmations(
            &[
                Confirmation::Device,
                Confirmation::PublicIp("203.0.113.1".into()),
            ],
            None,
            None,
            Some(&dev_blob),
            None,
            Some(&fp),
        );
        assert!(matches!(err, Err(FactorError::IpTrustForbidden)));
    }
}
