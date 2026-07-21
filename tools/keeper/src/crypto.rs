//! Pure crypto: Shamir over AES GF(256), scrypt passphrase wrap,
//! hybrid PQ seal (ML-KEM-768 + AES-256-GCM via HKDF-SHA256).

use aes_gcm::aead::{Aead, KeyInit};
use aes_gcm::{Aes256Gcm, Nonce};
use base64::{engine::general_purpose::STANDARD as B64, Engine};
use hkdf::Hkdf;
use ml_kem::kem::{Decapsulate, Encapsulate, FromSeed, KeyExport, Kem};
use ml_kem::{ml_kem_768, MlKem768, Seed};
use rand::{Rng, RngCore};
use scrypt::{scrypt, Params as ScryptParams};
use serde::{Deserialize, Serialize};
use sha2::Sha256;
use thiserror::Error;
use zeroize::Zeroize;

pub const ROOT_LEN: usize = 32;
pub const DEFAULT_K: u8 = 2;
pub const DEFAULT_N: u8 = 3;
pub const CANARY_PLAINTEXT: &str = "keeper-canary-v1";
/// Format version for hybrid PQ sealed secrets (breaking vs classical v1).
pub const CRYPTO_VERSION: u32 = 2;
pub const HYBRID_ALGORITHM: &str = "ML-KEM-768 + AES-256-GCM via HKDF-SHA256 (hybrid PQ)";
const HKDF_SALT: &[u8] = b"keeper-mlkem768";
const HKDF_INFO: &[u8] = b"keeper-v2-hybrid";

#[derive(Debug, Error)]
pub enum CryptoError {
    #[error("{0}")]
    Msg(String),
    #[error("wrong passphrase or corrupt wrap")]
    WrongPassphrase,
    #[error("aead failure")]
    Aead,
    #[error("unsupported sealed algorithm/version (need hybrid PQ v2)")]
    UnsupportedSealed,
}

// --- GF(256) AES field (generator 0x03) ---

static mut GF_EXP: [u8; 512] = [0; 512];
static mut GF_LOG: [u8; 256] = [0; 256];
static GF_INIT: std::sync::Once = std::sync::Once::new();

fn init_gf() {
    GF_INIT.call_once(|| {
        fn xtime(a: u8) -> u8 {
            let a = a as u16;
            let doubled = a << 1;
            (if a & 0x80 != 0 {
                doubled ^ 0x1b
            } else {
                doubled
            }) as u8
        }
        // SAFETY: single-threaded once init
        unsafe {
            let mut x: u8 = 1;
            for i in 0..255 {
                GF_EXP[i] = x;
                GF_LOG[x as usize] = i as u8;
                x = xtime(x) ^ x; // *= 3
            }
            for i in 255..512 {
                GF_EXP[i] = GF_EXP[i - 255];
            }
            GF_LOG[0] = 0;
        }
    });
}

fn gf_mul(a: u8, b: u8) -> u8 {
    init_gf();
    if a == 0 || b == 0 {
        return 0;
    }
    unsafe {
        let i = GF_LOG[a as usize] as usize + GF_LOG[b as usize] as usize;
        GF_EXP[i]
    }
}

fn gf_div(a: u8, b: u8) -> Result<u8, CryptoError> {
    init_gf();
    if b == 0 {
        return Err(CryptoError::Msg("gf_div by zero".into()));
    }
    if a == 0 {
        return Ok(0);
    }
    unsafe {
        let i = (GF_LOG[a as usize] as usize + 255 - GF_LOG[b as usize] as usize) % 255;
        Ok(GF_EXP[i])
    }
}

fn eval_poly(coeffs: &[u8], x: u8) -> u8 {
    let mut result = 0u8;
    for &c in coeffs.iter().rev() {
        result = gf_mul(result, x) ^ c;
    }
    result
}

#[derive(Clone, Debug)]
pub struct Share {
    pub id: u8,
    pub data: Vec<u8>,
}

