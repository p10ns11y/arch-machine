//! YubiKey challenge-response factor backend (HMAC-SHA1 slot).
//!
//! Production: `ykchalresp` (slot 1 or 2). Tests: [`MockYubi`] with a fixed secret.
//! The response only **releases a sealed share** — it never KDFs the Shamir root alone.

use crate::crypto::Share;
use crate::factors::{FactorError, SealedShareBlob};
use aes_gcm::aead::{Aead, KeyInit};
use aes_gcm::{Aes256Gcm, Nonce};
use base64::{engine::general_purpose::STANDARD as B64, Engine};
use hkdf::Hkdf;
use hmac::{Hmac, Mac};
use rand::RngCore;
use serde::{Deserialize, Serialize};
use sha1::Sha1;
use sha2::Sha256;
use std::process::Command;
use thiserror::Error;
use zeroize::Zeroize;

type HmacSha1 = Hmac<Sha1>;

pub const YUBI_HKDF_SALT: &[u8] = b"keeper-yubi-v1";
pub const YUBI_HKDF_INFO: &[u8] = b"share-seal-cr";
pub const YUBI_ALGO: &str = "hmac-sha1-cr-v1";
/// Default challenge-response slot (YubiKey configuration slot 2 is common for HMAC).
pub const DEFAULT_SLOT: u8 = 2;

#[derive(Debug, Error)]
pub enum YubiError {
    #[error("yubikey challenge-response failed: {0}")]
    Challenge(String),
    #[error("ykchalresp not found (install yubikey-personalization / yubikey-manager tools)")]
    ToolMissing,
    #[error(transparent)]
    Factor(#[from] FactorError),
    #[error("{0}")]
    Msg(String),
}

/// Host-side challenge-response (same path for mock and live hardware).
pub trait YubiChallenge: Send + Sync {
    fn slot(&self) -> u8;
    /// HMAC-SHA1 over `challenge` (typically 32–64 bytes). Returns raw digest bytes.
    fn challenge_response(&self, challenge: &[u8]) -> Result<Vec<u8>, YubiError>;
}

/// Test/CI backend: fixed 20-byte HMAC key (same crypto as YubiKey CR slot).
#[derive(Clone)]
pub struct MockYubi {
    pub slot: u8,
    pub secret: [u8; 20],
}

impl MockYubi {
    pub fn from_secret_bytes(secret: [u8; 20]) -> Self {
        Self { slot: DEFAULT_SLOT, secret }
    }

    /// Derive a stable mock secret from a passphrase-like string (tests only).
    pub fn from_seed(seed: &str) -> Self {
        let mut secret = [0u8; 20];
        let hk = Hkdf::<Sha256>::new(Some(b"keeper-mock-yubi"), seed.as_bytes());
        hk.expand(b"hmac-sha1-key", &mut secret).expect("hkdf");
        Self {
            slot: DEFAULT_SLOT,
            secret,
        }
    }
}

impl YubiChallenge for MockYubi {
    fn slot(&self) -> u8 {
        self.slot
    }

    fn challenge_response(&self, challenge: &[u8]) -> Result<Vec<u8>, YubiError> {
        let mut mac = <HmacSha1 as Mac>::new_from_slice(&self.secret)
            .map_err(|e| YubiError::Msg(format!("hmac key: {e}")))?;
        mac.update(challenge);
        Ok(mac.finalize().into_bytes().to_vec())
    }
}

/// Live hardware via `ykchalresp -s <slot> -x <hex>`.
pub struct LiveYubi {
    pub slot: u8,
}

impl Default for LiveYubi {
    fn default() -> Self {
        Self { slot: DEFAULT_SLOT }
    }
}

impl YubiChallenge for LiveYubi {
    fn slot(&self) -> u8 {
        self.slot
    }

