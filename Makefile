.PHONY: lint validate-profiles evidence-smoke eye-comfort-test eye-comfort-generate-check ci-help archy archy-release

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

ci-help:
	@echo "make lint | validate-profiles | evidence-smoke | eye-comfort-test | eye-comfort-generate-check | archy"

# Keeper threshold vault tests (also intended for CI — see PR #28 if workflow scope blocks push)
.PHONY: keeper-test
keeper-test:
	cargo test --manifest-path modules/security/keeper/Cargo.toml
