"""Domain REST API (D2/D5/D6, D5-extended 2026-08).

The mobile client talks to these resources instead of the backend's raw
endpoints. Resources: sessions, config, model, skills, tools, files,
audio, cron, projects, memory, knowledge, mcp, plugins, git, analytics,
tasks, artifacts, starmap, subagents, pet, billing, credentials,
messaging, webhooks, terminal. D5-extended: long-tail features are now
included per the all-features migration requirement.

Design contract: `server/DESIGN.md`.
"""

from __future__ import annotations

import asyncio
import html
import json
import logging
import os
import re
import secrets
import sqlite3
import time
from datetime import datetime, timezone
from typing import Any
from urllib.parse import quote

import httpx
import yaml
from fastapi import APIRouter, Body, Depends, HTTPException, Query, Request, Response
from fastapi.responses import FileResponse, JSONResponse
from starlette.background import BackgroundTask

from .auth import api_key_dependency
from .backend import BackendError, BackendManager
from .concurrency import BoundedExecutor
from .config import Settings
from .drafts import DraftStore
from .profiles import ProfileStore
from .plugin_manifest import enrich_plugin_inventory, profile_plugins_root
from .prompts import SavedPromptsStore
from .runtime import get_hermes_home
from .session_shares import share_store
from .session_live_state import SessionLiveState
from . import local_workspace
from .tasks import STATUSES, TaskStore

logger = logging.getLogger("hermes_mobile_server.domain")
_draft_store = DraftStore()

# Hermes owns the canonical Kanban board.  These are deliberately kept here
# rather than in ``tasks.py``: the latter is retained only as an injected,
# isolated test double for the legacy endpoint tests.
HERMES_KANBAN_STATUSES = (
    "triage", "todo", "scheduled", "ready", "running", "blocked",
    "review", "done", "archived",
)


def _kanban_timestamp(value: Any) -> str | None:
    """Convert Hermes' epoch-second task timestamps to the mobile wire format."""
    if value is None:
        return None
    try:
        return datetime.fromtimestamp(int(value), tz=timezone.utc).isoformat(
            timespec="seconds"
        )
    except (TypeError, ValueError, OSError):
        return None


def _mobile_priority(value: Any) -> str:
    """Keep the pre-existing mobile priority vocabulary while preserving order."""
    try:
        priority = int(value)
    except (TypeError, ValueError):
        priority = 0
    if priority >= 2:
        return "urgent"
    if priority == 1:
        return "high"
    if priority < 0:
        return "low"
    return "normal"


def _hermes_priority(value: Any) -> int:
    """Translate the mobile picker value to Hermes' native numeric priority."""
    if isinstance(value, int):
        return value
    if isinstance(value, str):
        named = {"low": -1, "normal": 0, "high": 1, "urgent": 2}
        if value in named:
            return named[value]
        try:
            return int(value)
        except ValueError:
            pass
    return 0


def _mobile_task(task: Any) -> dict[str, Any]:
    """Adapt one canonical Hermes Kanban task to the mobile task contract.

    The source row remains Hermes' task: ids, status and all lifecycle writes
    are never invented by the mobile server.  Extra Hermes fields are retained
    under ``hermes`` for forward-compatible clients.
    """
    if not isinstance(task, dict):
        raise ValueError("Hermes Kanban returned an invalid task payload")
    created_at = _kanban_timestamp(task.get("created_at"))
    started_at = _kanban_timestamp(task.get("started_at"))
    completed_at = _kanban_timestamp(task.get("completed_at"))
    return {
        "id": str(task.get("id") or ""),
        "title": str(task.get("title") or ""),
        "prompt": str(task.get("body") or ""),
        "priority": _mobile_priority(task.get("priority")),
        "priority_value": _hermes_priority(task.get("priority")),
        "status": str(task.get("status") or "triage"),
        "session_id": task.get("session_id"),
        "created_at": created_at,
        # Hermes has no synthetic updated_at column.  A run start is the
        # closest lifecycle update; otherwise preserve creation time.
        "updated_at": started_at or completed_at or created_at,
        "completed_at": completed_at,
        "hermes": task,
    }

def _config_document(payload: Any) -> dict:
    """Validate without narrowing the open-world Hermes config document."""
    if not isinstance(payload, dict):
        raise HTTPException(status_code=422, detail="config must be an object")
    return payload


async def _backend_json(
    backend: BackendManager,
    method: str,
    path: str,
    query: dict | None = None,
    body: Any = None,
    headers: dict[str, str] | None = None,
) -> Any:
    """Call a backend REST endpoint and return its parsed JSON (or None)."""
    client = await backend.http_client()
    try:
        request_kwargs = {"params": query or {}, "json": body}
        if headers is not None:
            request_kwargs["headers"] = headers
        resp = await client.request(method, path, **request_kwargs)
    except httpx.HTTPError as exc:
        raise HTTPException(status_code=502, detail=f"backend unreachable: {exc.__class__.__name__}")
    if resp.status_code >= 400:
        detail = resp.text[:300]
        try:
            payload = resp.json()
            if isinstance(payload, dict):
                raw_error = payload.get("error")
                if isinstance(raw_error, dict):
                    detail = raw_error.get("message") or raw_error.get("error") or detail
                else:
                    detail = payload.get("detail") or raw_error or detail
        except ValueError:
            pass
        raise HTTPException(status_code=resp.status_code, detail=detail)
    if not resp.content:
        return None
    return resp.json()


def _ok_response(result: Any | None) -> dict:
    """Normalize a backend mutation result to a stable mobile envelope.

    If the upstream returned a dict, pass successful results through (they may
    contain the deleted object or extra metadata). An explicit ``ok: false``
    is a mutation failure even when the upstream used HTTP 200.
    """
    if isinstance(result, dict):
        if result.get("ok") is False:
            raw_error = result.get("error")
            if isinstance(raw_error, dict):
                detail = raw_error.get("message") or raw_error.get("error")
            else:
                detail = result.get("message") or raw_error
            raise HTTPException(status_code=422, detail=detail or "mutation failed")
        return result
    return {"ok": True}


async def _all_session_messages(
    backend: BackendManager,
    session_id: str,
    *,
    page_size: int = 500,
    profile: str | None = None,
) -> list[Any]:
    """Read every raw Hermes history row without silently truncating exports."""
    rows: list[Any] = []
    offset = 0
    while True:
        payload = await _backend_json(
            backend,
            "GET",
            f"/api/sessions/{session_id}/messages",
            query={
                "limit": page_size,
                "offset": offset,
                **({"profile": profile} if profile else {}),
            },
        )
        page = (payload or {}).get("messages", []) if isinstance(payload, dict) else []
        if not isinstance(page, list):
            raise HTTPException(status_code=502, detail="Hermes returned invalid messages")
        rows.extend(page)
        if len(page) < page_size:
            return rows
        offset += len(page)


_EXPORT_HTML_CSS = """
:root{font-family:Inter,system-ui,sans-serif;background:#fbf6e9;color:#3d3626}
body{margin:0}.shell{max-width:820px;margin:auto;padding:24px 16px 72px}
header{margin-bottom:24px}h1{font-size:24px;margin:0 0 6px}
.meta{color:#8a7f63;font-size:13px}
.message{background:#fffdf4;border:1px solid #e7ddc2;border-radius:14px;padding:14px 16px;margin:12px 0;box-shadow:0 2px 8px #3d36260d}
.message.user{margin-left:8%;background:#f5edd6}
.role{text-transform:capitalize;font-size:12px;font-weight:700;color:#8a7f63;margin-bottom:8px}
.text{white-space:pre-wrap;overflow-wrap:anywhere;font-size:14px;line-height:1.65}
details.fold{background:#f7f0dc;border:1px solid #e7ddc2;border-radius:10px;padding:8px 12px;margin:8px 0}
details.fold summary{cursor:pointer;font-size:12px;font-weight:600;color:#8a7f63}
details.fold pre{white-space:pre-wrap;overflow-wrap:anywhere;font:12px/1.6 ui-monospace,Consolas,monospace;margin:8px 0 0}
"""


def _export_message_html(message: Any) -> str:
    """Render one raw Hermes history row; tool/thinking content is folded."""
    if not isinstance(message, dict):
        return ""
    role = str(message.get("role") or "assistant")
    texts: list[str] = []
    folds: list[tuple[str, str]] = []
    content = message.get("content")
    if isinstance(content, str):
        texts.append(content)
    elif isinstance(content, list):
        for part in content:
            if not isinstance(part, dict):
                texts.append(str(part))
                continue
            part_type = str(part.get("type") or "")
            if part_type in ("thinking", "reasoning"):
                folds.append(
                    ("Thinking", str(part.get("thinking") or part.get("text") or ""))
                )
            elif part_type in ("tool_use", "tool_call"):
                name = str(part.get("name") or "tool")
                body = part.get("input") or part.get("arguments") or {}
                if not isinstance(body, str):
                    body = json.dumps(body, ensure_ascii=False, indent=2)
                folds.append((f"Tool: {name}", body))
            elif part_type == "tool_result":
                body = part.get("content")
                if not isinstance(body, str):
                    body = json.dumps(body, ensure_ascii=False, indent=2)
                folds.append(("Tool result", body))
            else:
                value = part.get("text") or part.get("content") or ""
                texts.append(value if isinstance(value, str) else json.dumps(value, ensure_ascii=False))
    elif content is not None:
        texts.append(json.dumps(content, ensure_ascii=False, indent=2))
    for call in message.get("tool_calls") or []:
        if not isinstance(call, dict):
            continue
        function = call.get("function") if isinstance(call.get("function"), dict) else {}
        name = str(call.get("name") or function.get("name") or "tool")
        args = call.get("arguments") or function.get("arguments") or ""
        if not isinstance(args, str):
            args = json.dumps(args, ensure_ascii=False, indent=2)
        folds.append((f"Tool call: {name}", args))
    if role == "tool":
        summary = f"Tool result: {message.get('tool_name') or 'tool'}"
        body = "\n\n".join(texts)
        return (
            '<details class="fold tool"><summary>%s</summary><pre>%s</pre></details>'
            % (html.escape(summary), html.escape(body))
        )
    css_role = "user" if role == "user" else "assistant"
    body_html = "".join(
        '<div class="text">%s</div>' % html.escape(text) for text in texts if text
    )
    folds_html = "".join(
        '<details class="fold"><summary>%s</summary><pre>%s</pre></details>'
        % (html.escape(summary), html.escape(body))
        for summary, body in folds
    )
    return (
        '<article class="message %s"><div class="role">%s</div>%s%s</article>'
        % (css_role, html.escape(role), body_html, folds_html)
    )


def _render_session_html_export(payload: dict[str, Any]) -> str:
    """Render a self-contained, injection-safe HTML export of a session."""
    title = html.escape(str(payload.get("title") or "Hermes session"))
    cards = "".join(
        _export_message_html(message) for message in payload.get("messages") or []
    )
    meta = html.escape(
        "%s · %s messages · exported %s"
        % (
            payload.get("session_id") or "",
            payload.get("message_count") or 0,
            payload.get("exported_at") or "",
        )
    )
    return (
        '<!doctype html><html lang="zh-CN"><head><meta charset="utf-8">'
        '<meta name="viewport" content="width=device-width,initial-scale=1">'
        "<title>%s</title><style>%s</style></head><body>"
        '<main class="shell"><header><h1>%s</h1><div class="meta">%s</div></header>'
        "%s</main></body></html>"
    ) % (title, _EXPORT_HTML_CSS, title, meta, cards)


async def _backend_json_fallback(
    backend: BackendManager,
    method: str,
    primary_path: str,
    *,
    primary_query: dict | None = None,
    primary_body: Any = None,
    fallback_path: str,
    fallback_query: dict | None = None,
    fallback_body: Any = None,
) -> Any:
    """Call the Hermes Agent API, falling back to the WebUI-compatible route.

    Hermes Mobile has historically targeted the Agent ``/api/fs`` and modern
    mutable Git routes.  The standalone WebUI exposes the same read surface as
    ``/api/filesystem`` and uses ``repo`` instead of ``path``.  Retrying only
    a 404 keeps normal backend errors visible while making both deployments
    first-class mobile targets.
    """
    try:
        return await _backend_json(
            backend, method, primary_path, query=primary_query, body=primary_body
        )
    except HTTPException as exc:
        if exc.status_code != 404:
            raise
    return await _backend_json(
        backend, method, fallback_path, query=fallback_query, body=fallback_body
    )


def _row_id(row: dict) -> str:
    return str(row.get("id") or row.get("session_id") or "")


def _row_parent_id(row: dict) -> str:
    return str(row.get("parent_session_id") or row.get("parent_id") or "")


def _row_config(row: dict) -> dict:
    config = row.get("model_config") or {}
    if isinstance(config, str):
        try:
            config = json.loads(config)
        except (TypeError, ValueError):
            return {}
    return config if isinstance(config, dict) else {}


def _is_continuation_session(parent: dict | None, child: dict | None) -> bool:
    """Mirror WebUI ``_is_continuation_session`` exactly.

    A child is the next segment of the same conversation (compression rotation
    or CLI close + ``hermes -c``), NOT a sidebar child session.
    """
    if not parent or not child:
        return False
    if str(child.get("session_source") or "").strip().lower() == "fork":
        return False
    parent_source = str(parent.get("source") or "").strip().lower()
    child_source = str(child.get("source") or "").strip().lower()
    if parent_source and child_source and parent_source != child_source:
        return False
    if parent.get("end_reason") not in {"compression", "cli_close"}:
        return False
    ended_at = parent.get("ended_at")
    if ended_at is None:
        return True
    try:
        return float(child.get("started_at") or 0) >= float(ended_at)
    except (TypeError, ValueError):
        return False


def _is_child_session(row: dict, rows_by_id: dict[str, dict] | None = None) -> bool:
    """Any durable row with a parent that is not a compression continuation.

    Mirrors WebUI: children keep their own source (subagent, weixin, …); only
    continuation segments are collapsed away.
    """
    parent_id = _row_parent_id(row)
    if not parent_id:
        return False
    if rows_by_id is None:
        return True
    parent = rows_by_id.get(parent_id)
    return not _is_continuation_session(parent, row)


def _is_subagent_child(row: dict) -> bool:
    """Delegated child: read-only, hidden from write chokepoints."""
    return bool(_row_parent_id(row)) and str(row.get("source") or "").lower() == "subagent"


def _subagent_projection(row: dict, parent_id: str) -> dict:
    child_id = _row_id(row)
    projected = {
        **row,
        "id": child_id,
        "parent_id": parent_id,
    }
    # Normalize activity timestamps for state.db rows (last_activity_at) so
    # the client sidebar can sort/display children uniformly.
    last_activity = row.get("last_activity_at") or row.get("updated_at") or row.get("ended_at")
    projected.setdefault("updated_at", last_activity)
    projected.setdefault("last_message_at", last_activity)
    projected.setdefault("started_at", row.get("started_at") or row.get("created_at"))
    # WebUI generates a source-derived label for untitled delegated sessions
    # (e.g. desktop -> "Desktop Session").
    if not (row.get("title") or "").strip():
        source = str(row.get("source") or "").strip()
        if source:
            projected["title"] = f"{source.capitalize()} Session"
    if str(row.get("source") or "").lower() == "subagent":
        projected.update(
            {
                "child_session_id": child_id,
                "goal": row.get("title") or "Desktop Session",
                "status": "completed" if row.get("ended_at") else "running",
                "read_only": True,
                "is_cli_session": False,
            }
        )
    return projected


# Full child projection is expensive (paginated scan of every durable row).
# Cache it briefly and share one in-flight scan across list/subagent callers so
# a burst of sidebar refreshes cannot fan out into repeated upstream scans.
_CHILD_PROJECTION_TTL_SECONDS = 5.0
_CHILD_PROJECTION_MAX_PAGES = 200
_child_projection_cache: dict[tuple[str | None, bool], tuple[float, list[dict]]] = {}
_child_projection_inflight: dict[tuple[str | None, bool], asyncio.Task] = {}


def _read_state_db_sessions() -> list[dict]:
    """Read all sessions straight from Hermes ``state.db`` (read-only).

    WebUI parity: its GatewayWatcher reads state.db directly because the
    backend REST projection does not expose desktop/subagent-surface rows.
    A single indexed query is cheap and gives us parent lineage, source,
    end_reason and timestamps needed for the continuation predicate.
    """
    db_path = get_hermes_home() / "state.db"
    if not db_path.exists():
        return []
    uri = f"{db_path.resolve().as_uri()}?mode=ro"
    try:
        conn = sqlite3.connect(uri, uri=True)
    except sqlite3.Error as exc:
        logger.warning("[subagent] state.db read-only open failed: %s", exc)
        conn = sqlite3.connect(str(db_path))
    try:
        conn.row_factory = sqlite3.Row
        cols = {row[1] for row in conn.execute("PRAGMA table_info(sessions)")}
        if "source" not in cols or "parent_session_id" not in cols:
            return []

        def opt(col: str) -> str:
            return f"s.{col}" if col in cols else "NULL"

        rows = conn.execute(
            f"""
            SELECT s.id,
                   {opt('title')} AS title,
                   {opt('model')} AS model,
                   s.source,
                   {opt('cwd')} AS cwd,
                   {opt('message_count')} AS message_count,
                   {opt('parent_session_id')} AS parent_session_id,
                   {opt('session_source')} AS session_source,
                   {opt('started_at')} AS started_at,
                   {opt('ended_at')} AS ended_at,
                   {opt('end_reason')} AS end_reason,
                   {opt('last_activity_at')} AS last_activity_at,
                   {opt('archived')} AS archived,
                   {opt('pinned')} AS pinned,
                   {opt('profile_name')} AS profile_name
            FROM sessions s
            """
        ).fetchall()
        return [dict(row) for row in rows]
    except sqlite3.Error as exc:
        logger.warning("[subagent] state.db scan failed: %s", exc)
        return []
    finally:
        conn.close()


async def _scan_child_session_rows(
    backend: BackendManager,
    *,
    profile: str | None = None,
    include_archived: bool = False,
) -> list[dict]:
    """Read the complete durable child projection, honoring upstream paging.

    Stops on an empty page, ``has_more=false``, or when ``offset >= total``;
    no speculative EOF probing. A hard page cap protects against a broken
    upstream that never terminates.
    """
    all_rows: list[dict] = []
    offset = 0
    scan_started = time.perf_counter()
    for page_index in range(_CHILD_PROJECTION_MAX_PAGES):
        payload = await _backend_json(
            backend,
            "GET",
            "/api/sessions",
            query={
                "limit": 100,
                "offset": offset,
                "include_children": "true",
                **({"profile": profile} if profile else {}),
                "archived": "include" if include_archived else "exclude",
                "order": "recent",
            },
        )
        page = (payload or {}).get("sessions") or (payload or {}).get("data") or []
        logger.info(
            "[subagent] child scan page=%d offset=%d rows=%d has_more=%s total=%s",
            page_index, offset, len(page) if isinstance(page, list) else -1,
            (payload or {}).get("has_more"), (payload or {}).get("total"),
        )
        if not isinstance(page, list) or not page:
            break
        all_rows.extend(row for row in page if isinstance(row, dict))
        offset += len(page)
        total = (payload or {}).get("total")
        if (payload or {}).get("has_more") is False:
            break
        if isinstance(total, int) and offset >= total:
            break
    else:
        logger.warning(
            "[subagent] child projection scan hit page cap (%d pages, %d rows)",
            _CHILD_PROJECTION_MAX_PAGES, len(all_rows),
        )
    rows_by_id = {
        _row_id(row): row for row in all_rows if _row_id(row)
    }
    # The backend REST projection hides desktop/subagent-surface rows (WebUI's
    # GatewayWatcher reads state.db directly for the same reason). Merge the
    # direct state.db read so delegated Desktop Sessions reach the client.
    # REST rows win on conflicts: they carry live fields state.db lacks.
    db_rows = await asyncio.to_thread(_read_state_db_sessions)
    if profile is not None:
        db_rows = [row for row in db_rows if row.get("profile_name") == profile]
    if db_rows:
        merged = {_row_id(row): row for row in db_rows if _row_id(row)}
        merged.update(rows_by_id)
        rows_by_id = merged
        logger.info(
            "[subagent] state.db merge db_rows=%d rest_rows=%d merged=%d",
            len(db_rows), len(all_rows), len(rows_by_id),
        )
    children = [
        row for row in rows_by_id.values()
        if _is_child_session(row, rows_by_id)
        and (include_archived or not row.get("archived"))
        and (profile is None or not row.get("profile_name") or row.get("profile_name") == profile)
    ]
    logger.info(
        "[subagent] child scan complete pages=%d scanned=%d children=%d took=%.1fms",
        page_index + 1, len(all_rows), len(children),
        (time.perf_counter() - scan_started) * 1000,
    )
    return children


