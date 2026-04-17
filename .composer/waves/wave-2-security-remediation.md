# Wave 2: Security Hardening and Remediation (P1)

## Scope
- Port and verify modern security tooling in the modular flow (`osv-scanner`, `grype`, `syft`, `pip-audit`, `cargo-audit`).
- Apply remediation policy workflow end-to-end: simple fix -> upgrade -> remove, with lock/cache handling.
- Prioritize Python/ML environments first (`ai_amd`, `xai_exp`) for vulnerability remediation.

## Suggested Task Allocation
- Task `P1-4`: security toolchain integration and verification -> `Safinel`
- Task `P1-5`: remediation workflow execution and policy conformance -> `Trusinel`
- Task `P1-6`: Python/ML environment remediation first pass -> `Eusinel`

## Exit Criteria
- Security tooling is integrated and executable in the modular pipeline.
- Remediation policy steps are consistently followed for discovered issues.
- Python/ML remediation backlog is reduced with clear verification evidence.
