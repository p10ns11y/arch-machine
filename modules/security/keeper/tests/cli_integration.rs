//! Dual CLI runs: simple any-2-of-3 + escrow get without passphrase.

use std::process::Command;
use tempfile::tempdir;

fn bin() -> Command {
    let mut c = Command::new(env!("CARGO_BIN_EXE_keeper"));
    c.env_remove("KEEPER_PASSPHRASE");
    c.env_remove("KEEPER_KNOWLEDGE");
    c
}

#[test]
fn dual_cli_simple_recover_and_escrow_get() {
    for i in 1..=2 {
        let dir = tempdir().unwrap();
        let root = dir.path().join(format!("vault{i}"));
        let escrow = dir.path().join(format!("escrow{i}.json"));
        let pass = format!("cli-pass-phrase-{i}-xx");

        let out = bin()
            .env("KEEPER_PASSPHRASE", &pass)
            .args([
                "init",
                "--escrow",
                escrow.to_str().unwrap(),
                "--root",
                root.to_str().unwrap(),
            ])
            .output()
            .unwrap();
        assert!(
            out.status.success(),
            "init: {}",
            String::from_utf8_lossy(&out.stderr)
        );
        let init_body = String::from_utf8_lossy(&out.stdout);
        assert!(init_body.contains("ML-KEM-768"));
        assert!(init_body.contains("any-2-of-3"));

        let st = bin()
            .args(["status", "--root", root.to_str().unwrap()])
            .output()
            .unwrap();
        assert_eq!(st.status.code(), Some(2));
        let st_body = String::from_utf8_lossy(&st.stdout);
        assert!(st_body.contains("remember") || st_body.contains("ONE passphrase"));

        let put = bin()
            .env("KEEPER_PASSPHRASE", &pass)
            .args([
                "put",
                "demo",
                "--value",
                "payload-mfa",
                "--root",
                root.to_str().unwrap(),
            ])
            .output()
            .unwrap();
        assert!(put.status.success(), "{}", String::from_utf8_lossy(&put.stderr));

        // Daily get: passphrase only (no knowledge)
        let get = bin()
            .env("KEEPER_PASSPHRASE", &pass)
            .args(["get", "demo", "--root", root.to_str().unwrap()])
            .output()
            .unwrap();
        assert!(get.status.success(), "{}", String::from_utf8_lossy(&get.stderr));
        assert_eq!(String::from_utf8_lossy(&get.stdout).trim(), "payload-mfa");

        // Get without passphrase via escrow
        let get_esc = bin()
            .env_remove("KEEPER_PASSPHRASE")
            .args([
                "get",
                "demo",
                "--escrow",
                escrow.to_str().unwrap(),
                "--root",
                root.to_str().unwrap(),
            ])
            .output()
            .unwrap();
        assert!(
            get_esc.status.success(),
            "escrow get: {}",
            String::from_utf8_lossy(&get_esc.stderr)
        );
        assert_eq!(
            String::from_utf8_lossy(&get_esc.stdout).trim(),
            "payload-mfa"
        );

        // recover marks healthy
        let rec = bin()
            .env_remove("KEEPER_PASSPHRASE")
            .args([
                "recover",
                "--escrow",
                escrow.to_str().unwrap(),
                "--root",
                root.to_str().unwrap(),
            ])
            .output()
            .unwrap();
        assert!(
            rec.status.success(),
            "recover: {}",
            String::from_utf8_lossy(&rec.stderr)
        );
        let body = String::from_utf8_lossy(&rec.stdout);
        assert!(body.contains("offline+device"));
        assert!(body.contains("\"healthy\": true") || body.contains("\"healthy\":true"));

        let st2 = bin()
            .args(["status", "--root", root.to_str().unwrap()])
            .output()
            .unwrap();
        assert!(st2.status.success());
        assert!(String::from_utf8_lossy(&st2.stdout).contains("drill-proven"));
    }
}
