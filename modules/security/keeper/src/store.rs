//! Filesystem layout for keeper data root.

use crate::crypto::{PassphraseWrap, RootWrapped, Sealed, ShareJson};
use crate::factors::SealedShareBlob;
use serde::{Deserialize, Serialize};
use std::fs;
use std::path::{Path, PathBuf};
use thiserror::Error;

#[derive(Debug, Error)]
pub enum StoreError {
    #[error("io: {0}")]
    Io(#[from] std::io::Error),
    #[error("json: {0}")]
    Json(#[from] serde_json::Error),
    #[error("{0}")]
    Msg(String),
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Meta {
    pub version: u32,
    pub k: u8,
    pub n: u8,
    pub drill_proven: bool,
    pub created_at: String,
    pub kdf: String,
    /// Hybrid PQ algorithm for sealed secrets.
    pub seal_algorithm: String,
    /// Enrolled factor roles (e.g. passphrase, offline, device, knowledge).
    #[serde(default)]
    pub factors: Vec<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub last_drill_at: Option<String>,
}

pub struct Paths {
    pub root: PathBuf,
}

impl Paths {
    pub fn new(root: impl AsRef<Path>) -> Self {
        Self {
            root: root.as_ref().to_path_buf(),
        }
    }

    pub fn meta(&self) -> PathBuf {
        self.root.join("meta.json")
    }
    pub fn passphrase_wrap(&self) -> PathBuf {
        self.root.join("shares").join("passphrase.wrap.json")
    }
    pub fn device_blob(&self) -> PathBuf {
        self.root.join("shares").join("device.sealed.json")
    }
    pub fn knowledge_blob(&self) -> PathBuf {
        self.root.join("shares").join("knowledge.sealed.json")
    }
    pub fn yubi_blob(&self) -> PathBuf {
        self.root.join("shares").join("yubikey.sealed.json")
    }
    pub fn canary(&self) -> PathBuf {
        self.root.join("canary.sealed.json")
    }
    pub fn pq_ek(&self) -> PathBuf {
        self.root.join("pq").join("encapsulation.key.json")
    }
    pub fn pq_dk_wrap(&self) -> PathBuf {
        self.root.join("pq").join("decapsulation.seed.wrap.json")
    }
    pub fn secret(&self, name: &str) -> PathBuf {
        self.root
            .join("secrets")
            .join(format!("{name}.sealed.json"))
    }
}

pub fn ensure_root(root: &Path) -> Result<(), StoreError> {
    fs::create_dir_all(root.join("shares"))?;
    fs::create_dir_all(root.join("secrets"))?;
    fs::create_dir_all(root.join("pq"))?;
    Ok(())
}

pub fn sanitize_name(name: &str) -> Result<(), StoreError> {
    if name.is_empty()
        || !name
            .chars()
            .all(|c| c.is_ascii_alphanumeric() || matches!(c, '.' | '_' | '@' | '+' | '-'))
    {
        return Err(StoreError::Msg(
            "secret name must be alphanumeric plus . _ @ + -".into(),
        ));
    }
    Ok(())
}

fn write_json<T: Serialize>(path: &Path, value: &T) -> Result<(), StoreError> {
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent)?;
    }
    let data = serde_json::to_vec_pretty(value)?;
    fs::write(path, data)?;
    // best-effort mode on unix
    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt;
        let _ = fs::set_permissions(path, fs::Permissions::from_mode(0o600));
    }
    Ok(())
}

fn read_json<T: for<'de> Deserialize<'de>>(path: &Path) -> Result<T, StoreError> {
    let data = fs::read_to_string(path)?;
    Ok(serde_json::from_str(&data)?)
}

pub fn read_meta(root: &Path) -> Result<Option<Meta>, StoreError> {
    let p = Paths::new(root).meta();
    if !p.exists() {
        return Ok(None);
    }
    Ok(Some(read_json(&p)?))
}

pub fn write_meta(root: &Path, meta: &Meta) -> Result<(), StoreError> {
    write_json(&Paths::new(root).meta(), meta)
}

pub fn write_passphrase_wrap(root: &Path, w: &PassphraseWrap) -> Result<(), StoreError> {
    write_json(&Paths::new(root).passphrase_wrap(), w)
}

pub fn read_passphrase_wrap(root: &Path) -> Result<PassphraseWrap, StoreError> {
    read_json(&Paths::new(root).passphrase_wrap())
}

pub fn write_device_blob(root: &Path, s: &SealedShareBlob) -> Result<(), StoreError> {
    write_json(&Paths::new(root).device_blob(), s)
}

pub fn read_device_blob(root: &Path) -> Result<SealedShareBlob, StoreError> {
    read_json(&Paths::new(root).device_blob())
}

pub fn write_knowledge_blob(root: &Path, s: &SealedShareBlob) -> Result<(), StoreError> {
    write_json(&Paths::new(root).knowledge_blob(), s)
}

pub fn read_knowledge_blob(root: &Path) -> Result<SealedShareBlob, StoreError> {
    read_json(&Paths::new(root).knowledge_blob())
}

pub fn write_yubi_blob(root: &Path, s: &crate::yubi::YubiShareBlob) -> Result<(), StoreError> {
    write_json(&Paths::new(root).yubi_blob(), s)
}

pub fn read_yubi_blob(root: &Path) -> Result<crate::yubi::YubiShareBlob, StoreError> {
    read_json(&Paths::new(root).yubi_blob())
}

pub fn yubi_blob_exists(root: &Path) -> bool {
    Paths::new(root).yubi_blob().exists()
}

pub fn write_canary(root: &Path, s: &Sealed) -> Result<(), StoreError> {
    write_json(&Paths::new(root).canary(), s)
}

pub fn read_canary(root: &Path) -> Result<Sealed, StoreError> {
    read_json(&Paths::new(root).canary())
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct PqEncapsulationKey {
    pub algorithm: String,
    pub encapsulation_key: String,
}

pub fn write_pq_ek(root: &Path, ek_b64: &str, algorithm: &str) -> Result<(), StoreError> {
    write_json(
        &Paths::new(root).pq_ek(),
        &PqEncapsulationKey {
            algorithm: algorithm.into(),
            encapsulation_key: ek_b64.into(),
        },
    )
}

pub fn read_pq_ek(root: &Path) -> Result<PqEncapsulationKey, StoreError> {
    read_json(&Paths::new(root).pq_ek())
}

pub fn write_pq_dk_wrap(root: &Path, w: &RootWrapped) -> Result<(), StoreError> {
    write_json(&Paths::new(root).pq_dk_wrap(), w)
}

pub fn read_pq_dk_wrap(root: &Path) -> Result<RootWrapped, StoreError> {
    read_json(&Paths::new(root).pq_dk_wrap())
}

pub fn write_secret(root: &Path, name: &str, s: &Sealed) -> Result<(), StoreError> {
    sanitize_name(name)?;
    write_json(&Paths::new(root).secret(name), s)
}

pub fn read_secret(root: &Path, name: &str) -> Result<Sealed, StoreError> {
    sanitize_name(name)?;
    read_json(&Paths::new(root).secret(name))
}

pub fn write_escrow(path: &Path, s: &ShareJson) -> Result<(), StoreError> {
    write_json(path, s)
}

pub fn read_escrow(path: &Path) -> Result<ShareJson, StoreError> {
    read_json(path)
}
