# Security Policy

The arch-machine project treats security as first-class (see `policies/security-remediation.md`).

## Supported Versions

Only the current `sentinel` branch + latest tagged releases are supported.

## Reporting a Vulnerability

**Please do not open public issues for security vulnerabilities.**

Instead:
1. Use the evidence pipeline: Run `tinfoil` or `maintenance/security-audit.sh` + `extract-evidence.sh`.
2. Open a private security advisory on GitHub, or email the maintainer with the evidence bundle.
3. The project will treat the report using its own ruthless remediation policy (audit → built-in fix → small fix → kill after evidence).

We will acknowledge receipt within 48 hours and aim for resolution or mitigation with an accompanying evidence bundle.

Thank you for helping keep the Guardian strong.
