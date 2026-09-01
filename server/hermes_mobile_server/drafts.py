"""Durable composer drafts for Hermes runtimes without the legacy draft API."""

from __future__ import annotations

import json
import threading
from pathlib import Path
from typing import Any

from .config import DEFAULT_CONFIG_DIR


class DraftStore:
    """Small JSON-backed fallback, scoped to the authenticated mobile server."""

    def __init__(self, path: Path | None = None) -> None:
        self._path = path or DEFAULT_CONFIG_DIR / "session-drafts.json"
        self._lock = threading.RLock()

    def _load(self) -> dict[str, dict[str, Any]]:
        try:
            raw = json.loads(self._path.read_text(encoding="utf-8"))
            return raw if isinstance(raw, dict) else {}
        except (OSError, ValueError):
            return {}

    def get(self, session_id: str) -> dict[str, Any]:
        with self._lock:
            value = self._load().get(session_id, {})
        return value if isinstance(value, dict) else {}

    def save(
        self, session_id: str, *, text: str | None, files: list[Any] | None
    ) -> dict[str, Any]:
        with self._lock:
            data = self._load()
            draft = self.get(session_id)
            if text is not None:
                draft["text"] = text
            if files is not None:
                draft["files"] = files
            draft.setdefault("text", "")
            draft.setdefault("files", [])
            data[session_id] = draft
            self._path.parent.mkdir(parents=True, exist_ok=True)
            temp = self._path.with_suffix(".tmp")
            temp.write_text(json.dumps(data, ensure_ascii=False), encoding="utf-8")
            temp.replace(self._path)
            return draft