/// Split secret into n shares; any k reconstruct.
pub fn shamir_split(secret: &[u8], k: u8, n: u8) -> Result<Vec<Share>, CryptoError> {
    if secret.is_empty() {
        return Err(CryptoError::Msg("empty secret".into()));
    }
    if k < 2 || n < k {
        return Err(CryptoError::Msg("need 2 ≤ k ≤ n ≤ 255".into()));
    }
    let k = k as usize;
    let n = n as usize;
    let mut shares: Vec<Share> = (1..=n)
        .map(|i| Share {
            id: i as u8,
            data: vec![0u8; secret.len()],
        })
        .collect();

    let mut rng = rand::thread_rng();
    for (bi, &sb) in secret.iter().enumerate() {
        let mut coeffs = vec![0u8; k];
        coeffs[0] = sb;
        for c in coeffs.iter_mut().skip(1) {
            *c = rng.gen();
        }
        for (i, share) in shares.iter_mut().enumerate() {
            let x = (i + 1) as u8;
            share.data[bi] = eval_poly(&coeffs, x);
        }
    }
    Ok(shares)
}

/// Reconstruct with at least k shares.
pub fn shamir_combine(shares: &[Share], k: u8) -> Result<Vec<u8>, CryptoError> {
    let k = k as usize;
    if shares.len() < k {
        return Err(CryptoError::Msg(format!("need at least {k} shares")));
    }
    let used = &shares[..k];
    let len = used[0].data.len();
    for s in used {
        if s.data.len() != len {
            return Err(CryptoError::Msg("share length mismatch".into()));
        }
        if s.id < 1 {
            return Err(CryptoError::Msg("bad share id".into()));
        }
    }
    let mut secret = vec![0u8; len];
    for bi in 0..len {
        let mut acc = 0u8;
        for i in 0..k {
            let xi = used[i].id;
            let yi = used[i].data[bi];
            let mut li = 1u8;
            for (j, share) in used.iter().enumerate().take(k) {
                if i == j {
                    continue;
                }
                let xj = share.id;
                li = gf_mul(li, gf_div(xj, xi ^ xj)?);
            }
            acc ^= gf_mul(yi, li);
        }
        secret[bi] = acc;
    }
    Ok(secret)
}

pub fn generate_root() -> Vec<u8> {
    let mut r = vec![0u8; ROOT_LEN];
    rand::thread_rng().fill_bytes(&mut r);
    r
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PassphraseWrap {
    pub v: u32,
    pub kdf: String,
    pub salt: String,
    pub nonce: String,
    pub ct: String,
    #[serde(rename = "shareId")]
    pub share_id: u8,
}

fn scrypt_key(passphrase: &str, salt: &[u8]) -> Result<[u8; 32], CryptoError> {
    let params = ScryptParams::new(14, 8, 1, 32) // N=2^14=16384
        .map_err(|e| CryptoError::Msg(format!("scrypt params: {e}")))?;
    let mut key = [0u8; 32];
    scrypt(passphrase.as_bytes(), salt, &params, &mut key)
        .map_err(|e| CryptoError::Msg(format!("scrypt: {e}")))?;
    Ok(key)
}

pub fn wrap_with_passphrase(share_data: &[u8], share_id: u8, passphrase: &str) -> Result<PassphraseWrap, CryptoError> {
    if passphrase.is_empty() {
        return Err(CryptoError::Msg("passphrase required".into()));
    }
    let mut salt = [0u8; 16];
    let mut nonce_bytes = [0u8; 12];
    rand::thread_rng().fill_bytes(&mut salt);
    rand::thread_rng().fill_bytes(&mut nonce_bytes);
    let mut key = scrypt_key(passphrase, &salt)?;
    let cipher = Aes256Gcm::new_from_slice(&key).map_err(|_| CryptoError::Aead)?;
    key.zeroize();
    let nonce = Nonce::from_slice(&nonce_bytes);
    let ct = cipher
        .encrypt(nonce, share_data)
        .map_err(|_| CryptoError::Aead)?;
    Ok(PassphraseWrap {
        v: CRYPTO_VERSION,
        kdf: "scrypt".into(),
        salt: B64.encode(salt),
        nonce: B64.encode(nonce_bytes),
        ct: B64.encode(ct),
        share_id,
    })
}

pub fn unwrap_with_passphrase(wrapped: &PassphraseWrap, passphrase: &str) -> Result<Vec<u8>, CryptoError> {
    let salt = B64
        .decode(&wrapped.salt)
        .map_err(|e| CryptoError::Msg(format!("salt: {e}")))?;
    let nonce_bytes = B64
        .decode(&wrapped.nonce)
        .map_err(|e| CryptoError::Msg(format!("nonce: {e}")))?;
    let ct = B64
        .decode(&wrapped.ct)
        .map_err(|e| CryptoError::Msg(format!("ct: {e}")))?;
    let mut key = scrypt_key(passphrase, &salt)?;
    let cipher = Aes256Gcm::new_from_slice(&key).map_err(|_| CryptoError::Aead)?;
    key.zeroize();
    if nonce_bytes.len() != 12 {
        return Err(CryptoError::Msg("bad nonce len".into()));
    }
    let nonce = Nonce::from_slice(&nonce_bytes);
    cipher
        .decrypt(nonce, ct.as_ref())
        .map_err(|_| CryptoError::WrongPassphrase)
}

/// Hybrid PQ sealed secret (canary / put payloads).
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Sealed {
    pub v: u32,
    pub algorithm: String,
    /// ML-KEM-768 ciphertext (base64).
    pub kem_ct: String,
    pub nonce: String,
    pub ct: String,
}

/// Classical AES wrap of PQ decapsulation seed under threshold root R.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RootWrapped {
    pub v: u32,
    pub purpose: String,
    pub nonce: String,
    pub ct: String,
}

