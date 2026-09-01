from __future__ import annotations

import asyncio
from typing import Any

import httpx
from fastapi import FastAPI
from fastapi.testclient import TestClient

from hermes_mobile_server.config import Settings
from hermes_mobile_server.domain_api import (
    _child_projection_cache,
    _child_projection_inflight,
    _scan_child_session_rows,
    build_domain_router,
)
from hermes_mobile_server.ws_proxy import _pipe


AUTH = {"Authorization": "Bearer test-key-42"}


import pytest


@pytest.fixture(autouse=True)
def _clear_child_projection_cache(tmp_path, monkeypatch):
    # Keep tests hermetic: never read the developer's real Hermes state.db.
    monkeypatch.setenv("HERMES_HOME", str(tmp_path / "no-hermes-home"))
    _child_projection_cache.clear()
    _child_projection_inflight.clear()
    yield
    _child_projection_cache.clear()
    _child_projection_inflight.clear()


class SessionBackend:
    is_running = True

    def __init__(self) -> None:
        self.calls: list[tuple[str, str, dict, Any]] = []
        self.client = SessionClient(self)
        self.spawn_nodes: list[dict] = []
        self.active_nodes: list[dict] = []

    async def http_client(self):
        return self.client

    async def gateway_rpc(self, method, params=None, timeout=60.0):
        if method == "spawn_tree.list":
            return {"entries": [{"session_id": "parent-2", "path": "tree-2"}]}
        if method == "spawn_tree.load":
            return {"subagents": self.spawn_nodes}
        if method == "delegation.status":
            return {"active": self.active_nodes}
        raise AssertionError(f"unexpected gateway method: {method}")


class SessionClient:
    def __init__(self, backend: SessionBackend) -> None:
        self.backend = backend
        self.parents = [
            {"id": "parent-1", "title": "First", "source": "mobile"},
            {"id": "parent-2", "title": "Second", "source": "mobile"},
        ]
        self.all_rows = [
            self.parents[0],
            {
                "id": "child-old",
                "title": "Historical child",
                "source": "subagent",
                "parent_session_id": "parent-1",
                "message_count": 2,
            },
            self.parents[1],
            {
                "id": "child-2",
                "title": "Child two",
                "source": "subagent",
                "parent_session_id": "parent-2",
                "message_count": 7,
                "created_at": 10,
                "updated_at": 20,
                "model": "model-a",
            },
            {
                "id": "grandchild-2",
                "title": "Nested child",
                "source": "subagent",
                "parent_session_id": "child-2",
                "message_count": 3,
            },
            {
                # WeChat-origin child of a mobile parent: cross-source, so it
                # is a real sidebar child per WebUI (not a continuation).
                "id": "weixin-child",
                "title": "Weixin child",
                "source": "weixin",
                "parent_session_id": "parent-2",
                "message_count": 4,
            },
            {
                # Same-source compression continuation of an ended parent:
                # collapsed per WebUI _is_continuation_session.
                "id": "continuation-2",
                "title": "Compression continuation",
                "source": "mobile",
                "parent_session_id": "parent-ended",
                "started_at": 100,
                "model_config": {"_delegate_from": "parent-ended"},
            },
            {
                "id": "parent-ended",
                "title": "Ended parent",
                "source": "mobile",
                "end_reason": "compression",
                "ended_at": 90,
            },
        ]

    async def request(self, method, path, params=None, json=None, headers=None):
        query = params or {}
        self.backend.calls.append((method, path, query, json))
        if method == "GET" and path == "/api/sessions":
            offset = int(query.get("offset", 0))
            limit = int(query.get("limit", 100))
            if str(query.get("include_children", "false")).lower() == "true":
                page = self.all_rows[offset : offset + limit]
                return httpx.Response(
                    200,
                    json={
                        "sessions": page,
                        "total": len(self.all_rows),
                        "has_more": offset + len(page) < len(self.all_rows),
                    },
                )
            page = self.parents[offset : offset + limit]
            return httpx.Response(
                200,
                json={"sessions": page, "total": len(self.parents), "has_more": False},
            )
        if method == "GET" and path.startswith("/api/sessions/"):
            sid = path.split("/")[3]
            row = next((row for row in self.all_rows if row["id"] == sid), None)
            if row is None:
                return httpx.Response(404, json={"detail": "missing"})
            if path.endswith("/messages"):
                return httpx.Response(200, json={"messages": [{"role": "user", "content": "hi"}]})
            return httpx.Response(200, json=row)
        return httpx.Response(200, json={"ok": True})


def make_client(backend: SessionBackend) -> TestClient:
    app = FastAPI()
    app.include_router(build_domain_router(Settings(api_key="test-key-42"), backend))
    return TestClient(app)