async def _all_child_session_rows(
    backend: BackendManager,
    *,
    profile: str | None = None,
    include_archived: bool = False,
) -> list[dict]:
    """Cached, de-duplicated wrapper around the full child projection scan."""
    key = (profile, include_archived)
    started = time.perf_counter()
    now = time.monotonic()
    cached = _child_projection_cache.get(key)
    if cached and now - cached[0] < _CHILD_PROJECTION_TTL_SECONDS:
        logger.info(
            "[subagent] child projection cache HIT key=%s age=%.2fs rows=%d took=%.1fms",
            key, now - cached[0], len(cached[1]),
            (time.perf_counter() - started) * 1000,
        )
        return cached[1]
    inflight = _child_projection_inflight.get(key)
    shared = inflight is not None
    if inflight is None:
        inflight = asyncio.ensure_future(
            _scan_child_session_rows(
                backend, profile=profile, include_archived=include_archived
            )
        )
        _child_projection_inflight[key] = inflight
    try:
        rows = await inflight
    finally:
        _child_projection_inflight.pop(key, None)
    _child_projection_cache[key] = (time.monotonic(), rows)
    logger.info(
        "[subagent] child projection cache %s key=%s rows=%d took=%.1fms",
        "SHARED-INFLIGHT" if shared else "MISS",
        key, len(rows), (time.perf_counter() - started) * 1000,
    )
    return rows


def _read_state_db_detail(session_id: str) -> dict | None:
    """Read one session row from state.db for surfaces hidden from REST."""
    for row in _read_state_db_sessions():
        if _row_id(row) == session_id:
            return row
    return None


def _read_state_db_messages(
    session_id: str, *, limit: int = 500, offset: int = 0
) -> list[dict]:
    """Read transcript rows from state.db for sessions REST cannot serve."""
    db_path = get_hermes_home() / "state.db"
    if not db_path.exists():
        return []
    uri = f"{db_path.resolve().as_uri()}?mode=ro"
    try:
        conn = sqlite3.connect(uri, uri=True)
    except sqlite3.Error:
        return []
    try:
        conn.row_factory = sqlite3.Row
        rows = conn.execute(
            """
            SELECT role, content, tool_call_id, tool_calls, tool_name,
                   timestamp, reasoning, reasoning_content, display_kind,
                   display_metadata
            FROM messages
            WHERE session_id = ? AND COALESCE(active, 1) = 1
            ORDER BY timestamp ASC, id ASC
            LIMIT ? OFFSET ?
            """,
            (session_id, limit, offset),
        ).fetchall()
        return [dict(row) for row in rows]
    except sqlite3.Error as exc:
        logger.warning("[subagent] state.db messages read failed: %s", exc)
        return []
    finally:
        conn.close()


async def _session_detail_compat(
    backend: BackendManager, session_id: str, *, profile: str | None = None
) -> dict:
    detail: Any = None
    try:
        detail = await _backend_json(
            backend,
            "GET",
            f"/api/sessions/{session_id}",
            query={"profile": profile} if profile else None,
        )
    except HTTPException as exc:
        if exc.status_code != 404:
            raise
    if not (isinstance(detail, dict) and _row_id(detail)):
        try:
            detail = await _backend_json(
                backend,
                "GET",
                "/api/session",
                query={
                    "session_id": session_id,
                    "messages": 0,
                    **({"profile": profile} if profile else {}),
                },
            )
        except HTTPException as legacy_exc:
            if legacy_exc.status_code != 404:
                raise
            detail = None
    if not (isinstance(detail, dict) and _row_id(detail)):
        detail = await asyncio.to_thread(_read_state_db_detail, session_id)
        if detail is None:
            raise HTTPException(status_code=404, detail="session not found")
    detail = dict(detail)
    if _is_subagent_child(detail):
        detail.update({"read_only": True, "is_cli_session": False})
    return detail


async def _session_messages_compat(
    backend: BackendManager,
    session_id: str,
    *,
    limit: int = 500,
    offset: int = 0,
    profile: str | None = None,
) -> list[Any]:
    try:
        payload = await _backend_json(
            backend,
            "GET",
            f"/api/sessions/{session_id}/messages",
            query={
                "limit": limit,
                "offset": offset,
                **({"profile": profile} if profile else {}),
            },
        )
        if isinstance(payload, dict) and isinstance(payload.get("messages"), list):
            return payload["messages"]
    except HTTPException as exc:
        if exc.status_code != 404:
            raise
    try:
        payload = await _backend_json(
            backend,
            "GET",
            "/api/session",
            query={
                "session_id": session_id,
                "messages": limit,
                "messages_offset": offset,
                **({"profile": profile} if profile else {}),
            },
        )
        if isinstance(payload, dict) and isinstance(payload.get("messages"), list):
            return payload["messages"]
    except HTTPException as legacy_exc:
        if legacy_exc.status_code != 404:
            raise
    return await asyncio.to_thread(
        _read_state_db_messages, session_id, limit=limit, offset=offset
    )


async def _reject_subagent_mutation(
    backend: BackendManager, session_id: str, *, profile: str | None = None
) -> None:
    try:
        detail = await _session_detail_compat(
            backend, session_id, profile=profile
        )
    except HTTPException as exc:
        if exc.status_code == 404:
            # Runtime-only sessions have no durable row yet; the route's own
            # RPC fallbacks (e.g. session.title) handle them.
            return
        raise
    if _is_subagent_child(detail):
        raise HTTPException(status_code=403, detail="subagent sessions are read-only")


