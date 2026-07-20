.PHONY: lint validate-profiles evidence-smoke eye-comfort-test eye-comfort-generate-check ci-help archy archy-release archy-test groxy-test xchat-remote-test groxy-python-test

lint:
	@shellcheck --severity=warning $$(find . -name '*.sh' -not -path './.grok/*' -not -path './logs/*' -not -path './systemd/*' 2>/dev/null) || true
	@yamllint -c .yamllint.yml config/ 2>/dev/null || true
	@markdownlint '**/*.md' --ignore 'FUNREADME.md' --ignore 'node_modules' 2>/dev/null || true

validate-profiles:
	@./scripts/profile-validation-harness.sh

evidence-smoke:
	@./maintenance/extract-evidence.sh 2>/dev/null || echo "Evidence smoke (sample run)"
	@ls -l logs/evidence-bundle-*.json 2>/dev/null | tail -3 || true

# SN-EC-2 / Fusion Surplus — eye-comfort pure Python gates (hard fail)
eye-comfort-test:
	@cd modules/productivity/eye-comfort && PYTHONPATH=lib python3 lib/test_schedule.py
	@cd modules/productivity/eye-comfort && PYTHONPATH=lib python3 lib/test_tamil_schedule.py

eye-comfort-generate-check:
	@cd modules/productivity/eye-comfort && PYTHONPATH=lib python3 lib/generate_packages.py --check

# Ratatui control plane (main entry / loop) — binary: archy
archy:
	cargo build --manifest-path crates/archy/Cargo.toml

archy-release:
	cargo build --release --manifest-path crates/archy/Cargo.toml
	@echo "binary: crates/archy/target/release/archy"
	@echo "run:    ./crates/archy/target/release/archy"
	@echo "or:     tinfoil tui  (after install to PATH or from repo with binary present)"

# Ratatui control plane unit tests (TEA, Grok preload, audit dry-run smoke)
archy-test:
	cargo test --manifest-path crates/archy/Cargo.toml

# XChat DM remote control — Rust satellite (tools/xchat-remote, binary: groxy)
groxy-test xchat-remote-test:
	cargo test --manifest-path tools/xchat-remote/Cargo.toml

# Python v1 reference suite (optional)
groxy-python-test:
	python3 tools/groxy/tests/test_groxy.py

ci-help:
	@echo "make lint | validate-profiles | evidence-smoke | eye-comfort-test | eye-comfort-generate-check | archy | archy-test | keeper-test | groxy-test"

# Keeper threshold vault tests (also intended for CI — see PR #28 if workflow scope blocks push)
.PHONY: keeper-test
keeper-test:
	cargo test --manifest-path modules/security/keeper/Cargo.toml