def test_session_parent_pagination_attaches_all_real_children_and_parent_chain():
    backend = SessionBackend()
    with make_client(backend) as client:
        response = client.get(
            "/api/v1/sessions", headers=AUTH, params={"limit": 1, "offset": 1}
        )

    assert response.status_code == 200
    body = response.json()
    assert body["total"] == 2
    assert body["offset"] == 1
    assert body["has_more"] is False
    rows = {row["id"]: row for row in body["sessions"]}
    assert set(rows) == {"parent-2", "child-2", "grandchild-2", "weixin-child"}
    assert rows["child-2"] == {
        **rows["child-2"],
        "source": "subagent",
        "parent_session_id": "parent-2",
        "read_only": True,
        "is_cli_session": False,
    }
    assert rows["child-2"]["title"] == "Child two"
    assert rows["child-2"]["message_count"] == 7
    assert rows["child-2"]["created_at"] == 10
    assert rows["child-2"]["updated_at"] == 20
    assert rows["child-2"]["model"] == "model-a"
    # Non-subagent children keep their own flags (WebUI only coerces subagent).
    assert rows["weixin-child"]["source"] == "weixin"
    assert rows["weixin-child"]["parent_session_id"] == "parent-2"
    assert rows["weixin-child"]["title"] == "Weixin child"
    assert rows["weixin-child"]["message_count"] == 4
    assert rows["weixin-child"].get("read_only") is not True
    assert "continuation-2" not in rows
    parent_calls = [call for call in backend.calls if call[1] == "/api/sessions"]
    assert parent_calls[0][2]["include_children"] == "false"
    # The child scan terminates on the upstream paging contract
    # (has_more=false): exactly one page, no speculative EOF probing.
    child_scans = [call for call in parent_calls if call[2]["include_children"] == "true"]
    assert len(child_scans) == 1


def test_list_sessions_does_not_duplicate_child_already_in_parent_page():
    """Hermes may still return parented mobile rows with include_children=false.

    Attaching the child projection again must not emit a second copy of the
    same session id (sidebar expand would show two identical children).
    """
    backend = SessionBackend()
    mobile_child = {
        "id": "mobile-fork",
        "title": "Mobile fork",
        "source": "mobile",
        "parent_session_id": "parent-1",
        "message_count": 1,
    }
    backend.client.all_rows.insert(1, mobile_child)
    # Surface the child on the "parents only" page as Hermes does for mobile.
    backend.client.parents = [backend.client.parents[0], mobile_child, backend.client.parents[1]]

    with make_client(backend) as client:
        response = client.get("/api/v1/sessions", headers=AUTH, params={"limit": 50})

    assert response.status_code == 200
    ids = [row["id"] for row in response.json()["sessions"]]
    assert ids.count("mobile-fork") == 1
    assert "parent-1" in ids


def test_subagents_projection_returns_child_sessions_and_grouped_nodes():
    backend = SessionBackend()
    backend.spawn_nodes = [
        {"id": "snapshot-node", "child_session_id": "child-2", "goal": "Snapshot goal"},
    ]
    with make_client(backend) as client:
        response = client.get("/api/v1/subagents/projection", headers=AUTH)

    assert response.status_code == 200
    body = response.json()
    sessions = {row["id"]: row for row in body["sessions"]}
    # All child sessions surface, regardless of source; continuations hidden.
    assert {"child-old", "child-2", "grandchild-2", "weixin-child"} <= set(sessions)
    assert "continuation-2" not in sessions
    assert sessions["child-2"]["parent_session_id"] == "parent-2"
    assert sessions["child-2"]["read_only"] is True
    assert sessions["weixin-child"]["source"] == "weixin"

    by_session = body["by_session"]
    # Subagent-sourced durable children + snapshot nodes grouped per parent.
    assert [n["id"] for n in by_session["parent-1"]] == ["child-old"]
    parent2_ids = {n["id"] for n in by_session["parent-2"]}
    assert parent2_ids == {"child-2"}
    assert by_session["parent-2"][0]["goal"] == "Snapshot goal"
    assert [n["id"] for n in by_session["child-2"]] == ["grandchild-2"]
    assert body["total"] == sum(len(v) for v in by_session.values())


def test_non_subagent_parent_relationship_is_not_projected_as_child():
    backend = SessionBackend()
    with make_client(backend) as client:
        response = client.get(
            "/api/v1/sessions", headers=AUTH, params={"limit": 1, "offset": 1}
        )
    ids = {row["id"] for row in response.json()["sessions"]}
    assert "continuation-2" not in ids


