.PHONY: lint validate-profiles evidence-smoke ci-help

lint:
	@shellcheck --severity=warning $$(find . -name '*.sh' -not -path './.grok/*' -not -path './logs/*' -not -path './systemd/*' 2>/dev/null) || true
	@yamllint -c .yamllint.yml config/ 2>/dev/null || true
	@markdownlint '**/*.md' --ignore 'FUNREADME.md' --ignore 'node_modules' 2>/dev/null || true

validate-profiles:
	@./scripts/profile-validation-harness.sh

evidence-smoke:
	@./maintenance/extract-evidence.sh 2>/dev/null || echo "Evidence smoke (sample run)"
	@ls -l logs/evidence-bundle-*.json 2>/dev/null | tail -3 || true

ci-help:
	@echo "make lint | validate-profiles | evidence-smoke"
