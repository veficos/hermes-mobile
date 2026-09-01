"""Task store (ADR 0001): SQLite-backed product backlog owned by the mobile server.

The Hermes backend has no task entity, so `/api/v1/tasks` persists here.
Executing a Task creates a Session seeded with the Task's prompt (ADR 0003);
completion is written back by watching gateway broadcast events
(`message.complete` / `session.info` with `running == false`).

Uses stdlib ``sqlite3`` (no new dependency); every operation runs in a worker
thread via ``asyncio.to_thread`` guarded by an asyncio lock.
"""

from __future__ import annotations

import asyncio
import logging
import secrets
import sqlite3
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

logger = logging.getLogger("hermes_mobile_server.tasks")

PRIORITIES = ("low", "normal", "high", "urgent")
STATUSES = ("inbox", "ready", "running", "blocked", "review", "done", "archived")

#: SQLite lives next to the server config (same owned directory).
_DB_PATH = Path.home() / ".hermes-mobile-server" / "tasks.db"


def _now() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


def _new_id() -> str:
    return f"task_{int(time.time() * 1000):x}{secrets.token_hex(3)}"


class TaskStore:
    """Async wrapper around a single SQLite connection (low concurrency)."""

    def __init__(self, path: Path | str | None = None) -> None:
        self._path = Path(path) if path else _DB_PATH
        self._lock = asyncio.Lock()
        self._conn: sqlite3.Connection | None = None
        #: session_id → task_id for running tasks (ADR 0003 completion watch).
        self._running_by_session: dict[str, str] = {}
        #: Sessions that emitted at least one message.complete (turn started).
        self._saw_message: set[str] = set()

    # ------------------------------------------------------------- lifecycle
    async def init(self) -> None:
        if self._conn is not None:
            return
        self._path.parent.mkdir(parents=True, exist_ok=True)

        def _open() -> sqlite3.Connection:
            # Cross-thread usage is serialized by our asyncio.Lock; disable
            # sqlite3's own thread guard (threadpool threads differ per call).
            conn = sqlite3.connect(self._path, check_same_thread=False)
            conn.row_factory = sqlite3.Row
            conn.execute(
                """
                CREATE TABLE IF NOT EXISTS tasks (
                    id TEXT PRIMARY KEY,
                    title TEXT NOT NULL,
                    prompt TEXT NOT NULL DEFAULT '',
                    priority TEXT NOT NULL DEFAULT 'normal',
                    status TEXT NOT NULL DEFAULT 'inbox',
                    session_id TEXT,
                    created_at TEXT NOT NULL,
                    updated_at TEXT NOT NULL,
                    completed_at TEXT
                )
                """
            )
            conn.commit()
            return conn

        self._conn = await asyncio.to_thread(_open)

    async def close(self) -> None:
        async with self._lock:
            if self._conn is not None:
                conn = self._conn
                self._conn = None
                await asyncio.to_thread(conn.close)

    # ------------------------------------------------------------------ CRUD
    @staticmethod
    def _row_to_dict(row: sqlite3.Row) -> dict[str, Any]:
        return {
            "id": row["id"],
            "title": row["title"],
            "prompt": row["prompt"],
            "priority": row["priority"],
            "status": row["status"],
            "session_id": row["session_id"],
            "created_at": row["created_at"],
            "updated_at": row["updated_at"],
            "completed_at": row["completed_at"],
        }

    async def create(self, title: str, prompt: str = "", priority: str = "normal") -> dict[str, Any]:
        await self.init()
        if not title.strip():
            raise ValueError("title is required")
        if priority not in PRIORITIES:
            priority = "normal"
        task = {
            "id": _new_id(),
            "title": title.strip(),
            "prompt": prompt,
            "priority": priority,
            "status": "inbox",
            "session_id": None,
            "created_at": _now(),
            "updated_at": _now(),
            "completed_at": None,
        }

        def _insert() -> None:
            assert self._conn is not None
            self._conn.execute(
                """INSERT INTO tasks
                   (id, title, prompt, priority, status, session_id, created_at, updated_at, completed_at)
                   VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)""",
                (
                    task["id"], task["title"], task["prompt"], task["priority"],
                    task["status"], task["session_id"], task["created_at"],
                    task["updated_at"], task["completed_at"],
                ),
            )
            self._conn.commit()

        async with self._lock:
            await asyncio.to_thread(_insert)
        return task

    async def list(self, status: str | None = None, limit: int = 200) -> list[dict[str, Any]]:
        await self.init()

        def _select() -> list[dict[str, Any]]:
            assert self._conn is not None
            if status:
                rows = self._conn.execute(
                    "SELECT * FROM tasks WHERE status = ? ORDER BY created_at DESC LIMIT ?",
                    (status, limit),
                ).fetchall()
            else:
                rows = self._conn.execute(
                    "SELECT * FROM tasks ORDER BY created_at DESC LIMIT ?", (limit,)
                ).fetchall()
            return [self._row_to_dict(r) for r in rows]

        async with self._lock:
            return await asyncio.to_thread(_select)

    async def get(self, task_id: str) -> dict[str, Any] | None:
        await self.init()

        def _select() -> dict[str, Any] | None:
            assert self._conn is not None
            row = self._conn.execute(
                "SELECT * FROM tasks WHERE id = ?", (task_id,)
            ).fetchone()
            return self._row_to_dict(row) if row else None

        async with self._lock:
            return await asyncio.to_thread(_select)

    async def update(self, task_id: str, **fields: Any) -> dict[str, Any] | None:
        """Patch mutable fields; returns the updated task (or None if missing)."""
        await self.init()
        allowed = {"title", "prompt", "priority", "status", "session_id"}
        updates = {k: v for k, v in fields.items() if k in allowed and v is not None}
        if not updates:
            return await self.get(task_id)
        updates["updated_at"] = _now()
        if "status" in updates:
            updates["completed_at"] = _now() if updates["status"] == "done" else None

        cols = ", ".join(f"{k} = ?" for k in updates)
        params = [*updates.values(), task_id]

        def _patch() -> dict[str, Any] | None:
            assert self._conn is not None
            cur = self._conn.execute(f"UPDATE tasks SET {cols} WHERE id = ?", params)
            self._conn.commit()
            if cur.rowcount == 0:
                return None
            row = self._conn.execute("SELECT * FROM tasks WHERE id = ?", (task_id,)).fetchone()
            return self._row_to_dict(row) if row else None

        async with self._lock:
            return await asyncio.to_thread(_patch)

    async def delete(self, task_id: str) -> bool:
        await self.init()

        def _delete() -> bool:
            assert self._conn is not None
            cur = self._conn.execute("DELETE FROM tasks WHERE id = ?", (task_id,))
            self._conn.commit()
            return cur.rowcount > 0

        async with self._lock:
            return await asyncio.to_thread(_delete)

    # ------------------------------------------------------------ run (ADR 3)
    async def mark_running(self, task_id: str, durable_id: str, runtime_id: str) -> dict[str, Any] | None:
        """Watch keyed on the runtime id (gateway events carry it, not the
        durable id); the durable id is what the task row stores."""
        self._running_by_session[runtime_id] = task_id
        self._saw_message.discard(runtime_id)
        return await self.update(task_id, status="running", session_id=durable_id)

    async def complete(self, task_id: str, runtime_id: str | None = None) -> dict[str, Any] | None:
        task = await self.update(task_id, status="done")
        if runtime_id is not None:
            self._running_by_session.pop(runtime_id, None)
        elif task and task.get("session_id"):
            self._running_by_session.pop(task["session_id"], None)
        return task

    async def on_backend_event(self, event: dict[str, Any]) -> None:
        """Watch gateway events; write back completion (ADR 0003)."""
        etype = event.get("type")
        session_id = event.get("session_id")
        if not session_id:
            return
        task_id = self._running_by_session.get(session_id)
        if task_id is None:
            return
        if etype == "message.complete":
            # A message finished — the turn has actually started. Record it so
            # a session.info(running=false) that races the prompt.submit is not
            # mistaken for completion (ADR 0003).
            self._saw_message.add(session_id)
        elif etype == "session.info":
            payload = event.get("payload") or {}
            if payload.get("running") is False and session_id in self._saw_message:
                try:
                    await self.complete(task_id, session_id)
                except Exception:  # noqa: BLE001
                    logger.exception("marking task %s done failed", task_id)
        elif etype == "background.complete":
            self._saw_message.add(session_id)
            try:
                await self.complete(task_id, session_id)
            except Exception:  # noqa: BLE001
                logger.exception("marking task %s done failed", task_id)
