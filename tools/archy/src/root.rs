//! Discover arch-machine / tinfoil repo root for shell backends.

use std::env;
use std::path::{Path, PathBuf};

pub fn discover_root() -> PathBuf {
    for key in ["TINFOIL_ROOT", "ARCH_MACHINE_ROOT"] {
        if let Ok(p) = env::var(key) {
            let pb = PathBuf::from(p);
            if looks_like_root(&pb) {
                return pb;
            }
        }
    }

    // Walk from cwd and from executable
    let mut candidates = Vec::new();
    if let Ok(cwd) = env::current_dir() {
        candidates.push(cwd.clone());
        candidates.extend(cwd.ancestors().map(|p| p.to_path_buf()));
    }
    if let Ok(exe) = env::current_exe() {
        if let Some(dir) = exe.parent() {
            candidates.push(dir.to_path_buf());
            candidates.push(dir.join(".."));
            candidates.push(dir.join("../.."));
            candidates.push(dir.join("../../.."));
        }
    }
    candidates.push(PathBuf::from("/usr/share/tinfoil"));

    for c in candidates {
        if let Ok(canon) = c.canonicalize() {
            if looks_like_root(&canon) {
                return canon;
            }
        } else if looks_like_root(&c) {
            return c;
        }
    }

    env::current_dir().unwrap_or_else(|_| PathBuf::from("."))
}

fn looks_like_root(p: &Path) -> bool {
    p.join("maintenance/inventory.sh").is_file()
        || p.join("install.sh").is_file()
        || (p.join("lib/tui.sh").is_file() && p.join("maintenance").is_dir())
}