def build_domain_router(
    settings: Settings,
    backend: BackendManager | None,
    *,
    task_store: TaskStore | None = None,
    profile_store: ProfileStore | None = None,
    prompt_store: SavedPromptsStore | None = None,
    local_executor: BoundedExecutor | None = None,
) -> APIRouter:
    router = APIRouter(
        prefix="/api/v1",
        dependencies=[Depends(api_key_dependency(settings))],
        tags=["domain"],
    )
    session_live_state = SessionLiveState()
    if backend is not None and hasattr(backend, "add_event_listener"):
        backend.add_event_listener(session_live_state.on_backend_event)
    if backend is not None and hasattr(backend, "add_lifecycle_listener"):
        backend.add_lifecycle_listener(session_live_state.reset)

    def require_backend() -> BackendManager:
        if backend is None or not backend.is_running:
            raise HTTPException(status_code=503, detail="Hermes backend is not running")
        return backend

    # Own executor when the caller (app.py, in production) doesn't share one
    # explicitly — keeps every existing `build_domain_router(settings,
    # backend)` call site (tests included) working unchanged.
    _local_executor = local_executor or BoundedExecutor(
        settings.local_fs_max_workers, thread_name_prefix="hermes-local-fs"
    )

    async def local(call):
        """Run a local-workspace call off the event loop.

        File/Git operations shell out (`subprocess.run`) or walk directory
        trees; run inline they'd block every other concurrent request (REST
        and WS relay alike) for their duration. Workspace failures still
        become a stable client 422.
        """
        try:
            return await _local_executor.run(call)
        except local_workspace.WorkspaceError as exc:
            raise HTTPException(status_code=422, detail=str(exc)) from exc

    # ------------------------------------------------------------ sessions
    @router.post("/sessions")
    async def create_session(
        payload: dict = Body(default={}),
    ) -> dict:
        """Create a session; the durable id is the only id the client stores."""
        be = require_backend()
        params: dict = {"cols": 48, "source": "mobile"}
        cwd = (payload or {}).get("cwd")
        if cwd:
            params["cwd"] = cwd
        try:
            result = await be.gateway_rpc("session.create", params)
        except BackendError as exc:
            raise HTTPException(status_code=502, detail=str(exc))
        return {
            "id": result.get("stored_session_id"),
            "session_id": result.get("session_id"),
            "info": result.get("info"),
        }

    @router.get("/sessions")
    async def list_sessions(
        limit: int = Query(50, ge=1, le=500),
        offset: int = Query(0, ge=0),
        q: str | None = None,
        profile: str | None = None,
        include_archived: bool = False,
    ) -> dict:
        """List durable sessions; ``q`` enables server-side FTS search.

        Returns extended session row fields matching WebUI agent-session module:
        is_streaming, cron_running, pending_user_message, active_stream_id,
        last_message_at, archived, pinned, composer_draft preview, profile.

        Desktop parity: offset pagination mirrors Hermes' own
        ``GET /api/sessions`` contract (``{sessions, total, limit, offset}``).
        Hermes caps a single page at 100 rows, so wider mobile pages are
        fulfilled by stitching consecutive Hermes pages before slicing.
        The response includes ``total``/``offset`` so the client can drive
        "load more" rows exactly like the desktop sidebar's pageWindow().
        """
        be = require_backend()
        list_started = time.perf_counter()
        logger.info(
            "[subagent] list_sessions start limit=%d offset=%d profile=%s archived=%s q=%s",
            limit, offset, profile, include_archived, bool(q),
        )
        if q:
            data = await _backend_json(
                be, "GET", "/api/sessions/search",
                query={
                    "q": q,
                    "limit": min(limit, 100),
                    "archived": "include" if include_archived else "exclude",
                    **({"profile": profile} if profile else {}),
                },
            )
            results = (data or {}).get("results", [])
            return {
                "sessions": [
                    session_live_state.project(row)
                    for row in results
                    if isinstance(row, dict)
                ],
                "total": None,
                "offset": 0,
            }

        async def _fetch_page(page_offset: int, page_limit: int) -> dict:
            list_query = {
                "limit": page_limit,
                "offset": page_offset,
                "include_children": "false",
                **({"profile": profile} if profile else {}),
                "archived": "include" if include_archived else "exclude",
                "order": "recent",
            }
            # Explicit profile selection must use the profile-scoped projection;
            # the runtime-global route follows whichever Hermes profile is active.
            primary_path = "/api/profiles/sessions" if profile is not None else "/api/sessions"
            fallback_path = "/api/sessions" if profile is not None else "/api/profiles/sessions"
            try:
                return await _backend_json(be, "GET", primary_path, query=list_query) or {}
            except HTTPException as exc:
                if exc.status_code != 404:
                    raise
                return await _backend_json(be, "GET", fallback_path, query=list_query) or {}

        # Stitch pages: Hermes caps one page at 100 rows. When the upstream
        # does not report ``total``, request one extra row as an EOF probe so
        # ``has_more`` is not falsely true just because we filled the window.
        rows: list[dict] = []
        total: int | None = None
        fetched = 0
        cursor = offset
        has_more = False
        while fetched < limit:
            page_size = min(limit - fetched, 100)
            request_size = page_size + 1 if total is None else page_size
            data = await _fetch_page(cursor, request_size)
            page = data.get("sessions", []) or []
            if total is None and isinstance(data.get("total"), int):
                total = data["total"]
            if not isinstance(page, list) or not page:
                break
            if total is None and len(page) > page_size:
                has_more = True
                rows.extend(r for r in page[:page_size] if isinstance(r, dict))
                fetched += page_size
                break
            rows.extend(r for r in page if isinstance(r, dict))
            fetched += len(page)
            cursor += len(page)
            if len(page) < page_size:
                break
        detail_semaphore = asyncio.Semaphore(8)

        async def _enrich_session(row: dict) -> dict:
            sid = row.get("session_id") or row.get("id") or ""
            merged = dict(row)
            needs_detail = bool(sid) and (
                "parent_session_id" not in merged and "parent_id" not in merged
            )
            needs_live_fields = bool(sid) and not any(k in merged for k in (
                "is_streaming", "cron_running", "pending_user_message",
                "last_message_at", "archived", "pinned", "composer_draft",
            ))
            if needs_detail or needs_live_fields:
                try:
                    async with detail_semaphore:
                        detail = await _backend_json(
                            be,
                            "GET",
                            f"/api/sessions/{sid}",
                            query={"profile": profile} if profile is not None else None,
                        ) or {}
                    for k in (
                        "is_streaming", "cron_running", "pending_user_message",
                        "has_pending_user_message", "active_stream_id",
                        "last_message_at", "archived", "pinned",
                        "composer_draft", "profile", "parent_session_id", "parent_id",
                    ):
                        if k in detail and k not in merged:
                            merged[k] = detail[k]
                except Exception:
                    pass
            row_profile = merged.get("profile") or profile
            share = (
                share_store.for_session(str(sid), profile=row_profile)
                if sid else None
            )
            if share:
                merged["share_token"] = share.get("token")
                merged["share_created_at"] = share.get("created_at")
            if profile is not None and not (merged.get("profile") or merged.get("profile_name")):
                merged["profile"] = profile
            return merged

        enriched = await asyncio.gather(*(
            _enrich_session(row) for row in rows if isinstance(row, dict)
        ))
        visible_ids = {
            _row_id(row) for row in enriched if isinstance(row, dict) and _row_id(row)
        }
        child_rows = await _all_child_session_rows(
            be, profile=profile, include_archived=include_archived
        )
        children: list[dict] = []
        known_ids = set(visible_ids)
        remaining = list(child_rows)
        while remaining:
            attached_this_pass: list[dict] = []
            still_remaining: list[dict] = []
            for row in remaining:
                child_id = _row_id(row)
                # Hermes may still return some parented rows (e.g. mobile forks)
                # even when include_children=false. Skip those — re-attaching
                # the same id produces duplicate expandable children in the UI.
                if not child_id or child_id in known_ids:
                    continue
                parent_id = _row_parent_id(row)
                if parent_id not in known_ids:
                    still_remaining.append(row)
                    continue
                child = _subagent_projection(row, parent_id)
                attached_this_pass.append(child)
                known_ids.add(child_id)
            if not attached_this_pass:
                break
            children.extend(attached_this_pass)
            remaining = still_remaining
        logger.info(
            "[subagent] session projection visible_parents=%d scanned_children=%d attached=%d",
            len(visible_ids), len(child_rows), len(children),
        )
        enriched.extend(children)
        by_id = {str(row.get("session_id") or row.get("id"))
            for row in enriched
            if isinstance(row, dict) and (row.get("session_id") or row.get("id"))
        }
        pending_parent_ids = [
            str(row.get("parent_session_id") or row.get("parent_id"))
            for row in enriched
            if isinstance(row, dict)
            and (row.get("parent_session_id") or row.get("parent_id"))
            and str(row.get("parent_session_id") or row.get("parent_id")) not in by_id
        ]
        fetched_parent_ids: set[str] = set()
        while pending_parent_ids:
            parent_id = pending_parent_ids.pop(0)
            if parent_id in by_id or parent_id in fetched_parent_ids:
                continue
            fetched_parent_ids.add(parent_id)
            try:
                parent = await _backend_json(
                    be,
                    "GET",
                    f"/api/sessions/{parent_id}",
                    query={"profile": profile} if profile is not None else None,
                )
            except HTTPException:
                # Deleted/inaccessible parents leave their child as a root.
                continue
            if not isinstance(parent, dict):
                continue
            parent_sid = str(parent.get("session_id") or parent.get("id") or parent_id)
            parent = {**parent, "id": parent_sid}
            if profile is not None and not (parent.get("profile") or parent.get("profile_name")):
                parent["profile"] = profile
            enriched.append(parent)
            by_id.add(parent_sid)
            ancestor = parent.get("parent_session_id") or parent.get("parent_id")
            if ancestor and str(ancestor) not in by_id:
                pending_parent_ids.append(str(ancestor))
        if profile is not None:
            for row in enriched:
                if not (row.get("profile") or row.get("profile_name")):
                    row["profile"] = profile
        enriched = [session_live_state.project(row) for row in enriched]
        logger.info(
            "[subagent] list_sessions complete rows=%d children_attached=%d parents_fetched=%d took=%.1fms",
            len(enriched), len(children), len(fetched_parent_ids),
            (time.perf_counter() - list_started) * 1000,
        )
        return {
            "sessions": enriched,
            # Desktop parity: expose the paging window so the sidebar can
            # render a "load more" row (has_more) instead of guessing.
            "total": total,
            "offset": offset,
            "has_more": (total is not None and offset + fetched < total)
            or (total is None and has_more),
        }

    # Register this literal route before /sessions/{session_id}; otherwise a
    # POST is consumed by the detail route's path match and Starlette returns
    # 405 without reaching the batch handler.
    @router.post("/sessions/batch-delete")
    async def batch_delete_sessions(
        payload: dict = Body(...), profile: str | None = Query(None)
    ) -> Any:
        """Batch delete multiple sessions (WebUI sidebar bulk-delete parity)."""
        require_backend()
        ids = payload.get("ids") if isinstance(payload, dict) else None
        if not isinstance(ids, list) or not ids:
            raise HTTPException(status_code=400, detail="ids must be a non-empty list")
        deleted: list[str] = []
        failed: list[dict] = []
        for sid in ids:
            sid_str = str(sid)
            try:
                await delete_session(sid_str, profile=profile)
                deleted.append(sid_str)
            except Exception as exc:
                failed.append({"id": sid_str, "error": str(exc)})
        return {"deleted": deleted, "failed": failed}

    @router.post("/profiles/sessions/pull-requests")
    async def scan_session_pull_requests(payload: dict = Body(...)) -> Any:
        """Proxy Hermes' durable transcript-to-PR association scan."""
        ids = payload.get("ids") if isinstance(payload, dict) else None
        if not isinstance(ids, list) or any(not isinstance(item, str) for item in ids):
            raise HTTPException(status_code=400, detail="ids must be a list of strings")
        return await _backend_json(
            require_backend(),
            "POST",
            "/api/profiles/sessions/pull-requests",
            body={"ids": ids},
        )

    @router.get("/sessions/{session_id}")
    async def session_detail(session_id: str, profile: str | None = None) -> Any:
        be = require_backend()
        detail = await _session_detail_compat(be, session_id, profile=profile)
        return session_live_state.project(detail)

    @router.get("/sessions/{session_id}/messages")
    async def session_messages(
        session_id: str,
        limit: int = Query(500, ge=1, le=500),
        offset: int = Query(0, ge=0),
        profile: str | None = None,
    ) -> Any:
        be = require_backend()
        messages = await _session_messages_compat(
            be, session_id, limit=limit, offset=offset, profile=profile
        )
        detail = await _session_detail_compat(be, session_id, profile=profile)
        total = int(detail.get("message_count") or 0) if isinstance(detail, dict) else 0
        result = {"session_id": session_id, "messages": messages, "total": total}
        # Hermes' session.branch count slices the raw gateway history, while
        # mobile merges tool-result rows into their assistant card. Preserve
        # the original zero-based history address so branching an old rendered
        # message never under-counts hidden/merged rows.
        if isinstance(result.get("messages"), list):
            result = dict(result)
            result["messages"] = [
                ({**row, "history_ordinal": offset + index}
                 if isinstance(row, dict) else row)
                for index, row in enumerate(result["messages"])
            ]
        return result

    @router.post("/sessions/{session_id}/open")
    async def open_session(session_id: str) -> dict:
        """Idempotent snapshot for opening a session (D8).

        Returns messages + session detail. Live binding still happens on the
        client's own WS via ``session.resume`` (see DESIGN.md §1.3).
        """
        be = require_backend()
        messages = await _session_messages_compat(
            be, session_id, limit=500, offset=0
        )
        detail = await _session_detail_compat(be, session_id)
        return {
            "id": session_id,
            "messages": messages,
            "detail": detail or {},
        }

    @router.patch("/sessions/{session_id}")
    async def patch_session(
        session_id: str,
        payload: dict = Body(...),
        profile: str | None = None,
    ) -> Any:
        be = require_backend()
        if not isinstance(payload, dict):
            raise HTTPException(status_code=422, detail="object body required")
        supported = {"title", "archived", "pinned", "project_id"}
        unknown = set(payload) - supported
        if unknown:
            raise HTTPException(status_code=422, detail=f"unsupported fields: {', '.join(sorted(unknown))}")
        await _reject_subagent_mutation(be, session_id, profile=profile)
        result: Any = {"ok": True}
        canonical = {
            field: payload[field]
            for field in ("title", "archived", "pinned")
            if field in payload
        }
        if canonical:
            try:
                result = await _backend_json(
                    be,
                    "PATCH",
                    f"/api/sessions/{session_id}",
                    query={"profile": profile} if profile else None,
                    body=canonical,
                )
            except HTTPException as exc:
                # Fresh chats and newly-created branches live only in the
                # gateway's runtime session map until their first turn is
                # persisted.  The canonical REST PATCH therefore returns 404
                # for them.  Desktop handles this exact case through
                # ``session.title``, which both renames and persists the live
                # session.  Keep the fallback deliberately narrow: archive
                # and pin remain durable-row operations, and the RPC rejects
                # an empty title.
                title = str(canonical.get("title") or "").strip()
                if exc.status_code != 404 or set(canonical) != {"title"} or not title:
                    raise
                try:
                    result = await be.gateway_rpc(
                        "session.title",
                        {
                            "session_id": session_id,
                            "title": title,
                            **({"profile": profile} if profile else {}),
                        },
                    )
                except BackendError as rpc_exc:
                    raise HTTPException(status_code=502, detail=str(rpc_exc)) from rpc_exc
        if "project_id" in payload:
            result = await move_session(
                session_id, {"project_id": payload["project_id"]},
                profile=profile,
            )
        return result

    @router.delete("/sessions/{session_id}")
    async def delete_session(
        session_id: str, profile: str | None = Query(None)
    ) -> dict:
        be = require_backend()
        await _reject_subagent_mutation(be, session_id, profile=profile)
        return _ok_response(
            await _backend_json(
                be, "DELETE", f"/api/sessions/{session_id}",
                query={"profile": profile} if profile else None,
            )
        )

    @router.get("/sessions/{session_id}/draft")
    async def get_session_draft(
        session_id: str, profile: str | None = Query(None)
    ) -> dict:
        """Return the persisted composer draft for a session (WebUI parity).

        GET /api/v1/sessions/{id}/draft -> {"draft": {"text": str, "files": list}}
        """
        # Current Hermes releases removed /api/session/draft.  Use the mobile
        # server's durable fallback rather than repeatedly probing that 404.
        draft = _draft_store.get(session_id, profile=profile)
        return {"draft": {"text": draft.get("text", ""), "files": draft.get("files", [])}}

    @router.post("/sessions/{session_id}/draft")
    async def save_session_draft(
        session_id: str, payload: dict = Body(default={}),
        profile: str | None = Query(None),
    ) -> dict:
        """Persist the composer draft (text + attachments) for a session.

        Mirrors WebUI POST /api/session/draft:
        - body: {"text": str (optional), "files": list (optional)}
        - input size caps: 50 KB text, 50 file entries
        - does NOT touch session updated_at (typing must not trigger end-of-turn reloads)
        """
        text = payload.get("text") if isinstance(payload, dict) else None
        files = payload.get("files") if isinstance(payload, dict) else None
        _MAX_DRAFT_TEXT = 50_000
        _MAX_DRAFT_FILES = 50
        if text is not None and not isinstance(text, str):
            text = ""
        if isinstance(text, str) and len(text) > _MAX_DRAFT_TEXT:
            text = text[:_MAX_DRAFT_TEXT]
        if files is not None and not isinstance(files, list):
            files = []
        if isinstance(files, list) and len(files) > _MAX_DRAFT_FILES:
            files = files[:_MAX_DRAFT_FILES]
        draft = _draft_store.save(
            session_id, text=text, files=files, profile=profile
        )
        return {"ok": True, "draft": draft}

    @router.put("/sessions/{session_id}/pin")
    async def pin_session(
        session_id: str, payload: dict = Body(default={}),
        profile: str | None = Query(None),
    ) -> Any:
        """Pin/unpin a session to the top of the sidebar list.

        Mirrors WebUI pin/unpin actions. Pinned sessions appear in the
        dedicated 'Pinned' group above the time-grouped recent list.
        """
        be = require_backend()
        await _reject_subagent_mutation(be, session_id, profile=profile)
        pinned = bool((payload or {}).get("pinned", True))
        return await _backend_json(
            be, "PATCH", f"/api/sessions/{session_id}",
            query={"profile": profile} if profile else None,
            body={"pinned": pinned}
        )

    @router.post("/sessions/{session_id}/branch")
    async def branch_session(
        session_id: str, payload: dict = Body(default={}),
        profile: str | None = Query(None),
    ) -> dict:
        """Fork a stored session without first changing the mobile active session."""
        be = require_backend()
        await _reject_subagent_mutation(be, session_id, profile=profile)
        branch_params: dict[str, Any] = {}
        keep_count = (payload or {}).get("keep_count")
        if keep_count is not None:
            if not isinstance(keep_count, int) or keep_count < 0:
                raise HTTPException(status_code=422, detail="keep_count must be non-negative")
            branch_params["count"] = keep_count
        title = str((payload or {}).get("title") or "").strip()
        if title:
            branch_params["name"] = title[:80]
        try:
            resumed = await be.gateway_rpc(
                "session.resume",
                {
                    "session_id": session_id,
                    "cols": 48,
                    "source": "mobile",
                    "omit_messages": True,
                    **({"profile": profile} if profile else {}),
                },
            )
            runtime_id = resumed.get("session_id")
            if not runtime_id:
                raise BackendError("session.resume returned no runtime session id")
            result = await be.gateway_rpc(
                "session.branch", {"session_id": runtime_id, **branch_params}
            )
        except BackendError as exc:
            raise HTTPException(status_code=502, detail=str(exc)) from exc
        new_id = result.get("stored_session_id") or result.get("session_id")
        detail: dict[str, Any] = {}
        if new_id:
            try:
                raw = await _backend_json(
                    be, "GET", f"/api/sessions/{new_id}",
                    query={"profile": profile} if profile else None,
                ) or {}
                if isinstance(raw, dict):
                    detail = raw.get("session", raw)
            except HTTPException:
                detail = {}
        return {
            **result,
            "session": {
                "id": new_id,
                "session_id": new_id,
                "title": result.get("title"),
                "parent_session_id": session_id,
                **detail,
            },
        }

    @router.post("/sessions/{session_id}/duplicate")
    async def duplicate_session(
        session_id: str, profile: str | None = Query(None)
    ) -> dict:
        """Create an independent copy of a durable Hermes session.

        Current ``hermes serve`` intentionally has no legacy
        ``/api/session/duplicate`` route.  Its canonical session import API is
        the lossless way to materialise another durable row, so compose the
        copy from the authoritative detail and message endpoints.  Unlike
        ``session.branch`` this does not create lineage: it mirrors WebUI's
        duplicate action (same transcript/workspace/model, fresh lifecycle).
        """
        be = require_backend()
        await _reject_subagent_mutation(be, session_id, profile=profile)
        source = await _session_detail_compat(be, session_id, profile=profile)
        messages = await _session_messages_compat(be, session_id, profile=profile)
        if not isinstance(source, dict):
            raise HTTPException(status_code=404, detail="session not found")
        now = time.time()
        duplicate_id = f"{time.strftime('%Y%m%d_%H%M%S')}_{secrets.token_hex(4)}"
        title = str(source.get("title") or "Untitled").strip() or "Untitled"
        # SessionDB.import_sessions accepts the canonical exported row. Remove
        # identity/lifecycle/lineage fields whose values must belong to the new
        # independent session, while retaining real Hermes configuration.
        copied = {
            key: value
            for key, value in source.items()
            if key
            not in {
                "id", "session_id", "parent_id", "parent_session_id",
                "pinned", "archived", "share_token", "share_created_at",
                "created_at", "updated_at", "started_at", "ended_at",
                "end_reason", "active_stream_id", "is_streaming",
            }
        }
        copied.update(
            {
                "id": duplicate_id,
                "session_id": duplicate_id,
                "title": f"{title} (copy)",
                "source": source.get("source") or "mobile",
                "started_at": now,
                "ended_at": now,
                "end_reason": "duplicated",
                "pinned": False,
                "archived": False,
                "messages": messages if isinstance(messages, list) else [],
            }
        )
        imported = await _backend_json(
            be, "POST", "/api/sessions/import", body={"sessions": [copied]}
        )
        if not isinstance(imported, dict) or int(imported.get("imported") or 0) != 1:
            raise HTTPException(status_code=502, detail="Hermes did not import the duplicate")
        detail = await _backend_json(
            be, "GET", f"/api/sessions/{duplicate_id}",
            query={"profile": profile} if profile else None,
        )
        return {"ok": True, "session": detail}

    @router.post("/sessions/{session_id}/title/regenerate")
    async def regenerate_session_title(
        session_id: str, payload: dict = Body(default={}),
        profile: str | None = Query(None),
    ) -> dict:
        """Generate and persist a title through Hermes' real auxiliary LLM."""
        be = require_backend()
        messages = await _all_session_messages(be, session_id, profile=profile)
        transcript: list[str] = []
        for row in messages if isinstance(messages, list) else []:
            if not isinstance(row, dict) or row.get("role") not in {"user", "assistant"}:
                continue
            content = row.get("content")
            if isinstance(content, str) and content.strip():
                transcript.append(f"{row.get('role')}: {content.strip()}")
        if not transcript:
            raise HTTPException(status_code=422, detail="session has no titleable messages")
        # WebUI defaults to the opening topic; prefer_latest lets callers use
        # the newest turns after a conversation changes direction.
        excerpt = transcript[-12:] if bool((payload or {}).get("prefer_latest")) else transcript[:12]
        try:
            generated = await be.gateway_rpc(
                "llm.oneshot",
                {
                    "task": "title_generation",
                    "instructions": (
                        "Generate one concise conversation title in the same language "
                        "as the conversation. Return only the title, without quotes, "
                        "markdown, punctuation wrappers, or explanation. Maximum 60 characters."
                    ),
                    "input": "\n".join(excerpt)[:12000],
                    "max_tokens": 80,
                    "temperature": 0.2,
                },
                timeout=120.0,
            )
            title = str(generated.get("text") or "").strip().strip('"\'`# ')
            title = " ".join(title.splitlines()).strip()[:80]
            if not title:
                raise BackendError("title generator returned an empty title")
            resumed = await be.gateway_rpc(
                "session.resume",
                {
                    "session_id": session_id,
                    "cols": 48,
                    "source": "mobile",
                    "omit_messages": True,
                    **({"profile": profile} if profile else {}),
                },
            )
            runtime_id = str(resumed.get("session_id") or "").strip()
            if not runtime_id:
                raise BackendError("session.resume returned no runtime session id")
            await be.gateway_rpc(
                "session.title", {"session_id": runtime_id, "title": title}
            )
        except BackendError as exc:
            raise HTTPException(status_code=502, detail=str(exc)) from exc
        return {"ok": True, "title": title, "session": {"id": session_id, "title": title}}

    @router.post("/sessions/{session_id}/move")
    async def move_session(
        session_id: str, payload: dict = Body(default={}),
        profile: str | None = Query(None),
    ) -> Any:
        be = require_backend()
        project_id = str((payload or {}).get("project_id") or "").strip()
        if not project_id:
            raise HTTPException(status_code=422, detail="project_id is required")

        try:
            snapshot = await be.gateway_rpc("projects.list", {})
            projects = snapshot.get("projects", []) if isinstance(snapshot, dict) else []
            project = next(
                (
                    item
                    for item in projects
                    if isinstance(item, dict) and str(item.get("id")) == project_id
                ),
                None,
            )
            if project is None:
                raise HTTPException(status_code=404, detail="project not found")

            cwd = str(project.get("path") or "").strip()
            if not cwd:
                repos = project.get("repos") or []
                cwd = next(
                    (
                        str(repo.get("path")).strip()
                        for repo in repos
                        if isinstance(repo, dict) and str(repo.get("path") or "").strip()
                    ),
                    "",
                )
            if not cwd:
                raise HTTPException(
                    status_code=422, detail="target project has no working folder"
                )

            return await be.gateway_rpc(
                "session.workspace.move", {
                    "cwd": cwd,
                    "session_key": session_id,
                    **({"profile": profile} if profile else {}),
                }
            )
        except HTTPException:
            raise
        except BackendError as exc:
            raise HTTPException(status_code=502, detail=str(exc)) from exc

    @router.post("/sessions/{session_id}/workspace")
    async def set_session_workspace(
        session_id: str, payload: dict = Body(default={}),
        profile: str | None = Query(None),
    ) -> Any:
        """Move the session's working directory to an explicit cwd.

        Same gateway ``session.workspace.move`` the desktop composer workspace
        chip uses; ``/sessions/{id}/move`` only accepts project ids, while the
        composer can also pick the server's default cwd or any project path.
        """
        be = require_backend()
        cwd = str((payload or {}).get("cwd") or "").strip()
        if not cwd:
            raise HTTPException(status_code=422, detail="cwd is required")
        try:
            return await be.gateway_rpc(
                "session.workspace.move", {
                    "cwd": cwd,
                    "session_key": session_id,
                    **({"profile": profile} if profile else {}),
                }
            )
        except BackendError as exc:
            raise HTTPException(status_code=502, detail=str(exc)) from exc

    @router.post("/sessions/import")
    async def import_sessions(payload: dict = Body(...)) -> Any:
        return await _backend_json(
            require_backend(), "POST", "/api/sessions/import", body=payload
        )

    @router.get("/sessions/{session_id}/export")
    async def export_session(
        session_id: str,
        response: Response,
        format: str = Query("json", pattern="^(json|html)$"),
        profile: str | None = Query(None),
    ) -> dict:
        """Return a transport-safe export built from Hermes' canonical session API."""
        be = require_backend()
        session = await _backend_json(
            be, "GET", f"/api/sessions/{session_id}",
            query={"profile": profile} if profile else None,
        ) or {}
        messages = await _all_session_messages(be, session_id, profile=profile)
        payload = {
            "exported_at": datetime.now(timezone.utc).isoformat(),
            "session_id": session_id,
            "title": session.get("title") if isinstance(session, dict) else None,
            "session": session,
            "message_count": len(messages),
            "messages": messages,
        }
        if format == "html":
            content = _render_session_html_export(payload)
            mime_type = "text/html; charset=utf-8"
        else:
            content = json.dumps(payload, ensure_ascii=False, indent=2)
            mime_type = "application/json"
        filename = f"hermes-{session_id}.{format}"
        safe_filename = re.sub(r"[^A-Za-z0-9._-]", "_", filename)
        response.headers["Content-Disposition"] = (
            f'attachment; filename="{safe_filename}"'
        )
        return {
            "filename": filename,
            "mime_type": mime_type,
            "content": content,
        }

    @router.post("/sessions/{session_id}/share")
    async def create_session_share(
        session_id: str, profile: str | None = Query(None)
    ) -> dict:
        """Create or refresh an immutable public snapshot from real Hermes data."""
        be = require_backend()
        session = await _backend_json(
            be, "GET", f"/api/sessions/{session_id}",
            query={"profile": profile} if profile else None,
        )
        messages = await _all_session_messages(be, session_id, profile=profile)
        if not isinstance(session, dict):
            raise HTTPException(status_code=404, detail="session not found")
        if not isinstance(messages, list) or not messages:
            raise HTTPException(status_code=422, detail="empty sessions cannot be shared")
        snapshot = share_store.create(
            session_id, session, messages, profile=profile
        )
        return {
            "ok": True,
            "share": {
                "token": snapshot["token"],
                "url": f"/share/{snapshot['token']}",
                "title": snapshot["title"],
                "message_count": snapshot["message_count"],
                "created_at": snapshot["created_at"],
            },
            "session": {
                **session,
                "share_token": snapshot["token"],
                "share_created_at": snapshot["created_at"],
            },
        }

    @router.delete("/sessions/{session_id}/share")
    async def revoke_session_share(
        session_id: str, profile: str | None = Query(None)
    ) -> dict:
        if not share_store.revoke(session_id, profile=profile):
            raise HTTPException(status_code=404, detail="session share not found")
        return {"ok": True, "session_id": session_id}

    @router.post("/sessions/{session_id}/stop")
    async def stop_session_stream(
        session_id: str, payload: dict = Body(default={}),
        profile: str | None = Query(None),
    ) -> Any:
        be = require_backend()
        # ``active_stream_id`` is a stream identity, not a gateway runtime
        # session id. Resume the durable row first and interrupt that runtime;
        # the previous implementation knowingly sent the stream id as a
        # session id and paid for a failed RPC on every stop.
        try:
            resumed = await be.gateway_rpc(
                "session.resume",
                {
                    "session_id": session_id,
                    "cols": 48,
                    "source": "mobile",
                    "omit_messages": True,
                    **({"profile": profile} if profile else {}),
                },
            )
            runtime_id = str(resumed.get("session_id") or "").strip()
            if not runtime_id:
                raise BackendError("session.resume returned no runtime session id")
            return await be.gateway_rpc(
                "session.interrupt", {"session_id": runtime_id}
            )
        except BackendError as exc:
            raise HTTPException(status_code=502, detail=str(exc)) from exc

    # -------------------------------------------------------------- config
    @router.get("/config")
    async def get_config(profile: str | None = Query(None)) -> dict:
        """Full normalized Hermes config, preserving unknown/plugin fields."""
        be = require_backend()
        query = {"profile": profile} if profile else None
        full = await _backend_json(be, "GET", "/api/config", query=query) or {}
        return {"config": _config_document(full)}

    @router.get("/config/schema")
    async def get_config_schema(profile: str | None = Query(None)) -> Any:
        query = {"profile": profile} if profile else None
        return await _backend_json(require_backend(), "GET", "/api/config/schema", query=query)

    @router.get("/config/defaults")
    async def get_config_defaults(profile: str | None = Query(None)) -> dict:
        query = {"profile": profile} if profile else None
        full = await _backend_json(require_backend(), "GET", "/api/config/defaults", query=query) or {}
        return {"config": _config_document(full)}

    @router.put("/config")
    async def put_config(
        payload: dict = Body(...), profile: str | None = Query(None)
    ) -> Any:
        """Deep-merge an open-world Hermes config document."""
        be = require_backend()
        query = {"profile": profile} if profile else None
        return await _backend_json(
            be,
            "PUT",
            "/api/config",
            query=query,
            body={"config": _config_document(payload.get("config", {}))},
        )

    @router.put("/config/replace")
    async def replace_config(
        payload: dict = Body(...), profile: str | None = Query(None)
    ) -> Any:
        """Replace the full config document, including deletion of omitted keys."""
        document = _config_document(payload.get("config"))
        query = {"profile": profile} if profile else None
        return await _backend_json(
            require_backend(),
            "PUT",
            "/api/config/raw",
            query=query,
            body={"yaml_text": yaml.safe_dump(document, sort_keys=False)},
        )

    @router.get("/config/raw")
    async def get_raw_config(profile: str | None = Query(None)) -> dict:
        query = {"profile": profile} if profile else None
        payload = await _backend_json(require_backend(), "GET", "/api/config/raw", query=query) or {}
        raw = yaml.safe_load(str(payload.get("yaml") or "")) or {}
        return {"config": _config_document(raw), "path": payload.get("path")}

    # Open-world configuration adjuncts used by the schema-driven mobile UI.
    @router.get("/env")
    async def get_env(profile: str | None = Query(None)) -> Any:
        return await _backend_json(require_backend(), "GET", "/api/env", query={"profile": profile} if profile else None)

    @router.put("/env")
    async def put_env(payload: dict = Body(...), profile: str | None = Query(None)) -> Any:
        return await _backend_json(require_backend(), "PUT", "/api/env", query={"profile": profile} if profile else None, body=payload)

    @router.delete("/env")
    async def delete_env(payload: dict = Body(...), profile: str | None = Query(None)) -> dict:
        return _ok_response(
            await _backend_json(
                require_backend(), "DELETE", "/api/env",
                query={"profile": profile} if profile else None,
                body=payload,
            )
        )

    @router.post("/env/reveal")
    async def reveal_env(payload: dict = Body(...), profile: str | None = Query(None)) -> Any:
        return await _backend_json(require_backend(), "POST", "/api/env/reveal", query={"profile": profile} if profile else None, body=payload)

    @router.get("/providers/custom-endpoints")
    async def custom_endpoints(profile: str | None = Query(None)) -> Any:
        return await _backend_json(require_backend(), "GET", "/api/providers/custom-endpoints", query={"profile": profile} if profile else None)

    @router.post("/providers/custom-endpoints")
    async def save_custom_endpoint(payload: dict = Body(...), profile: str | None = Query(None)) -> Any:
        return await _backend_json(require_backend(), "POST", "/api/providers/custom-endpoints", query={"profile": profile} if profile else None, body=payload)

    @router.post("/providers/custom-endpoints/validate")
    async def validate_custom_endpoint(
        payload: dict = Body(...), profile: str | None = Query(None)
    ) -> Any:
        return await _backend_json(
            require_backend(),
            "POST",
            "/api/providers/custom-endpoints/validate",
            query={"profile": profile} if profile else None,
            body=payload,
        )

    @router.post("/providers/custom-endpoints/{endpoint_id}/activate")
    async def activate_custom_endpoint(endpoint_id: str, profile: str | None = Query(None)) -> Any:
        return await _backend_json(require_backend(), "POST", f"/api/providers/custom-endpoints/{endpoint_id}/activate", query={"profile": profile} if profile else None)

    @router.delete("/providers/custom-endpoints/{endpoint_id}")
    async def delete_custom_endpoint(endpoint_id: str, profile: str | None = Query(None)) -> dict:
        return _ok_response(
            await _backend_json(
                require_backend(),
                "DELETE",
                f"/api/providers/custom-endpoints/{endpoint_id}",
                query={"profile": profile} if profile else None,
            )
        )

    @router.get("/providers/oauth")
    async def oauth_providers(profile: str | None = Query(None)) -> Any:
        return await _backend_json(require_backend(), "GET", "/api/providers/oauth", query={"profile": profile} if profile else None)

    @router.post("/providers/oauth/{provider_id}/{operation}")
    async def oauth_provider_action(provider_id: str, operation: str, payload: dict = Body(default={}), profile: str | None = Query(None)) -> Any:
        if operation not in {"start", "submit"}:
            raise HTTPException(status_code=404, detail="unknown OAuth operation")
        return await _backend_json(require_backend(), "POST", f"/api/providers/oauth/{provider_id}/{operation}", query={"profile": profile} if profile else None, body=payload)

    @router.get("/providers/oauth/{provider_id}/poll/{session_id}")
    async def poll_provider_oauth(provider_id: str, session_id: str, profile: str | None = Query(None)) -> Any:
        return await _backend_json(require_backend(), "GET", f"/api/providers/oauth/{provider_id}/poll/{session_id}", query={"profile": profile} if profile else None)

    @router.delete("/providers/oauth/{provider_id}")
    async def disconnect_provider_oauth(provider_id: str, profile: str | None = Query(None)) -> dict:
        return _ok_response(
            await _backend_json(
                require_backend(),
                "DELETE",
                f"/api/providers/oauth/{provider_id}",
                query={"profile": profile} if profile else None,
            )
        )

    @router.delete("/providers/oauth/sessions/{session_id}")
    async def cancel_oauth_session(session_id: str, profile: str | None = Query(None)) -> dict:
        return _ok_response(
            await _backend_json(
                require_backend(),
                "DELETE",
                f"/api/providers/oauth/sessions/{session_id}",
                query={"profile": profile} if profile else None,
            )
        )

    @router.get("/logs")
    async def get_logs(
        file: str = Query("agent"),
        lines: int = Query(100),
        level: str | None = Query(None),
        component: str | None = Query(None),
        search: str | None = Query(None),
    ) -> Any:
        """Proxy Hermes `GET /api/logs` for the command center."""
        be = require_backend()
        query: dict[str, Any] = {"file": file, "lines": lines}
        if level:
            query["level"] = level
        if component:
            query["component"] = component
        if search:
            query["search"] = search
        return await _backend_json(be, "GET", "/api/logs", query=query)

    # --------------------------------------------------------------- model
    @router.get("/model")
    async def get_model(refresh: bool = Query(False)) -> dict:
        be = require_backend()
        info = await _backend_json(be, "GET", "/api/model/info") or {}
        params = {"explicit_only": True, **({"refresh": True} if refresh else {})}
        try:
            options = await be.gateway_rpc("model.options", params)
        except (BackendError, AttributeError):
            options = await _backend_json(
                be,
                "GET",
                "/api/model/options",
                query={"explicit_only": "1", **({"refresh": "1"} if refresh else {})},
            ) or {}
        return {
            "current": {
                "model": info.get("model"),
                "provider": info.get("provider"),
                "context_length": info.get("effective_context_length"),
            },
            "providers": options.get("providers", []),
        }

    @router.get("/model/info")
    async def get_model_info() -> Any:
        return await _backend_json(require_backend(), "GET", "/api/model/info")

    @router.get("/model/options")
    async def get_model_options(request: Request) -> Any:
        return await _backend_json(
            require_backend(),
            "GET",
            "/api/model/options",
            query=dict(request.query_params),
        )

    @router.get("/model/recommended-default")
    async def get_recommended_model(
        provider: str = Query(...), profile: str | None = Query(None)
    ) -> Any:
        query = {"provider": provider}
        if profile:
            query["profile"] = profile
        return await _backend_json(
            require_backend(), "GET", "/api/model/recommended-default", query=query
        )

    @router.get("/model/auxiliary")
    async def get_auxiliary_models(profile: str | None = Query(None)) -> Any:
        return await _backend_json(
            require_backend(),
            "GET",
            "/api/model/auxiliary",
            query={"profile": profile} if profile else None,
        )

    @router.get("/model/moa")
    async def get_moa_models(profile: str | None = Query(None)) -> Any:
        return await _backend_json(
            require_backend(),
            "GET",
            "/api/model/moa",
            query={"profile": profile} if profile else None,
        )

    @router.put("/model/moa")
    async def save_moa_models(
        payload: dict = Body(...), profile: str | None = Query(None)
    ) -> Any:
        return await _backend_json(
            require_backend(),
            "PUT",
            "/api/model/moa",
            query={"profile": profile} if profile else None,
            body=payload,
        )

    @router.post("/model/set")
    async def set_model_assignment(
        payload: dict = Body(...), profile: str | None = Query(None)
    ) -> Any:
        return await _backend_json(
            require_backend(),
            "POST",
            "/api/model/set",
            query={"profile": profile} if profile else None,
            body=payload,
        )

    @router.post("/model/switch")
    async def switch_model(payload: dict = Body(...)) -> dict:
        """Switch the main model; echoes whether it applied now or is deferred."""
        provider = payload.get("provider")
        model = payload.get("model")
        if not provider or not model:
            raise HTTPException(status_code=422, detail="provider and model are required")
        be = require_backend()
        result = await _backend_json(
            be, "POST", "/api/model/set",
            body={"scope": "main", "provider": provider, "model": model},
        ) or {}
        # Hermes defers mid-turn switches; surface that as a first-class field.
        applied = "deferred" if (result.get("deferred") or result.get("warning")) else "now"
        return {
            "applied": applied,
            "warning": result.get("warning"),
            "model": result.get("model"),
            "provider": result.get("provider"),
        }

    # ------------------------------------------------------------ profiles
    # Resolution chain (real data only, never invented):
    #   1. upstream ``/api/profiles`` when the Hermes backend exposes it
    #   2. the ``profiles`` field of ``/api/config`` (older runtimes)
    #   3. the mobile server's own durable ``profiles.json`` (ProfileStore),
    #      which keeps the feature functional and persistent everywhere.
    profiles_store = profile_store or ProfileStore()

    def _profile_name(value: Any) -> str | None:
        if isinstance(value, str):
            name = value.strip()
            return name or None
        if isinstance(value, dict):
            name = str(value.get("name") or value.get("id") or "").strip()
            return name or None
        return None

    def _profile_container(payload: Any) -> Any:
        if isinstance(payload, dict) and isinstance(payload.get("data"), dict):
            return payload["data"]
        return payload

    def _normalize_profiles(payload: Any) -> list[dict]:
        container = _profile_container(payload)
        if isinstance(container, dict):
            items = container.get("profiles") or []
        elif isinstance(container, list):
            items = container
        else:
            items = []
        normalized: list[dict] = []
        for item in items:
            if not isinstance(item, dict):
                continue
            record = dict(item)
            if not record.get("name") and record.get("id"):
                record["name"] = record["id"]
            if str(record.get("name") or "").strip():
                normalized.append(record)
        return normalized

    def _active_from_profiles(profiles: list[dict]) -> str | None:
        for profile in profiles:
            if (
                profile.get("is_active") is True
                or profile.get("active") is True
                or profile.get("isActive") is True
            ):
                return _profile_name(profile)
        return None

    def _active_from_payload(payload: Any, profiles: list[dict]) -> str | None:
        container = _profile_container(payload)
        if isinstance(container, dict):
            active = _profile_name(container.get("active")) or _profile_name(
                container.get("active_profile")
            )
            if active:
                return active
        if isinstance(payload, dict) and payload is not container:
            active = _profile_name(payload.get("active")) or _profile_name(
                payload.get("active_profile")
            )
            if active:
                return active
        return _active_from_profiles(profiles)

    async def _upstream_active_profiles(
        be: BackendManager,
    ) -> tuple[str | None, str | None] | None:
        try:
            payload = await _backend_json(be, "GET", "/api/profiles/active") or {}
        except HTTPException as exc:
            if exc.status_code != 404:
                raise
            return None
        container = _profile_container(payload)
        active = _active_from_payload(payload, [])
        current = None
        if isinstance(container, dict):
            current = _profile_name(container.get("current")) or _profile_name(
                container.get("current_profile")
            )
        if current is None and isinstance(payload, dict) and payload is not container:
            current = _profile_name(payload.get("current")) or _profile_name(
                payload.get("current_profile")
            )
        return active, current

    async def _profiles_payload_from_config(
        be: BackendManager,
    ) -> tuple[list[dict], str | None] | None:
        """``/api/config`` profiles-field fallback; None when unsupported."""
        try:
            config = await _backend_json(be, "GET", "/api/config") or {}
        except HTTPException as exc:
            if exc.status_code != 404:
                raise
            return None
        profiles = config.get("profiles") if isinstance(config, dict) else None
        if isinstance(profiles, list):
            normalized = _normalize_profiles(profiles)
            return normalized, _active_from_payload(config, normalized)
        return None

    async def _profiles_from_config(be: BackendManager) -> list[dict] | None:
        payload = await _profiles_payload_from_config(be)
        return payload[0] if payload is not None else None

    async def _profiles_write_target() -> str:
        """Where profile writes land: ``upstream`` | ``config`` | ``local``."""
        if backend is None or not backend.is_running:
            return "local"
        try:
            await _backend_json(backend, "GET", "/api/profiles")
            return "upstream"
        except HTTPException as exc:
            if exc.status_code != 404:
                raise
        if await _profiles_from_config(backend) is not None:
            return "config"
        return "local"

    async def _save_profile_via_config(be: BackendManager, profile: dict) -> dict:
        existing = await _profiles_from_config(be) or []
        merged: list[dict] = []
        replaced = False
        for item in existing:
            if str(item.get("name") or "") == profile["name"]:
                merged.append({**item, **profile})
                replaced = True
            else:
                merged.append(item)
        if not replaced:
            merged.append(profile)
        await _backend_json(
            be, "PUT", "/api/config", body={"config": {"profiles": merged}}
        )
        return {"ok": True, "profile": profile, "source": "config"}

    def _clean_profile_payload(payload: Any, *, name: str | None = None) -> dict:
        if not isinstance(payload, dict):
            raise HTTPException(status_code=422, detail="object body required")
        resolved = (name or str(payload.get("name") or "")).strip()
        if not resolved:
            raise HTTPException(status_code=422, detail="profile name is required")
        return {**payload, "name": resolved}

    @router.get("/profiles")
    async def list_profiles() -> dict:
        """List profiles + the active one, from the first real source."""
        if backend is not None and backend.is_running:
            try:
                payload = await _backend_json(backend, "GET", "/api/profiles")
                profiles = _normalize_profiles(payload)
                active = _active_from_payload(payload, profiles)
                current = None
                active_payload = await _upstream_active_profiles(backend)
                if active_payload is not None:
                    active = active_payload[0] or active
                    current = active_payload[1]
                return {
                    "profiles": profiles,
                    "active": active,
                    "current": current,
                    "source": "upstream",
                }
            except HTTPException as exc:
                if exc.status_code != 404:
                    raise
            config_payload = await _profiles_payload_from_config(backend)
            if config_payload is not None:
                config_profiles, active = config_payload
                return {
                    "profiles": config_profiles,
                    "active": active,
                    "source": "config",
                }
        snap = profiles_store.snapshot()
        return {"profiles": snap["profiles"], "active": snap["active"], "source": "local"}

    async def _upstream_write(coro_fn):
        """Run an upstream write; return None when the route is unsupported."""
        try:
            return await coro_fn()
        except HTTPException as exc:
            if exc.status_code in (404, 405):
                return None
            raise

    @router.post("/profiles")
    async def create_profile(payload: dict = Body(...)) -> Any:
        profile = _clean_profile_payload(payload)
        target = await _profiles_write_target()
        if target == "upstream":
            result = await _upstream_write(
                lambda: _backend_json(backend, "POST", "/api/profiles", body=profile)
            )
            if result is not None:
                return result
            target = (
                "config"
                if await _profiles_from_config(backend) is not None
                else "local"
            )
        if target == "config":
            return await _save_profile_via_config(backend, profile)
        record = profiles_store.upsert(profile)
        return {"ok": True, "profile": record, "source": "local"}

    @router.put("/profiles/{name}")
    async def update_profile(name: str, payload: dict = Body(...)) -> Any:
        profile = _clean_profile_payload(payload, name=name)
        target = await _profiles_write_target()
        if target == "upstream":
            result = await _upstream_write(
                lambda: _backend_json(
                    backend, "PUT", f"/api/profiles/{name}", body=profile
                )
            )
            if result is not None:
                if isinstance(result, dict):
                    active = _active_from_payload(result, [])
                    if active:
                        return {**result, "active": active}
                return result
            target = (
                "config"
                if await _profiles_from_config(backend) is not None
                else "local"
            )
        if target == "config":
            existing = await _profiles_from_config(backend) or []
            if not any(str(p.get("name") or "") == name for p in existing):
                raise HTTPException(status_code=404, detail="profile not found")
            return await _save_profile_via_config(backend, profile)
        record = profiles_store.upsert(profile)
        return {"ok": True, "profile": record, "source": "local"}

    @router.post("/profiles/{name}/activate")
    async def activate_profile(name: str) -> Any:
        """Switch the backend's active profile (a real backend-side change)."""
        target = await _profiles_write_target()
        if target == "upstream":
            result = await _upstream_write(
                lambda: _backend_json(
                    backend, "POST", "/api/profiles/active", body={"name": name}
                )
            )
            if result is not None:
                return result
            target = (
                "config"
                if await _profiles_from_config(backend) is not None
                else "local"
            )
        if target == "config":
            existing = await _profiles_from_config(backend) or []
            if not any(str(p.get("name") or "") == name for p in existing):
                raise HTTPException(status_code=404, detail="profile not found")
            merged = [
                {**p, "is_active": str(p.get("name") or "") == name}
                for p in existing
            ]
            await _backend_json(
                backend, "PUT", "/api/config", body={"config": {"profiles": merged}}
            )
            return {"ok": True, "active": name, "source": "config"}
        if not profiles_store.set_active(name):
            raise HTTPException(status_code=404, detail="profile not found")
        return {"ok": True, "active": name, "source": "local"}

    @router.delete("/profiles/{name}")
    async def delete_profile(name: str) -> Any:
        target = await _profiles_write_target()
        if target == "upstream":
            result = await _upstream_write(
                lambda: _backend_json(backend, "DELETE", f"/api/profiles/{name}")
            )
            if result is not None:
                return _ok_response(result)
            target = (
                "config"
                if await _profiles_from_config(backend) is not None
                else "local"
            )
        if target == "config":
            existing = await _profiles_from_config(backend) or []
            merged = [p for p in existing if str(p.get("name") or "") != name]
            if len(merged) == len(existing):
                raise HTTPException(status_code=404, detail="profile not found")
            await _backend_json(
                backend, "PUT", "/api/config", body={"config": {"profiles": merged}}
            )
            return {"ok": True, "source": "config"}
        if not profiles_store.delete(name):
            raise HTTPException(status_code=404, detail="profile not found")
        return {"ok": True, "source": "local"}

    # Canonical dashboard profile routes. Advanced profile artifacts live in
    # the Hermes runtime, so the companion forwards them without narrowing the
    # response or replacing path-based archive semantics.
    @router.get("/profiles/active")
    async def get_active_profile() -> dict:
        payload = await list_profiles()
        return {
            "active": payload.get("active"),
            "current": payload.get("current"),
        }

    @router.post("/profiles/active")
    async def set_active_profile(payload: dict = Body(...)) -> Any:
        name = str(payload.get("name") or "").strip()
        if not name:
            raise HTTPException(status_code=422, detail="profile name is required")
        return await activate_profile(name)

    @router.patch("/profiles/{name}")
    async def rename_profile(name: str, payload: dict = Body(...)) -> Any:
        new_name = str(payload.get("new_name") or "").strip()
        if not new_name:
            raise HTTPException(status_code=422, detail="new_name is required")
        return await _backend_json(
            require_backend(),
            "PATCH",
            f"/api/profiles/{name}",
            body={"new_name": new_name},
        )

    @router.put("/profiles/{name}/description")
    async def update_profile_description(name: str, payload: dict = Body(...)) -> Any:
        return await _backend_json(
            require_backend(),
            "PUT",
            f"/api/profiles/{name}/description",
            body=payload,
        )

    @router.put("/profiles/{name}/model")
    async def update_profile_model(name: str, payload: dict = Body(...)) -> Any:
        return await _backend_json(
            require_backend(),
            "PUT",
            f"/api/profiles/{name}/model",
            body=payload,
        )

    @router.get("/profiles/{name}/soul")
    async def get_profile_soul(name: str) -> Any:
        return await _backend_json(
            require_backend(), "GET", f"/api/profiles/{name}/soul"
        )

    @router.put("/profiles/{name}/soul")
    async def put_profile_soul(name: str, payload: dict = Body(...)) -> Any:
        return await _backend_json(
            require_backend(),
            "PUT",
            f"/api/profiles/{name}/soul",
            body=payload,
        )

    @router.get("/profiles/{name}/setup-command")
    async def get_profile_setup_command(name: str) -> Any:
        return await _backend_json(
            require_backend(),
            "GET",
            f"/api/profiles/{name}/setup-command",
        )

    @router.post("/profiles/{name}/export")
    async def export_profile(name: str, payload: dict = Body(default={})) -> Any:
        return await _backend_json(
            require_backend(),
            "POST",
            f"/api/profiles/{name}/export",
            body=payload,
        )

    @router.post("/profiles/import")
    async def import_profile(payload: dict = Body(...)) -> Any:
        return await _backend_json(
            require_backend(), "POST", "/api/profiles/import", body=payload
        )

    # -------------------------------------------------------------- skills
    @router.get("/skills")
    async def list_skills(profile: str | None = Query(None)) -> Any:
        be = require_backend()
        query = {"profile": profile} if profile else None
        return await _backend_json(be, "GET", "/api/skills", query=query)

    @router.put("/skills/{name}/enabled")
    async def toggle_skill(
        name: str,
        payload: dict = Body(...),
        profile: str | None = Query(None),
    ) -> Any:
        be = require_backend()
        return await _backend_json(
            be, "PUT", "/api/skills/toggle",
            query={"profile": profile} if profile else None,
            body={"name": name, "enabled": payload.get("enabled", False)},
        )

    @router.put("/skills/toggle")
    async def toggle_skill_canonical(
        payload: dict = Body(...), profile: str | None = Query(None)
    ) -> Any:
        return await _backend_json(
            require_backend(),
            "PUT",
            "/api/skills/toggle",
            query={"profile": profile} if profile else None,
            body=payload,
        )

    @router.get("/skills/content")
    async def skill_content(name: str = Query(...)) -> Any:
        be = require_backend()
        return await _backend_json(be, "GET", "/api/skills/content", query={"name": name})

    # Skill edit/archive for learned (provenance="agent") skills reuse the
    # generic learning-node endpoints (GET/PUT/DELETE /starmap/node below) —
    # a skill IS a learning-graph node server-side, same as a memory.

    @router.get("/skills/hub/sources")
    async def skill_hub_sources() -> Any:
        be = require_backend()
        return await _backend_json(be, "GET", "/api/skills/hub/sources")

    @router.get("/skills/hub/search")
    async def skill_hub_search(
        q: str = Query(...),
        source: str | None = Query(None),
        limit: int | None = Query(None),
    ) -> Any:
        be = require_backend()
        query = {"q": q}
        if source:
            query["source"] = source
        if limit is not None:
            query["limit"] = limit
        return await _backend_json(be, "GET", "/api/skills/hub/search", query=query)

    @router.get("/skills/hub/preview")
    async def skill_hub_preview(identifier: str = Query(...)) -> Any:
        be = require_backend()
        return await _backend_json(
            be, "GET", "/api/skills/hub/preview", query={"identifier": identifier}
        )

    @router.get("/skills/hub/scan")
    async def skill_hub_scan(identifier: str = Query(...)) -> Any:
        be = require_backend()
        return await _backend_json(
            be, "GET", "/api/skills/hub/scan", query={"identifier": identifier}
        )

    @router.post("/skills/hub/install")
    async def skill_hub_install(payload: dict = Body(...)) -> Any:
        be = require_backend()
        return await _backend_json(be, "POST", "/api/skills/hub/install", body=payload)

    @router.post("/skills/hub/uninstall")
    async def skill_hub_uninstall(payload: dict = Body(...)) -> Any:
        be = require_backend()
        return await _backend_json(be, "POST", "/api/skills/hub/uninstall", body=payload)

    @router.post("/skills/hub/update")
    async def skill_hub_update(payload: dict = Body(...)) -> Any:
        be = require_backend()
        return await _backend_json(be, "POST", "/api/skills/hub/update", body=payload)

    # --------------------------------------------------------------- tools
    @router.get("/tools")
    async def list_tools(profile: str | None = Query(None)) -> Any:
        be = require_backend()
        query = {"profile": profile} if profile else None
        return await _backend_json(be, "GET", "/api/tools/toolsets", query=query)

    @router.get("/tools/terminal/backends")
    async def terminal_backends(profile: str | None = Query(None)) -> Any:
        return await _backend_json(
            require_backend(),
            "GET",
            "/api/tools/terminal/backends",
            query={"profile": profile} if profile else None,
        )

    @router.put("/tools/terminal/backend")
    async def select_terminal_backend(
        payload: dict = Body(...),
        profile: str | None = Query(None),
    ) -> Any:
        return await _backend_json(
            require_backend(),
            "PUT",
            "/api/tools/terminal/backend",
            query={"profile": profile} if profile else None,
            body=payload,
        )

    @router.put("/tools/{name}/enabled")
    async def toggle_tool(
        name: str,
        payload: dict = Body(...),
        profile: str | None = Query(None),
    ) -> Any:
        be = require_backend()
        return await _backend_json(
            be, "PUT", f"/api/tools/toolsets/{name}",
            query={"profile": profile} if profile else None,
            body={"enabled": payload.get("enabled", False)},
        )

    @router.put("/tools/{name}")
    async def toggle_tool_canonical(
        name: str,
        payload: dict = Body(...),
        profile: str | None = Query(None),
    ) -> Any:
        return await _backend_json(
            require_backend(),
            "PUT",
            f"/api/tools/toolsets/{name}",
            query={"profile": profile} if profile else None,
            body=payload,
        )

    @router.get("/tools/{name}/config")
    async def toolset_config(name: str, profile: str | None = Query(None)) -> Any:
        return await _backend_json(require_backend(), "GET", f"/api/tools/toolsets/{name}/config", query={"profile": profile} if profile else None)

    @router.get("/tools/{name}/models")
    async def toolset_models(name: str, provider: str | None = Query(None), profile: str | None = Query(None)) -> Any:
        query = {key: value for key, value in {"provider": provider, "profile": profile}.items() if value}
        return await _backend_json(require_backend(), "GET", f"/api/tools/toolsets/{name}/models", query=query or None)

    @router.put("/tools/{name}/provider")
    async def select_toolset_provider(name: str, payload: dict = Body(...), profile: str | None = Query(None)) -> Any:
        return await _backend_json(require_backend(), "PUT", f"/api/tools/toolsets/{name}/provider", query={"profile": profile} if profile else None, body=payload)

    @router.put("/tools/{name}/model")
    async def select_toolset_model(name: str, payload: dict = Body(...), profile: str | None = Query(None)) -> Any:
        return await _backend_json(require_backend(), "PUT", f"/api/tools/toolsets/{name}/model", query={"profile": profile} if profile else None, body=payload)

    @router.post("/tools/{name}/post-setup")
    async def toolset_post_setup(name: str, payload: dict = Body(...), profile: str | None = Query(None)) -> Any:
        return await _backend_json(require_backend(), "POST", f"/api/tools/toolsets/{name}/post-setup", query={"profile": profile} if profile else None, body=payload)

    @router.get("/tools/computer-use/status")
    async def computer_use_status(profile: str | None = Query(None)) -> Any:
        return await _backend_json(
            require_backend(),
            "GET",
            "/api/tools/computer-use/status",
            query={"profile": profile} if profile else None,
        )

    @router.post("/tools/computer-use/permissions/grant")
    async def computer_use_grant(profile: str | None = Query(None)) -> Any:
        return await _backend_json(
            require_backend(),
            "POST",
            "/api/tools/computer-use/permissions/grant",
            query={"profile": profile} if profile else None,
            body={},
        )

    # -------------------------------------------------------- saved prompts
    # WebUI `/api/prompts` parity.  When the running backend exposes the route
    # we proxy it; otherwise we fall back to the very same on-disk file the
    # WebUI uses ($HERMES_HOME/webui/saved_prompts.json), so snippets stay
    # shared with the desktop UI either way.
    prompts_store = prompt_store or SavedPromptsStore()

    async def _prompts_upstream(be: BackendManager) -> bool:
        try:
            await _backend_json(be, "GET", "/api/prompts")
            return True
        except HTTPException as exc:
            if exc.status_code != 404:
                raise
            return False

    @router.get("/prompts")
    async def list_prompts() -> dict:
        be = require_backend()
        if await _prompts_upstream(be):
            data = await _backend_json(be, "GET", "/api/prompts") or {}
            prompts = data.get("prompts") if isinstance(data, dict) else None
            return {"prompts": prompts if isinstance(prompts, list) else []}
        return {"prompts": prompts_store.list()}

    @router.post("/prompts")
    async def save_prompt(payload: dict = Body(...)) -> dict:
        be = require_backend()
        text = str((payload or {}).get("text") or "").strip()
        label = str((payload or {}).get("label") or "").strip()
        if not text:
            raise HTTPException(status_code=422, detail="text is required")
        if len(text) > 8000:
            raise HTTPException(status_code=422, detail="text too long (max 8000 chars)")
        if await _prompts_upstream(be):
            return await _backend_json(
                be, "POST", "/api/prompts", body={"text": text, "label": label}
            )
        try:
            prompt = prompts_store.add(text, label)
        except ValueError as exc:
            raise HTTPException(status_code=422, detail=str(exc)) from exc
        return {"ok": True, "prompt": prompt}

    @router.delete("/prompts/{prompt_id}")
    async def delete_prompt(prompt_id: str) -> dict:
        be = require_backend()
        if await _prompts_upstream(be):
            return _ok_response(
                await _backend_json(
                    be, "DELETE", "/api/prompts", body={"id": prompt_id}
                )
            )
        try:
            prompts_store.delete(prompt_id)
        except ValueError as exc:
            raise HTTPException(status_code=422, detail=str(exc)) from exc
        return {"ok": True}

    # --------------------------------------------------------------- files
    @router.get("/files")
    async def list_files(path: str = Query(...)) -> Any:
        return await local(lambda: local_workspace.entries(path))

    @router.get("/files/drives")
    async def filesystem_drives() -> Any:
        """List safe local roots for the mobile file browser."""
        return local_workspace.drives()

    @router.get("/files/entries")
    async def filesystem_entries(
        path: str = Query(...), root: str | None = Query(None)
    ) -> Any:
        """WebUI-compatible directory metadata (parent, repo flag, entries)."""
        return await local(lambda: local_workspace.project_entries(path, root))

    @router.get("/files/read")
    async def read_file(path: str = Query(...)) -> Any:
        return await local(lambda: local_workspace.read_text(path))

    @router.post("/files/write")
    async def write_file(payload: dict = Body(...)) -> Any:
        """Overwrite/create a UTF-8 text file (spot editor)."""
        return await local(lambda: local_workspace.write_text(payload.get("path", ""), str(payload.get("content", ""))))

    @router.get("/files/read-data-url")
    async def read_file_data_url(path: str = Query(...)) -> Any:
        return await local(lambda: local_workspace.read_data_url(path))

    @router.get("/files/download")
    async def download_file(path: str = Query(...)) -> Any:
        """Stream a file, or a zipped directory, to the mobile client."""
        info = await local(lambda: local_workspace.prepare_download(path))
        background = None
        if info.get("cleanup"):
            background = BackgroundTask(os.unlink, info["path"])
        return FileResponse(
            path=info["path"],
            filename=info["filename"],
            media_type=info["media_type"],
            background=background,
        )

    @router.post("/files/reveal")
    async def reveal_file(payload: dict = Body(...)) -> Any:
        return await local(lambda: local_workspace.reveal(payload.get("path", "")))

    @router.get("/files/default-cwd")
    async def default_cwd() -> Any:
        """Default working directory + git branch (file browser start path)."""
        return local_workspace.default_cwd()

    # --------------------------------------------------------------- audio
    @router.get("/audio/elevenlabs/voices")
    async def elevenlabs_voices(profile: str | None = Query(None)) -> Any:
        query = {"profile": profile} if profile else None
        return await _backend_json(
            require_backend(),
            "GET",
            "/api/audio/elevenlabs/voices",
            query=query,
        )

    async def _stt_configured(be: BackendManager) -> bool:
        """Pre-flight STT check (D2 §2.2): fail fast instead of hanging."""
        try:
            config = await _backend_json(be, "GET", "/api/config") or {}
        except HTTPException:
            return False
        stt = config.get("stt") or {}
        return bool(stt.get("enabled")) and bool(stt.get("provider"))

    @router.post("/audio/transcribe")
    async def transcribe(payload: dict = Body(...)) -> Any:
        be = require_backend()
        if not await _stt_configured(be):
            # Top-level structured error: the Flutter decoder cannot extract
            # a message from the map-valued ``detail`` of an HTTPException.
            return JSONResponse(
                status_code=409,
                content={
                    "error": {
                        "code": "stt_not_configured",
                        "message": "Speech-to-text provider is not configured",
                    }
                },
            )
        return await _backend_json(be, "POST", "/api/audio/transcribe", body=payload)

    @router.post("/audio/speak")
    async def speak(payload: dict = Body(...)) -> Any:
        be = require_backend()
        return await _backend_json(be, "POST", "/api/audio/speak", body=payload)

    # ---------------------------------------------------------------- cron
    @router.get("/cron")
    async def list_cron() -> Any:
        be = require_backend()
        return await _backend_json(be, "GET", "/api/cron/jobs")

    @router.post("/cron")
    async def create_cron(payload: dict = Body(...)) -> Any:
        """Create a scheduled job (Scheduler editor): prompt/schedule/name/
        deliver/workdir/model/… (see CronJobCreate in the backend)."""
        be = require_backend()
        return await _backend_json(be, "POST", "/api/cron/jobs", body=payload)

    # Static catalog routes must be registered before /cron/{job_id}. Starlette
    # treats a path match with the wrong method as final, so placing these after
    # PUT/DELETE /cron/{job_id} makes their GET requests return 405.
    @router.get("/cron/delivery-targets")
    async def cron_delivery_targets() -> Any:
        return await _backend_json(
            require_backend(), "GET", "/api/cron/delivery-targets"
        )

    @router.get("/cron/blueprints")
    async def cron_blueprints() -> Any:
        return await _backend_json(
            require_backend(), "GET", "/api/cron/blueprints"
        )

    @router.post("/cron/blueprints/instantiate")
    async def instantiate_cron_blueprint(payload: dict = Body(...)) -> Any:
        return await _backend_json(
            require_backend(),
            "POST",
            "/api/cron/blueprints/instantiate",
            body=payload,
        )

    @router.put("/cron/{job_id}")
    async def update_cron(job_id: str, payload: dict = Body(...)) -> Any:
        """Update a scheduled job; body is a partial field map."""
        be = require_backend()
        return await _backend_json(
            be, "PUT", f"/api/cron/jobs/{job_id}", body={"updates": payload}
        )

    @router.delete("/cron/{job_id}")
    async def delete_cron(job_id: str) -> dict:
        be = require_backend()
        return _ok_response(
            await _backend_json(be, "DELETE", f"/api/cron/jobs/{job_id}")
        )

    @router.get("/cron/{job_id}/runs")
    async def cron_runs(job_id: str, limit: int = Query(20)) -> Any:
        be = require_backend()
        return await _backend_json(
            be, "GET", f"/api/cron/jobs/{job_id}/runs", query={"limit": limit}
        )

    @router.post("/cron/{job_id}/pause")
    async def pause_cron(job_id: str) -> Any:
        be = require_backend()
        return await _backend_json(be, "POST", f"/api/cron/jobs/{job_id}/pause")

    @router.post("/cron/{job_id}/resume")
    async def resume_cron(job_id: str) -> Any:
        be = require_backend()
        return await _backend_json(be, "POST", f"/api/cron/jobs/{job_id}/resume")

    @router.post("/cron/{job_id}/trigger")
    async def trigger_cron(job_id: str) -> Any:
        be = require_backend()
        return await _backend_json(be, "POST", f"/api/cron/jobs/{job_id}/trigger")

    # -------------------------------------------------------------- memory
    @router.get("/memory")
    async def memory_status(profile: str | None = Query(None)) -> Any:
        """Active provider + discovered providers + builtin file sizes."""
        be = require_backend()
        query = {"profile": profile} if profile else None
        return await _backend_json(be, "GET", "/api/memory", query=query)

    @router.put("/memory/provider")
    async def memory_set_provider(
        payload: dict = Body(...), profile: str | None = Query(None)
    ) -> Any:
        be = require_backend()
        query = {"profile": profile} if profile else None
        return await _backend_json(
            be, "PUT", "/api/memory/provider", query=query, body=payload
        )

    @router.post("/memory/reset")
    async def memory_reset(
        payload: dict = Body(default={}), profile: str | None = Query(None)
    ) -> Any:
        be = require_backend()
        query = {"profile": profile} if profile else None
        return await _backend_json(
            be, "POST", "/api/memory/reset", query=query, body=payload
        )

    @router.get("/memory/providers/{provider}/config")
    async def memory_provider_config(
        provider: str, profile: str | None = Query(None)
    ) -> Any:
        query = {"surface": "declared"}
        if profile:
            query["profile"] = profile
        return await _backend_json(
            require_backend(),
            "GET",
            f"/api/memory/providers/{provider}/config",
            query=query,
        )

    @router.put("/memory/providers/{provider}/config")
    async def memory_save_provider_config(
        provider: str,
        payload: dict = Body(...),
        profile: str | None = Query(None),
    ) -> Any:
        query = {"surface": "declared"}
        if profile:
            query["profile"] = profile
        return await _backend_json(
            require_backend(),
            "PUT",
            f"/api/memory/providers/{provider}/config",
            query=query,
            body={"values": payload.get("values", {})},
        )

    @router.post("/memory/providers/{provider}/oauth/start")
    async def memory_start_provider_oauth(
        provider: str, profile: str | None = Query(None)
    ) -> Any:
        query = {"profile": profile} if profile else None
        return await _backend_json(
            require_backend(),
            "POST",
            f"/api/memory/providers/{provider}/oauth/start",
            query=query,
        )

    @router.get("/memory/providers/{provider}/oauth/status")
    async def memory_provider_oauth_status(
        provider: str, profile: str | None = Query(None)
    ) -> Any:
        query = {"profile": profile} if profile else None
        return await _backend_json(
            require_backend(),
            "GET",
            f"/api/memory/providers/{provider}/oauth/status",
            query=query,
        )

    @router.get("/curator")
    async def curator_status() -> Any:
        return await _backend_json(require_backend(), "GET", "/api/curator")

    @router.put("/curator/paused")
    async def curator_set_paused(payload: dict = Body(...)) -> Any:
        return await _backend_json(
            require_backend(), "PUT", "/api/curator/paused", body=payload
        )

    @router.post("/curator/run")
    async def curator_run() -> Any:
        return await _backend_json(require_backend(), "POST", "/api/curator/run")

    # ------------------------------------------------------------- projects
    @router.get("/projects")
    async def list_projects() -> dict:
        """Projects are a gateway-only method; go through the gateway RPC."""
        be = require_backend()
        try:
            return await be.gateway_rpc("projects.list", {})
        except BackendError as exc:
            raise HTTPException(status_code=502, detail=str(exc))

    @router.get("/projects/tree")
    async def project_tree(preview_limit: int = Query(3, ge=0, le=20)) -> dict:
        """Desktop sidebar parity: authoritative project → repo → lane tree.

        Mirrors the desktop ``projects.tree`` gateway RPC
        (``{projects, active_id, scoped_session_ids}``). The overview payload
        keeps lane ``sessions`` empty but preserves counts; per-project
        hydration goes through ``/projects/{id}/sessions``.
        """
        be = require_backend()
        try:
            payload = await be.gateway_rpc(
                "projects.tree", {"preview_limit": preview_limit}
            )
        except BackendError as exc:
            raise HTTPException(status_code=502, detail=str(exc))
        if isinstance(payload, dict):
            return payload
        return {"projects": [], "active_id": None, "scoped_session_ids": []}

    @router.get("/projects/{project_id}/sessions")
    async def project_sessions(project_id: str) -> dict:
        """Hydrate one project's lanes with full session rows (drill-in).

        Mirrors the desktop ``projects.project_sessions`` gateway RPC; the
        response is ``{project: SidebarProjectTree | null}`` with hydrated
        lane ``sessions`` arrays (time-descending).
        """
        be = require_backend()
        try:
            payload = await be.gateway_rpc(
                "projects.project_sessions", {"project_id": project_id}
            )
        except BackendError as exc:
            raise HTTPException(status_code=502, detail=str(exc))
        if isinstance(payload, dict):
            return payload
        return {"project": None}

    # ------------------------------------------------------------------ git
    # Thin passthrough to the backend's /api/git/* dashboard routes (the
    # mobile server does not re-implement git; it only re-exposes the surface
    # with API-key auth, D2/D5).
    @router.get("/git/status")
    async def git_status(path: str = Query(...)) -> Any:
        return await _backend_json(
            require_backend(), "GET", "/api/git/status", query={"path": path}
        )

    @router.get("/git/branches")
    async def git_branches(path: str = Query(...)) -> Any:
        return await _backend_json(
            require_backend(), "GET", "/api/git/branches", query={"path": path}
        )

    @router.get("/git/base-branches")
    async def git_base_branches(path: str = Query(...)) -> Any:
        return await _backend_json(
            require_backend(), "GET", "/api/git/base-branches", query={"path": path}
        )

    @router.get("/git/worktrees")
    async def git_worktrees(path: str = Query(...)) -> Any:
        return await _backend_json(
            require_backend(), "GET", "/api/git/worktrees", query={"path": path}
        )

    @router.post("/git/worktree/add")
    async def git_worktree_add(payload: dict = Body(...)) -> Any:
        return await _backend_json(
            require_backend(), "POST", "/api/git/worktree/add", body=payload
        )

    @router.post("/git/worktree/remove")
    async def git_worktree_remove(payload: dict = Body(...)) -> Any:
        return await _backend_json(
            require_backend(), "POST", "/api/git/worktree/remove", body=payload
        )

    @router.get("/git/log")
    async def git_log(
        path: str = Query(...),
        limit: int = Query(50, ge=1, le=500),
        offset: int = Query(0, ge=0),
        search: str | None = Query(None),
        author: str | None = Query(None),
        branch: str | None = Query(None),
    ) -> Any:
        return await local(lambda: local_workspace.git_log(path, limit, offset, search, author, branch))

    @router.get("/git/log/commit")
    async def git_log_commit(
        path: str = Query(...),
        sha: str = Query(...),
    ) -> Any:
        return await local(lambda: local_workspace.git_commit_detail(path, sha))

    @router.get("/git/diff")
    async def git_diff(
        path: str = Query(...),
        file: str = Query(...),
        mode: str = Query("worktree"),
        oid: str | None = Query(None),
    ) -> Any:
        return await local(lambda: local_workspace.git_diff(path, file, staged=mode == "staged", oid=oid))

    @router.get("/git/remotes")
    async def git_remotes(path: str = Query(...)) -> Any:
        return await local(lambda: local_workspace.git_remotes(path))

    @router.get("/git/stashes")
    async def git_stashes(path: str = Query(...)) -> Any:
        return await local(lambda: local_workspace.git_stashes(path))

    @router.get("/git/review/list")
    async def git_review_list(
        path: str = Query(...),
        scope: str = Query("uncommitted"),
        base: str | None = Query(None),
    ) -> Any:
        return await _backend_json(
            require_backend(),
            "GET",
            "/api/git/review/list",
            query={"path": path, "scope": scope, **({"base": base} if base else {})},
        )

    @router.get("/git/review/diff")
    async def git_review_diff(
        path: str = Query(...),
        file: str = Query(...),
        scope: str = Query("uncommitted"),
        base: str | None = Query(None),
        staged: bool = Query(False),
    ) -> Any:
        return await _backend_json(
            require_backend(),
            "GET",
            "/api/git/review/diff",
            query={
                "path": path,
                "file": file,
                "scope": scope,
                "staged": str(staged).lower(),
                **({"base": base} if base else {}),
            },
        )

    @router.get("/git/file-diff")
    async def git_file_diff(path: str = Query(...), file: str = Query(...)) -> Any:
        return await _backend_json(
            require_backend(), "GET", "/api/git/file-diff",
            query={"path": path, "file": file},
        )

    @router.get("/git/review/commit-context")
    async def git_commit_context(path: str = Query(...)) -> Any:
        return await _backend_json(
            require_backend(), "GET", "/api/git/review/commit-context",
            query={"path": path},
        )

    @router.get("/git/review/rev-parse")
    async def git_rev_parse(
        path: str = Query(...), ref: str | None = Query(None)
    ) -> Any:
        return await _backend_json(
            require_backend(), "GET", "/api/git/review/rev-parse",
            query={"path": path, **({"ref": ref} if ref else {})},
        )

    @router.get("/git/review/ship-info")
    async def git_ship_info(path: str = Query(...)) -> Any:
        return await _backend_json(
            require_backend(), "GET", "/api/git/review/ship-info",
            query={"path": path},
        )

    @router.post("/git/review/pr-list")
    async def git_pr_list(payload: dict = Body(...)) -> Any:
        return await _backend_json(
            require_backend(), "POST", "/api/git/review/pr-list", body=payload
        )

    @router.post("/git/review/stage")
    async def git_stage(payload: dict = Body(...)) -> Any:
        return await _backend_json(
            require_backend(), "POST", "/api/git/review/stage", body=payload
        )

    @router.post("/git/review/unstage")
    async def git_unstage(payload: dict = Body(...)) -> Any:
        return await _backend_json(
            require_backend(), "POST", "/api/git/review/unstage", body=payload
        )

    @router.post("/git/review/revert")
    async def git_revert(payload: dict = Body(...)) -> Any:
        return await _backend_json(
            require_backend(), "POST", "/api/git/review/revert", body=payload
        )

    @router.post("/git/review/commit")
    async def git_commit(payload: dict = Body(...)) -> Any:
        return await _backend_json(
            require_backend(), "POST", "/api/git/review/commit", body=payload
        )

    @router.post("/git/review/push")
    async def git_push(payload: dict = Body(...)) -> Any:
        return await _backend_json(
            require_backend(), "POST", "/api/git/review/push", body=payload
        )

    @router.post("/git/review/create-pr")
    async def git_create_pr(payload: dict = Body(...)) -> Any:
        return await _backend_json(
            require_backend(), "POST", "/api/git/review/create-pr", body=payload
        )

    @router.post("/git/branch/switch")
    async def git_branch_switch(payload: dict = Body(...)) -> Any:
        return await _backend_json(
            require_backend(), "POST", "/api/git/branch/switch", body=payload
        )

    # ------------------------------------------------------------- analytics
    @router.get("/analytics/usage")
    async def analytics_usage(
        days: int = Query(30, ge=1, le=365),
        profile: str | None = Query(None),
    ) -> Any:
        """Daily token/cost/session series + totals + skills/tools breakdown."""
        return await _backend_json(
            require_backend(),
            "GET",
            "/api/analytics/usage",
            query={"days": days, **({"profile": profile} if profile else {})},
        )

    @router.get("/analytics/models")
    async def analytics_models(
        days: int = Query(30, ge=1, le=365),
    ) -> Any:
        """Per-model token/cost/session breakdown with capability metadata."""
        return await _backend_json(require_backend(), "GET", "/api/analytics/models", query={"days": days})

    # ------------------------------------------------------------------ ops
    # Maintenance actions (desktop parity: Command Center's Maintenance tab /
    # `hermes doctor` / `hermes security audit` / `hermes backup` / `hermes
    # debug share`). doctor/security-audit/backup spawn a background action
    # tailed via the existing /actions/{name}/status poller; debug-share is
    # synchronous (uploads a redacted report + logs, returns share URLs).
    @router.post("/ops/doctor")
    async def ops_doctor() -> Any:
        return await _backend_json(require_backend(), "POST", "/api/ops/doctor", body={})

    @router.post("/ops/security-audit")
    async def ops_security_audit() -> Any:
        return await _backend_json(require_backend(), "POST", "/api/ops/security-audit", body={})

    @router.post("/ops/backup")
    async def ops_backup() -> Any:
        return await _backend_json(require_backend(), "POST", "/api/ops/backup", body={})

    @router.post("/ops/debug-share")
    async def ops_debug_share() -> Any:
        return await _backend_json(require_backend(), "POST", "/api/ops/debug-share", body={})

    # ------------------------------------------------------------ knowledge
    # Backend "star map" learning graph (getStarmapGraph / learning node CRUD).
    @router.get("/knowledge/graph")
    async def knowledge_graph() -> Any:
        """Deprecated alias of ``GET /starmap/graph``."""
        be = require_backend()
        return await _backend_json(be, "GET", "/api/learning/graph")

    @router.get("/knowledge/node")
    async def knowledge_node(id: str = Query(...)) -> Any:
        """Deprecated alias of ``GET /starmap/node``."""
        be = require_backend()
        return await _backend_json(be, "GET", "/api/learning/node", query={"id": id})

    @router.put("/knowledge/node")
    async def knowledge_node_update(payload: dict = Body(...)) -> Any:
        """Deprecated alias of ``PUT /starmap/node``."""
        be = require_backend()
        return await _backend_json(be, "PUT", "/api/learning/node", body=payload)

    @router.delete("/knowledge/node")
    async def knowledge_node_delete(id: str = Query(...)) -> dict:
        """Deprecated alias of ``DELETE /starmap/node``."""
        be = require_backend()
        return _ok_response(
            await _backend_json(be, "DELETE", "/api/learning/node", query={"id": id})
        )

    # ---------------------------------------------------------------- mcp
    @router.get("/mcp/servers")
    async def mcp_servers(profile: str | None = Query(None)) -> Any:
        be = require_backend()
        query = {"profile": profile} if profile else None
        return await _backend_json(be, "GET", "/api/mcp/servers", query=query)

    @router.post("/mcp/servers")
    async def mcp_server_create(
        payload: dict = Body(...), profile: str | None = Query(None)
    ) -> Any:
        be = require_backend()
        query = {"profile": profile} if profile else None
        return await _backend_json(be, "POST", "/api/mcp/servers", query=query, body=payload)

    @router.put("/mcp/servers")
    async def mcp_servers_replace(
        payload: dict = Body(...), profile: str | None = Query(None)
    ) -> Any:
        """Replace the complete MCP map; deep-merge config cannot delete keys."""
        query = {"profile": profile} if profile else None
        return await _backend_json(
            require_backend(), "PUT", "/api/mcp/servers", query=query, body=payload
        )

    @router.delete("/mcp/servers/{name}")
    async def mcp_server_delete(name: str, profile: str | None = Query(None)) -> dict:
        query = {"profile": profile} if profile else None
        return _ok_response(
            await _backend_json(
                require_backend(), "DELETE", f"/api/mcp/servers/{name}", query=query
            )
        )

    @router.put("/mcp/servers/{name}/enabled")
    async def mcp_server_toggle(
        name: str, payload: dict = Body(...), profile: str | None = Query(None)
    ) -> Any:
        be = require_backend()
        query = {"profile": profile} if profile else None
        return await _backend_json(
            be, "PUT", f"/api/mcp/servers/{name}/enabled",
            query=query,
            body={"enabled": payload.get("enabled", False)},
        )

    @router.get("/mcp/servers/{name}/test")
    async def mcp_server_test(name: str, profile: str | None = Query(None)) -> Any:
        # Upstream registers this diagnostic as POST (hermes_cli/web_routers/
        # mcp.py's test_mcp_server) even though mobile's own contract keeps it
        # a read-shaped GET; the internal forward must match upstream's verb.
        be = require_backend()
        query = {"profile": profile} if profile else None
        return await _backend_json(be, "POST", f"/api/mcp/servers/{name}/test", query=query)

    @router.post("/mcp/servers/{name}/auth")
    async def mcp_server_auth(
        name: str, request: Request, profile: str | None = Query(None)
    ) -> Any:
        # Hermes derives its OAuth redirect URI from the incoming dashboard
        # request. Preserve the phone-reachable mobile origin and advertise
        # our /api/v1 proxy prefix so the provider returns to the public relay
        # instead of the backend's private 127.0.0.1 port.
        from urllib.parse import urlparse

        public = (settings.public_url or str(request.base_url)).rstrip("/")
        parsed = urlparse(public)
        forwarded_headers = {
            "host": parsed.netloc,
            "x-forwarded-host": parsed.netloc,
            "x-forwarded-proto": parsed.scheme or request.url.scheme,
            "x-forwarded-prefix": "/api/v1",
        }
        query = {"profile": profile} if profile else None
        return await _backend_json(
            require_backend(),
            "POST",
            f"/api/mcp/servers/{name}/auth",
            query=query,
            headers=forwarded_headers,
        )

    @router.get("/mcp/oauth/flows/{flow_id}")
    async def mcp_oauth_flow(flow_id: str, profile: str | None = Query(None)) -> Any:
        query = {"profile": profile} if profile else None
        return await _backend_json(
            require_backend(), "GET", f"/api/mcp/oauth/flows/{flow_id}", query=query
        )

    @router.delete("/mcp/oauth/flows/{flow_id}")
    async def mcp_oauth_flow_cancel(
        flow_id: str, profile: str | None = Query(None)
    ) -> Any:
        query = {"profile": profile} if profile else None
        return await _backend_json(
            require_backend(),
            "DELETE",
            f"/api/mcp/oauth/flows/{flow_id}",
            query=query,
        )

    @router.get("/mcp/catalog")
    async def mcp_catalog(profile: str | None = Query(None)) -> Any:
        be = require_backend()
        query = {"profile": profile} if profile else None
        return await _backend_json(be, "GET", "/api/mcp/catalog", query=query)

    @router.post("/mcp/catalog/install")
    async def mcp_catalog_install(
        payload: dict = Body(...), profile: str | None = Query(None)
    ) -> Any:
        query = {"profile": profile} if profile else None
        return await _backend_json(
            require_backend(), "POST", "/api/mcp/catalog/install", query=query, body=payload
        )

    @router.get("/actions/{name}/status")
    async def action_status(
        name: str,
        lines: int = Query(200, ge=1, le=2000),
        profile: str | None = Query(None),
    ) -> Any:
        return await _backend_json(
            require_backend(),
            "GET",
            f"/api/actions/{name}/status",
            query={"lines": lines, **({"profile": profile} if profile else {})},
        )

    # -------------------------------------------------------------- plugins
    # Inventory/toggle use the gateway. Declarative mobile contributions may
    # additionally call their own namespaced backend REST endpoint.
    @router.get("/plugins")
    async def list_plugins(profile: str | None = Query(None)) -> Any:
        be = require_backend()
        hermes_home = get_hermes_home()
        try:
            # Validate before forwarding the profile to the gateway or touching
            # disk. The resolved path is recomputed by the enrichment worker.
            profile_plugins_root(hermes_home, profile)
        except ValueError as exc:
            raise HTTPException(status_code=422, detail=str(exc)) from exc
        try:
            payload = await be.gateway_rpc(
                "plugins.manage",
                {"action": "list", **({"profile": profile} if profile else {})},
            )
        except BackendError as exc:
            raise HTTPException(status_code=502, detail=str(exc))
        source_root = getattr(getattr(be, "runtime", None), "source_root", None)
        if source_root is None:
            return payload
        try:
            return await asyncio.to_thread(
                enrich_plugin_inventory,
                payload,
                source_root=source_root,
                hermes_home=hermes_home,
                profile=profile,
            )
        except Exception:  # noqa: BLE001 - inventory remains available on bad disk state
            logger.exception("Failed to enrich plugin inventory from manifests")
            return payload

    @router.put("/plugins/{name}/enabled")
    async def toggle_plugin(
        name: str,
        payload: dict = Body(...),
        profile: str | None = Query(None),
    ) -> Any:
        be = require_backend()
        try:
            return await be.gateway_rpc(
                "plugins.manage",
                {
                    "action": "toggle",
                    "name": name,
                    "enable": payload.get("enabled", False),
                    **({"profile": profile} if profile else {}),
                },
            )
        except BackendError as exc:
            raise HTTPException(status_code=502, detail=str(exc))

    @router.post("/plugins/install")
    async def install_plugin(
        payload: dict = Body(...), profile: str | None = Query(None)
    ) -> Any:
        identifier = str(payload.get("identifier") or "").strip()
        if not identifier:
            raise HTTPException(status_code=422, detail="identifier is required")
        try:
            return await require_backend().gateway_rpc(
                "plugins.manage",
                {
                    "action": "install",
                    "identifier": identifier,
                    "force": bool(payload.get("force")),
                    "enable": payload.get("enable", True) is not False,
                    **({"profile": profile} if profile else {}),
                },
            )
        except BackendError as exc:
            raise HTTPException(status_code=502, detail=str(exc))

    @router.api_route(
        "/plugins/{plugin_id}/{action_path:path}",
        methods=["GET", "POST", "PUT", "PATCH", "DELETE"],
    )
    async def invoke_plugin_contribution(
        plugin_id: str,
        action_path: str,
        request: Request,
    ) -> Any:
        if not plugin_id or not action_path or ".." in action_path.split("/"):
            raise HTTPException(status_code=422, detail="invalid plugin action path")
        payload = None
        if request.method not in ("GET", "DELETE"):
            try:
                payload = await request.json()
            except ValueError:
                payload = None
        return await _backend_json(
            require_backend(),
            request.method,
            f"/api/plugins/{quote(plugin_id, safe='')}/{quote(action_path, safe='/')}",
            query=dict(request.query_params),
            body=payload,
        )

    # ----------------------------------------------------------------- tasks
    # Production is a view of Hermes' *actual* Kanban plugin.  The plugin
    # routes are the public, canonical surface used by the desktop dashboard
    # and CLI, including its transition validation and dispatcher behaviour.
    # ``TaskStore`` survives strictly as an explicitly injected test double;
    # it must never be constructed implicitly in production.
    legacy_task_store = task_store
    if legacy_task_store is not None and backend is not None:
        backend.add_event_listener(legacy_task_store.on_backend_event)

    @router.get("/tasks")
    async def list_tasks(
        status: str | None = Query(None),
        limit: int = Query(200, ge=1, le=500),
    ) -> dict:
        if legacy_task_store is not None:
            if status and status not in STATUSES:
                raise HTTPException(status_code=422, detail=f"status must be one of {STATUSES}")
            return {"tasks": await legacy_task_store.list(status=status, limit=limit)}
        if status and status not in HERMES_KANBAN_STATUSES:
            raise HTTPException(
                status_code=422,
                detail=f"status must be one of {HERMES_KANBAN_STATUSES}",
            )
        board = await _backend_json(
            require_backend(), "GET", "/api/plugins/kanban/board",
            query={"include_archived": "true"},
        )
        tasks = [
            _mobile_task(task)
            for column in (board.get("columns") or [])
            for task in (column.get("tasks") or [])
        ]
        if status:
            tasks = [task for task in tasks if task["status"] == status]
        return {"tasks": tasks[:limit]}

    @router.post("/tasks")
    async def create_task(payload: dict = Body(...)) -> dict:
        if legacy_task_store is not None:
            try:
                return await legacy_task_store.create(
                    title=str(payload.get("title", "")).strip(),
                    prompt=str(payload.get("prompt", "")),
                    priority=str(payload.get("priority", "normal")),
                )
            except ValueError as exc:
                raise HTTPException(status_code=422, detail=str(exc)) from exc
        title = str(payload.get("title", "")).strip()
        if not title:
            raise HTTPException(status_code=422, detail="title is required")
        created = await _backend_json(
            require_backend(), "POST", "/api/plugins/kanban/tasks",
            body={
                "title": title,
                "body": str(payload.get("prompt", "")),
                "priority": _hermes_priority(payload.get("priority", "normal")),
                # A mobile-created task should enter the same triage lane the
                # Hermes dashboard exposes, rather than a mobile-only inbox.
                "triage": bool(payload.get("triage", True)),
            },
        )
        return _mobile_task(created.get("task"))

    @router.get("/tasks/{task_id}")
    async def get_task(task_id: str) -> dict:
        if legacy_task_store is not None:
            task = await legacy_task_store.get(task_id)
            if task is None:
                raise HTTPException(status_code=404, detail="task not found")
            return task
        result = await _backend_json(
            require_backend(), "GET", f"/api/plugins/kanban/tasks/{task_id}"
        )
        return _mobile_task(result.get("task"))

    @router.patch("/tasks/{task_id}")
    async def patch_task(
        task_id: str,
        payload: dict = Body(...),
        profile: str | None = None,
    ) -> dict:
        if legacy_task_store is not None:
            task = await legacy_task_store.update(task_id, **payload)
            if task is None:
                raise HTTPException(status_code=404, detail="task not found")
            return task
        patch: dict[str, Any] = {}
        if "title" in payload:
            patch["title"] = payload["title"]
        if "prompt" in payload:
            patch["body"] = payload["prompt"]
        if "priority" in payload:
            patch["priority"] = _hermes_priority(payload["priority"])
        if "status" in payload:
            status = str(payload["status"])
            if status not in HERMES_KANBAN_STATUSES:
                raise HTTPException(
                    status_code=422,
                    detail=f"status must be one of {HERMES_KANBAN_STATUSES}",
                )
            patch["status"] = status
        if not patch:
            return await get_task(task_id)
        result = await _backend_json(
            require_backend(), "PATCH", f"/api/plugins/kanban/tasks/{task_id}",
            query={"profile": profile} if profile else None,
            body=patch,
        )
        return _mobile_task(result.get("task"))

    @router.delete("/tasks/{task_id}")
    async def delete_task(task_id: str) -> dict:
        if legacy_task_store is not None:
            if not await legacy_task_store.delete(task_id):
                raise HTTPException(status_code=404, detail="task not found")
            return {"ok": True}
        result = await _backend_json(
            require_backend(), "DELETE", f"/api/plugins/kanban/tasks/{task_id}"
        )
        if not result.get("deleted", False):
            raise HTTPException(status_code=404, detail="task not found")
        return {"ok": True}

    @router.post("/tasks/{task_id}/run")
    async def run_task(task_id: str) -> dict:
        if legacy_task_store is not None:
            task = await legacy_task_store.get(task_id)
            if task is None:
                raise HTTPException(status_code=404, detail="task not found")
            if task["status"] == "running":
                raise HTTPException(status_code=409, detail="task is already running")
            be = require_backend()
            try:
                result = await be.gateway_rpc(
                    "session.create", {"cols": 48, "source": "mobile"}
                )
            except BackendError as exc:
                raise HTTPException(status_code=502, detail=str(exc)) from exc
            session_id = result.get("stored_session_id") or result.get("session_id")
            runtime_id = result.get("session_id")
            if not session_id or not runtime_id:
                raise HTTPException(status_code=502, detail="session.create returned no id")
            await legacy_task_store.mark_running(task_id, session_id, runtime_id)
            prompt = (task.get("prompt") or "").strip()
            if prompt:
                asyncio.create_task(_submit_task_prompt(be, runtime_id, prompt, task_id))
            return {"task": await legacy_task_store.get(task_id), "session_id": session_id}

        # Hermes intentionally has no direct "run this card in a detached
        # mobile session" operation.  Promote the card through its canonical
        # state machine and nudge the real dispatcher, which preserves claims,
        # retries and worker ownership exactly as desktop does.
        task = await get_task(task_id)
        if task["status"] == "running":
            raise HTTPException(status_code=409, detail="task is already running")
        if task["status"] != "ready":
            task = await patch_task(task_id, {"status": "ready"})
        dispatch = await _backend_json(
            require_backend(), "POST", "/api/plugins/kanban/dispatch"
        )
        return {"task": await get_task(task_id), "dispatch": dispatch}

    # -------------------------------------------------- files (extended)
    @router.post("/files/move")
    async def move_file(payload: dict = Body(...)) -> Any:
        return await local(lambda: local_workspace.move(
            payload.get("path", ""), payload.get("dest", ""), overwrite=bool(payload.get("overwrite"))
        ))

    @router.post("/files/copy")
    async def copy_files(payload: dict = Body(...)) -> Any:
        """Copy one or more selected entries into a directory.

        The request shape intentionally mirrors the WebUI browser: sources,
        dest_path and overwrite.  Single-item callers may use source/path.
        """
        sources = payload.get("sources") or [payload.get("path") or payload.get("source")]
        sources = [item for item in sources if isinstance(item, str) and item]
        if not sources or not isinstance(payload.get("dest_path") or payload.get("dest"), str):
            raise HTTPException(status_code=422, detail="sources and dest_path are required")
        return await local(lambda: local_workspace.copy(
            sources, payload.get("dest_path") or payload.get("dest"), overwrite=bool(payload.get("overwrite"))
        ))

    @router.post("/files/mkdir")
    async def mkdir(payload: dict = Body(...)) -> Any:
        return await local(lambda: local_workspace.mkdir(payload.get("path", "")))

    @router.post("/files/delete")
    async def delete_file(payload: dict = Body(...)) -> Any:
        sources = payload.get("sources") or [payload.get("path")]
        sources = [item for item in sources if isinstance(item, str) and item]
        return await local(lambda: local_workspace.remove(sources, recursive=bool(payload.get("recursive"))))

    @router.post("/files/upload")
    async def upload_file(payload: dict = Body(...)) -> Any:
        """Upload a file via base64 data URL (attachment flow, D6)."""
        return await local(lambda: local_workspace.write_data_url(
            payload.get("path", ""), payload.get("data_url", ""), overwrite=bool(payload.get("overwrite"))
        ))

    @router.delete("/files")
    async def delete_file_canonical(payload: dict = Body(default={})) -> Any:
        sources = payload.get("sources") or [payload.get("path")]
        sources = [item for item in sources if isinstance(item, str) and item]
        return await local(
            lambda: local_workspace.remove(
                sources, recursive=bool(payload.get("recursive"))
            )
        )

    # ------------------------------------------------------------ artifacts
    #
    # The backend has no /api/artifacts endpoint. The desktop client extracts
    # artifacts (image paths, file paths, URLs) from session transcripts
    # client-side. We port that logic server-side so the mobile client gets
    # the same results without downloading every transcript.

    @router.get("/artifacts")
    async def list_artifacts(
        session_id: str | None = Query(None),
        limit: int = Query(50, ge=1, le=200),
        offset: int = Query(0, ge=0),
    ) -> Any:
        be = require_backend()
        client = await be.http_client()

        # Determine which sessions to scan.
        if session_id:
            sessions_to_scan = [{"id": session_id, "title": None}]
        else:
            try:
                resp = await client.request(
                    "GET", "/api/profiles/sessions",
                    params={"limit": min(limit * 2, 100)},
                )
                raw = resp.json() if resp.status_code < 400 else {}
            except httpx.HTTPError:
                raw = {}
            sessions_to_scan = (raw or {}).get("sessions", []) or []

        # Scan each session's transcript for artifacts.
        all_artifacts: list[dict] = []
        seen_keys: set[str] = set()

        for sess in sessions_to_scan:
            sid = sess.get("id") or sess.get("session_id") or ""
            if not sid:
                continue
            stitle = (sess.get("title") or sess.get("preview") or
                      "Untitled session")
            try:
                resp = await client.request(
                    "GET", f"/api/sessions/{sid}/messages",
                    params={"limit": 200},
                )
                if resp.status_code >= 400:
                    continue
                msgs = (resp.json() or {}).get("messages", []) or []
            except httpx.HTTPError:
                continue

            for msg in msgs:
                if msg.get("role") not in ("assistant", "tool"):
                    continue
                row_id = msg.get("row_id") or msg.get("id")
                text = _extract_message_text(msg)
                found = _collect_artifacts_from_text(text)
                # Also scan tool call arguments and JSON tool results.
                if msg.get("tool_calls"):
                    for tc in msg["tool_calls"]:
                        _collect_artifacts_from_obj(tc, found)
                if msg.get("tool_result"):
                    _collect_artifacts_from_obj(
                        msg["tool_result"], found)
                elif text:
                    parsed = _try_parse_json(text)
                    if parsed is not None:
                        _collect_artifacts_from_obj(parsed, found)

                for value in found:
                    value = _normalize_artifact_value(value)
                    if not value or not _looks_like_artifact(value):
                        continue
                    key = f"{sid}:{value}"
                    if key in seen_keys:
                        continue
                    seen_keys.add(key)
                    all_artifacts.append({
                        "id": key,
                        "kind": _artifact_kind(value),
                        "value": value,
                        "label": _artifact_label(value),
                        "session_id": sid,
                        "session_title": stitle,
                        "row_id": row_id,
                    })
                    if len(all_artifacts) >= limit + offset:
                        break
                if len(all_artifacts) >= limit + offset:
                    break
            if len(all_artifacts) >= limit + offset:
                break

        page = all_artifacts[offset:offset + limit]
        return {"artifacts": page, "total": len(all_artifacts)}

    # -------------------------------------------------------------- starmap
    @router.get("/starmap/graph")
    async def starmap_graph() -> Any:
        be = require_backend()
        return await _backend_json(be, "GET", "/api/learning/graph")

    @router.get("/starmap/node")
    async def starmap_node(id: str = Query(...)) -> Any:
        be = require_backend()
        return await _backend_json(be, "GET", "/api/learning/node", query={"id": id})

    @router.put("/starmap/node")
    async def starmap_node_update(payload: dict = Body(...)) -> Any:
        be = require_backend()
        return await _backend_json(be, "PUT", "/api/learning/node", body=payload)

    @router.delete("/starmap/node")
    async def starmap_node_delete(id: str = Query(...)) -> dict:
        be = require_backend()
        return _ok_response(
            await _backend_json(be, "DELETE", "/api/learning/node", query={"id": id})
        )

    # ----------------------------------------------------------- subagents
    @router.get("/subagents")
    async def list_subagents(session_id: str = Query(...)) -> Any:
        be = require_backend()
        try:
            indexed = await be.gateway_rpc(
                "spawn_tree.list", {"session_id": session_id, "limit": 50}
            )
            nodes: dict[str, dict] = {}
            for entry in indexed.get("entries", []):
                path = entry.get("path")
                if not path:
                    continue
                try:
                    snapshot = await be.gateway_rpc("spawn_tree.load", {"path": path})
                except BackendError:
                    continue
                for node in snapshot.get("subagents", []):
                    if isinstance(node, dict):
                        item = dict(node)
                        child_session_id = str(item.get("child_session_id") or "")
                        if child_session_id:
                            item["child_session_id"] = child_session_id
                            item["session_id"] = child_session_id
                        else:
                            item.pop("session_id", None)
                        item.setdefault("status", "completed")
                        nodes[child_session_id or str(item.get("id") or item.get("subagent_id"))] = item
            try:
                durable_rows = [
                    row for row in await _all_child_session_rows(be)
                    if _is_subagent_child(row)
                ]
                for row in durable_rows:
                    parent_id = _row_parent_id(row)
                    if parent_id != session_id:
                        continue
                    child_id = _row_id(row)
                    if child_id:
                        nodes[child_id] = _subagent_projection(row, parent_id)
            except (BackendError, TypeError, ValueError):
                pass
            try:
                active = await be.gateway_rpc("delegation.status", {})
                for node in active.get("active", []):
                    if isinstance(node, dict) and str(node.get("parent_session_id") or node.get("parent_id") or session_id) == session_id:
                        item = dict(node)
                        child_session_id = str(item.get("child_session_id") or "")
                        if child_session_id:
                            item["child_session_id"] = child_session_id
                            item["session_id"] = child_session_id
                            existing = nodes.get(child_session_id)
                            nodes[child_session_id] = {**(existing or {}), **item}
                        else:
                            item.pop("session_id", None)
                            nodes[str(item.get("id") or item.get("subagent_id"))] = item
            except BackendError:
                pass
            return {"subagents": list(nodes.values())}
        except BackendError as exc:
            raise HTTPException(status_code=502, detail=str(exc))

    @router.post("/subagents/query")
    async def query_subagents(payload: dict = Body(...)) -> Any:
        be = require_backend()
        session_ids = {
            str(value) for value in payload.get("session_ids", []) if str(value)
        }
        logger.info(
            "[subagent] query start parents=%d ids=%s",
            len(session_ids), sorted(session_ids),
        )
        grouped: dict[str, dict[str, dict]] = {sid: {} for sid in session_ids}
        if not session_ids:
            return {"by_session": {}}
        try:
            indexed = await be.gateway_rpc(
                "spawn_tree.list", {"cross_session": True, "limit": 1000}
            )
            snapshot_entries = indexed.get("entries", [])
            logger.info(
                "[subagent] spawn-tree index entries=%d requested_parents=%d",
                len(snapshot_entries), len(session_ids),
            )
            snapshot_matches = 0
            snapshot_nodes = 0
            for entry in snapshot_entries:
                parent_id = str(entry.get("session_id") or "")
                path = entry.get("path")
                if parent_id not in session_ids or not path:
                    continue
                snapshot_matches += 1
                try:
                    snapshot = await be.gateway_rpc("spawn_tree.load", {"path": path})
                except BackendError as exc:
                    logger.warning(
                        "[subagent] spawn-tree load failed parent=%s path=%s error=%s",
                        parent_id, path, exc,
                    )
                    continue
                loaded_nodes = snapshot.get("subagents", [])
                logger.info(
                    "[subagent] spawn-tree loaded parent=%s path=%s nodes=%d",
                    parent_id, path, len(loaded_nodes),
                )
                for node in loaded_nodes:
                    if not isinstance(node, dict):
                        continue
                    item = dict(node)
                    child_session_id = str(item.get("child_session_id") or "")
                    if child_session_id:
                        item["child_session_id"] = child_session_id
                        item["session_id"] = child_session_id
                    else:
                        item.pop("session_id", None)
                    item.setdefault("status", "completed")
                    key = child_session_id or str(item.get("id") or item.get("subagent_id") or "")
                    if key:
                        grouped[parent_id][key] = item
                        snapshot_nodes += 1
            logger.info(
                "[subagent] spawn-tree summary matched_snapshots=%d merged_nodes=%d",
                snapshot_matches, snapshot_nodes,
            )

            durable_rows = [
                row for row in await _all_child_session_rows(be)
                if _is_subagent_child(row)
            ]
            logger.info(
                "[subagent] durable projection rows=%d (cached shared scan)",
                len(durable_rows),
            )
            durable_candidates = 0
            durable_matches = 0
            for row in durable_rows:
                if not isinstance(row, dict) or not _is_subagent_child(row):
                    continue
                parent_id = _row_parent_id(row)
                if parent_id in session_ids:
                    durable_candidates += 1
                else:
                    continue
                child_id = _row_id(row)
                if child_id:
                    durable_matches += 1
                    logger.info(
                        "[subagent] durable match parent=%s child=%s source=%s",
                        parent_id, child_id, row.get("source"),
                    )
                    existing = grouped[parent_id].get(child_id)
                    projected = _subagent_projection(row, parent_id)
                    grouped[parent_id][child_id] = {
                        **projected,
                        **(existing or {}),
                        "id": child_id,
                        "session_id": child_id,
                        "child_session_id": child_id,
                        "goal": (existing or {}).get("goal") or projected.get("goal"),
                    }
            logger.info(
                "[subagent] durable summary scanned=%d parent_candidates=%d matched=%d",
                len(durable_rows), durable_candidates, durable_matches,
            )

            active = await be.gateway_rpc("delegation.status", {})
            active_rows = active.get("active", [])
            active_matches = 0
            logger.info("[subagent] active status rows=%d", len(active_rows))
            for node in active_rows:
                if not isinstance(node, dict):
                    continue
                parent_id = str(node.get("parent_session_id") or node.get("parent_id") or "")
                if parent_id not in session_ids:
                    continue
                item = dict(node)
                child_session_id = str(item.get("child_session_id") or "")
                if child_session_id:
                    item["child_session_id"] = child_session_id
                    item["session_id"] = child_session_id
                    key = child_session_id
                    existing = grouped[parent_id].get(key, {})
                    grouped[parent_id][key] = {
                        **item,
                        **existing,
                        "id": child_session_id,
                        "goal": item.get("goal") or existing.get("goal"),
                        "status": item.get("status") or existing.get("status") or "running",
                        "progress": item.get("progress", existing.get("progress")),
                    }
                else:
                    item.pop("session_id", None)
                    key = str(item.get("id") or item.get("subagent_id") or "")
                    if key:
                        grouped[parent_id][key] = item
                if key:
                    active_matches += 1
                    logger.info(
                        "[subagent] active match parent=%s node=%s child_session=%s status=%s",
                        parent_id, key, item.get("child_session_id"),
                        item.get("status"),
                    )
            result = {
                sid: list(nodes.values()) for sid, nodes in grouped.items()
            }
            logger.info(
                "[subagent] query complete snapshot=%d durable=%d active=%d counts=%s",
                snapshot_nodes, durable_matches, active_matches,
                {sid: len(nodes) for sid, nodes in result.items()},
            )
            return {"by_session": result}
        except BackendError as exc:
            logger.exception(
                "[subagent] query failed parents=%s error=%s",
                sorted(session_ids), exc,
            )
            raise HTTPException(status_code=502, detail=str(exc))

    @router.get("/subagents/projection")
    async def subagents_projection() -> Any:
        """Full child-session + runtime projection for the sidebar tree.

        Shape: {sessions: [SessionRow-shaped child rows], by_session:
        {parent_id: [SubagentNode]}, total: int}. Reuses the cached child
        scan and the query merge logic so the client gets one authoritative
        snapshot instead of stitching /sessions and /subagents/query.
        """
        be = require_backend()
        child_rows = await _all_child_session_rows(be)
        sessions: list[dict] = []
        parent_ids: list[str] = []
        seen_parents: set[str] = set()
        for row in child_rows:
            parent_id = _row_parent_id(row)
            if not parent_id:
                continue
            if parent_id not in seen_parents:
                seen_parents.add(parent_id)
                parent_ids.append(parent_id)
            sessions.append(_subagent_projection(row, parent_id))
        grouped_payload = await query_subagents({"session_ids": parent_ids})
        by_session = (
            grouped_payload.get("by_session", {})
            if isinstance(grouped_payload, dict)
            else {}
        )
        total = sum(len(nodes) for nodes in by_session.values())
        logger.info(
            "[subagent] projection sessions=%d parents=%d total_nodes=%d",
            len(sessions), len(parent_ids), total,
        )
        return {"sessions": sessions, "by_session": by_session, "total": total}

    @router.get("/subagents/active")
    async def active_subagents() -> Any:
        be = require_backend()
        try:
            return await be.gateway_rpc("agents.list", {})
        except BackendError as exc:
            raise HTTPException(status_code=502, detail=str(exc))

    @router.post("/subagents/{subagent_id}/interrupt")
    async def interrupt_subagent(
        subagent_id: str, profile: str | None = Query(None)
    ) -> Any:
        be = require_backend()
        try:
            return await be.gateway_rpc(
                "subagent.interrupt",
                {"subagent_id": subagent_id, **({"profile": profile} if profile else {})},
            )
        except BackendError as exc:
            raise HTTPException(status_code=502, detail=str(exc))

    # ----------------------------------------------------------------- pet
    @router.get("/pet")
    async def pet_info() -> Any:
        be = require_backend()
        try:
            return await be.gateway_rpc("pet.info", {})
        except BackendError as exc:
            raise HTTPException(status_code=502, detail=str(exc))

    @router.get("/pet/gallery")
    async def pet_gallery() -> Any:
        be = require_backend()
        try:
            return await be.gateway_rpc("pet.gallery", {})
        except BackendError as exc:
            raise HTTPException(status_code=502, detail=str(exc))

    @router.post("/pet/select")
    async def pet_select(payload: dict = Body(...)) -> Any:
        be = require_backend()
        try:
            return await be.gateway_rpc("pet.select", payload)
        except BackendError as exc:
            raise HTTPException(status_code=502, detail=str(exc))

    @router.post("/pet/hatch")
    async def pet_hatch(payload: dict = Body(...)) -> Any:
        be = require_backend()
        try:
            return await be.gateway_rpc("pet.hatch", payload)
        except BackendError as exc:
            raise HTTPException(status_code=502, detail=str(exc))

    @router.post("/pet/generate")
    async def pet_generate(payload: dict = Body(...)) -> Any:
        be = require_backend()
        try:
            return await be.gateway_rpc("pet.generate", payload)
        except BackendError as exc:
            raise HTTPException(status_code=502, detail=str(exc))

    @router.get("/pet/generate/status")
    async def pet_generate_status() -> Any:
        be = require_backend()
        try:
            return await be.gateway_rpc("pet.generate.status", {})
        except BackendError as exc:
            raise HTTPException(status_code=502, detail=str(exc))

    @router.post("/pet/disable")
    async def pet_disable() -> Any:
        be = require_backend()
        try:
            return await be.gateway_rpc("pet.disable", {})
        except BackendError as exc:
            raise HTTPException(status_code=502, detail=str(exc))

    @router.post("/pet/rename")
    async def pet_rename(payload: dict = Body(...)) -> Any:
        be = require_backend()
        try:
            return await be.gateway_rpc("pet.rename", payload)
        except BackendError as exc:
            raise HTTPException(status_code=502, detail=str(exc))

    @router.post("/pet/cancel")
    async def pet_cancel(payload: dict = Body(...)) -> Any:
        be = require_backend()
        try:
            return await be.gateway_rpc("pet.cancel", payload)
        except BackendError as exc:
            raise HTTPException(status_code=502, detail=str(exc))

    @router.post("/pet/remove")
    async def pet_remove(payload: dict = Body(...)) -> Any:
        be = require_backend()
        try:
            return await be.gateway_rpc("pet.remove", payload)
        except BackendError as exc:
            raise HTTPException(status_code=502, detail=str(exc))

    # ------------------------------------------------------------- billing
    @router.get("/billing")
    async def billing_state() -> Any:
        be = require_backend()
        try:
            return await be.gateway_rpc("billing.state", {})
        except BackendError as exc:
            raise HTTPException(status_code=502, detail=str(exc))

    @router.post("/billing/charge")
    async def billing_charge(payload: dict = Body(...)) -> Any:
        be = require_backend()
        try:
            return await be.gateway_rpc("billing.charge", payload)
        except BackendError as exc:
            raise HTTPException(status_code=502, detail=str(exc))

    @router.get("/billing/charge/status")
    async def billing_charge_status(charge_id: str = Query(..., min_length=1)) -> Any:
        be = require_backend()
        try:
            return await be.gateway_rpc(
                "billing.charge_status", {"charge_id": charge_id}
            )
        except BackendError as exc:
            raise HTTPException(status_code=502, detail=str(exc))

    @router.post("/billing/auto-reload")
    async def billing_auto_reload(payload: dict = Body(...)) -> Any:
        be = require_backend()
        try:
            return await be.gateway_rpc("billing.auto_reload", payload)
        except BackendError as exc:
            raise HTTPException(status_code=502, detail=str(exc))

    @router.post("/billing/step-up")
    async def billing_step_up(payload: dict = Body(...)) -> Any:
        be = require_backend()
        try:
            return await be.gateway_rpc("billing.step_up", payload)
        except BackendError as exc:
            raise HTTPException(status_code=502, detail=str(exc))

    @router.get("/billing/usage-bars")
    async def usage_bars() -> Any:
        be = require_backend()
        try:
            return await be.gateway_rpc("usage.bars", {})
        except BackendError as exc:
            raise HTTPException(status_code=502, detail=str(exc))

    @router.get("/provider/quota")
    async def provider_quota(
        provider: str = Query(default=""), refresh: bool = Query(default=False)
    ) -> Any:
        """Ambient provider quota/usage status (WebUI `/api/provider/quota`).

        Passes supported backend payloads through untouched. Older Hermes
        runtimes do not expose this optional route; report that capability as
        unavailable instead of leaking the upstream 404 through Mobile's API.
        """
        be = require_backend()
        query: dict[str, str] = {}
        if provider.strip():
            query["provider"] = provider.strip()
        if refresh:
            query["refresh"] = "true"
        try:
            return await _backend_json(
                be, "GET", "/api/provider/quota", query=query
            )
        except HTTPException as exc:
            if exc.status_code != 404:
                raise
            return {
                "supported": False,
                "status": "unavailable",
                "message": (
                    "Provider quota is not supported by this Hermes runtime."
                ),
            }

    @router.get("/subscription")
    async def subscription_state() -> Any:
        be = require_backend()
        try:
            return await be.gateway_rpc("subscription.state", {})
        except BackendError as exc:
            raise HTTPException(status_code=502, detail=str(exc))

    @router.post("/subscription/preview")
    async def subscription_preview(payload: dict = Body(...)) -> Any:
        be = require_backend()
        try:
            return await be.gateway_rpc("subscription.preview", payload)
        except BackendError as exc:
            raise HTTPException(status_code=502, detail=str(exc))

    @router.post("/subscription/change")
    async def subscription_change(payload: dict = Body(...)) -> Any:
        be = require_backend()
        try:
            return await be.gateway_rpc("subscription.change", payload)
        except BackendError as exc:
            raise HTTPException(status_code=502, detail=str(exc))

    @router.post("/subscription/resume")
    async def subscription_resume() -> Any:
        be = require_backend()
        try:
            return await be.gateway_rpc("subscription.resume", {})
        except BackendError as exc:
            raise HTTPException(status_code=502, detail=str(exc))

    @router.post("/subscription/upgrade")
    async def subscription_upgrade(payload: dict = Body(...)) -> Any:
        be = require_backend()
        try:
            return await be.gateway_rpc("subscription.upgrade", payload)
        except BackendError as exc:
            raise HTTPException(status_code=502, detail=str(exc))

    # --------------------------------------------------------- credentials
    @router.get("/credentials/providers")
    async def credential_providers() -> Any:
        be = require_backend()
        try:
            return await be.gateway_rpc("model.options", {"explicit_only": True, "include_unconfigured": True})
        except BackendError as exc:
            raise HTTPException(status_code=502, detail=str(exc))

    @router.post("/credentials/save-key")
    async def save_credential_key(payload: dict = Body(...)) -> Any:
        be = require_backend()
        try:
            return await be.gateway_rpc("model.save_key", payload)
        except BackendError as exc:
            raise HTTPException(status_code=502, detail=str(exc))

    @router.post("/credentials/disconnect")
    async def disconnect_credential(payload: dict = Body(...)) -> Any:
        be = require_backend()
        try:
            return await be.gateway_rpc("model.disconnect", payload)
        except BackendError as exc:
            raise HTTPException(status_code=502, detail=str(exc))

    # ----------------------------------------------------------- messaging
    @router.get("/messaging/platforms")
    async def messaging_platforms(profile: str | None = Query(None)) -> Any:
        be = require_backend()
        return await _backend_json(
            be,
            "GET",
            "/api/messaging/platforms",
            query={"profile": profile} if profile else None,
        )

    @router.put("/messaging/platforms/{platform}")
    async def messaging_update_platform(
        platform: str,
        payload: dict = Body(...),
        profile: str | None = Query(None),
    ) -> Any:
        return await _backend_json(
            require_backend(),
            "PUT",
            f"/api/messaging/platforms/{platform}",
            query={"profile": profile} if profile else None,
            body=payload,
        )

    @router.post("/messaging/platforms/{platform}/test")
    async def messaging_test_platform(
        platform: str, profile: str | None = Query(None)
    ) -> Any:
        return await _backend_json(
            require_backend(),
            "POST",
            f"/api/messaging/platforms/{platform}/test",
            query={"profile": profile} if profile else None,
        )

    @router.get("/pairing")
    async def messaging_pairing(profile: str | None = Query(None)) -> Any:
        return await _backend_json(
            require_backend(),
            "GET",
            "/api/pairing",
            query={"profile": profile} if profile else None,
        )

    @router.post("/pairing/approve")
    async def messaging_approve_pairing(payload: dict = Body(...)) -> Any:
        return await _backend_json(
            require_backend(), "POST", "/api/pairing/approve", body=payload
        )

    @router.post("/pairing/revoke")
    async def messaging_revoke_pairing(payload: dict = Body(...)) -> Any:
        return await _backend_json(
            require_backend(), "POST", "/api/pairing/revoke", body=payload
        )

    @router.post("/gateway/restart")
    async def messaging_restart_gateway() -> Any:
        return await _backend_json(require_backend(), "POST", "/api/gateway/restart")

    @router.get("/messaging/{platform}/config")
    async def messaging_config(
        platform: str, profile: str | None = Query(None)
    ) -> Any:
        be = require_backend()
        result = await _backend_json(
            be,
            "GET",
            "/api/messaging/platforms",
            query={"profile": profile} if profile else None,
        )
        item = next(
            (
                row
                for row in (result.get("platforms") or [])
                if isinstance(row, dict)
                and str(row.get("id") or row.get("name") or "").lower()
                == platform.lower()
            ),
            None,
        )
        if item is None:
            raise HTTPException(status_code=404, detail="messaging platform not found")
        return item

    @router.put("/messaging/{platform}/config")
    async def messaging_set_config(
        platform: str,
        payload: dict = Body(...),
        profile: str | None = Query(None),
    ) -> Any:
        be = require_backend()
        return await _backend_json(
            be,
            "PUT",
            f"/api/messaging/platforms/{platform}",
            query={"profile": profile} if profile else None,
            body=payload,
        )

    @router.post("/messaging/{platform}/env")
    async def messaging_set_env(
        platform: str,
        payload: dict = Body(...),
        profile: str | None = Query(None),
    ) -> Any:
        be = require_backend()
        key = str(payload.get("key") or "").strip()
        if not key:
            raise HTTPException(status_code=422, detail="key is required")
        value = str(payload.get("value") or "")
        body = {"env": {key: value}} if value.strip() else {"clear_env": [key]}
        return await _backend_json(
            be,
            "PUT",
            f"/api/messaging/platforms/{platform}",
            query={"profile": profile} if profile else None,
            body=body,
        )

    @router.get("/messaging/{platform}/pending")
    async def messaging_pending(
        platform: str, profile: str | None = Query(None)
    ) -> Any:
        be = require_backend()
        result = await _backend_json(
            be,
            "GET",
            "/api/pairing",
            query={"profile": profile} if profile else None,
        )
        return {
            "pending": [
                row
                for row in (result.get("pending") or [])
                if isinstance(row, dict)
                and str(row.get("platform") or "").lower() == platform.lower()
            ]
        }

    @router.post("/messaging/{platform}/pair/{pairing_id}/approve")
    async def messaging_approve_pair(
        platform: str,
        pairing_id: str,
        profile: str | None = Query(None),
    ) -> Any:
        be = require_backend()
        return await _backend_json(
            be,
            "POST",
            "/api/pairing/approve",
            body={
                "platform": platform,
                "request_id": pairing_id,
                **({"profile": profile} if profile else {}),
            },
        )

    # ------------------------------------------------------------ webhooks
    @router.get("/webhooks")
    async def list_webhooks() -> Any:
        be = require_backend()
        result = await _backend_json(be, "GET", "/api/webhooks")
        return {**result, "webhooks": result.get("subscriptions", [])}

    @router.post("/webhooks/enable")
    async def enable_webhooks() -> Any:
        return await _backend_json(
            require_backend(), "POST", "/api/webhooks/enable"
        )

    @router.post("/webhooks")
    async def create_webhook(payload: dict = Body(...)) -> Any:
        be = require_backend()
        return await _backend_json(be, "POST", "/api/webhooks", body=payload)

    @router.put("/webhooks/{webhook_id}/enabled")
    async def set_webhook_enabled(webhook_id: str, payload: dict = Body(...)) -> Any:
        be = require_backend()
        return await _backend_json(
            be,
            "PUT",
            f"/api/webhooks/{webhook_id}/enabled",
            body={"enabled": bool(payload.get("enabled"))},
        )

    @router.delete("/webhooks/{webhook_id}")
    async def delete_webhook(webhook_id: str) -> dict:
        be = require_backend()
        return _ok_response(
            await _backend_json(be, "DELETE", f"/api/webhooks/{webhook_id}")
        )

    # ------------------------------------------------------- git (extended)
    @router.post("/git/commit-message")
    async def git_commit_message(payload: dict = Body(...)) -> Any:
        be = require_backend()
        path = str(payload.get("path") or "").strip()
        if not path:
            raise HTTPException(status_code=422, detail="path is required")
        context = await _backend_json(
            be, "GET", "/api/git/review/commit-context", query={"path": path}
        )
        diff = str(context.get("diff") or "")
        if not diff.strip():
            return {"message": ""}
        try:
            result = await be.gateway_rpc(
                "llm.oneshot",
                {
                    "template": "commit_message",
                    "temperature": 0.8,
                    "variables": {
                        "avoid": str(payload.get("previous") or ""),
                        "diff": diff,
                        "recent_commits": context.get("recent") or [],
                    },
                },
            )
        except BackendError as exc:
            raise HTTPException(status_code=502, detail=str(exc)) from exc
        return {"message": str(result.get("text") or "").strip()}

    @router.post("/git/pr/create")
    async def git_pr_create(payload: dict = Body(...)) -> Any:
        be = require_backend()
        path = str(payload.get("path") or "").strip()
        if not path:
            raise HTTPException(status_code=422, detail="path is required")
        return await _backend_json(
            be, "POST", "/api/git/review/create-pr", body={"path": path}
        )

    # ---------------------------------------------------- terminal (extended)
    @router.post("/terminal/execute")
    async def terminal_execute(payload: dict = Body(...)) -> Any:
        """Execute through the guarded Hermes terminal gateway."""
        if not isinstance(payload, dict):
            raise HTTPException(status_code=422, detail="object body required")
        command = payload.get("command")
        if not isinstance(command, str) or not command.strip():
            raise HTTPException(status_code=422, detail="command is required")
        if len(command) > 20_000:
            raise HTTPException(status_code=422, detail="command exceeds 20000 characters")
        cwd = payload.get("cwd")
        if cwd is not None and not isinstance(cwd, str):
            raise HTTPException(status_code=422, detail="cwd must be a string")
        executable = command.strip()
        if cwd and cwd.strip():
            target = cwd.strip()
            if os.name == "nt":
                escaped = target.replace('"', '""')
                executable = f'cd /d "{escaped}" && {executable}'
            else:
                escaped = target.replace("'", "'\"'\"'")
                executable = f"cd '{escaped}' && {executable}"
        be = require_backend()
        try:
            return await be.gateway_rpc("shell.exec", {"command": executable}, timeout=35.0)
        except BackendError as exc:
            raise HTTPException(status_code=502, detail=str(exc))

    return router