def test_subagent_query_merges_durable_snapshot_and_active_by_child_session_id():
    backend = SessionBackend()
    backend.spawn_nodes = [
        {"id": "snapshot-node", "child_session_id": "child-2", "goal": "Snapshot goal"},
        {"id": "spawn-without-session", "goal": "Pending spawn"},
    ]
    backend.active_nodes = [
        {
            "id": "active-node",
            "child_session_id": "child-2",
            "parent_session_id": "parent-2",
            "status": "running",
            "progress": "working",
        }
    ]
    with make_client(backend) as client:
        response = client.post(
            "/api/v1/subagents/query",
            headers=AUTH,
            json={"session_ids": ["parent-2"]},
        )

    assert response.status_code == 200
    nodes = response.json()["by_session"]["parent-2"]
    child = next(node for node in nodes if node.get("child_session_id") == "child-2")
    assert child["id"] == "child-2"
    assert child["session_id"] == "child-2"
    assert child["goal"] == "Snapshot goal"
    assert child["status"] == "running"
    assert child["progress"] == "working"
    pending = next(node for node in nodes if node.get("id") == "spawn-without-session")
    assert "session_id" not in pending
    child_scans = [
        call for call in backend.calls
        if call[1] == "/api/sessions" and call[2].get("include_children") == "true"
    ]
    assert len(child_scans) == 1


def test_child_projection_scan_is_cached_across_bursts():
    backend = SessionBackend()
    with make_client(backend) as client:
        for _ in range(3):
            response = client.get("/api/v1/sessions", headers=AUTH)
            assert response.status_code == 200
    child_scans = [
        call for call in backend.calls
        if call[1] == "/api/sessions" and call[2].get("include_children") == "true"
    ]
    # Three sidebar refreshes within the TTL share one upstream scan.
    assert len(child_scans) == 1


def test_child_detail_messages_and_open_are_read_only_and_mutations_are_rejected():
    backend = SessionBackend()
    with make_client(backend) as client:
        detail = client.get("/api/v1/sessions/child-2", headers=AUTH)
        messages = client.get("/api/v1/sessions/child-2/messages", headers=AUTH)
        opened = client.post("/api/v1/sessions/child-2/open", headers=AUTH)
        mutation_statuses = [
            client.patch(
                "/api/v1/sessions/child-2", headers=AUTH, json={"title": "no"}
            ).status_code,
            client.delete("/api/v1/sessions/child-2", headers=AUTH).status_code,
            client.post("/api/v1/sessions/child-2/branch", headers=AUTH, json={}).status_code,
            client.post("/api/v1/sessions/child-2/duplicate", headers=AUTH, json={}).status_code,
        ]

    assert detail.json()["read_only"] is True
    assert detail.json()["is_cli_session"] is False
    assert messages.status_code == 200
    assert opened.json()["detail"]["read_only"] is True
    assert mutation_statuses == [403, 403, 403, 403]
    assert not any(
        method in {"PATCH", "DELETE"} and path == "/api/sessions/child-2"
        for method, path, _query, _body in backend.calls
    )


class LegacySessionClient(SessionClient):
    async def request(self, method, path, params=None, json=None, headers=None):
        self.backend.calls.append((method, path, params or {}, json))
        if method == "GET" and path.startswith("/api/sessions/child-2"):
            return httpx.Response(404, json={"detail": "old backend"})
        if method == "GET" and path == "/api/session":
            payload = next(row for row in self.all_rows if row["id"] == "child-2")
            return httpx.Response(
                200,
                json={**payload, "messages": [{"role": "assistant", "content": "legacy"}]},
            )
        return await super().request(method, path, params=params, json=json, headers=headers)


def test_child_detail_and_messages_fall_back_to_legacy_session_route():
    backend = SessionBackend()
    backend.client = LegacySessionClient(backend)
    with make_client(backend) as client:
        detail = client.get("/api/v1/sessions/child-2", headers=AUTH)
        messages = client.get("/api/v1/sessions/child-2/messages", headers=AUTH)

    assert detail.status_code == 200
    assert detail.json()["read_only"] is True
    assert messages.json()["messages"][0]["content"] == "legacy"


class ClosedUpstream:
    async def __aiter__(self):
        if False:
            yield "never"

    async def send(self, frame):
        return None

    async def close(self):
        return None


class WaitingClientWebSocket:
    def __init__(self) -> None:
        self.closed: tuple[int, str] | None = None
        self.waiting = asyncio.Event()

    async def receive_text(self):
        await self.waiting.wait()
        return ""

    async def send_text(self, frame):
        return None

    async def close(self, code=1000, reason=""):
        self.closed = (code, reason)
        self.waiting.set()


