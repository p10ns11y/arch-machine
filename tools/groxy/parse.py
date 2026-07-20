"""Parse inbound XChat DM text into structured remote commands."""

from __future__ import annotations

import re
from dataclasses import dataclass
from typing import Any

from .policy import SAFE_COMMANDS


@dataclass(frozen=True)
class ParsedCommand:
    """Normalized remote command extracted from a DM body."""

    verb: str
    args: str
    raw: str
    confirm_token: str | None = None
    is_public_post: bool = False  # always False for DM path; reserved for guards

    @property
    def command_line(self) -> str:
        if self.args:
            return f"{self.verb} {self.args}".strip()
        return self.verb


_PREFIX_RE = re.compile(
    r"^\s*(?:!g(?:roxy)?|groxy|/groxy|@?groxy)\s*[:\s]?\s*",
    re.IGNORECASE,
)
_CONFIRM_RE = re.compile(
    r"^\s*confirm\s+([A-Za-z0-9_-]+)\s*(.*)$",
    re.IGNORECASE,
)
# Verbs accepted without a !g prefix (exact first token only — never free-text → run).
_EXPLICIT_VERBS = SAFE_COMMANDS | frozenset(
    {
        "pkg",
        "actuate",
        "install",
        "expand",
        "remediate",
        "apply",
        "rm",
        "delete",
        "reboot",
        "shutdown",
        "yolo",
        "confirm",
    }
)
# Multi-char aliases only — single letters collide with English ("I have…").
_ALIASES = {
    "inv": "inventory",
    "?": "help",
}


def has_control_prefix(text: str) -> bool:
    t = re.sub(r"^🤖\s*", "", (text or "").strip())
    return bool(_PREFIX_RE.match(t))


def strip_control_prefix(text: str) -> str:
    """Remove optional !g / groxy control prefixes."""
    t = (text or "").strip()
    # Drop leading bot emoji noise sometimes present in auto-replies
    t = re.sub(r"^🤖\s*", "", t)
    return _PREFIX_RE.sub("", t, count=1).strip()


def is_groxy_outbound_noise(text: str) -> bool:
    """True for our own reply packages (must not re-enter as commands)."""
    t = (text or "").strip()
    if not t:
        return True
    if t.startswith("groxy OK:") or t.startswith("groxy FAIL:"):
        return True
    if t.startswith("✓ Done:") or t.startswith("✗ Failed:"):
        return True
    if t.startswith("── visual ──") or "╔══" in t[:80]:
        return True
    if t.startswith("[media]"):
        return True
    if t.startswith("PR: https://"):
        return True
    return False


def parse_dm_text(text: str) -> ParsedCommand | None:
    """
    Parse DM body into a command.

    Accepted forms:
      help
      !g status
      groxy inventory
      status
      run how is disk usage
      !g free form prompt here   (prefix required for free-form → run)
      confirm abc123 pkg install foo

    Safety: arbitrary chat without a known verb and without !g/groxy prefix
    is NOT treated as a command (avoids historical DM misfires).
    """
    if text is None:
        return None
    if is_groxy_outbound_noise(text):
        return None

    prefixed = has_control_prefix(text)
    body = strip_control_prefix(text)
    if not body:
        return None
    if is_groxy_outbound_noise(body):
        return None

    # Ignore pure URLs / empty noise
    if body.startswith("http://") or body.startswith("https://"):
        return None

    m = _CONFIRM_RE.match(body)
    if m:
        token = m.group(1)
        rest = (m.group(2) or "").strip()
        if rest:
            parts = rest.split(None, 1)
            verb = parts[0].lower()
            args = parts[1] if len(parts) > 1 else ""
        else:
            verb = "confirm"
            args = ""
        return ParsedCommand(verb=verb, args=args, raw=body, confirm_token=token)

    parts = body.split(None, 1)
    verb = parts[0].lower().lstrip("/")
    args = parts[1] if len(parts) > 1 else ""
    verb = _ALIASES.get(verb, verb)

    if verb in _EXPLICIT_VERBS:
        return ParsedCommand(verb=verb, args=args, raw=body)

    # Free-form → run only with explicit !g / groxy prefix
    if prefixed:
        return ParsedCommand(verb="run", args=body, raw=body)

    return None


def parse_dm_event(event: dict[str, Any]) -> ParsedCommand | None:
    """Parse a single X API dm_event dict."""
    if not isinstance(event, dict):
        return None
    et = event.get("event_type") or event.get("type") or ""
    if et and et not in ("MessageCreate", "message_create", "Message", ""):
        # Still allow events that only carry text
        if "text" not in event:
            return None
    text = event.get("text") or event.get("message") or ""
    return parse_dm_text(str(text))


def sender_id_of(event: dict[str, Any]) -> str | None:
    for key in ("sender_id", "senderId", "sender"):
        v = event.get(key)
        if v is None:
            continue
        if isinstance(v, dict):
            return str(v.get("id") or v.get("user_id") or "") or None
        return str(v)
    return None


def event_id_of(event: dict[str, Any]) -> str | None:
    v = event.get("id") or event.get("event_id")
    return str(v) if v is not None else None


def conversation_id_of(event: dict[str, Any]) -> str | None:
    v = event.get("dm_conversation_id") or event.get("conversation_id")
    return str(v) if v is not None else None
