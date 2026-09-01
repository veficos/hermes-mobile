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

    @staticmethod
    def _key(session_id: str, profile: str | None) -> str:
        return f"{profile or ''}\0{session_id}"

    def get(self, session_id: str, *, profile: str | None = None) -> dict[str, Any]:
        with self._lock:
            data = self._load()
            scoped_key = self._key(session_id, profile)
            value = data.get(scoped_key)
            # One-way compatibility: an unscoped legacy draft may be adopted
            # by the first scoped read, but scoped drafts never fall back to
            # another profile.
            if value is None and session_id in data:
                value = data.pop(session_id)
                data[scoped_key] = value
                self._path.parent.mkdir(parents=True, exist_ok=True)
                temp = self._path.with_suffix(".tmp")
                temp.write_text(
                    json.dumps(data, ensure_ascii=False), encoding="utf-8"
                )
                temp.replace(self._path)
            if value is None:
                value = {}
        return value if isinstance(value, dict) else {}

    def save(
        self,
        session_id: str,
        *,
        text: str | None,
        files: list[Any] | None,
        profile: str | None = None,
    ) -> dict[str, Any]:
        with self._lock:
            data = self._load()
            draft = self.get(session_id, profile=profile)
            if text is not None:
                draft["text"] = text
            if files is not None:
                draft["files"] = files
            draft.setdefault("text", "")
            draft.setdefault("files", [])
            data[self._key(session_id, profile)] = draft
            self._path.parent.mkdir(parents=True, exist_ok=True)
            temp = self._path.with_suffix(".tmp")
            temp.write_text(json.dumps(data, ensure_ascii=False), encoding="utf-8")
            temp.replace(self._path)
            return draft