def _seed_state_db(home, sessions, messages=()):
    import sqlite3

    db_path = home / "state.db"
    home.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(str(db_path))
    conn.execute(
        "CREATE TABLE sessions (id TEXT PRIMARY KEY, source TEXT, "
        "parent_session_id TEXT, title TEXT, model TEXT, message_count INTEGER, "
        "started_at REAL, ended_at REAL, end_reason TEXT, last_activity_at REAL, "
        "archived INTEGER, pinned INTEGER, profile_name TEXT)"
    )
    conn.execute(
        "CREATE TABLE messages (id INTEGER PRIMARY KEY AUTOINCREMENT, "
        "session_id TEXT, role TEXT, content TEXT, tool_call_id TEXT, "
        "tool_calls TEXT, tool_name TEXT, timestamp REAL, reasoning TEXT, "
        "reasoning_content TEXT, display_kind TEXT, display_metadata TEXT, "
        "active INTEGER)"
    )
    conn.executemany(
        "INSERT INTO sessions (id, source, parent_session_id, title, model, "
        "message_count, started_at, ended_at, end_reason, last_activity_at, "
        "archived, pinned, profile_name) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)",
        sessions,
    )
    conn.executemany(
        "INSERT INTO messages (session_id, role, content, timestamp, active) "
        "VALUES (?,?,?,?,1)",
        messages,
    )
    conn.commit()
    conn.close()


def test_explicit_profile_excludes_unlabeled_current_state_db_children(
    tmp_path, monkeypatch
):
    home = tmp_path / "hermes-home"
    _seed_state_db(
        home,
        sessions=[
            ("default-parent", "desktop", None, "Default parent", "m", 1, 1.0, None, None, 1.0, 0, 0, None),
            ("unlabeled-child", "desktop", "default-parent", "Current child", "m", 1, 2.0, None, None, 2.0, 0, 0, None),
            ("experts-child", "desktop", "expert-parent", "Expert child", "m", 1, 2.0, None, None, 2.0, 0, 0, "experts"),
        ],
    )
    monkeypatch.setenv("HERMES_HOME", str(home))

    backend = SessionBackend()
    backend.client.all_rows = [
        {"id": "expert-parent", "title": "Expert parent", "profile_name": "experts"}
    ]
    children = asyncio.run(_scan_child_session_rows(backend, profile="experts"))

    assert [row["id"] for row in children] == ["experts-child"]


def test_state_db_fallback_exposes_desktop_delegate_children(tmp_path, monkeypatch):
    """Desktop delegate children exist only in state.db, not in backend REST."""
    home = tmp_path / "hermes-home"
    _seed_state_db(
        home,
        sessions=[
            ("parent-desk", "desktop", None, "Parent", "m", 10, 1.0, None, None, 5.0, 0, 0, None),
            ("desk-child", "desktop", "parent-desk", "", "m", 3, 2.0, 4.0, "agent_close", 4.0, 0, 0, None),
        ],
        messages=[
            ("desk-child", "user", "do the task", 2.0),
            ("desk-child", "assistant", "done", 3.0),
        ],
    )
    monkeypatch.setenv("HERMES_HOME", str(home))
    _child_projection_cache.clear()

    class EmptyRestBackend(SessionBackend):
        def __init__(self):
            super().__init__()
            # REST exposes the desktop parent but hides its delegate child:
            # exactly the gap WebUI works around by reading state.db directly.
            parent_row = {
                "id": "parent-desk", "title": "Parent", "source": "desktop",
            }
            self.client.parents = [parent_row]
            self.client.all_rows = [parent_row]

    backend = EmptyRestBackend()
    with make_client(backend) as client:
        listing = client.get("/api/v1/sessions", headers=AUTH)
        detail = client.get("/api/v1/sessions/desk-child", headers=AUTH)
        messages = client.get("/api/v1/sessions/desk-child/messages", headers=AUTH)

    assert listing.status_code == 200
    rows = {row["id"]: row for row in listing.json()["sessions"]}
    assert "desk-child" in rows
    assert rows["desk-child"]["parent_session_id"] == "parent-desk"
    assert rows["desk-child"]["title"] == "Desktop Session"
    assert detail.status_code == 200
    assert detail.json()["id"] == "desk-child"
    assert [m["content"] for m in messages.json()["messages"]] == [
        "do the task", "done",
    ]


class WsBackend:
    async def connect_gateway_ws(self, consume_ready=False):
        return ClosedUpstream()


async def _run_upstream_close_case():
    client = WaitingClientWebSocket()
    await asyncio.wait_for(_pipe(client, WsBackend()), timeout=0.5)
    return client


def test_ws_upstream_close_immediately_closes_client_instead_of_hanging():
    client = asyncio.run(_run_upstream_close_case())
    assert client.closed == (1011, "backend gateway disconnected")
