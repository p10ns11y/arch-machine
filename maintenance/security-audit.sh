#!/usr/bin/env bash
# Threat-focused security audit for archy / tinfoil.
#
# Default path (quiet): short plain findings for four threat areas + compact SUMMARY.
# Full tool chatter → report file. Use --verbose for install chatter / ClamAV / tool how-tos.
#
# Threat areas (criterion 2):
#   malware  — rootkits / trojan-style host indicators (rkhunter, unhide; clam optional)
#   ports    — listening / open network exposure
#   supply   — pacman + npm/node_modules (IDE-adjacent) + osv/grype when present
#   config   — weak setup (Lynis summary, sensitive perms, unlocked/no-password users)
#
# Exit policy (matches print_summary + --help):
#   0  clean — no FAIL and no WARN (skips are ok)
#   1  one or more WARN findings, no FAIL
#   2  one or more FAIL findings (malware hit, critical lynis, infected files, etc.)
#
# Non-interactive: never prompts (archy jobs use null stdin).
# TOOL REFERENCE: lynis, rkhunter, unhide, clamav (verbose), osv-scanner, grype, syft, npm/pnpm audit

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../" && pwd)"

get_logs_dir() {
    if [[ "$ROOT_DIR" == "/usr/share/tinfoil" || "$ROOT_DIR" == /usr/share/tinfoil* ]]; then
        local data_home="${XDG_DATA_HOME:-$HOME/.local/share}"
        echo "$data_home/tinfoil/logs"
    else
        echo "$ROOT_DIR/logs"
    fi
}

LOGS_DIR="$(get_logs_dir)"
REPORTS_DIR="$LOGS_DIR/security-reports"
LIB_DIR="$ROOT_DIR/lib"

if [[ -f "$LIB_DIR/logger.sh" ]]; then
    # shellcheck source=/dev/null
    source "$LIB_DIR/logger.sh"
else
    echo "ERROR: Logger library not found: $LIB_DIR/logger.sh" >&2
    exit 1
fi

# Quiet default: suppress logger emoji sections for console; still use log for file if set.
AUDIT_MODE="global"
AUDIT_TARGET=""
AUDIT_VERBOSE=false
DRY_RUN="${DRY_RUN:-false}"

COUNT_OK=0
COUNT_WARN=0
COUNT_FAIL=0
COUNT_SKIP=0

# Per-area status: ok | warn | fail | skip
STATUS_MALWARE="skip"
STATUS_PORTS="skip"
STATUS_SUPPLY="skip"
STATUS_CONFIG="skip"

command_exists() { command -v "$1" >/dev/null 2>&1; }

check_sudo() { timeout 3 sudo -n true 2>/dev/null; }

choose_report_path() {
    if [[ -n "${TINFOIL_TARGET_DIR:-}" && -d "$TINFOIL_TARGET_DIR" ]]; then
        echo "$TINFOIL_TARGET_DIR/security-audit-$(date +%Y%m%d-%H%M%S).txt"
    elif [[ "$AUDIT_MODE" == "project" && -n "$AUDIT_TARGET" && -d "$AUDIT_TARGET" ]]; then
        local proj
        proj=$(cd "$AUDIT_TARGET" && pwd)
        echo "$proj/security-audit-$(date +%Y%m%d-%H%M%S).txt"
    else
        mkdir -p "$REPORTS_DIR"
        echo "$REPORTS_DIR/security-audit-$(date +%Y%m%d-%H%M%S).txt"
    fi
}

parse_audit_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --global) AUDIT_MODE="global"; shift ;;
            --project)
                AUDIT_MODE="project"
                if [[ $# -gt 1 && ! "$2" =~ ^-- ]]; then
                    AUDIT_TARGET="$2"
                    shift 2
                else
                    AUDIT_TARGET="."
                    shift
                fi
                ;;
            --verbose|-v) AUDIT_VERBOSE=true; shift ;;
            --dry-run) DRY_RUN=true; shift ;;
            -h|--help)
                cat <<'EOF'
security-audit.sh — threat-focused host audit (archy-friendly)

  --global          Full machine audit (default)
  --project [dir]   Project-scoped supply-chain focus
  --verbose, -v     Extra scans (ClamAV quick), tool install hints, raw tool tails
  --dry-run         Print planned checks only