async def _submit_task_prompt(be: BackendManager, runtime_id: str, prompt: str, task_id: str) -> None:
    """Fire-and-forget prompt.submit; failures surface in the session itself."""
    try:
        await be.gateway_rpc(
            "prompt.submit",
            {"session_id": runtime_id, "text": prompt},
            timeout=300.0,
        )
    except BackendError as exc:
        logger.warning("task %s prompt.submit failed: %s", task_id, exc)


# ── Artifact extraction helpers ──────────────────────────────────────────────
# Ported from the desktop client's artifact-utils.ts. The backend has no
# /api/artifacts endpoint, so we scan session transcripts server-side.

_ARTIFACT_MD_IMAGE_RE = re.compile(r'!\[([^\]]*)\]\(([^)\s]+)\)')
_ARTIFACT_MD_LINK_RE = re.compile(r'\[([^\]]+)\]\(([^)\s]+)\)')
_ARTIFACT_URL_RE = re.compile(r'https?://[^\s<>"\')]+')
_ARTIFACT_PATH_RE = re.compile(
    r'(^|[\s("\'`])((?:/|~/|\.\.?/)[^\s"\'`<>]+(?:\.[a-z0-9]{1,8})?)',
    re.IGNORECASE,
)
_ARTIFACT_IMAGE_EXT_RE = re.compile(
    r'\.(?:png|jpe?g|gif|webp|svg|bmp)(?:\?.*)?$', re.IGNORECASE)
