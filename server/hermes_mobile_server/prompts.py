"""Saved prompt snippets (WebUI `/api/prompts` parity).

The WebUI backend persists saved prompts to
``$HERMES_HOME/webui/saved_prompts.json``.  This store reads/writes the exact
same file and record schema so snippets saved from mobile show up in the
desktop WebUI and vice versa.  It is used as the fallback when the running
backend does not expose ``/api/prompts`` itself.
"""

from __future__ import annotations

import json
import threading
import time
import uuid
from pathlib import Path
from typing import Any

from .runtime import get_hermes_home

#: WebUI contract (api/routes.py): at most 200 saved prompts, 8000 chars each.
MAX_SAVED_PROMPTS = 200
MAX_PROMPT_TEXT = 8000


class SavedPromptsStore:
    """JSON-list store sharing the WebUI saved_prompts.json file/schema."""

    def __init__(self, path: Path | None = None) -> None:
        self._path = (
            path or Path(get_hermes_home()).expanduser() / "webui" / "saved_prompts.json"
        )
        self._lock = threading.RLock()

    def _load(self) -> list[dict[str, Any]]:
        try:
            raw = json.loads(self._path.read_text(encoding="utf-8"))
        except (OSError, ValueError):
            return []
        if not isinstance(raw, list):
            return []
        return [p for p in raw if isinstance(p, dict)]

    def _save(self, prompts: list[dict[str, Any]]) -> None:
        self._path.parent.mkdir(parents=True, exist_ok=True)
        temp = self._path.with_suffix(".tmp")
        temp.write_text(json.dumps(prompts, ensure_ascii=False, indent=2), encoding="utf-8")
        temp.replace(self._path)

    def list(self) -> list[dict[str, Any]]:
        with self._lock:
            return self._load()

    def add(self, text: str, label: str = "") -> dict[str, Any]:
        text = text.strip()
        label = label.strip()
        if not text:
            raise ValueError("text is required")
        if len(text) > MAX_PROMPT_TEXT:
            raise ValueError("text too long (max 8000 chars)")
        with self._lock:
            prompts = self._load()
            if len(prompts) >= MAX_SAVED_PROMPTS:
                raise ValueError("saved prompts limit reached (max 200)")
            prompt = {
                "id": uuid.uuid4().hex[:12],
                "label": label or text[:60],
                "text": text,
                "created_at": time.time(),
            }
            prompts.append(prompt)
            self._save(prompts)
            return prompt

    def delete(self, prompt_id: str) -> bool:
        prompt_id = prompt_id.strip()
        if not prompt_id:
            raise ValueError("id is required")
        with self._lock:
            prompts = self._load()
            remaining = [p for p in prompts if str(p.get("id") or "") != prompt_id]
            if len(remaining) == len(prompts):
                return False
            self._save(remaining)
            return True
