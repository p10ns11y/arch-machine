"""Allowlist and high-blast remote policy (enforced independently of Grok YOLO)."""

from __future__ import annotations

import os
import re
from dataclasses import dataclass, field
from pathlib import Path
from typing import Iterable

# Commands that may mutate the host and require an explicit confirm step.
HIGH_BLAST = frozenset(
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
    }
)

SAFE_COMMANDS = frozenset(
    {
        "help",
        "ping",
        "status",
        "inventory",
        "audit",
        "omarchy",
        "run",
        "confirm",
        "whoami",
    }
)


@dataclass(frozen=True)
class Policy:
    """Remote control policy: who may command, and what is auto-run."""

    allowlist_ids: frozenset[str] = field(default_factory=frozenset)
    allowlist_usernames: frozenset[str] = field(default_factory=frozenset)
    require_confirm_high_blast: bool = True

    def is_allowed_sender(self, sender_id: str | None, username: str | None = None) -> bool:
        if not sender_id and not username:
            return False
        if sender_id and str(sender_id) in self.allowlist_ids:
            return True
        if username and username.lstrip("@").lower() in self.allowlist_usernames:
            return True
        return False

    def is_high_blast(self, command: str) -> bool:
        cmd = (command or "").strip().lower()
        if not cmd:
            return False
        head = cmd.split()[0]
        if head in HIGH_BLAST:
            return True
        # Subcommands that look destructive even under a safe verb.
        if re.search(r"\b(rm|reboot|shutdown|format|dd)\b", cmd):
            return True
        return False


def load_policy_from_env(
    *,
    extra_ids: Iterable[str] | None = None,
    extra_usernames: Iterable[str] | None = None,
) -> Policy:
    """Build policy from GROXY_ALLOWLIST_IDS / GROXY_ALLOWLIST_USERNAMES and optional extras."""
    ids: set[str] = set()
    users: set[str] = set()

    raw_ids = os.environ.get("GROXY_ALLOWLIST_IDS", "").strip()
    if raw_ids:
        for part in re.split(r"[\s,]+", raw_ids):
            if part:
                ids.add(part)

    raw_users = os.environ.get("GROXY_ALLOWLIST_USERNAMES", "").strip()
    if raw_users:
        for part in re.split(r"[\s,]+", raw_users):
            if part:
                users.add(part.lstrip("@").lower())

    if extra_ids:
        ids.update(str(x) for x in extra_ids if x)
    if extra_usernames:
        users.update(u.lstrip("@").lower() for u in extra_usernames if u)

    # Default: empty allowlist rejects everyone (fail closed) unless env set.
    require = os.environ.get("GROXY_REQUIRE_CONFIRM", "1") not in ("0", "false", "False")
    return Policy(
        allowlist_ids=frozenset(ids),
        allowlist_usernames=frozenset(users),
        require_confirm_high_blast=require,
    )


def load_policy_file(path: Path) -> Policy:
    """Load allowlist from a simple key=value or line-based config file."""
    ids: set[str] = set()
    users: set[str] = set()
    require = True
    if not path.is_file():
        return load_policy_from_env()

    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        if "=" in line:
            key, _, val = line.partition("=")
            key = key.strip().lower()
            val = val.strip()
            if key in ("allowlist_ids", "ids"):
                for part in re.split(r"[\s,]+", val):
                    if part:
                        ids.add(part)
            elif key in ("allowlist_usernames", "usernames", "users"):
                for part in re.split(r"[\s,]+", val):
                    if part:
                        users.add(part.lstrip("@").lower())
            elif key in ("require_confirm", "require_confirm_high_blast"):
                require = val not in ("0", "false", "False", "no")
        else:
            # bare id or @username
            if line.startswith("@"):
                users.add(line.lstrip("@").lower())
            elif line.isdigit():
                ids.add(line)
            else:
                users.add(line.lower())

    # Merge env on top of file
    env = load_policy_from_env(extra_ids=ids, extra_usernames=users)
    return Policy(
        allowlist_ids=env.allowlist_ids,
        allowlist_usernames=env.allowlist_usernames,
        require_confirm_high_blast=require
        if "GROXY_REQUIRE_CONFIRM" not in os.environ
        else env.require_confirm_high_blast,
    )
