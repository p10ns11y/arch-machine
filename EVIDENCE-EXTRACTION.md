# AI Evidence Extraction System

> **Soft redirect.** Prefer [docs/MAINTENANCE.md](docs/MAINTENANCE.md) (Evidence Extraction) + ontology `evidence`.  
> Soft-obsolete: [arch-design/soft-obsolete-candidates.md](arch-design/soft-obsolete-candidates.md) (SO-12).

This system extracts high-signal evidence from maintenance logs for AI agent consumption, providing token-efficient insights instead of verbose raw logs.

## Overview

The evidence extraction system processes maintenance logs to create compact, structured evidence bundles containing:
- **Security audit results**: Status, metrics, blockers, vulnerabilities
- **Installation issues**: Errors, warnings, tool failures
- **System health**: Update status, service issues, configuration problems

## Key Benefits

- **97% size reduction**: 371K installer.log → 9.4K evidence bundle
- **27% additional compression**: TOON format reduces JSON by ~27%
- **High-signal content**: Focuses on actionable information (errors, blockers, metrics)
- **Structured format**: JSON/TOON for easy AI processing

## Usage

### Automatic Extraction
Evidence bundles are automatically generated after:
- Security audits (`maintenance/security-audit.sh`)
- Weekly maintenance (`maintenance/weekly-check.sh`)

### Manual Extraction
```bash
# Extract evidence from latest logs
./maintenance/extract-evidence.sh

# Extract to custom location
./maintenance/extract-evidence.sh -o /path/to/output

# Dry run
./maintenance/extract-evidence.sh --dry-run
```

## Output Files

- `logs/evidence-bundle-YYYYMMDD-HHMMSS.json` - Main evidence bundle
- `logs/evidence-bundle-YYYYMMDD-HHMMSS.toon` - TOON-compressed version (if available)

## Evidence Structure

```json
{
  "timestamp": "2026-04-16T10:07:48Z",
  "hostname": "mzapan",
  "evidence": {
    "security": {
      "status": "completed",
      "critical_issues": 0,
      "user_accounts": {"total": 30, "unlocked": 2},
      "blockers": ["sudo_required"]
    },
    "installer": {
      "errors": [{"timestamp": "...", "message": "...", "category": "error"}],
      "warnings": [{"timestamp": "...", "message": "...", "category": "warning"}],
      "total_unique": 83
    },
    "updates": {
      "system_packages": 0,
      "security_updates": 0,
      "summary": {...}
    }
  },
  "summary": {
    "critical_issues": 0,
    "errors_count": 33,
    "warnings_count": 50,
    "total_issues": 83,
    "blockers": ["sudo_required"]
  }
}
```

## Components

- **`lib/evidence.sh`**: Core extraction functions
- **`maintenance/extract-evidence.sh`**: Runner script
- **Vector integration**: Optional log parsing pipeline
- **TOON compression**: Optional token optimization

## For AI Agents

Evidence bundles provide:
- **Actionable insights**: What needs attention
- **Blocker identification**: Why things failed
- **Status summaries**: System health at a glance
- **Change tracking**: Compare bundles over time

Use the evidence bundles instead of raw logs to minimize token consumption while maintaining full situational awareness.
## Surface Integration

Prefer **archy** evidence menu / `./maintenance/extract-evidence.sh` (see `docs/MAINTENANCE.md`).

Gum `lib/tui/` still has an extract/browse path (frozen, SO-1). Do not treat `tinfoil tui` as day-1.
