"""Resolve the authenticated X account via xurl (no identities stored in-repo)."""

from __future__ import annotations

import json
import os
import shutil
import subprocess
from dataclasses import dataclass
from typing import Any


@dataclass(frozen=True)
class XIdentity:
    user_id: str
    username: str
    name: str = ""


def _xurl_bin() -> str | None:
    return shutil.which(os.environ.get("XURL_BIN", "xurl")) or shutil.which("xurl")


def fetch_authenticated_user(*, xurl_bin: str | None = None, timeout: float = 30.0) -> XIdentity | None:
    """
    GET /2/users/me through xurl. Returns None on failure.
    Never logs tokens; caller decides what to print (username only is OK).
    """
    bin_ = xurl_bin or _xurl_bin()
    if not bin_:
        return None
    try:
        proc = subprocess.run(
            [bin_, "/2/users/me"],
            capture_output=True,
            text=True,
            timeout=timeout,
            check=False,
        )
    except (OSError, subprocess.TimeoutExpired):
        return None
    if proc.returncode != 0:
        return None
    raw = (proc.stdout or "").strip()
    if not raw:
        return None
    try:
        # tolerate verbose noise
        if not raw.lstrip().startswith("{"):
            i = raw.find("{")
            if i < 0:
                return None
            raw = raw[i:]
        data: dict[str, Any] = json.loads(raw)
    except json.JSONDecodeError:
        return None
    me = data.get("data") or {}
    uid = str(me.get("id") or "").strip()
    uname = str(me.get("username") or "").strip()
    if not uid or not uname:
        return None
    return XIdentity(user_id=uid, username=uname, name=str(me.get("name") or ""))
