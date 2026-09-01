"""Durable immutable public snapshots for mobile session sharing."""

from __future__ import annotations

import html
import json
import secrets
import threading
import time
from pathlib import Path
from typing import Any

from .config import DEFAULT_CONFIG_DIR


class SessionShareStore:
    """JSON-backed bearer-capability snapshots.

    Hermes' current headless server exposes durable sessions but no public
    share creation route. The mobile server therefore owns only the immutable
    transport snapshot; every byte in it is read from Hermes first.
    """

    def __init__(self, path: Path | None = None) -> None:
        self._path = path or DEFAULT_CONFIG_DIR / "session-shares.json"
        self._lock = threading.RLock()

    def _load(self) -> dict[str, dict[str, Any]]:
        try:
            raw = json.loads(self._path.read_text(encoding="utf-8"))
            return raw if isinstance(raw, dict) else {}
        except (OSError, ValueError):
            return {}

    def _save(self, data: dict[str, dict[str, Any]]) -> None:
        self._path.parent.mkdir(parents=True, exist_ok=True)
        temp = self._path.with_suffix(".tmp")
        temp.write_text(json.dumps(data, ensure_ascii=False), encoding="utf-8")
        temp.replace(self._path)

    def create(
        self,
        session_id: str,
        session: dict[str, Any],
        messages: list[Any],
        *,
        profile: str | None = None,
    ) -> dict[str, Any]:
        with self._lock:
            data = self._load()
            # Refreshing a share revokes the old bearer token atomically.
            for token, snapshot in list(data.items()):
                if (
                    str(snapshot.get("session_id") or "") == session_id
                    and (snapshot.get("profile") or None) == profile
                ):
                    data.pop(token, None)
            token = secrets.token_urlsafe(32)
            now = time.time()
            snapshot = {
                "token": token,
                "session_id": session_id,
                "profile": profile,
                "title": str(session.get("title") or "Untitled"),
                "created_at": now,
                "message_count": len(messages),
                "session": session,
                "messages": messages,
            }
            data[token] = snapshot
            self._save(data)
            return snapshot

    def get(self, token: str) -> dict[str, Any] | None:
        with self._lock:
            snapshot = self._load().get(token)
        return snapshot if isinstance(snapshot, dict) else None

    def for_session(
        self, session_id: str, *, profile: str | None = None
    ) -> dict[str, Any] | None:
        with self._lock:
            values = self._load().values()
            snapshot = next(
                (
                    row
                    for row in values
                    if str(row.get("session_id") or "") == session_id
                    and (row.get("profile") or None) == profile
                ),
                None,
            )
        return snapshot if isinstance(snapshot, dict) else None

    def revoke(self, session_id: str, *, profile: str | None = None) -> bool:
        with self._lock:
            data = self._load()
            tokens = [
                token
                for token, row in data.items()
                if str(row.get("session_id") or "") == session_id
                and (row.get("profile") or None) == profile
            ]
            for token in tokens:
                data.pop(token, None)
            if tokens:
                self._save(data)
            return bool(tokens)


def render_share_html(snapshot: dict[str, Any]) -> str:
    """Render a standalone, safe conversation snapshot."""
    title = html.escape(str(snapshot.get("title") or "Hermes conversation"))
    cards: list[str] = []
    for row in snapshot.get("messages") or []:
        if not isinstance(row, dict):
            continue
        role = str(row.get("role") or "message")
        content = row.get("content")
        if not isinstance(content, str):
            content = json.dumps(content, ensure_ascii=False, indent=2)
        cards.append(
            '<article class="message %s"><div class="role">%s</div><pre>%s</pre></article>'
            % (html.escape(role), html.escape(role), html.escape(content))
        )
    return """<!doctype html><html lang="zh-CN"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>%s</title><style>
:root{color-scheme:light dark;font-family:Inter,system-ui,sans-serif;background:#f5f6f8;color:#182033}
body{margin:0}.shell{max-width:820px;margin:auto;padding:24px 16px 72px}header{margin-bottom:24px}
h1{font-size:24px;margin:0 0 6px}.meta{color:#68758a;font-size:13px}.message{background:#fff;border:1px solid #dbe0e8;border-radius:14px;padding:14px 16px;margin:12px 0;box-shadow:0 2px 8px #1720330d}
.message.user{margin-left:10%%;background:#eef4ff}.role{text-transform:capitalize;font-size:12px;font-weight:700;color:#68758a;margin-bottom:8px}pre{white-space:pre-wrap;overflow-wrap:anywhere;font:14px/1.65 Inter,system-ui,sans-serif;margin:0}
@media(prefers-color-scheme:dark){:root{background:#11151d;color:#e8edf6}.message{background:#191f2a;border-color:#303949}.message.user{background:#17253c}.meta,.role{color:#9ca9bc}}
</style></head><body><main class="shell"><header><h1>%s</h1><div class="meta">Hermes · %s messages</div></header>%s</main></body></html>""" % (
        title,
        title,
        int(snapshot.get("message_count") or len(cards)),
        "".join(cards),
    )


share_store = SessionShareStore()