/// Generate ML-KEM-768 keypair; returns (decapsulation_seed 64B, encapsulation_key bytes).
pub fn generate_pq_keypair() -> (Vec<u8>, Vec<u8>) {
    let (dk, ek) = MlKem768::generate_keypair();
    let seed = dk.to_bytes();
    let ek_bytes = ek.to_bytes();
    (seed.as_slice().to_vec(), ek_bytes.as_slice().to_vec())
}

fn aead_key_from_shared(ss: &[u8]) -> Result<[u8; 32], CryptoError> {
    let hk = Hkdf::<Sha256>::new(Some(HKDF_SALT), ss);
    let mut okm = [0u8; 32];
    hk.expand(HKDF_INFO, &mut okm)
        .map_err(|_| CryptoError::Msg("hkdf expand failed".into()))?;
    Ok(okm)
}

/// Hybrid seal: encapsulate to ML-KEM-768 public key, AES-GCM payload.
pub fn seal_hybrid(ek_bytes: &[u8], plaintext: &[u8]) -> Result<Sealed, CryptoError> {
    let ek_key = ml_kem::kem::Key::<ml_kem_768::EncapsulationKey>::try_from(ek_bytes)
        .map_err(|_| CryptoError::Msg("invalid ML-KEM encapsulation key bytes".into()))?;
    let ek = ml_kem_768::EncapsulationKey::new(&ek_key)
        .map_err(|_| CryptoError::Msg("invalid ML-KEM encapsulation key".into()))?;
    let (kem_ct, shared) = ek.encapsulate();
    let mut aead_key = aead_key_from_shared(shared.as_slice())?;
    let mut nonce_bytes = [0u8; 12];
    rand::thread_rng().fill_bytes(&mut nonce_bytes);
    let cipher = Aes256Gcm::new_from_slice(&aead_key).map_err(|_| CryptoError::Aead)?;
    aead_key.zeroize();
    let nonce = Nonce::from_slice(&nonce_bytes);
    let ct = cipher
        .encrypt(nonce, plaintext)
        .map_err(|_| CryptoError::Aead)?;
    Ok(Sealed {
        v: CRYPTO_VERSION,
        algorithm: HYBRID_ALGORITHM.into(),
        kem_ct: B64.encode(kem_ct.as_slice()),
        nonce: B64.encode(nonce_bytes),
        ct: B64.encode(ct),
    })
}

