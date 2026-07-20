"""Host-side actions invoked by groxy (inventory, audit, grok headless, etc.)."""

from __future__ import annotations

import os
import platform
import shutil
import subprocess
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Sequence


@dataclass
class HostResult:
    ok: bool
    verb: str
    output: str
    exit_code: int
    duration_sec: float
    effect_path: Path | None = None
    command: list[str] | None = None


def repo_root() -> Path:
    env = os.environ.get("GROXY_ROOT") or os.environ.get("TINFOIL_ROOT") or os.environ.get("ARCH_MACHINE_ROOT")
    if env:
        return Path(env).resolve()
    # tools/groxy/host.py → tools/groxy → tools → repo
    return Path(__file__).resolve().parents[2]


def hostname() -> str:
    return platform.node() or "localhost"


def run_cmd(
    argv: Sequence[str],
    *,
    cwd: Path | None = None,
    timeout: float = 120.0,
    env: dict[str, str] | None = None,
) -> tuple[int, str]:
    merged = os.environ.copy()
    if env:
        merged.update(env)
    try:
        proc = subprocess.run(
            list(argv),
            cwd=str(cwd) if cwd else None,
            capture_output=True,
            text=True,
            timeout=timeout,
            env=merged,
            check=False,
        )
        out = (proc.stdout or "") + (("\n" + proc.stderr) if proc.stderr else "")
        return proc.returncode, out.strip()
    except subprocess.TimeoutExpired as e:
        partial = ""
        if e.stdout:
            partial += e.stdout if isinstance(e.stdout, str) else e.stdout.decode("utf-8", "replace")
        if e.stderr:
            partial += "\n" + (e.stderr if isinstance(e.stderr, str) else e.stderr.decode("utf-8", "replace"))
        return 124, (partial + f"\n(timeout after {timeout}s)").strip()
    except FileNotFoundError:
        return 127, f"command not found: {argv[0]}"


def write_effect_log(out_dir: Path, name: str, content: str) -> Path:
    out_dir.mkdir(parents=True, exist_ok=True)
    path = out_dir / name
    path.write_text(content, encoding="utf-8")
    return path


def action_ping(effect_dir: Path) -> HostResult:
    t0 = time.monotonic()
    # Operator-facing outcome only (no host/cwd in DM path)
    msg = "Reachable — ready for next command"
    path = write_effect_log(effect_dir, "host-effect-ping.txt", msg + "\n")
    return HostResult(
        ok=True,
        verb="ping",
        output=msg,
        exit_code=0,
        duration_sec=time.monotonic() - t0,
        effect_path=path,
        command=["ping-internal"],
    )


def action_help() -> HostResult:
    text = """Commands:
• help — this list
• ping — liveness
• status / inventory — package snapshot summary
• audit — security audit
• omarchy — omarchy status
• run <prompt> — restricted grok task
• confirm <token> … — approve high-blast
Prefix optional: !g …
"""
    return HostResult(ok=True, verb="help", output=text.strip(), exit_code=0, duration_sec=0.0)


def action_inventory(effect_dir: Path, *, text_only: bool = True) -> HostResult:
    root = repo_root()
    script = root / "maintenance" / "inventory.sh"
    t0 = time.monotonic()
    if not script.is_file():
        msg = f"missing {script}"
        path = write_effect_log(effect_dir, "host-effect-inventory.txt", msg + "\n")
        return HostResult(False, "inventory", msg, 1, time.monotonic() - t0, path, [str(script)])
    argv = [str(script), "--text", "--no-write"] if text_only else [str(script), "--json", "--no-write"]
    code, out = run_cmd(argv, cwd=root, timeout=90)
    path = write_effect_log(effect_dir, "host-effect-inventory.txt", out + "\n")
    return HostResult(
        ok=code == 0,
        verb="inventory" if not text_only else "status",
        output=out or f"(exit {code})",
        exit_code=code,
        duration_sec=time.monotonic() - t0,
        effect_path=path,
        command=argv,
    )


def action_audit(effect_dir: Path) -> HostResult:
    root = repo_root()
    script = root / "maintenance" / "security-audit.sh"
    t0 = time.monotonic()
    if not script.is_file():
        msg = f"missing {script}"
        path = write_effect_log(effect_dir, "host-effect-audit.txt", msg + "\n")
        return HostResult(False, "audit", msg, 1, time.monotonic() - t0, path)
    # Prefer dry-run / sample flags if present; fall back to --help capture as proof of invoke
    code, out = run_cmd([str(script), "--help"], cwd=root, timeout=30)
    # Many audit scripts use --dry-run; try if help mentions it
    if "--dry-run" in out or "dry-run" in out.lower():
        code, out = run_cmd([str(script), "--dry-run"], cwd=root, timeout=180)
    path = write_effect_log(effect_dir, "host-effect-audit.txt", out + "\n")
    return HostResult(
        ok=code == 0,
        verb="audit",
        output=out[:4000] if out else f"(exit {code})",
        exit_code=code,
        duration_sec=time.monotonic() - t0,
        effect_path=path,
        command=[str(script)],
    )