_ARTIFACT_FILE_EXT_RE = re.compile(
    r'\.(?:png|jpe?g|gif|webp|svg|bmp|pdf|txt|json|md|csv|zip|tar|gz'
    r'|mp3|wav|mp4|mov)(?:\?.*)?$', re.IGNORECASE)
_ARTIFACT_KEY_HINT_RE = re.compile(
    r'(path|file|url|image|artifact|output|download|result|target)',
    re.IGNORECASE)


def _extract_message_text(msg: dict) -> str:
    """Extract the best text representation from a message object."""
    for key in ("text", "content", "context"):
        val = msg.get(key)
        if isinstance(val, str) and val.strip():
            return val
    if isinstance(msg.get("content"), list):
        parts = []
        for part in msg["content"]:
            if isinstance(part, str):
                parts.append(part)
            elif isinstance(part, dict):
                t = part.get("text") or part.get("content")
                if isinstance(t, str):
                    parts.append(t)
        return " ".join(parts)
    return ""


def _try_parse_json(text: str):
    """Try to parse text as JSON; return None on failure."""
    text = text.strip()
    if not text:
        return None
    try:
        return json.loads(text)
    except (json.JSONDecodeError, ValueError):
        return None


def _normalize_artifact_value(value: str) -> str:
    """Normalize candidates extracted from persisted/escaped transcripts.

    Historical tool results can contain JSON-escaped newlines as literal
    ``\\n`` text.  The desktop renderer sees decoded message strings before
    artifact indexing, so trim those serialized delimiters here as well.
    """
    normalized = value.strip()
    for delimiter in (r"\r\n", r"\n", r"\r", r"\t"):
        normalized = normalized.split(delimiter, 1)[0]
    return normalized.rstrip("),.;|")