Threat areas: malware | ports | supply | config
Exit: 0=clean (no warn/fail; skips ok), 1=warn only, 2=fail
EOF
                exit 0
                ;;
            *) shift ;;
        esac
    done
}

parse_audit_args "$@"
SECURITY_REPORT="$(choose_report_path)"
: >"$SECURITY_REPORT"

report() {
    echo "$*" >>"$SECURITY_REPORT"
}

# --- console emission (archy-readable, no emoji) ---

emit() {
    # emit LEVEL AREA message
    local level="$1" area="$2" msg="$3"
    local tag
    case "$level" in
        ok)   tag="ok";   COUNT_OK=$((COUNT_OK + 1)) ;;
        warn) tag="!";    COUNT_WARN=$((COUNT_WARN + 1)) ;;
        fail) tag="x";    COUNT_FAIL=$((COUNT_FAIL + 1)) ;;
        skip) tag="·";    COUNT_SKIP=$((COUNT_SKIP + 1)) ;;
        info) tag="·"; ;;
        *)    tag="·"; ;;
    esac
    printf '[%s] %-8s %s\n' "$tag" "$area" "$msg"
    report "[$level] [$area] $msg"
}

set_area_status() {
    # set_area_status AREA level  (worst wins: fail > warn > ok > skip)
    local area="$1" level="$2" var
    case "$area" in
        malware) var=STATUS_MALWARE ;;
        ports)   var=STATUS_PORTS ;;
        supply)  var=STATUS_SUPPLY ;;
        config)  var=STATUS_CONFIG ;;
        *) return ;;
    esac
    local cur="${!var}"
    local rank_cur=0 rank_new=0
    case "$cur" in skip) rank_cur=0 ;; ok) rank_cur=1 ;; warn) rank_cur=2 ;; fail) rank_cur=3 ;; esac
    case "$level" in skip) rank_new=0 ;; ok) rank_new=1 ;; warn) rank_new=2 ;; fail) rank_new=3 ;; esac
    if [[ "$rank_new" -gt "$rank_cur" ]]; then
        printf -v "$var" '%s' "$level"
    fi
}

header() {
    echo "tinfoil audit  mode=$AUDIT_MODE  host=$(hostname)  user=$(whoami)"
    echo "report: $SECURITY_REPORT"
    if [[ "$DRY_RUN" == "true" ]]; then
        echo "mode: DRY-RUN (no scanners executed)"
    fi
    echo ""
}

# ─── MALWARE / ROOTKIT ───────────────────────────────────────────

