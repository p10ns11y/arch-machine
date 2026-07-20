"""groxy CLI — XChat DM remote control for this host."""

from __future__ import annotations

import argparse
import json
import os
import sys
import time
from pathlib import Path

from . import __version__
from .dispatch import process_event, run_once
from .dm_io import DryRunDmIO, XurlDmIO, resolve_xurl
from .host import hostname, repo_root
from .package import build_outbound_package
from .policy import load_policy_file, load_policy_from_env
from .state import default_state_path, load_state, save_state

BANNER = f"""groxy {__version__} — XChat DM remote control for arch-machine hosts
Inbound:  XChat DM (allowlisted) → host action (inventory/audit/grok/…)
Outbound: result summary + visual explanation → XChat DM (or dry-run files)
"""


def _default_config() -> Path:
    return repo_root() / "config" / "groxy" / "allowlist.conf"


def _default_work() -> Path:
    xdg = Path.home() / ".local" / "state" / "groxy"
    return xdg


def _common_flags(p: argparse.ArgumentParser, *, suppress_defaults: bool = False) -> None:
    """
    Shared flags. When attached to subparsers use suppress_defaults=True so a
    value set before the subcommand is not wiped by store_true default=False.
    """
    d = argparse.SUPPRESS if suppress_defaults else None
    p.add_argument(
        "--config",
        type=Path,
        default=d if suppress_defaults else None,
        help="allowlist config path (default: config/groxy/allowlist.conf)",
    )
    p.add_argument(
        "--state",
        type=Path,
        default=d if suppress_defaults else None,
        help="state file for seen DM ids (default: ~/.local/state/groxy/state.json)",
    )
    p.add_argument(
        "--work-dir",
        type=Path,
        default=d if suppress_defaults else None,
        help="working dir for effects + outbound packages",
    )
    p.add_argument(
        "--dry-run",
        action="store_true",
        default=argparse.SUPPRESS if suppress_defaults else False,
        help="do not call live xurl send; write outbound packages to disk",
    )
    p.add_argument(
        "--live",
        action="store_true",
        default=argparse.SUPPRESS if suppress_defaults else False,
        help="send real XChat DMs via xurl (requires auth)",
    )
    p.add_argument(
        "--reply-to",
        default=argparse.SUPPRESS if suppress_defaults else os.environ.get("GROXY_REPLY_TO", ""),
        help="DM recipient username (e.g. Peramanathan) for replies",
    )
    p.add_argument(
        "--allow-id",
        action="append",
        default=argparse.SUPPRESS if suppress_defaults else [],
        help="extra allowlisted sender user id (repeatable)",
    )
    p.add_argument(
        "--allow-user",
        action="append",
        default=argparse.SUPPRESS if suppress_defaults else [],
        help="extra allowlisted username (repeatable)",
    )


def build_parser() -> argparse.ArgumentParser:
    # Root defaults (flags before subcommand)
    root_common = argparse.ArgumentParser(add_help=False)
    _common_flags(root_common, suppress_defaults=False)
    # Subcommand copy uses SUPPRESS so missing flags don't clobber root values
    sub_common = argparse.ArgumentParser(add_help=False)
    _common_flags(sub_common, suppress_defaults=True)

    p = argparse.ArgumentParser(
        prog="groxy",
        description="XChat DM remote control bridge (summary + visual back to chat)",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=BANNER,
        parents=[root_common],
    )
    p.add_argument("--version", action="version", version=f"groxy {__version__}")

    sub = p.add_subparsers(dest="cmd", required=False)

    sub.add_parser("help", help="show help banner", parents=[sub_common])

    once = sub.add_parser("once", help="poll DM events once and process", parents=[sub_common])
    once.add_argument("--fixture", type=Path, help="JSON dm_events fixture (dry-run path)")
    once.add_argument("--max", type=int, default=20, help="max events to fetch")

    poll = sub.add_parser("poll", help="poll DM events in a loop", parents=[sub_common])
    poll.add_argument("--interval", type=float, default=45.0, help="seconds between polls")
    poll.add_argument("--fixture", type=Path, help="JSON fixture (re-read each loop; dry-run)")
    poll.add_argument("--max", type=int, default=20)
    poll.add_argument("--count", type=int, default=0, help="stop after N loops (0=forever)")

    inj = sub.add_parser("inject", help="inject one synthetic DM command (local E2E)", parents=[sub_common])
    inj.add_argument("text", help='command text e.g. "status" or "!g inventory"')
    inj.add_argument("--sender-id", default="295441607", help="synthetic sender id")
    inj.add_argument("--event-id", default=None, help="synthetic event id")

    demo = sub.add_parser(
        "demo-outbound",
        help="build a summary+visual package without inbound (dry-run proof)",
        parents=[sub_common],
    )
    demo.add_argument("--verb", default="status")
    demo.add_argument("--text", default="demo host status: ok")

    return p