def _looks_like_artifact(value: str) -> bool:
    """Check if a string looks like a path or URL worth showing."""
    value = _normalize_artifact_value(value)
    if value.startswith(("http://", "https://")):
        if "`" in value or "\\" in value:
            return False
        try:
            from urllib.parse import urlparse
            return bool(urlparse(value).hostname)
        except ValueError:
            return False
    if value.startswith("data:image/"):
        return True
    if value.startswith(("/", "./", "../", "~/", "file://")):
        if _ARTIFACT_IMAGE_EXT_RE.search(value) or _ARTIFACT_FILE_EXT_RE.search(value):
            return True
        return "/" in value and "." in value
    return False


def _artifact_kind(value: str) -> str:
    """Classify exactly like desktop: image, file, or link."""
    value = _normalize_artifact_value(value)
    if value.startswith("data:image/") or _ARTIFACT_IMAGE_EXT_RE.search(value):
        return "image"
    if value.startswith(("/", "./", "../", "~/", "file://")):
        return "file"
    return "link"


def _artifact_label(value: str) -> str:
    """Generate a short human-readable label from an artifact value."""
    value = _normalize_artifact_value(value)
    try:
        from urllib.parse import urlparse
        parsed = urlparse(value)
        if parsed.scheme in ("http", "https"):
            parts = parsed.path.rstrip("/").split("/")
            return parts[-1] if parts[-1] else value
    except Exception:
        pass
    parts = value.replace("\\", "/").rstrip("/").split("/")
    return parts[-1] if parts[-1] else value


