#!/bin/bash
# =============================================================================
# SECURITY AUDIT WORKFLOW (Complete & Clean Flow)
# =============================================================================
# - Works identically on your local Linux/macOS machine AND in any CI/CD pipeline
# - Uses live internet checks every run (fresh vuln DBs from OSV, NVD, GitHub Advisories, etc.)
# - Covers: Node.js/npm • Python/PyPI • Rust/crates • Full Linux host/system hardening
# - Generates CycloneDX SBOM + scans it with Grype
# - Lynis full system audit (Hardening Index + detailed report)
# - Fail-safe by default (continues on warnings; customize --fail-on to make strict)
#
# Usage:
#   chmod +x security-scan.sh
#   ./security-scan.sh
#
# Author: Grok (April 2026) – tailored for your Node/Python/Rust + Linux focus
# =============================================================================

set -euo pipefail

echo "🚀 Starting Complete Security Audit Workflow"
echo "   (live vuln checks • SBOM • Lynis • multi-language)"
echo "========================================================================"

# ----------------------------------------------------------------------------
# 1. NATIVE ECOSYSTEM AUDITS (fast, official tools – live checks)
# ----------------------------------------------------------------------------
echo "🔍 [1/5] Native ecosystem audits (Node / Python / Rust)..."

if [ -f "package.json" ] || [ -f "package-lock.json" ] || [ -f "yarn.lock" ] || [ -f "pnpm-lock.yaml" ]; then
    echo "   → Node.js / npm audit (live)"
    npm ci --ignore-scripts --no-audit --prefer-offline >/dev/null 2>&1 || true
    npm audit --audit-level=moderate
else
    echo "   → No Node.js project detected (skipped)"
fi

if [ -f "requirements.txt" ] || [ -f "pyproject.toml" ] || [ -f "Pipfile" ] || [ -f "poetry.lock" ]; then
    echo "   → Python / pip-audit (live)"
    python -m pip install --upgrade pip-audit --quiet || true
    pip-audit --strict --desc on --vulnerability-db https://osv.dev/vuln
else
    echo "   → No Python project detected (skipped)"
fi

if [ -f "Cargo.toml" ] || [ -f "Cargo.lock" ]; then
    echo "   → Rust / cargo audit (live)"
    rustup component add clippy >/dev/null 2>&1 || true
    cargo install cargo-audit --quiet --locked || true
    cargo audit --db https://github.com/RustSec/advisory-db.git
else
    echo "   → No Rust project detected (skipped)"
fi

# ----------------------------------------------------------------------------
# 2. OSV-SCANNER (Google) – universal lockfile scanner (live)
# ----------------------------------------------------------------------------
echo "🔍 [2/5] OSV-Scanner – multi-language lockfile scan (Node/Python/Rust/Go/etc.)..."
osv-scanner scan --format table .

# ----------------------------------------------------------------------------
# 3. SYFT SBOM GENERATION + GRYPE SCAN
# ----------------------------------------------------------------------------
echo "🔍 [3/5] Syft SBOM generation (CycloneDX JSON) + Grype scan..."
echo "   → Generating SBOM for entire project..."
syft . -o cyclonedx-json > sbom.cdx.json
echo "   ✅ SBOM saved → sbom.cdx.json"

echo "   → Scanning SBOM with Grype (live vuln DB)..."
grype sbom:./sbom.cdx.json --fail-on high --only-fixed || echo "   ⚠️  High/critical issues found in SBOM (review above)"

# Optional: extra filesystem scan (uncomment if you want deeper coverage)
# echo "   → Extra Grype filesystem scan..."
# grype . --fail-on high --only-fixed || echo "   ⚠️  Filesystem issues found"

# ----------------------------------------------------------------------------
# 4. LYNIS LINUX SYSTEM/HOST AUDIT (full hardening check)
# ----------------------------------------------------------------------------
echo "🔍 [4/5] Lynis full Linux system/host security audit..."
echo "   → Running Lynis (requires sudo for complete visibility)..."
sudo lynis audit system --quiet --logfile /tmp/lynis-audit.log --report-file /tmp/lynis-report.dat || true

# Show summary (last 60 lines + Hardening Index)
echo "   📋 Lynis summary (Hardening Index + key findings):"
tail -n 60 /tmp/lynis-audit.log | grep -E "(Hardening index|Warning|Suggestion|Action|Security)" || true
echo "   ✅ Full Lynis report saved → /tmp/lynis-audit.log"
echo "      (copy to /var/log/lynis-report.dat for persistence)"

# ----------------------------------------------------------------------------
# 5. FINAL SUMMARY & ARTIFACTS
# ----------------------------------------------------------------------------
echo "========================================================================"
echo "✅ COMPLETE SECURITY AUDIT FINISHED"
echo ""
echo "📦 Artifacts created:"
echo "   • sbom.cdx.json          → CycloneDX SBOM (use with Dependency-Track, etc.)"
echo "   • /tmp/lynis-audit.log   → Full Lynis system hardening report"
echo ""
echo "🔗 Next steps (recommended):"
echo "   1. Review any HIGH/CRITICAL findings above"
echo "   2. Run 'grype sbom:./sbom.cdx.json' again for details"
echo "   3. Commit sbom.cdx.json or upload to a central SBOM store"
echo "   4. Aim for Lynis Hardening Index ≥ 75"
echo ""
echo "This workflow is identical in CI/CD - just drop security-scan.sh into your pipeline!"
echo "========================================================================"