scan_malware() {
    echo "## malware"
    report ""
    report "=== malware ==="

    if [[ "$DRY_RUN" == "true" ]]; then
        emit skip malware "dry-run: would run rkhunter/unhide"
        set_area_status malware skip
        return
    fi

    local any=false hit=false

    if command_exists rkhunter; then
        any=true
        if check_sudo; then
            timeout 15 sudo rkhunter --update >/dev/null 2>&1 || true
            local out
            out=$(timeout 90 sudo rkhunter --check --sk --nocolors --quiet 2>&1 || true)
            report "$out"
            if echo "$out" | grep -qiE 'Rootkit|Warning:|Possible rootkit'; then
                local n
                n=$(echo "$out" | grep -ciE 'Rootkit|Warning:' || true)
                emit fail malware "rkhunter: $n warning(s) — see report"
                set_area_status malware fail
                hit=true
            else
                emit ok malware "rkhunter: no rootkit indicators"
                set_area_status malware ok
            fi
        else
            emit skip malware "rkhunter: needs passwordless sudo (sudo -n)"
            set_area_status malware skip
        fi
    else
        emit skip malware "rkhunter not installed"
    fi

    if command_exists unhide; then
        any=true
        if check_sudo; then
            local uout
            uout=$(timeout 30 sudo unhide proc 2>&1 || true)
            report "$uout"
            if echo "$uout" | grep -qiE 'Found HIDDEN|WARNING|suspicious'; then
                emit fail malware "unhide: hidden process indicators"
                set_area_status malware fail
                hit=true
            else
                emit ok malware "unhide: no hidden process hits"
                set_area_status malware ok
            fi
        else
            emit skip malware "unhide: needs passwordless sudo"
            set_area_status malware skip
        fi
    else
        emit skip malware "unhide not installed"
    fi

    # ClamAV only verbose (slow)
    if [[ "$AUDIT_VERBOSE" == "true" ]] && command_exists clamscan; then
        any=true
        if check_sudo; then
            timeout 20 sudo freshclam --quiet 2>/dev/null || true
            local cout
            cout=$(timeout 120 sudo clamscan -r --bell=no --max-filesize=10M --max-scansize=50M \
                --exclude-dir='^/proc' --exclude-dir='^/sys' --exclude-dir='^/dev' \
                /usr/bin /usr/sbin /tmp "$HOME/Downloads" 2>&1 || true)
            report "$cout"
            local infected
            infected=$(echo "$cout" | grep -c 'FOUND' || true)
            if [[ "${infected:-0}" -gt 0 ]]; then
                emit fail malware "clamav: $infected infection hit(s)"
                set_area_status malware fail
                hit=true
            else
                emit ok malware "clamav quick paths: clean"
                set_area_status malware ok
            fi
        else
            emit skip malware "clamav: needs sudo"
        fi
    elif [[ "$AUDIT_VERBOSE" != "true" ]]; then
        emit info malware "clamav full/quick path: verbose only (--verbose)"
    fi

    if [[ "$any" == "false" ]]; then
        emit skip malware "no rootkit tools (install: pacman -S rkhunter unhide)"
        set_area_status malware skip
    elif [[ "$hit" == "false" && "$STATUS_MALWARE" != "skip" && "$STATUS_MALWARE" != "fail" ]]; then
        set_area_status malware ok
    fi
    echo ""
}

# ─── PORTS / LISTENING ───────────────────────────────────────────

