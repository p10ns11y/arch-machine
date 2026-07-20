"""XChat DM I/O adapters via xurl (live) or file sinks (dry-run / fixtures)."""

from __future__ import annotations

import json
import os
import re
import shutil
import subprocess
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Protocol


class DmReader(Protocol):
    def list_events(self, *, max_results: int = 20) -> list[dict[str, Any]]: ...


class DmSender(Protocol):
    def send_text(self, recipient: str, text: str) -> dict[str, Any]: ...

    def send_with_media(self, recipient: str, text: str, media_path: Path | None) -> dict[str, Any]: ...


class RateLimitedError(RuntimeError):
    """X API rate limit (HTTP 429). sleep_sec is a recommended wait before retry."""

    def __init__(self, message: str, *, sleep_sec: float = 90.0, reset_at: int | None = None):
        super().__init__(message)
        self.sleep_sec = max(5.0, float(sleep_sec))
        self.reset_at = reset_at


_RESET_RE = re.compile(r"X-Rate-Limit-Reset:\s*(\d+)", re.IGNORECASE)
_REMAINING_RE = re.compile(r"X-Rate-Limit-Remaining:\s*(\d+)", re.IGNORECASE)
_STATUS_RE = re.compile(r"<\s*(\d{3})\b")


@dataclass
class DryRunDmIO:
    """Read fixtures; write outbound payloads to a directory."""

    fixture_path: Path | None
    out_dir: Path
    sent: list[dict[str, Any]] | None = None

    def __post_init__(self) -> None:
        if self.sent is None:
            self.sent = []
        self.out_dir.mkdir(parents=True, exist_ok=True)

    def list_events(self, *, max_results: int = 20) -> list[dict[str, Any]]:
        if not self.fixture_path or not self.fixture_path.is_file():
            return []
        data = json.loads(self.fixture_path.read_text(encoding="utf-8"))
        if isinstance(data, list):
            events = data
        elif isinstance(data, dict):
            events = data.get("data") or data.get("events") or []
        else:
            events = []
        return list(events)[:max_results]

    def send_text(self, recipient: str, text: str) -> dict[str, Any]:
        return self.send_with_media(recipient, text, None)

    def send_with_media(self, recipient: str, text: str, media_path: Path | None) -> dict[str, Any]:
        n = len(self.sent or [])
        entry = {
            "recipient": recipient,
            "text": text,
            "media_path": str(media_path) if media_path else None,
            "mode": "dry-run",
        }
        assert self.sent is not None
        self.sent.append(entry)
        path = self.out_dir / f"send-{n:04d}.json"
        path.write_text(json.dumps(entry, indent=2), encoding="utf-8")
        (self.out_dir / f"send-{n:04d}.txt").write_text(text, encoding="utf-8")
        if media_path and Path(media_path).is_file():
            dest = self.out_dir / f"send-{n:04d}-media{Path(media_path).suffix}"
            dest.write_bytes(Path(media_path).read_bytes())
            entry["media_copied"] = str(dest)
            path.write_text(json.dumps(entry, indent=2), encoding="utf-8")
        return {"ok": True, "dry_run": True, "path": str(path), **entry}


@dataclass
class XurlDmIO:
    """Live DM I/O using the xurl CLI."""

    xurl_bin: str = "xurl"
    username: str | None = None

    def _base(self) -> list[str]:
        cmd = [self.xurl_bin]
        if self.username:
            cmd.extend(["-u", self.username])
        return cmd

    def list_events(self, *, max_results: int = 20) -> list[dict[str, Any]]:
        # Keep max_results modest; each poll costs 1 request against a low DM cap (~15/window).
        n = max(1, min(max_results, 25))
        url = (
            f"/2/dm_events?dm_event.fields=id,text,event_type,created_at,"
            f"sender_id,dm_conversation_id&max_results={n}"
        )
        # -v so we can read rate-limit headers on failure (still JSON on stdout when OK)
        proc = subprocess.run(
            self._base() + ["-v", url],
            capture_output=True,
            text=True,
            timeout=60,
            check=False,
        )
        out = (proc.stdout or "").strip()
        err = (proc.stderr or "").strip()
        combined = f"{err}\n{out}"

        if proc.returncode != 0:
            sleep_sec, reset_at = _rate_limit_wait(combined)
            if sleep_sec is not None or "429" in combined or "Too Many Requests" in combined:
                wait = sleep_sec if sleep_sec is not None else 90.0
                raise RateLimitedError(
                    f"xurl dm_events rate-limited (429); wait ~{int(wait)}s",
                    sleep_sec=wait,
                    reset_at=reset_at,
                )
            raise RuntimeError(f"xurl dm_events failed: {err or out or 'unknown error'}")

        # Success body is JSON; -v may interleave diagnostics on stderr only
        raw = out
        # If stdout has request noise, take last JSON object
        if raw and not raw.lstrip().startswith("{"):
            idx = raw.rfind("\n{")
            if idx >= 0:
                raw = raw[idx + 1 :]
            elif "{" in raw:
                raw = raw[raw.index("{") :]
        if not raw:
            return []
        try:
            data = json.loads(raw)
        except json.JSONDecodeError as e:
            raise RuntimeError(f"xurl dm_events bad JSON: {e}: {raw[:200]}") from e
        return list(data.get("data") or [])


def _rate_limit_wait(blob: str) -> tuple[float | None, int | None]:
    """Return (sleep_sec, reset_unix) if this looks like a 429 / exhausted limit."""
    reset_m = _RESET_RE.search(blob or "")
    remaining_m = _REMAINING_RE.search(blob or "")
    status_m = _STATUS_RE.search(blob or "")
    is_429 = "Too Many Requests" in (blob or "") or (status_m and status_m.group(1) == "429")
    remaining = int(remaining_m.group(1)) if remaining_m else None
    reset_at = int(reset_m.group(1)) if reset_m else None

    if not is_429 and remaining != 0:
        return None, reset_at

    if reset_at:
        sleep_sec = max(5.0, reset_at - time.time() + 3.0)
        return sleep_sec, reset_at
    if is_429 or remaining == 0:
        return 90.0, reset_at
    return None, reset_at

    def send_text(self, recipient: str, text: str) -> dict[str, Any]:
        recip = recipient if recipient.startswith("@") else recipient
        # xurl dm expects username; if numeric id, try as-is (may fail)
        proc = subprocess.run(
            self._base() + ["dm", recip, text],
            capture_output=True,
            text=True,
            timeout=60,
            check=False,
        )
        out = (proc.stdout or "") + (proc.stderr or "")
        return {
            "ok": proc.returncode == 0,
            "exit_code": proc.returncode,
            "output": out.strip(),
            "recipient": recip,
            "dry_run": False,
        }

    def send_with_media(self, recipient: str, text: str, media_path: Path | None) -> dict[str, Any]:
        # Upload visual media for archive/future attach; do not append upload logs to the DM body
        # (operator DMs stay outcome-first: done bullets + PR, no system noise).
        result: dict[str, Any] = {"media_upload": None}
        if media_path and Path(media_path).is_file():
            up = subprocess.run(
                self._base() + ["media", "upload", str(media_path)],
                capture_output=True,
                text=True,
                timeout=120,
                check=False,
            )
            result["media_upload"] = {
                "ok": up.returncode == 0,
                "output": ((up.stdout or "") + (up.stderr or "")).strip()[:500],
            }
        send = self.send_text(recipient, text)
        send.update(result)
        return send


def resolve_xurl() -> str | None:
    return shutil.which("xurl") or shutil.which(os.environ.get("XURL_BIN", "xurl"))
