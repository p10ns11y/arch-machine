"""Inbound DM event → allowlist → host action → outbound package (core loop)."""

from __future__ import annotations

import time
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

from .dm_io import DmReader, DmSender
from .host import HostResult, dispatch_host_action, hostname, repo_root
from .package import OutboundPackage, build_outbound_package
from .parse import (
    ParsedCommand,
    conversation_id_of,
    event_id_of,
    parse_dm_event,
    sender_id_of,
)
from .policy import Policy
from .state import GroxyState


@dataclass
class DispatchResult:
    accepted: bool
    reason: str
    event_id: str | None = None
    sender_id: str | None = None
    command: ParsedCommand | None = None
    host: HostResult | None = None
    package: OutboundPackage | None = None
    send_result: dict[str, Any] | None = None
    pending_token: str | None = None


@dataclass
class LoopReport:
    processed: list[DispatchResult] = field(default_factory=list)
    skipped: int = 0
    rejected: int = 0
    accepted: int = 0


def process_event(
    event: dict[str, Any],
    *,
    policy: Policy,
    state: GroxyState,
    effect_dir: Path,
    package_dir: Path,
    sender: DmSender | None = None,
    reply_to: str | None = None,
    dry_run: bool = True,
    username_map: dict[str, str] | None = None,
) -> DispatchResult:
    """
    Process one DM event through allowlist → parse → host → outbound package.
    This is the shipped inbound path (called by poll loop and tests).
    """
    eid = event_id_of(event)
    sid = sender_id_of(event)

    if eid and state.has_seen(eid):
        return DispatchResult(False, "already_seen", event_id=eid, sender_id=sid)

    # Public post guard: events marked as posts are rejected
    if event.get("is_public_post") or event.get("source") == "tweet":
        if eid:
            state.mark_seen(eid)
        return DispatchResult(False, "public_post_rejected", event_id=eid, sender_id=sid)

    uname = None
    if username_map and sid:
        uname = username_map.get(str(sid))
    if not policy.is_allowed_sender(sid, uname):
        if eid:
            state.mark_seen(eid)
        return DispatchResult(False, "sender_not_allowlisted", event_id=eid, sender_id=sid)

    cmd = parse_dm_event(event)
    if not cmd:
        if eid:
            state.mark_seen(eid)
        return DispatchResult(False, "no_command", event_id=eid, sender_id=sid)

    # High-blast gate
    if policy.require_confirm_high_blast and policy.is_high_blast(cmd.verb) and not cmd.confirm_token:
        token = state.add_pending(cmd.verb, cmd.args, sid or "", eid)
        if eid:
            state.mark_seen(eid)
        msg = (
            f"high-blast `{cmd.verb}` held.\n"
            f"Reply within this DM:\n"
            f"confirm {token} {cmd.verb} {cmd.args}".strip()
        )
        hr = HostResult(False, cmd.verb, msg, 403, 0.0)
        pkg = build_outbound_package(
            verb=cmd.verb,
            ok=False,
            result_text=msg,
            host=hostname(),
            cwd=str(repo_root()),
            out_dir=package_dir / f"evt-{eid or 'na'}",
            extra_meta={"pending_token": token, "conversation_id": conversation_id_of(event)},
        )
        send_res = None
        if sender and reply_to:
            send_res = _send_package(sender, reply_to, pkg, dry_run=dry_run)
        return DispatchResult(
            True,
            "pending_confirm",
            event_id=eid,
            sender_id=sid,
            command=cmd,
            host=hr,
            package=pkg,
            send_result=send_res,
            pending_token=token,
        )

    confirmed = False
    if cmd.confirm_token:
        pending = state.pop_pending(cmd.confirm_token)
        if not pending:
            if eid:
                state.mark_seen(eid)
            hr = HostResult(False, "confirm", f"unknown or expired token {cmd.confirm_token}", 404, 0.0)
            pkg = build_outbound_package(
                verb="confirm",
                ok=False,
                result_text=hr.output,
                host=hostname(),
                cwd=str(repo_root()),
                out_dir=package_dir / f"evt-{eid or 'na'}",
            )
            return DispatchResult(
                True, "bad_confirm", event_id=eid, sender_id=sid, command=cmd, host=hr, package=pkg
            )
        if pending.sender_id and sid and pending.sender_id != sid:
            if eid:
                state.mark_seen(eid)
            hr = HostResult(False, "confirm", "token sender mismatch", 403, 0.0)
            pkg = build_outbound_package(
                verb="confirm",
                ok=False,
                result_text=hr.output,
                host=hostname(),
                cwd=str(repo_root()),
                out_dir=package_dir / f"evt-{eid or 'na'}",
            )
            return DispatchResult(
                True, "confirm_sender_mismatch", event_id=eid, sender_id=sid, command=cmd, host=hr, package=pkg
            )
        # Prefer pending verb/args if command was bare confirm
        if cmd.verb == "confirm" or not cmd.args and pending.verb:
            cmd = ParsedCommand(
                verb=pending.verb,
                args=pending.args,
                raw=cmd.raw,
                confirm_token=cmd.confirm_token,
            )
        confirmed = True

    # Mark seen before long host work to avoid double-run on crash mid-job? 
    # Prefer after success for retries — but for remote control, mark early to avoid double blast.
    if eid:
        state.mark_seen(eid)

    effect_dir.mkdir(parents=True, exist_ok=True)
    hr = dispatch_host_action(
        cmd.verb,
        cmd.args,
        effect_dir,
        confirmed=confirmed,
        allow_yolo=False,
    )
    pkg_sub = package_dir / f"evt-{eid or int(time.time())}"
    pkg = build_outbound_package(
        verb=cmd.verb,
        ok=hr.ok,
        result_text=hr.output,
        host=hostname(),
        cwd=str(repo_root()),
        out_dir=pkg_sub,
        extra_meta={
            "exit_code": hr.exit_code,
            "duration_sec": hr.duration_sec,
            "effect_path": str(hr.effect_path) if hr.effect_path else None,
            "conversation_id": conversation_id_of(event),
        },
    )
    pkg.write_files(pkg_sub)

    send_res = None
    if sender and reply_to:
        send_res = _send_package(sender, reply_to, pkg, dry_run=dry_run)

    return DispatchResult(
        True,
        "ok" if hr.ok else "host_failed",
        event_id=eid,
        sender_id=sid,
        command=cmd,
        host=hr,
        package=pkg,
        send_result=send_res,
    )