scan_ports() {
    echo "## ports"
    report ""
    report "=== ports ==="

    if [[ "$DRY_RUN" == "true" ]]; then
        emit skip ports "dry-run: would list listening sockets"
        set_area_status ports skip
        return
    fi

    if ! command_exists ss; then
        emit skip ports "ss not available"
        set_area_status ports skip
        echo ""
        return
    fi

    local listen_lines
    listen_lines=$(ss -H -tuln 2>/dev/null || true)
    local count
    count=$(printf '%s\n' "$listen_lines" | grep -c . || true)
    report "$listen_lines"

    # Show compact unique local addresses (max 12)
    local shown=0
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        local addr
        addr=$(echo "$line" | awk '{print $5}')
        emit info ports "listen $addr"
        shown=$((shown + 1))
        [[ "$shown" -ge 12 ]] && break
    done <<<"$listen_lines"

    if [[ "${count:-0}" -gt 12 ]]; then
        emit info ports "... $((count - 12)) more listeners (see report)"
    fi

    # Suspicious / classic backdoor-ish ports
    local bad_ports=(ACCT-000033 12345 4444 5555 6666 6667 31337)
    local found_bad=()
    local p
    for p in "${bad_ports[@]}"; do
        if ss -H -tuln 2>/dev/null | grep -qE ":${p}\\b"; then
            found_bad+=("$p")
        fi
    done

    if [[ ${#found_bad[@]} -gt 0 ]]; then
        emit fail ports "suspicious listen port(s): ${found_bad[*]}"
        set_area_status ports fail
    else
        emit ok ports "no classic backdoor ports among ${count:-0} listeners"
        set_area_status ports ok
    fi

    # World-facing high ports (skip noisy mDNS/DHCP which are common on laptops)
    local public_high
    public_high=$(ss -H -tuln 2>/dev/null | awk '
      $5 ~ /0\.0\.0\.0:[0-9]+/ || $5 ~ /\*:[0-9]+/ {
        n=split($5,a,":"); port=a[n]+0
        if (port>=1024 && port!=22 && port!=5353 && port!=67 && port!=68) print port
      }' | sort -nu | head -8 | tr '\n' ' ')
    if [[ -n "${public_high// }" ]]; then
        emit warn ports "public high ports: $public_high"
        set_area_status ports warn
    else
        emit ok ports "no unexpected public high ports (mDNS/dhcp ignored)"
        set_area_status ports ok
    fi
    echo ""
}

# ─── SUPPLY CHAIN ────────────────────────────────────────────────

scan_supply_pacman() {
    if ! command_exists pacman; then
        emit skip supply "pacman not available"
        return
    fi
    if command_exists arch-audit; then
        local aout
        aout=$(timeout 60 arch-audit -u 2>&1 || true)
        report "$aout"
        local n
        n=$(echo "$aout" | grep -cE 'Vulnerable|is affected' || true)
        if [[ "${n:-0}" -gt 0 ]]; then
            emit warn supply "arch-audit: $n vulnerable package line(s)"
            set_area_status supply warn
            echo "$aout" | head -8 | while read -r l; do
                [[ -n "$l" ]] && emit info supply "  $l"
            done
        else
            emit ok supply "arch-audit: no known vulnerable packages"
            set_area_status supply ok
        fi
    else
        # Lightweight: count packages + flag if checkupdates has security-ish names
        local n_explicit
        n_explicit=$(pacman -Qqe 2>/dev/null | wc -l | tr -d ' ')
        emit ok supply "pacman: $n_explicit explicit packages (install arch-audit for CVE map)"
        set_area_status supply ok
        if command_exists checkupdates; then
            local ups
            ups=$(timeout 30 checkupdates 2>/dev/null | wc -l | tr -d ' ' || echo 0)
            if [[ "${ups:-0}" -gt 0 ]]; then
                emit warn supply "pacman: $ups pending updates (apply when ready)"
                set_area_status supply warn
            fi
        fi
    fi
}

scan_supply_node() {
    # Bound search: project target + common IDE / agent tool trees (not full-disk).
    local roots=()
    if [[ "$AUDIT_MODE" == "project" && -n "$AUDIT_TARGET" ]]; then
        roots+=("$AUDIT_TARGET")
    else
        roots+=("$ROOT_DIR" "$PWD")
        [[ -d "$HOME/.vscode" ]] && roots+=("$HOME/.vscode")
        [[ -d "$HOME/.vscode-server" ]] && roots+=("$HOME/.vscode-server")
        [[ -d "$HOME/.cursor" ]] && roots+=("$HOME/.cursor")
        [[ -d "$HOME/.config/Cursor" ]] && roots+=("$HOME/.config/Cursor")
        [[ -d "$HOME/.config/Code" ]] && roots+=("$HOME/.config/Code")
        [[ -d "$HOME/.local/share/code-server" ]] && roots+=("$HOME/.local/share/code-server")
        [[ -d "$HOME/.npm" ]] && roots+=("$HOME/.npm")
    fi

    local nm_hits=0
    local r nm
    for r in "${roots[@]}"; do
        [[ -d "$r" ]] || continue
        while IFS= read -r nm; do
            [[ -z "$nm" ]] && continue
            nm_hits=$((nm_hits + 1))
            report "node_modules: $nm"
            local dir
            dir=$(dirname "$nm")
            if [[ -f "$dir/package.json" ]] && command_exists npm; then
                local aout
                aout=$(timeout 90 bash -c "cd \"$dir\" && npm audit --audit-level=high --json 2>/dev/null" || true)
                report "npm audit $dir"
                report "$aout"
                if echo "$aout" | grep -qE '"high":[1-9]|"critical":[1-9]'; then
                    emit warn supply "npm high/critical vulns under $dir"
                    set_area_status supply warn
                fi
            fi
            [[ "$nm_hits" -ge 6 ]] && break
        done < <(find "$r" -maxdepth 5 -type d -name node_modules 2>/dev/null | head -n 8)
        [[ "$nm_hits" -ge 6 ]] && break
    done

    if [[ "$nm_hits" -eq 0 ]]; then
        emit ok supply "node_modules: none in bounded IDE/project paths"
        set_area_status supply ok
    else
        emit info supply "node_modules trees scanned (bounded): $nm_hits"
        set_area_status supply ok
    fi
}

scan_supply_osv_grype() {
    local target="."
    [[ "$AUDIT_MODE" == "project" && -n "$AUDIT_TARGET" ]] && target="$AUDIT_TARGET"

    if command_exists osv-scanner; then
        local oout
        oout=$(timeout 120 osv-scanner scan source -r "$target" \
            --experimental-exclude node_modules \
            --experimental-exclude .git \
            --verbosity error \
            --format table 2>&1 || true)
        report "$oout"
        if echo "$oout" | grep -qiE 'vulnerabilit|CVE-|GHSA-'; then
            local n
            n=$(echo "$oout" | grep -ciE 'CVE-|GHSA-|vulnerabilit' || true)
            emit warn supply "osv-scanner: $n vuln-related line(s) under $target"
            set_area_status supply warn
        else
            emit ok supply "osv-scanner: no issues (or empty tree) under $target"
            set_area_status supply ok
        fi
    else
        emit skip supply "osv-scanner not installed"
    fi

    if [[ "$AUDIT_VERBOSE" == "true" ]] && command_exists grype && command_exists syft; then
        local sbom="$LOGS_DIR/audit-sbom-$$.cdx.json"
        mkdir -p "$LOGS_DIR"
        if timeout 90 syft "$target" --exclude '**/node_modules/**' --exclude '**/.git/**' \
            -o cyclonedx-json >"$sbom" 2>/dev/null; then
            local gout
            gout=$(timeout 90 grype "sbom:$sbom" --fail-on high 2>&1 || true)
            report "$gout"
            if echo "$gout" | grep -qiE 'Critical|High'; then
                emit warn supply "grype: high/critical in SBOM of $target"
                set_area_status supply warn
            else
                emit ok supply "grype: no high/critical in SBOM"
                set_area_status supply ok
            fi
            rm -f "$sbom"
        fi
    fi
}

scan_supply() {
    echo "## supply"
    report ""
    report "=== supply ==="

    if [[ "$DRY_RUN" == "true" ]]; then
        emit skip supply "dry-run: would scan pacman + node + osv"
        set_area_status supply skip
        echo ""
        return
    fi

    if [[ "$AUDIT_MODE" == "global" ]]; then
        scan_supply_pacman
    fi
    scan_supply_node
    scan_supply_osv_grype
    echo ""
}

# ─── WEAK CONFIG ─────────────────────────────────────────────────

scan_config_lynis() {
    if ! command_exists lynis; then
        emit skip config "lynis not installed"
        return
    fi
    if ! check_sudo; then
        emit skip config "lynis: needs passwordless sudo"
        return
    fi
    local lrep="$REPORTS_DIR/lynis-report-$(date +%Y%m%d).txt"
    mkdir -p "$REPORTS_DIR"
    timeout 120 sudo lynis audit system --quiet --report-file "$lrep" >/dev/null 2>&1 || true
    report "lynis report: $lrep"
    local warnings=0 suggestions=0 critical=0
    if [[ -f "$lrep" ]]; then
        warnings=$(grep -c "Warning" "$lrep" 2>/dev/null || echo 0)
        suggestions=$(grep -c "Suggestion" "$lrep" 2>/dev/null || echo 0)
        critical=$(grep -c "Critical" "$lrep" 2>/dev/null || echo 0)
        warnings=${warnings//[^0-9]/}
        suggestions=${suggestions//[^0-9]/}
        critical=${critical//[^0-9]/}
        report "$(grep -E 'Warning|Critical' "$lrep" | head -20 || true)"
    fi
    if [[ "${critical:-0}" -gt 0 ]]; then
        emit fail config "lynis: $critical critical, $warnings warn, $suggestions suggest — $lrep"
        set_area_status config fail
    elif [[ "${warnings:-0}" -gt 0 ]]; then
        emit warn config "lynis: $warnings warnings, $suggestions suggestions — $lrep"
        set_area_status config warn
    else
        emit ok config "lynis: no critical/warning ($suggestions suggestions) — $lrep"
        set_area_status config ok
    fi
}

scan_config_perms() {
    local issues=0
    # sshd_config is commonly 644 on Arch; only flag private key material + shadow.
    local pairs=(
        "/etc/passwd:644"
        "/etc/shadow:600"
        "$HOME/.ssh/id_rsa:600"
        "$HOME/.ssh/id_ed25519:600"
        "$HOME/.ssh/id_ecdsa:600"
    )
    local fp expected actual
    for fp in "${pairs[@]}"; do
        local f="${fp%%:*}"
        expected="${fp#*:}"
        [[ -f "$f" ]] || continue
        actual=$(stat -c "%a" "$f" 2>/dev/null || echo "?")
        if [[ "$actual" != "$expected" ]]; then
            emit warn config "perm $f is $actual (want $expected)"
            set_area_status config warn
            issues=$((issues + 1))
        fi
    done
    if [[ "$issues" -eq 0 ]]; then
        emit ok config "sensitive file modes look correct"
        set_area_status config ok
    fi
}

scan_config_users() {
    if check_sudo; then
        local pout
        pout=$(timeout 10 sudo passwd -S -a 2>/dev/null || true)
        report "$pout"
        local np
        np=$(echo "$pout" | awk '$2 == "NP" {c++} END {print c+0}')
        if [[ "${np:-0}" -gt 0 ]]; then
            emit fail config "accounts with no password: $np"
            set_area_status config fail
        else
            emit ok config "no NP (no-password) accounts via passwd -S"
            set_area_status config ok
        fi
    else
        emit skip config "user lock status: needs sudo"
        set_area_status config skip
    fi
}

scan_config() {
    echo "## config"
    report ""
    report "=== config ==="

    if [[ "$DRY_RUN" == "true" ]]; then
        emit skip config "dry-run: would run lynis/perms/users"
        set_area_status config skip
        echo ""
        return
    fi

    if [[ "$AUDIT_MODE" == "global" ]]; then
        scan_config_lynis
        scan_config_perms
        scan_config_users
    else
        emit info config "project mode: host lynis/users skipped"
        scan_config_perms
        set_area_status config ok
    fi
    echo ""
}

# ─── SUMMARY ─────────────────────────────────────────────────────

AUDIT_EXIT=0

print_summary() {
    AUDIT_EXIT=0
    if [[ "$COUNT_FAIL" -gt 0 ]]; then
        AUDIT_EXIT=2
    elif [[ "$COUNT_WARN" -gt 0 ]]; then
        AUDIT_EXIT=1
    fi

    echo "## SUMMARY"
    echo "malware=$STATUS_MALWARE  ports=$STATUS_PORTS  supply=$STATUS_SUPPLY  config=$STATUS_CONFIG"
    echo "counts ok=$COUNT_OK warn=$COUNT_WARN fail=$COUNT_FAIL skip=$COUNT_SKIP"
    echo "exit=$AUDIT_EXIT  (0=clean 1=warn 2=fail)"
    echo "report=$SECURITY_REPORT"
    if [[ "$AUDIT_EXIT" -eq 0 ]]; then
        echo "next: review report if skips; keep weekly audit"
    elif [[ "$AUDIT_EXIT" -eq 1 ]]; then
        echo "next: triage WARN lines; prefer dry-run fixes first"
    else
        echo "next: treat FAIL as priority (malware/ports/config); re-run after fix"
    fi

    report ""
    report "=== SUMMARY ==="
    report "malware=$STATUS_MALWARE ports=$STATUS_PORTS supply=$STATUS_SUPPLY config=$STATUS_CONFIG"
    report "ok=$COUNT_OK warn=$COUNT_WARN fail=$COUNT_FAIL skip=$COUNT_SKIP exit=$AUDIT_EXIT"
}

main() {
    header
    if [[ "$AUDIT_VERBOSE" == "true" ]]; then
        echo "(verbose: clamav path + grype SBOM enabled when tools exist)"
        echo ""
    fi

    scan_malware
    scan_ports
    scan_supply
    scan_config

    # Optional evidence (quiet)
    local evidence_script=""
    if [[ -f "$ROOT_DIR/maintenance/extract-evidence.sh" ]]; then
        evidence_script="$ROOT_DIR/maintenance/extract-evidence.sh"
    fi
    if [[ -n "$evidence_script" && "$DRY_RUN" != "true" ]]; then
        "$evidence_script" >/dev/null 2>&1 || true
    fi

    print_summary
    exit "$AUDIT_EXIT"
}

main "$@"