def action_omarchy(effect_dir: Path) -> HostResult:
    root = repo_root()
    script = root / "maintenance" / "omarchy-status.sh"
    t0 = time.monotonic()
    if not script.is_file():
        msg = f"missing {script}"
        path = write_effect_log(effect_dir, "host-effect-omarchy.txt", msg + "\n")
        return HostResult(False, "omarchy", msg, 1, time.monotonic() - t0, path)
    code, out = run_cmd([str(script)], cwd=root, timeout=60)
    path = write_effect_log(effect_dir, "host-effect-omarchy.txt", out + "\n")
    return HostResult(
        ok=code == 0,
        verb="omarchy",
        output=out[:4000] if out else f"(exit {code})",
        exit_code=code,
        duration_sec=time.monotonic() - t0,
        effect_path=path,
        command=[str(script)],
    )


def action_grok_run(prompt: str, effect_dir: Path, *, yolo: bool = False) -> HostResult:
    """Invoke grok headless with a restricted default tool set."""
    t0 = time.monotonic()
    grok = shutil.which("grok")
    if not grok:
        msg = "grok not found on PATH"
        path = write_effect_log(effect_dir, "host-effect-grok.txt", msg + "\n")
        return HostResult(False, "run", msg, 127, time.monotonic() - t0, path)

    root = repo_root()
    argv = [
        grok,
        "-p",
        prompt,
        "--cwd",
        str(root),
        "--output-format",
        "plain",
        "--tools",
        "read_file,grep,list_dir,run_terminal_cmd",
        "--deny",
        "Bash(rm*)",
        "--deny",
        "Bash(sudo*)",
        "--max-turns",
        "8",
    ]
    if yolo:
        argv.append("--yolo")
    code, out = run_cmd(argv, cwd=root, timeout=300)
    path = write_effect_log(effect_dir, "host-effect-grok.txt", out + "\n")
    return HostResult(
        ok=code == 0,
        verb="run",
        output=out[:6000] if out else f"(exit {code})",
        exit_code=code,
        duration_sec=time.monotonic() - t0,
        effect_path=path,
        command=argv,
    )


def dispatch_host_action(
    verb: str,
    args: str,
    effect_dir: Path,
    *,
    confirmed: bool = False,
    allow_yolo: bool = False,
) -> HostResult:
    """Map parsed verb → host work. High-blast without confirm returns blocked result."""
    v = (verb or "").lower()
    a = (args or "").strip()

    if v in ("help",):
        return action_help()
    if v == "ping":
        return action_ping(effect_dir)
    if v == "whoami":
        msg = f"host={hostname()} root={repo_root()} user={os.environ.get('USER', '?')}"
        path = write_effect_log(effect_dir, "host-effect-whoami.txt", msg + "\n")
        return HostResult(True, "whoami", msg, 0, 0.0, path)
    if v in ("status",):
        return action_inventory(effect_dir, text_only=True)
    if v == "inventory":
        return action_inventory(effect_dir, text_only=False)
    if v == "audit":
        return action_audit(effect_dir)
    if v == "omarchy":
        return action_omarchy(effect_dir)
    if v == "run":
        if not a:
            return HostResult(False, "run", "usage: run <prompt>", 2, 0.0)
        return action_grok_run(a, effect_dir, yolo=allow_yolo)

    # High-blast family
    if v in ("pkg", "actuate", "install", "expand", "remediate", "apply", "rm", "delete", "reboot", "shutdown", "yolo"):
        if not confirmed:
            return HostResult(
                False,
                v,
                f"blocked: `{v}` is high-blast; send `confirm <token> {v} {a}` after pending grant",
                403,
                0.0,
            )
        # Even when confirmed, only allow a narrow dry-run maintenance path for pkg/actuate
        if v in ("pkg", "actuate"):
            root = repo_root()
            script = root / "maintenance" / "package-actuate.sh"
            t0 = time.monotonic()
            if script.is_file():
                code, out = run_cmd([str(script), "--dry-run", a] if a else [str(script), "--dry-run"], cwd=root, timeout=120)
                path = write_effect_log(effect_dir, f"host-effect-{v}.txt", out + "\n")
                return HostResult(code == 0, v, out[:4000], code, time.monotonic() - t0, path, [str(script)])
        return HostResult(
            False,
            v,
            f"confirmed but not auto-executed in v1 (manual/archy): {v} {a}".strip(),
            501,
            0.0,
        )

    return HostResult(False, v or "unknown", f"unknown command: {v}", 2, 0.0)