/// Hybrid open with ML-KEM-768 decapsulation seed (64 bytes).
pub fn open_hybrid(dk_seed: &[u8], sealed: &Sealed) -> Result<Vec<u8>, CryptoError> {
    if sealed.v != CRYPTO_VERSION || sealed.algorithm != HYBRID_ALGORITHM {
        return Err(CryptoError::UnsupportedSealed);
    }
    if sealed.kem_ct.is_empty() {
        return Err(CryptoError::UnsupportedSealed);
    }
    let seed = Seed::try_from(dk_seed)
        .map_err(|_| CryptoError::Msg("invalid ML-KEM seed length".into()))?;
    let (dk, _) = MlKem768::from_seed(&seed);
    let kem_bytes = B64
        .decode(&sealed.kem_ct)
        .map_err(|e| CryptoError::Msg(format!("kem_ct: {e}")))?;
    let kem_ct = ml_kem_768::Ciphertext::try_from(kem_bytes.as_slice())
        .map_err(|_| CryptoError::Msg("invalid ML-KEM ciphertext".into()))?;
    let shared = dk.decapsulate(&kem_ct);
    let mut aead_key = aead_key_from_shared(shared.as_slice())?;
    let nonce_bytes = B64
        .decode(&sealed.nonce)
        .map_err(|e| CryptoError::Msg(format!("nonce: {e}")))?;
    let ct = B64
        .decode(&sealed.ct)
        .map_err(|e| CryptoError::Msg(format!("ct: {e}")))?;
    if nonce_bytes.len() != 12 {
        return Err(CryptoError::Msg("bad nonce len".into()));
    }
    let cipher = Aes256Gcm::new_from_slice(&aead_key).map_err(|_| CryptoError::Aead)?;
    aead_key.zeroize();
    let nonce = Nonce::from_slice(&nonce_bytes);
    cipher
        .decrypt(nonce, ct.as_ref())
        .map_err(|_| CryptoError::Aead)
}

/// Wrap bytes under classical root R (used only for PQ seed storage).
pub fn seal_under_root(root: &[u8], plaintext: &[u8]) -> Result<RootWrapped, CryptoError> {
    if root.len() != ROOT_LEN {
        return Err(CryptoError::Msg("root must be 32 bytes".into()));
    }
    let mut nonce_bytes = [0u8; 12];
    rand::thread_rng().fill_bytes(&mut nonce_bytes);
    let cipher = Aes256Gcm::new_from_slice(root).map_err(|_| CryptoError::Aead)?;
    let nonce = Nonce::from_slice(&nonce_bytes);
    let ct = cipher
        .encrypt(nonce, plaintext)
        .map_err(|_| CryptoError::Aead)?;
    Ok(RootWrapped {
        v: CRYPTO_VERSION,
        purpose: "ml-kem-768-dk-seed".into(),
        nonce: B64.encode(nonce_bytes),
        ct: B64.encode(ct),
    })
}

pub fn open_under_root(root: &[u8], wrapped: &RootWrapped) -> Result<Vec<u8>, CryptoError> {
    if root.len() != ROOT_LEN {
        return Err(CryptoError::Msg("root must be 32 bytes".into()));
    }
    let nonce_bytes = B64
        .decode(&wrapped.nonce)
        .map_err(|e| CryptoError::Msg(format!("nonce: {e}")))?;
    let ct = B64
        .decode(&wrapped.ct)
        .map_err(|e| CryptoError::Msg(format!("ct: {e}")))?;
    if nonce_bytes.len() != 12 {
        return Err(CryptoError::Msg("bad nonce len".into()));
    }
    let cipher = Aes256Gcm::new_from_slice(root).map_err(|_| CryptoError::Aead)?;
    let nonce = Nonce::from_slice(&nonce_bytes);
    cipher
        .decrypt(nonce, ct.as_ref())
        .map_err(|_| CryptoError::Aead)
}