    fn challenge_response(&self, challenge: &[u8]) -> Result<Vec<u8>, YubiError> {
        if which_ykchalresp().is_none() {
            return Err(YubiError::ToolMissing);
        }
        let hex_chal = hex::encode(challenge);
        let out = Command::new("ykchalresp")
            .args(["-s", &self.slot.to_string(), "-x", &hex_chal])
            .output()
            .map_err(|e| YubiError::Challenge(e.to_string()))?;
        if !out.status.success() {
            return Err(YubiError::Challenge(format!(
                "ykchalresp exit {:?}: {}",
                out.status.code(),
                String::from_utf8_lossy(&out.stderr)
            )));
        }
        let s = String::from_utf8_lossy(&out.stdout);
        let hex = s.trim();
        hex::decode(hex).map_err(|e| YubiError::Challenge(format!("parse response: {e}")))
    }
}

fn which_ykchalresp() -> Option<std::path::PathBuf> {
    std::env::var_os("PATH").and_then(|paths| {
        for dir in std::env::split_paths(&paths) {
            let p = dir.join("ykchalresp");
            if p.is_file() {
                return Some(p);
            }
        }
        None
    })
}

/// Resolve backend: `KEEPER_YUBI_MOCK_SECRET` → mock; else live ykchalresp.
pub fn default_backend(slot: u8) -> Result<Box<dyn YubiChallenge>, YubiError> {
    if let Ok(seed) = std::env::var("KEEPER_YUBI_MOCK_SECRET") {
        if !seed.is_empty() {
            let mut m = MockYubi::from_seed(&seed);
            m.slot = slot;
            return Ok(Box::new(m));
        }
    }
    Ok(Box::new(LiveYubi { slot }))
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct YubiShareBlob {
    pub role: String,
    pub algorithm: String,
    pub slot: u8,
    /// Fixed challenge presented to the key at unlock (base64).
    pub challenge_b64: String,
    pub nonce_b64: String,
    pub ciphertext_b64: String,
    pub share_id: u8,
}

fn seal_key_from_response(response: &[u8], challenge: &[u8]) -> Result<[u8; 32], FactorError> {
    // Bind response to enrolled challenge so responses to other challenges cannot open.
    let mut ikm = response.to_vec();
    ikm.extend_from_slice(challenge);
    let hk = Hkdf::<Sha256>::new(Some(YUBI_HKDF_SALT), &ikm);
    let mut okm = [0u8; 32];
    hk.expand(YUBI_HKDF_INFO, &mut okm)
        .map_err(|_| FactorError::Msg("yubi hkdf failed".into()))?;
    ikm.zeroize();
    Ok(okm)
}

/// Seal a Shamir share under YubiKey challenge-response material.
pub fn seal_share_for_yubi(
    share: &Share,
    backend: &dyn YubiChallenge,
) -> Result<YubiShareBlob, YubiError> {
    let mut challenge = [0u8; 32];
    rand::thread_rng().fill_bytes(&mut challenge);
    let mut response = backend.challenge_response(&challenge)?;
    let mut key = seal_key_from_response(&response, &challenge)?;
    response.zeroize();

    let mut plain = Vec::with_capacity(1 + share.data.len());
    plain.push(share.id);
    plain.extend_from_slice(&share.data);

    let cipher = Aes256Gcm::new_from_slice(&key).map_err(|e| YubiError::Msg(e.to_string()))?;
    key.zeroize();
    let mut nonce = [0u8; 12];
    rand::thread_rng().fill_bytes(&mut nonce);
    let ct = cipher
        .encrypt(Nonce::from_slice(&nonce), plain.as_ref())
        .map_err(|_| YubiError::Msg("yubi aead seal failed".into()))?;
    plain.zeroize();

    Ok(YubiShareBlob {
        role: "yubikey".into(),
        algorithm: YUBI_ALGO.into(),
        slot: backend.slot(),
        challenge_b64: B64.encode(challenge),
        nonce_b64: B64.encode(nonce),
        ciphertext_b64: B64.encode(ct),
        share_id: share.id,
    })
}

/// Open Yubi share given the **same** backend response to the stored challenge.
pub fn open_share_for_yubi(
    blob: &YubiShareBlob,
    response: &[u8],
) -> Result<Share, FactorError> {
    if blob.algorithm != YUBI_ALGO {
        return Err(FactorError::Msg(format!(
            "unsupported yubi algorithm {}",
            blob.algorithm
        )));
    }
    let challenge = B64
        .decode(&blob.challenge_b64)
        .map_err(|e| FactorError::Msg(format!("challenge b64: {e}")))?;
    let mut key = seal_key_from_response(response, &challenge)?;
    let cipher = Aes256Gcm::new_from_slice(&key).map_err(|e| FactorError::Msg(e.to_string()))?;
    key.zeroize();
    let nonce = B64
        .decode(&blob.nonce_b64)
        .map_err(|e| FactorError::Msg(format!("nonce b64: {e}")))?;
    let ct = B64
        .decode(&blob.ciphertext_b64)
        .map_err(|e| FactorError::Msg(format!("ct b64: {e}")))?;
    if nonce.len() != 12 {
        return Err(FactorError::Msg("yubi nonce len".into()));
    }
    let plain = cipher
        .decrypt(Nonce::from_slice(&nonce), ct.as_ref())
        .map_err(|_| FactorError::Denied("yubi open failed (wrong key or response)".into()))?;
    if plain.is_empty() {
        return Err(FactorError::Msg("empty yubi share".into()));
    }
    let id = plain[0];
    if id != blob.share_id {
        return Err(FactorError::Msg("yubi share id mismatch".into()));
    }
    Ok(Share {
        id,
        data: plain[1..].to_vec(),
    })
}

/// Run challenge against stored blob and open share (real enroll/unlock path).
pub fn open_yubi_share_with_backend(
    blob: &YubiShareBlob,
    backend: &dyn YubiChallenge,
) -> Result<Share, YubiError> {
    let challenge = B64
        .decode(&blob.challenge_b64)
        .map_err(|e| YubiError::Msg(format!("challenge b64: {e}")))?;
    let response = backend.challenge_response(&challenge)?;
    Ok(open_share_for_yubi(blob, &response)?)
}

/// Compatibility shim type for factors module docs.
pub type YubiSealed = YubiShareBlob;

// Re-export shape similar to SealedShareBlob for callers that only need open after response.
pub fn yubi_blob_as_generic_note(_b: &YubiShareBlob) -> Option<&SealedShareBlob> {
    None
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::crypto::{generate_root, shamir_split};

    #[test]
    fn mock_yubi_seal_open_roundtrip() {
        let root = generate_root();
        let shares = shamir_split(&root, 2, 3).unwrap();
        let y = MockYubi::from_seed("ci-mock-yubi-secret");
        let blob = seal_share_for_yubi(&shares[0], &y).unwrap();
        assert_eq!(blob.algorithm, YUBI_ALGO);
        let opened = open_yubi_share_with_backend(&blob, &y).unwrap();
        assert_eq!(opened.id, shares[0].id);
        assert_eq!(opened.data, shares[0].data);
    }

    #[test]
    fn wrong_mock_secret_fails() {
        let root = generate_root();
        let shares = shamir_split(&root, 2, 3).unwrap();
        let y = MockYubi::from_seed("correct");
        let blob = seal_share_for_yubi(&shares[0], &y).unwrap();
        let bad = MockYubi::from_seed("wrong");
        assert!(open_yubi_share_with_backend(&blob, &bad).is_err());
    }

    #[test]
    fn response_alone_is_not_root() {
        let root = generate_root();
        let shares = shamir_split(&root, 2, 3).unwrap();
        let y = MockYubi::from_seed("solo-test");
        let blob = seal_share_for_yubi(&shares[0], &y).unwrap();
        let chal = B64.decode(&blob.challenge_b64).unwrap();
        let resp = y.challenge_response(&chal).unwrap();
        // One share cannot reconstruct k=2
        assert!(crate::crypto::shamir_combine(
            &[open_share_for_yubi(&blob, &resp).unwrap()],
            2
        )
        .is_err());
    }
}