def _collect_artifacts_from_text(text: str) -> list[str]:
    """Find artifact candidates in text using regex patterns."""
    found: list[str] = []
    for m in _ARTIFACT_MD_IMAGE_RE.finditer(text):
        if m.group(2):
            found.append(m.group(2))
    for m in _ARTIFACT_MD_LINK_RE.finditer(text):
        val = m.group(2) or ""
        if val and _looks_like_artifact(val):
            found.append(val)
    for m in _ARTIFACT_URL_RE.finditer(text):
        found.append(m.group(0))
    for m in _ARTIFACT_PATH_RE.finditer(text):
        found.append(m.group(2))
    return found


def _collect_artifacts_from_obj(obj, found: list[str], key_path: str = "") -> None:
    """Recursively scan an object for string values that look like artifacts."""
    if isinstance(obj, str):
        normalized = _normalize_artifact_value(obj)
        if not normalized:
            return
        if _ARTIFACT_KEY_HINT_RE.search(key_path) and _looks_like_artifact(normalized):
            found.append(normalized)
        elif _looks_like_artifact(normalized) and (
                _ARTIFACT_IMAGE_EXT_RE.search(normalized) or
                _ARTIFACT_FILE_EXT_RE.search(normalized)):
            found.append(normalized)
        return
    if isinstance(obj, list):
        for i, item in enumerate(obj):
            _collect_artifacts_from_obj(item, found, f"{key_path}.{i}")
        return
    if isinstance(obj, dict):
        for k, v in obj.items():
            _collect_artifacts_from_obj(v, found, f"{key_path}.{k}" if key_path else k)