/// Convenience: seal secret for vault after unlock (hybrid via stored ek).
pub fn seal(ek_bytes: &[u8], plaintext: &[u8]) -> Result<Sealed, CryptoError> {
    seal_hybrid(ek_bytes, plaintext)
}

/// Convenience: open secret with PQ seed recovered via root.
pub fn open(dk_seed: &[u8], sealed: &Sealed) -> Result<Vec<u8>, CryptoError> {
    open_hybrid(dk_seed, sealed)
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ShareJson {
    pub id: u8,
    pub data: String,
}

impl From<&Share> for ShareJson {
    fn from(s: &Share) -> Self {
        Self {
            id: s.id,
            data: B64.encode(&s.data),
        }
    }
}

impl TryFrom<ShareJson> for Share {
    type Error = CryptoError;
    fn try_from(j: ShareJson) -> Result<Self, Self::Error> {
        let data = B64
            .decode(&j.data)
            .map_err(|e| CryptoError::Msg(format!("share data: {e}")))?;
        Ok(Share { id: j.id, data })
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn shamir_roundtrip_all_pairs() {
        for _ in 0..20 {
            let secret = generate_root();
            let shares = shamir_split(&secret, 2, 3).unwrap();
            for pair in [[0usize, 1], [1, 2], [0, 2]] {
                let rec = shamir_combine(&[shares[pair[0]].clone(), shares[pair[1]].clone()], 2)
                    .unwrap();
                assert_eq!(secret, rec);
            }
        }
    }

    #[test]
    fn shamir_insufficient() {
        let secret = generate_root();
        let shares = shamir_split(&secret, 2, 3).unwrap();
        assert!(shamir_combine(&[shares[0].clone()], 2).is_err());
    }

    #[test]
    fn passphrase_wrap_roundtrip() {
        let data = generate_root();
        let w = wrap_with_passphrase(&data, 1, "correct-horse").unwrap();
        let out = unwrap_with_passphrase(&w, "correct-horse").unwrap();
        assert_eq!(data, out);
    }

    #[test]
    fn passphrase_wrong() {
        let data = generate_root();
        let w = wrap_with_passphrase(&data, 1, "correct-horse").unwrap();
        assert!(matches!(
            unwrap_with_passphrase(&w, "wrong"),
            Err(CryptoError::WrongPassphrase)
        ));
    }

    #[test]
    fn hybrid_seal_open() {
        let (seed, ek) = generate_pq_keypair();
        let s = seal_hybrid(&ek, CANARY_PLAINTEXT.as_bytes()).unwrap();
        assert_eq!(s.algorithm, HYBRID_ALGORITHM);
        assert_eq!(s.v, CRYPTO_VERSION);
        assert!(!s.kem_ct.is_empty());
        let p = open_hybrid(&seed, &s).unwrap();
        assert_eq!(p, CANARY_PLAINTEXT.as_bytes());
    }

    #[test]
    fn hybrid_wrong_key() {
        let (_seed, ek) = generate_pq_keypair();
        let (seed2, _) = generate_pq_keypair();
        let s = seal_hybrid(&ek, b"secret").unwrap();
        assert!(open_hybrid(&seed2, &s).is_err());
    }

    #[test]
    fn hybrid_rejects_missing_kem() {
        let (seed, _) = generate_pq_keypair();
        let bad = Sealed {
            v: 1,
            algorithm: "AES-only".into(),
            kem_ct: String::new(),
            nonce: B64.encode([0u8; 12]),
            ct: B64.encode([0u8; 16]),
        };
        assert!(matches!(
            open_hybrid(&seed, &bad),
            Err(CryptoError::UnsupportedSealed)
        ));
    }

    #[test]
    fn root_wrap_pq_seed() {
        let r = generate_root();
        let (seed, _) = generate_pq_keypair();
        let w = seal_under_root(&r, &seed).unwrap();
        let out = open_under_root(&r, &w).unwrap();
        assert_eq!(out, seed);
    }
}
