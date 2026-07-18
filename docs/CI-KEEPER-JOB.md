# CI job: keeper (add to `.github/workflows/ci.yml`)

GitHub OAuth tokens without the `workflow` scope cannot push workflow edits. Merge this job manually or push with a PAT that has `workflow` scope:

```yaml
  keeper:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@e8d4307400f9427dba7cb98e488d6ab85f1cec5f # v7.0.0
      - uses: dtolnay/rust-toolchain@stable
      - name: cargo test (modules/security/keeper)
        run: cargo test --manifest-path modules/security/keeper/Cargo.toml
```

Local equivalent: `make keeper-test`
