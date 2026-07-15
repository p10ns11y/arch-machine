#!/usr/bin/env python3
"""Assert eye-comfort theme vs TN timers stay mutually exclusive.

Drives shipped unit files and install.sh on disk — not a string reimplementation
of the policy. Fails if Conflicts= peer links or dual-flag gate regress.
"""
from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path

MODULE = Path(__file__).resolve().parent.parent
UNITS = MODULE / "units"
INSTALL = MODULE / "install.sh"

THEME_TIMER = UNITS / "eye-comfort-theme.timer"
TN_TIMER = UNITS / "eye-comfort-tn.timer"
THEME_SVC = UNITS / "eye-comfort-theme.service"
TN_SVC = UNITS / "eye-comfort-tn.service"


def _unit_text(path: Path) -> str:
    assert path.is_file(), f"missing shipped unit: {path}"
    return path.read_text(encoding="utf-8")


def _conflicts_line(text: str) -> list[str]:
    m = re.search(r"(?m)^Conflicts=(.+)$", text)
    if not m:
        return []
    return m.group(1).split()


def test_timer_units_conflict_each_other():
    theme = _unit_text(THEME_TIMER)
    tn = _unit_text(TN_TIMER)
    t_conf = _conflicts_line(theme)
    n_conf = _conflicts_line(tn)
    assert "eye-comfort-tn.timer" in t_conf, (
        f"{THEME_TIMER.name} must Conflicts=eye-comfort-tn.timer, got {t_conf}"
    )
    assert "eye-comfort-theme.timer" in n_conf, (
        f"{TN_TIMER.name} must Conflicts=eye-comfort-theme.timer, got {n_conf}"
    )


def test_service_units_conflict_each_other():
    theme = _unit_text(THEME_SVC)
    tn = _unit_text(TN_SVC)
    assert "eye-comfort-tn.service" in _conflicts_line(theme)
    assert "eye-comfort-theme.service" in _conflicts_line(tn)


def test_install_rejects_dual_timer_flags():
    """Real entrypoint: install.sh must exit non-zero with both flags."""
    assert INSTALL.is_file(), f"missing {INSTALL}"
    proc = subprocess.run(
        [str(INSTALL), "--with-timer", "--with-tn-timer", "--dry-run"],
        capture_output=True,
        text=True,
        check=False,
    )
    out = (proc.stdout or "") + (proc.stderr or "")
    assert proc.returncode != 0, (
        f"dual flags must fail, got exit 0:\n{out}"
    )
    assert re.search(r"mutually exclusive", out, re.I), (
        f"expected mutual exclusion error message, got:\n{out}"
    )
    # Must not claim both timers enabled
    assert not re.search(
        r"circadian timer enabled.*tn timer enabled|tn timer enabled.*circadian timer enabled",
        out,
        re.I | re.S,
    )


def main() -> int:
    tests = [
        test_timer_units_conflict_each_other,
        test_service_units_conflict_each_other,
        test_install_rejects_dual_timer_flags,
    ]
    failed = 0
    for t in tests:
        try:
            t()
            print(f"ok  {t.__name__}")
        except AssertionError as e:
            failed += 1
            print(f"FAIL {t.__name__}: {e}", file=sys.stderr)
    if failed:
        print(f"{failed} failed", file=sys.stderr)
        return 1
    print(f"{len(tests)} passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