def _resolve_policy(args: argparse.Namespace):
    cfg = args.config or _default_config()
    if cfg.is_file():
        policy = load_policy_file(cfg)
    else:
        policy = load_policy_from_env()
    # CLI extras
    ids = set(policy.allowlist_ids) | set(args.allow_id or [])
    users = set(policy.allowlist_usernames) | {u.lstrip("@").lower() for u in (args.allow_user or [])}
    from .policy import Policy

    return Policy(
        allowlist_ids=frozenset(ids),
        allowlist_usernames=frozenset(users),
        require_confirm_high_blast=policy.require_confirm_high_blast,
    )


def _work_paths(args: argparse.Namespace) -> tuple[Path, Path, Path]:
    work = args.work_dir or _default_work()
    effect = work / "effects"
    packages = work / "outbound"
    effect.mkdir(parents=True, exist_ok=True)
    packages.mkdir(parents=True, exist_ok=True)
    return work, effect, packages


def _is_dry(args: argparse.Namespace) -> bool:
    if args.live:
        return False
    if args.dry_run:
        return True
    # Default dry-run for safety
    return os.environ.get("GROXY_LIVE", "0") not in ("1", "true", "True")


def main(argv: list[str] | None = None) -> int:
    argv = list(sys.argv[1:] if argv is None else argv)
    parser = build_parser()
    # Bare `groxy` or `groxy --help` 
    if not argv or argv in (["-h"], ["--help"]):
        print(BANNER)
        parser.print_help()
        return 0

    args = parser.parse_args(argv)
    if args.cmd in (None, "help"):
        print(BANNER)
        parser.print_help()
        return 0

    dry = _is_dry(args)
    policy = _resolve_policy(args)
    state_path = args.state or default_state_path()
    state = load_state(state_path)
    work, effect_dir, package_dir = _work_paths(args)
    reply_to = (args.reply_to or os.environ.get("GROXY_REPLY_TO") or "").strip()

    if args.cmd == "demo-outbound":
        pkg = build_outbound_package(
            verb=args.verb,
            ok=True,
            result_text=args.text,
            host=hostname(),
            cwd=str(repo_root()),
            out_dir=package_dir / "demo",
        )
        written = pkg.write_files(package_dir / "demo")
        print(BANNER)
        print(f"dry-run outbound package → {package_dir / 'demo'}")
        for k, v in written.items():
            print(f"  {k}: {v}")
        print("--- dm_payload ---")
        print(pkg.dm_text())
        return 0

    if args.cmd == "inject":
        eid = args.event_id or f"inject-{int(time.time())}"
        event = {
            "id": eid,
            "event_type": "MessageCreate",
            "sender_id": str(args.sender_id),
            "text": args.text,
            "dm_conversation_id": "local-inject",
        }
        # Ensure sender is allowlisted for inject when empty policy
        if not policy.is_allowed_sender(str(args.sender_id), None):
            from .policy import Policy

            policy = Policy(
                allowlist_ids=frozenset(set(policy.allowlist_ids) | {str(args.sender_id)}),
                allowlist_usernames=policy.allowlist_usernames,
                require_confirm_high_blast=policy.require_confirm_high_blast,
            )
        sender = None
        if dry:
            sender = DryRunDmIO(fixture_path=None, out_dir=package_dir / "sends")
            if not reply_to:
                reply_to = "dry-run-recipient"
        else:
            xurl = resolve_xurl()
            if not xurl:
                print("error: xurl not found for --live", file=sys.stderr)
                return 2
            if not reply_to:
                print("error: --reply-to or GROXY_REPLY_TO required for --live", file=sys.stderr)
                return 2
            sender = XurlDmIO(xurl_bin=xurl)

        result = process_event(
            event,
            policy=policy,
            state=state,
            effect_dir=effect_dir,
            package_dir=package_dir,
            sender=sender,
            reply_to=reply_to,
            dry_run=dry,
        )
        save_state(state_path, state)
        print(BANNER)
        print(json.dumps(_result_public(result), indent=2, default=str))
        if result.package:
            print("--- dm_payload ---")
            print(result.package.dm_text())
        return 0 if result.accepted else 1

    if args.cmd in ("once", "poll"):
        fixture = getattr(args, "fixture", None)
        if dry or fixture:
            reader = DryRunDmIO(fixture_path=fixture, out_dir=package_dir / "sends")
            sender: DryRunDmIO | XurlDmIO | None = reader
            if not reply_to:
                reply_to = "dry-run-recipient"
        else:
            xurl = resolve_xurl()
            if not xurl:
                print("error: xurl not found", file=sys.stderr)
                return 2
            if not reply_to:
                print("error: --reply-to required for live poll", file=sys.stderr)
                return 2
            io = XurlDmIO(xurl_bin=xurl)
            reader = io
            sender = io

        loops = 1 if args.cmd == "once" else (args.count or 10**9)
        interval = getattr(args, "interval", 45.0)
        print(BANNER)
        print(f"mode={'dry-run' if dry or fixture else 'live'} work={work}")
        for i in range(int(loops)):
            try:
                report = run_once(
                    reader,
                    policy=policy,
                    state=state,
                    effect_dir=effect_dir,
                    package_dir=package_dir,
                    sender=sender,
                    reply_to=reply_to,
                    dry_run=dry or bool(fixture),
                    max_results=getattr(args, "max", 20),
                )
            except Exception as exc:  # keep poll alive through transient API errors
                print(f"[{i+1}] poll error: {exc}", file=sys.stderr)
                if args.cmd == "once":
                    return 1
                time.sleep(max(interval, 60.0))
                continue
            save_state(state_path, state)
            print(
                f"[{i+1}] processed={len(report.processed)} "
                f"accepted≈{report.accepted} rejected={report.rejected} skipped={report.skipped}"
            )
            for r in report.processed:
                print(f"  - {r.reason} event={r.event_id} verb={getattr(r.command, 'verb', None)}")
            if args.cmd == "once":
                break
            time.sleep(interval)
        return 0

    parser.print_help()
    return 2


def _result_public(result) -> dict:
    d = {
        "accepted": result.accepted,
        "reason": result.reason,
        "event_id": result.event_id,
        "sender_id": result.sender_id,
        "pending_token": result.pending_token,
        "command": None,
        "host": None,
        "package_dir_hint": None,
        "send_result": result.send_result,
    }
    if result.command:
        d["command"] = {
            "verb": result.command.verb,
            "args": result.command.args,
            "raw": result.command.raw,
        }
    if result.host:
        d["host"] = {
            "ok": result.host.ok,
            "verb": result.host.verb,
            "exit_code": result.host.exit_code,
            "effect_path": str(result.host.effect_path) if result.host.effect_path else None,
            "output_preview": (result.host.output or "")[:500],
        }
    if result.package and result.package.visual_path:
        d["package_dir_hint"] = str(result.package.visual_path.parent)
    return d


if __name__ == "__main__":
    raise SystemExit(main())