def _send_package(
    sender: DmSender,
    reply_to: str,
    pkg: OutboundPackage,
    *,
    dry_run: bool,
) -> dict[str, Any]:
    text = pkg.dm_text()
    media = pkg.media_path or pkg.visual_path
    # DryRun sender ignores dry_run flag; live sender always "live"
    return sender.send_with_media(reply_to, text, media)


def run_once(
    reader: DmReader,
    *,
    policy: Policy,
    state: GroxyState,
    effect_dir: Path,
    package_dir: Path,
    sender: DmSender | None = None,
    reply_to: str | None = None,
    dry_run: bool = True,
    max_results: int = 20,
    username_map: dict[str, str] | None = None,
) -> LoopReport:
    """Poll/read events and process newest-first unprocessed allowlisted commands."""
    report = LoopReport()
    events = reader.list_events(max_results=max_results)
    # Process oldest first so conversation order is natural
    for event in reversed(list(events)):
        eid = event_id_of(event)
        if eid and state.has_seen(eid):
            report.skipped += 1
            continue
        result = process_event(
            event,
            policy=policy,
            state=state,
            effect_dir=effect_dir,
            package_dir=package_dir,
            sender=sender,
            reply_to=reply_to,
            dry_run=dry_run,
            username_map=username_map,
        )
        report.processed.append(result)
        if not result.accepted:
            if result.reason == "sender_not_allowlisted":
                report.rejected += 1
            else:
                report.skipped += 1
        elif result.reason in ("ok", "host_failed", "pending_confirm", "bad_confirm", "confirm_sender_mismatch"):
            report.accepted += 1
        else:
            report.skipped += 1
    state.last_poll_at = time.time()
    return report
