"""Durable local profile storage.

Fallback for Hermes runtimes that expose neither ``/api/profiles`` nor a
``profiles`` field in ``/api/config``.  Lives next to the other mobile-server
state at ``~/.hermes-mobile-server/profiles.json`` so profiles stay real and
persistent even when the upstream backend has no profile surface at all.
"""

from __future__ import annotations

import json
import threading
from pathlib import Path
from typing import Any

from .config import DEFAULT_CONFIG_DIR


class ProfileStore:
    """Small JSON-backed store: ``{"profiles": [...], "active": name|None}``."""

    def __init__(self, path: Path | None = None) -> None:
        self._path = path or DEFAULT_CONFIG_DIR / "profiles.json"
        self._lock = threading.RLock()

    def _load(self) -> dict[str, Any]:
        try:
            raw = json.loads(self._path.read_text(encoding="utf-8"))
            return raw if isinstance(raw, dict) else {}
        except (OSError, ValueError):
            return {}

    def _write(self, data: dict[str, Any]) -> None:
        self._path.parent.mkdir(parents=True, exist_ok=True)
        temp = self._path.with_suffix(".tmp")
        temp.write_text(
            json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8"
        )
        temp.replace(self._path)

    def snapshot(self) -> dict[str, Any]:
        with self._lock:
            data = self._load()
        profiles = data.get("profiles")
        active = data.get("active")
        return {
            "profiles": [p for p in profiles if isinstance(p, dict)]
            if isinstance(profiles, list)
            else [],
            "active": active if isinstance(active, str) and active else None,
        }

    def upsert(self, profile: dict[str, Any]) -> dict[str, Any]:
        """Create or replace a profile keyed by its ``name``."""
        name = str(profile.get("name") or "").strip()
        if not name:
            raise ValueError("profile name is required")
        record = {**profile, "name": name}
        with self._lock:
            snap = self.snapshot()
            profiles = list(snap["profiles"])
            for index, existing in enumerate(profiles):
                if str(existing.get("name") or "") == name:
                    profiles[index] = {**existing, **record}
                    break
            else:
                profiles.append(record)
            self._write({"profiles": profiles, "active": snap["active"]})
        return record

    def delete(self, name: str) -> bool:
        with self._lock:
            snap = self.snapshot()
            profiles = [
                p for p in snap["profiles"] if str(p.get("name") or "") != name
            ]
            if len(profiles) == len(snap["profiles"]):
                return False
            active = snap["active"] if snap["active"] != name else None
            self._write({"profiles": profiles, "active": active})
        return True

    def set_active(self, name: str) -> bool:
        with self._lock:
            snap = self.snapshot()
            if not any(str(p.get("name") or "") == name for p in snap["profiles"]):
                return False
            self._write({"profiles": snap["profiles"], "active": name})
        return True
