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

#[test]
fn cli_enroll_yubi_mock_strong_get_and_solo_fail() {
    let dir = tempdir().unwrap();
    let root = dir.path().join("vault-y");
    let escrow = dir.path().join("escrow-y.json");
    let pass = "cli-yubi-pass-phrase-xx";
    let mock = "cli-mock-yubi-hmac-seed";

    let init = bin()
        .env("KEEPER_PASSPHRASE", pass)
        .args([
            "init",
            "--escrow",
            escrow.to_str().unwrap(),
            "--root",
            root.to_str().unwrap(),
        ])
        .output()
        .unwrap();
    assert!(init.status.success(), "{}", String::from_utf8_lossy(&init.stderr));

    // Enroll before secrets so mock path is clean; then put + strong get (CI allow flag)
    let en = bin()
        .env("KEEPER_PASSPHRASE", pass)
        .env("KEEPER_YUBI_MOCK_SECRET", mock)
        .args([
            "enroll-yubikey",
            "--escrow",
            escrow.to_str().unwrap(),
            "--root",
            root.to_str().unwrap(),
        ])
        .output()
        .unwrap();
    assert!(
        en.status.success(),
        "enroll: {}",
        String::from_utf8_lossy(&en.stderr)
    );
    let en_body = String::from_utf8_lossy(&en.stdout);
    assert!(en_body.contains("yubikey"));
    assert!(en_body.contains("any-2-of-4") || en_body.contains("\"n\": 4") || en_body.contains("\"n\":4"));

    let put = bin()
        .env("KEEPER_PASSPHRASE", pass)
        .args([
            "put",
            "api",
            "--value",
            "token-from-yubi-path",
            "--root",
            root.to_str().unwrap(),
        ])
        .output()
        .unwrap();
    assert!(put.status.success(), "{}", String::from_utf8_lossy(&put.stderr));

    // Strong get with mock after secrets requires explicit CI allow
    let get = bin()
        .env_remove("KEEPER_PASSPHRASE")
        .env("KEEPER_YUBI_MOCK_SECRET", mock)
        .env("KEEPER_ALLOW_YUBI_MOCK", "1")
        .args(["get", "api", "--yubi", "--root", root.to_str().unwrap()])
        .output()
        .unwrap();
    assert!(get.status.success(), "get --yubi: {}", String::from_utf8_lossy(&get.stderr));
    assert_eq!(
        String::from_utf8_lossy(&get.stdout).trim(),
        "token-from-yubi-path"
    );

    // Solo yubi must fail
    let probe = bin()
        .env("KEEPER_YUBI_MOCK_SECRET", mock)
        .args(["yubi-probe", "--root", root.to_str().unwrap()])
        .output()
        .unwrap();
    assert!(
        probe.status.success(),
        "yubi-probe should succeed when solo rejected: {}",
        String::from_utf8_lossy(&probe.stderr)
    );
    assert!(String::from_utf8_lossy(&probe.stdout).contains("soloYubiRejected"));

    // After enroll, status must not stay falsely healthy
    let st = bin()
        .args(["status", "--root", root.to_str().unwrap()])
        .output()
        .unwrap();
    let st_body = String::from_utf8_lossy(&st.stdout);
    assert!(
        st_body.contains("any-2-of-4-strong-yubi"),
        "status model: {st_body}"
    );
    assert!(
        st_body.contains("\"drillProven\": false") || st_body.contains("\"drillProven\":false"),
        "enroll must clear drill: {st_body}"
    );
}
