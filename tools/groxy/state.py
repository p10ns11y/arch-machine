"""Persistent state: seen DM event ids + pending high-blast confirms."""

from __future__ import annotations

import json
import secrets
import time
from dataclasses import asdict, dataclass, field
from pathlib import Path
from typing import Any


@dataclass
class PendingConfirm:
    token: str
    verb: str
    args: str
    sender_id: str
    created_at: float
    event_id: str | None = None


@dataclass
class GroxyState:
    seen_event_ids: list[str] = field(default_factory=list)
    pending: dict[str, dict[str, Any]] = field(default_factory=dict)
    last_poll_at: float | None = None

    def has_seen(self, event_id: str) -> bool:
        return event_id in self.seen_event_ids

    def mark_seen(self, event_id: str, *, maxlen: int = 500) -> None:
        if event_id in self.seen_event_ids:
            return
        self.seen_event_ids.append(event_id)
        if len(self.seen_event_ids) > maxlen:
            self.seen_event_ids = self.seen_event_ids[-maxlen:]

    def add_pending(self, verb: str, args: str, sender_id: str, event_id: str | None = None) -> str:
        token = secrets.token_hex(4)
        self.pending[token] = asdict(
            PendingConfirm(
                token=token,
                verb=verb,
                args=args,
                sender_id=sender_id,
                created_at=time.time(),
                event_id=event_id,
            )
        )
        return token

    def pop_pending(self, token: str) -> PendingConfirm | None:
        raw = self.pending.pop(token, None)
        if not raw:
            return None
        return PendingConfirm(**raw)


def default_state_path() -> Path:
    xdg = Path.home() / ".local" / "state" / "groxy"
    return xdg / "state.json"


def load_state(path: Path) -> GroxyState:
    if not path.is_file():
        return GroxyState()
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
        return GroxyState(
            seen_event_ids=list(data.get("seen_event_ids") or []),
            pending=dict(data.get("pending") or {}),
            last_poll_at=data.get("last_poll_at"),
        )
    except (json.JSONDecodeError, OSError, TypeError):
        return GroxyState()


def save_state(path: Path, state: GroxyState) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    payload = {
        "seen_event_ids": state.seen_event_ids,
        "pending": state.pending,
        "last_poll_at": state.last_poll_at,
    }
    path.write_text(json.dumps(payload, indent=2), encoding="utf-8")
