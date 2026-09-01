"""Comprehensive API endpoint tests for Hermes Mobile Server.

Covers 70+ REST endpoints across all domain resources. Tests include:
- Authentication enforcement (401)
- Management endpoints (health/status/restart/methods)
- Parameter validation (422 for out-of-range limits, etc.)
- Service-unavailable responses (503 when backend not running)
- Task CRUD (self-contained, no backend needed)
- Artifact extraction utilities (pure function unit tests)

Run with::

    uv run pytest tests/test_api_endpoints.py -v
"""

from __future__ import annotations

import json
from typing import Any

import httpx
import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient

from hermes_mobile_server import local_workspace
from hermes_mobile_server.app import create_app
from hermes_mobile_server.config import Settings
from hermes_mobile_server.domain_api import build_domain_router
from hermes_mobile_server.tasks import TaskStore

# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------


@pytest.fixture
def client_no_backend(tmp_path) -> TestClient:
    """App configured with a deliberately absurd hermes root so no backend
    can boot. All domain endpoints return 503; management endpoints still
    work for unauthenticated routes and auth checks for protected ones."""
    settings = Settings(
        api_key="test-key-42",
        backend_ready_timeout=0.01,
        hermes_root_override="Z:\\nonexistent\\hermes\\definitely\\not\\here",
    )
    return TestClient(
        create_app(settings, task_store=TaskStore(tmp_path / "tasks.db"))
    )


AUTH = {"Authorization": "Bearer test-key-42"}
BAD_AUTH = {"Authorization": "Bearer wrong-key"}


# ===========================================================================
# 1. AUTHENTICATION
# ===========================================================================


class TestAuthentication:
    """Every protected endpoint must reject missing or invalid bearer tokens
    with 401, and accept the configured bearer token (returning 200/503/etc
    but never 401)."""

    PROTECTED_GET = [
        "/api/v1/status",
        "/api/v1/sessions",
        "/api/v1/sessions/sess-1",
        "/api/v1/sessions/sess-1/messages",
        "/api/v1/config",
        "/api/v1/logs",
        "/api/v1/model",
        "/api/v1/model/auxiliary",
        "/api/v1/model/moa",
        "/api/v1/skills",
        "/api/v1/tools",
        "/api/v1/files",
        "/api/v1/files/read",
        "/api/v1/files/read-data-url",
        "/api/v1/files/download",
        "/api/v1/files/default-cwd",
        "/api/v1/cron",
        "/api/v1/cron/job-1/runs",
        "/api/v1/memory",
        "/api/v1/projects",
        "/api/v1/git/status",
        "/api/v1/git/branches",
        "/api/v1/git/review/list",
        "/api/v1/git/review/diff",
        "/api/v1/git/file-diff",
        "/api/v1/git/review/commit-context",
        "/api/v1/analytics/usage",
        "/api/v1/analytics/models",
        "/api/v1/knowledge/graph",
        "/api/v1/knowledge/node",
        "/api/v1/mcp/servers",
        "/api/v1/mcp/servers/foo/test",
        "/api/v1/mcp/catalog",
        "/api/v1/plugins",
        "/api/v1/tasks",
        "/api/v1/tasks/task-1",
        "/api/v1/artifacts",
        "/api/v1/starmap/graph",
        "/api/v1/starmap/node",
        "/api/v1/subagents",
        "/api/v1/subagents/active",
        "/api/v1/pet",
        "/api/v1/pet/gallery",
        "/api/v1/pet/generate/status",
        "/api/v1/billing",
        "/api/v1/billing/charge/status",
        "/api/v1/billing/usage-bars",
        "/api/v1/subscription",
        "/api/v1/credentials/providers",
        "/api/v1/messaging/platforms",
        "/api/v1/webhooks",
    ]

    def test_no_auth_rejected(self, client_no_backend: TestClient):
        for path in self.PROTECTED_GET:
            resp = client_no_backend.get(path, params={"limit": "1"})
            assert resp.status_code == 401, f"expected 401 for {path}"

    def test_wrong_auth_rejected(self, client_no_backend: TestClient):
        for path in self.PROTECTED_GET[:8]:  # sample — logic is shared anyway
            resp = client_no_backend.get(path, headers=BAD_AUTH)
            assert resp.status_code == 401, f"expected 401 for {path}"

    def test_valid_auth_passes_auth_check(self, client_no_backend: TestClient):
        """With correct key, endpoints reach the backend=503 stage (not 401)."""
        resp = client_no_backend.get("/api/v1/status", headers=AUTH)
        assert resp.status_code in (200, 503)

    def test_terminal_execute_requires_auth(self, client_no_backend: TestClient):
        payload = {"command": "echo test"}
        assert client_no_backend.post("/api/v1/terminal/execute", json=payload).status_code == 401
        assert client_no_backend.post(
            "/api/v1/terminal/execute", json=payload, headers=AUTH
        ).status_code == 503


# ===========================================================================
# 2. MANAGEMENT ENDPOINTS
# ===========================================================================


class TestManagement:
    def test_health_unauthenticated_200(self, client_no_backend: TestClient):
        resp = client_no_backend.get("/api/v1/health")
        assert resp.status_code == 200
        body = resp.json()
        assert "backend_running" in body
        assert "status" in body
        # No backend on this machine.
        assert body["backend_running"] is False

    def test_status_authenticated_shape(self, client_no_backend: TestClient):
        resp = client_no_backend.get("/api/v1/status", headers=AUTH)
        # Could be 503 if backend boot didn't finish, but shape must be there.
        assert resp.status_code in (200, 503)
        body = resp.json()
        # Even on 503 FastAPI returns an error object — only assert on 200.
        if resp.status_code == 200:
            for key in ("server", "capability", "backend", "ready_error"):
                assert key in body, f"status.{key} missing"

    def test_methods_authenticated(self, client_no_backend: TestClient):
        resp = client_no_backend.get("/api/v1/methods", headers=AUTH)
        assert resp.status_code == 200
        body = resp.json()
        assert "rest" in body
        assert "ws" in body
        assert "management" in body
        gateway_methods = set(body["ws"]["methods"])
        for required_method in (
            "session.create",
            "session.resume",
            "message.send",
            "approval.respond",
            "tools.configure",
        ):
            assert required_method in gateway_methods
        resources = set(body["rest"]["resources"])
        # Spot-check several resources we care about.
        for required in (
            "/api/v1/sessions",
            "/api/v1/files/upload",
            "/api/v1/artifacts",
            "/api/v1/tasks",
            "/api/v1/pet",
            "/api/v1/webhooks",
        ):
            assert required in resources, f"methods REST missing {required}"

    def test_restart_backend_503_when_no_backend(self, client_no_backend: TestClient):
        resp = client_no_backend.post("/api/v1/backend/restart", headers=AUTH)
        # backend may be None → 503, or initialized but not bootable → 500 from restart()
        assert resp.status_code in (500, 503)


# ===========================================================================
# 3. SESSIONS — parameter validation
# ===========================================================================


class TestSessionsValidation:
    """The sessions endpoints all require a backend (so they 503), but we
    verify FastAPI's Query validation layer (422) kicks in *before* the
    backend dependency check runs — i.e. the router-level Query validators
    on limit/offset actually work."""

    def test_sessions_limit_too_high_422(self, client_no_backend: TestClient):
        """Reproduces the reported 422 on limit=1000 (max is 500)."""
        resp = client_no_backend.get(
            "/api/v1/sessions", headers=AUTH, params={"limit": 1000}
        )
        assert resp.status_code == 422

    def test_sessions_limit_zero_422(self, client_no_backend: TestClient):
        resp = client_no_backend.get(
            "/api/v1/sessions", headers=AUTH, params={"limit": 0}
        )
        assert resp.status_code == 422

    def test_sessions_limit_boundary_ok(self, client_no_backend: TestClient):
        """Exactly 500 is OK (passes validation -> hits backend 503)."""
        resp = client_no_backend.get(
            "/api/v1/sessions", headers=AUTH, params={"limit": 500}
        )
        assert resp.status_code == 503

    def test_sessions_limit_negative_422(self, client_no_backend: TestClient):
        resp = client_no_backend.get(
            "/api/v1/sessions", headers=AUTH, params={"limit": -1}
        )
        assert resp.status_code == 422

    def test_session_messages_limit_501_422(self, client_no_backend: TestClient):
        resp = client_no_backend.get(
            "/api/v1/sessions/abc/messages",
            headers=AUTH,
            params={"limit": 501},
        )
        assert resp.status_code == 422

    def test_session_messages_offset_negative_422(self, client_no_backend: TestClient):
        resp = client_no_backend.get(
            "/api/v1/sessions/abc/messages",
            headers=AUTH,
            params={"offset": -1},
        )
        assert resp.status_code == 422

    def test_create_session_body_optional(self, client_no_backend: TestClient):
        """Empty body should be accepted (default={}) and yield 503."""
        resp = client_no_backend.post("/api/v1/sessions", headers=AUTH, json={})
        assert resp.status_code == 503

    def test_patch_session_requires_body(self, client_no_backend: TestClient):
        """PATCH expects a body via Body(...) so omitting it is 422, not 503."""
        resp = client_no_backend.patch("/api/v1/sessions/s1", headers=AUTH)
        # FastAPI returns 422 when Body(...) required field is missing.
        assert resp.status_code == 422

    @pytest.mark.parametrize(
        ("method", "path", "payload"),
        [
            ("post", "/api/v1/sessions/s1/branch", {}),
            ("post", "/api/v1/sessions/s1/move", {"project_id": "p1"}),
            ("post", "/api/v1/sessions/s1/stop", {"stream_id": "stream-1"}),
        ],
    )
    def test_session_management_routes_exist(
        self,
        client_no_backend: TestClient,
        method: str,
        path: str,
        payload: dict | None,
    ):
        response = client_no_backend.request(method, path, headers=AUTH, json=payload)
        assert response.status_code == 503

    def test_session_export_format_validation(self, client_no_backend: TestClient):
        response = client_no_backend.get(
            "/api/v1/sessions/s1/export",
            headers=AUTH,
            params={"format": "pdf"},
        )
        assert response.status_code == 422

    def test_session_management_routes_require_auth(self, client_no_backend: TestClient):
        response = client_no_backend.post("/api/v1/sessions/s1/branch", json={})
        assert response.status_code == 401

    def test_malformed_public_share_token_is_hidden(self, client_no_backend: TestClient):
        response = client_no_backend.get("/share/not.valid")
        assert response.status_code == 404


class TestCanonicalSessionBridge:
    """Session actions must target the API exposed by current ``hermes serve``."""

    class _Client:
        def __init__(self, backend) -> None:
            self.backend = backend

        async def request(self, method, path, params=None, json=None, headers=None):
            self.backend.calls.append((method, path, params or {}, json))
            if method == "PATCH" and path == "/api/sessions/runtime-only":
                return httpx.Response(404, json={"detail": "Session not found"})
            if method == "GET" and path == "/api/profiles/sessions":
                return httpx.Response(
                    200,
                    json={
                        "sessions": [{"id": "default-only", "title": "Default"}],
                        "total": 1,
                    },
                )
            if method == "GET" and path == "/api/sessions":
                return httpx.Response(
                    200,
                    json={
                        "sessions": [{"id": "expert-only", "title": "Expert"}],
                        "total": 1,
                    },
                )
            if method == "GET" and path == "/api/sessions/s1":
                return httpx.Response(200, json={"id": "s1", "title": "Session one"})
            if method == "POST" and path == "/api/profiles/sessions/pull-requests":
                return httpx.Response(
                    200,
                    json={
                        "pull_requests": {
                            "s1": {"number": 42, "url": "https://github.com/o/r/pull/42"}
                        },
                        "scanned": ["s1", "s2"],
                    },
                )
            if method == "GET" and path == "/api/sessions/default-only":
                return httpx.Response(
                    200,
                    json={
                        "id": "default-only",
                        "title": "Default",
                        "parent_session_id": "default-ancestor",
                    },
                )
            if method == "GET" and path == "/api/sessions/default-ancestor":
                return httpx.Response(
                    200, json={"id": "default-ancestor", "title": "Ancestor"}
                )
            if method == "GET" and path == "/api/sessions/s1/messages":
                return httpx.Response(200, json={"messages": [{"role": "user", "content": "hi"}]})
            if method == "GET" and path == "/api/sessions/sx":
                return httpx.Response(
                    200, json={"id": "sx", "title": 'XSS <script>alert(1)</script> & "q"'}
                )
            if method == "GET" and path == "/api/sessions/sx/messages":
                return httpx.Response(
                    200,
                    json={
                        "messages": [
                            {"role": "user", "content": "<script>alert('x')</script>"},
                            {
                                "role": "assistant",
                                "content": [
                                    {"type": "thinking", "thinking": "hmm <b>bold</b>"},
                                    {"type": "text", "text": "answer & <ok>"},
                                ],
                                "tool_calls": [
                                    {"name": "read", "arguments": {"path": "<x>.py"}}
                                ],
                            },
                            {"role": "tool", "tool_name": "read", "content": "tool <output>"},
                        ]
                    },
                )
            if method == "GET" and path == "/api/sessions/long":
                return httpx.Response(200, json={"id": "long", "title": "Long"})
            if method == "GET" and path == "/api/sessions/long/messages":
                offset = int((params or {}).get("offset") or 0)
                count = 500 if offset == 0 else (2 if offset == 500 else 0)
                return httpx.Response(
                    200,
                    json={
                        "messages": [
                            {"role": "user", "content": f"row-{offset + i}"}
                            for i in range(count)
                        ]
                    },
                )
            if method == "POST" and path == "/api/sessions/import":
                return httpx.Response(200, json={"ok": True, "imported": 1})
            if method == "GET" and path.startswith("/api/sessions/202"):
                sid = path.rsplit("/", 1)[-1]
                return httpx.Response(200, json={"id": sid, "title": "Session one (copy)"})
            if method == "POST" and path == "/api/sessions/s1/fork":
                return httpx.Response(200, json={"session_id": "child-1"})
            return httpx.Response(200, json={"ok": True})

    class _Backend:
        is_running = True

        def __init__(self) -> None:
            self.calls: list[tuple] = []
            self.client = TestCanonicalSessionBridge._Client(self)

        async def http_client(self):
            return self.client

        async def gateway_rpc(self, method, params=None, timeout=60.0):
            self.calls.append(("RPC", method, {}, params or {}))
            if method == "session.resume":
                return {"session_id": "runtime-s1"}
            if method == "session.branch":
                return {"session_id": "runtime-child", "stored_session_id": "child-1"}
            if method == "projects.list":
                return {
                    "projects": [
                        {"id": "p1", "path": "D:/work/project-one", "repos": []}
                    ]
                }
            if method == "session.workspace.move":
                return {"cwd": params["cwd"], "session_key": params["session_key"]}
            if method == "session.interrupt":
                return {"ok": True, "session_id": params["session_id"]}
            if method == "session.title":
                return {"ok": True, "title": params["title"]}
            if method == "llm.oneshot":
                return {"text": "A concise generated title"}
            raise AssertionError(f"unexpected gateway method: {method}")

    def _client(self):
        settings = Settings(api_key="test-key-42")
        backend = self._Backend()
        app = FastAPI()
        app.include_router(build_domain_router(settings, backend))
        return backend, TestClient(app)

    def test_pin_delete_and_branch_use_current_session_routes(self):
        backend, client = self._client()
        with client:
            assert client.put(
                "/api/v1/sessions/s1/pin", headers=AUTH, json={"pinned": True}
            ).status_code == 200
            assert client.delete("/api/v1/sessions/s1", headers=AUTH).status_code == 200
            branch = client.post(
                "/api/v1/sessions/s1/branch", headers=AUTH, json={"keep_count": 3}
            )
            assert branch.status_code == 200
            assert branch.json()["session"]["id"] == "child-1"

        assert ("PATCH", "/api/sessions/s1", {}, {"pinned": True}) in backend.calls
        assert ("DELETE", "/api/sessions/s1", {}, None) in backend.calls
        assert (
            "RPC",
            "session.branch",
            {},
            {"session_id": "runtime-s1", "count": 3},
        ) in backend.calls
        assert not any(path.startswith("/api/session/") for _, path, _, _ in backend.calls)

    def test_runtime_only_rename_falls_back_to_session_title_rpc(self):
        backend, client = self._client()
        with client:
            response = client.patch(
                "/api/v1/sessions/runtime-only",
                headers=AUTH,
                json={"title": "Runtime title"},
            )

        assert response.status_code == 200
        assert response.json()["title"] == "Runtime title"
        assert (
            "RPC",
            "session.title",
            {},
            {"session_id": "runtime-only", "title": "Runtime title"},
        ) in backend.calls

    def test_explicit_profile_prefers_profile_scoped_sessions_and_preserves_query(self):
        backend, client = self._client()
        with client:
            response = client.get(
                "/api/v1/sessions", headers=AUTH, params={"profile": "default"}
            )

        assert response.status_code == 200
        rows = response.json()["sessions"]
        assert [row["id"] for row in rows] == ["default-only", "default-ancestor"]
        assert all(row["profile"] == "default" for row in rows)
        assert backend.calls[0] == (
            "GET",
            "/api/profiles/sessions",
            {
                "limit": 51,
                "offset": 0,
                "include_children": "false",
                "profile": "default",
                "archived": "exclude",
                "order": "recent",
            },
            None,
        )
        assert (
            "GET",
            "/api/sessions/default-only",
            {"profile": "default"},
            None,
        ) in backend.calls
        assert (
            "GET",
            "/api/sessions/default-ancestor",
            {"profile": "default"},
            None,
        ) in backend.calls

    def test_message_pages_include_raw_history_ordinals(self):
        _backend, client = self._client()
        with client:
            response = client.get(
                "/api/v1/sessions/s1/messages",
                headers=AUTH,
                params={"limit": 50, "offset": 31},
            )

        assert response.status_code == 200
        assert response.json()["messages"][0]["history_ordinal"] == 31

    def test_pull_request_scan_proxies_ids_to_profile_endpoint(self):
        backend, client = self._client()
        with client:
            response = client.post(
                "/api/v1/profiles/sessions/pull-requests",
                headers=AUTH,
                json={"ids": ["s1", "s2"]},
            )

        assert response.status_code == 200
        assert response.json()["pull_requests"]["s1"]["number"] == 42
        assert (
            "POST",
            "/api/profiles/sessions/pull-requests",
            {},
            {"ids": ["s1", "s2"]},
        ) in backend.calls

    def test_session_detail_and_messages_forward_profile(self):
        backend, client = self._client()
        with client:
            detail = client.get(
                "/api/v1/sessions/s1", headers=AUTH, params={"profile": "experts"}
            )
            messages = client.get(
                "/api/v1/sessions/s1/messages",
                headers=AUTH,
                params={"limit": 50, "offset": 31, "profile": "experts"},
            )

        assert detail.status_code == 200
        assert messages.status_code == 200
        assert ("GET", "/api/sessions/s1", {"profile": "experts"}, None) in backend.calls
        assert (
            "GET",
            "/api/sessions/s1/messages",
            {"limit": 50, "offset": 31, "profile": "experts"},
            None,
        ) in backend.calls

    def test_export_is_composed_from_current_detail_and_messages_routes(self):
        backend, client = self._client()
        with client:
            response = client.get(
                "/api/v1/sessions/s1/export", headers=AUTH, params={"format": "json"}
            )
        assert response.status_code == 200
        exported = json.loads(response.json()["content"])
        assert exported["session_id"] == "s1"
        assert exported["message_count"] == 1
        assert exported["messages"][0]["content"] == "hi"
        assert any(path == "/api/sessions/s1/messages" for _, path, _, _ in backend.calls)

    def test_export_paginates_past_five_hundred_raw_messages(self):
        backend, client = self._client()
        with client:
            response = client.get(
                "/api/v1/sessions/long/export", headers=AUTH, params={"format": "json"}
            )

        assert response.status_code == 200
        exported = json.loads(response.json()["content"])
        assert exported["message_count"] == 502
        offsets = [
            call[2].get("offset")
            for call in backend.calls
            if call[1] == "/api/sessions/long/messages"
        ]
        assert offsets == [0, 500]

    def test_export_html_contains_title_and_messages(self):
        _backend, client = self._client()
        with client:
            response = client.get(
                "/api/v1/sessions/s1/export", headers=AUTH, params={"format": "html"}
            )

        assert response.status_code == 200
        body = response.json()
        assert body["filename"] == "hermes-s1.html"
        assert body["mime_type"].startswith("text/html")
        assert response.headers["Content-Disposition"].endswith('filename="hermes-s1.html"')
        content = body["content"]
        assert "<title>Session one</title>" in content
        assert '<article class="message user">' in content
        assert '<div class="text">hi</div>' in content
        assert "<style>" in content  # self-contained inline CSS

    def test_export_html_escapes_special_characters_and_folds_tool_parts(self):
        _backend, client = self._client()
        with client:
            response = client.get(
                "/api/v1/sessions/sx/export", headers=AUTH, params={"format": "html"}
            )

        assert response.status_code == 200
        content = response.json()["content"]
        # Title and message bodies are escaped; no raw markup can be injected.
        assert "<script>alert(1)</script>" not in content
        assert "&lt;script&gt;alert(1)&lt;/script&gt;" in content
        assert "&lt;script&gt;alert(&#x27;x&#x27;)&lt;/script&gt;" in content
        assert "answer &amp; &lt;ok&gt;" in content
        # Thinking, tool calls and tool results are folded into <details>.
        assert "<summary>Thinking</summary>" in content
        assert "<summary>Tool call: read</summary>" in content
        assert "<summary>Tool result: read</summary>" in content
        assert "tool &lt;output&gt;" in content

    def test_export_defaults_to_unchanged_json_payload(self):
        _backend, client = self._client()
        with client:
            response = client.get("/api/v1/sessions/s1/export", headers=AUTH)

        assert response.status_code == 200
        body = response.json()
        assert body["filename"] == "hermes-s1.json"
        assert body["mime_type"] == "application/json"
        exported = json.loads(body["content"])
        assert exported["session_id"] == "s1"
        assert exported["title"] == "Session one"
        assert exported["message_count"] == 1
        assert exported["messages"][0] == {"role": "user", "content": "hi"}

    def test_move_uses_current_workspace_gateway(self):
        backend, client = self._client()
        with client:
            response = client.post(
                "/api/v1/sessions/s1/move",
                headers=AUTH,
                json={"project_id": "p1"},
            )
        assert response.status_code == 200
        assert (
            "RPC",
            "session.workspace.move",
            {},
            {"cwd": "D:/work/project-one", "session_key": "s1"},
        ) in backend.calls
        assert not any(
            call[0] == "POST" and call[1] == "/api/session/move"
            for call in backend.calls
        )

    def test_stop_uses_session_interrupt_gateway(self):
        backend, client = self._client()
        with client:
            response = client.post(
                "/api/v1/sessions/s1/stop",
                headers=AUTH,
                json={"stream_id": "runtime-s1"},
            )
        assert response.status_code == 200
        assert (
            "RPC",
            "session.interrupt",
            {},
            {"session_id": "runtime-s1"},
        ) in backend.calls
        assert not any(
            call[0] == "GET" and call[1] == "/api/chat/cancel"
            for call in backend.calls
        )

    def test_duplicate_uses_canonical_export_import_without_lineage(self):
        backend, client = self._client()
        with client:
            response = client.post(
                "/api/v1/sessions/s1/duplicate", headers=AUTH, json={}
            )

        assert response.status_code == 200
        import_call = next(
            call for call in backend.calls
            if call[0] == "POST" and call[1] == "/api/sessions/import"
        )
        copied = import_call[3]["sessions"][0]
        assert copied["id"] != "s1"
        assert copied["title"] == "Session one (copy)"
        assert copied["messages"] == [{"role": "user", "content": "hi"}]
        assert "parent_session_id" not in copied

    def test_title_regenerate_uses_real_oneshot_then_persists_title(self):
        backend, client = self._client()
        with client:
            response = client.post(
                "/api/v1/sessions/s1/title/regenerate", headers=AUTH, json={}
            )

        assert response.status_code == 200
        assert response.json()["title"] == "A concise generated title"
        assert any(call[0:2] == ("RPC", "llm.oneshot") for call in backend.calls)
        assert (
            "RPC",
            "session.title",
            {},
            {"session_id": "runtime-s1", "title": "A concise generated title"},
        ) in backend.calls


# ===========================================================================
# 4. MODEL / SKILLS / TOOLS
# ===========================================================================


class TestModelSkillsTools:
    class _Client:
        def __init__(self, backend) -> None:
            self.backend = backend

        async def request(self, method, path, params=None, json=None, headers=None):
            self.backend.calls.append((method, path, params or {}, json))
            if method == "GET" and path == "/api/model/info":
                return httpx.Response(
                    200,
                    json={
                        "model": "claude-sonnet-4",
                        "provider": "anthropic",
                        "effective_context_length": 200000,
                    },
                )
            if method == "GET" and path == "/api/model/recommended-default":
                return httpx.Response(
                    200,
                    json={"provider": params["provider"], "model": "recommended"},
                )
            if method == "GET" and path == "/api/model/auxiliary":
                return httpx.Response(200, json={"main": {}, "tasks": []})
            if method == "GET" and path == "/api/model/moa":
                return httpx.Response(200, json={"default_preset": "default", "presets": {}})
            if method == "PUT" and path == "/api/model/moa":
                return httpx.Response(200, json={"ok": True, **(json or {})})
            if method == "POST" and path == "/api/model/set":
                return httpx.Response(200, json={"ok": True, **(json or {})})
            return httpx.Response(404, json={"detail": "not found"})

    class _Backend:
        is_running = True

        def __init__(self) -> None:
            self.calls: list[tuple] = []
            self.client = TestModelSkillsTools._Client(self)

        async def http_client(self):
            return self.client

        async def gateway_rpc(self, method, params=None, timeout=60.0):
            self.calls.append(("RPC", method, {}, params or {}))
            assert method == "model.options"
            return {"providers": [{"id": "anthropic", "models": ["claude-sonnet-4"]}]}

    def _model_client(self):
        settings = Settings(api_key="test-key-42")
        backend = self._Backend()
        app = FastAPI()
        app.include_router(build_domain_router(settings, backend))
        return backend, TestClient(app)

    def test_model_options_rpc_requires_explicit_models(self):
        backend, client = self._model_client()
        with client:
            response = client.get("/api/v1/model", headers=AUTH)

        assert response.status_code == 200
        assert response.json()["providers"] == [
            {"id": "anthropic", "models": ["claude-sonnet-4"]}
        ]
        assert ("RPC", "model.options", {}, {"explicit_only": True}) in backend.calls

    def test_model_options_refresh_rpc_adds_refresh_flag(self):
        backend, client = self._model_client()
        with client:
            response = client.get("/api/v1/model?refresh=true", headers=AUTH)

        assert response.status_code == 200
        assert (
            "RPC",
            "model.options",
            {},
            {"explicit_only": True, "refresh": True},
        ) in backend.calls

    def test_advanced_model_routes_preserve_profile_and_payload(self):
        backend, client = self._model_client()
        moa = {
            "default_preset": "fast",
            "active_preset": "fast",
            "presets": {},
        }
        with client:
            recommended = client.get(
                "/api/v1/model/recommended-default",
                headers=AUTH,
                params={"provider": "nous", "profile": "research"},
            )
            auxiliary = client.get(
                "/api/v1/model/auxiliary",
                headers=AUTH,
                params={"profile": "research"},
            )
            loaded_moa = client.get(
                "/api/v1/model/moa", headers=AUTH, params={"profile": "research"}
            )
            saved_moa = client.put(
                "/api/v1/model/moa",
                headers=AUTH,
                params={"profile": "research"},
                json=moa,
            )
            assignment = client.post(
                "/api/v1/model/set",
                headers=AUTH,
                params={"profile": "research"},
                json={
                    "scope": "auxiliary",
                    "task": "vision",
                    "provider": "auto",
                    "model": "",
                },
            )

        assert recommended.json()["model"] == "recommended"
        assert auxiliary.json()["tasks"] == []
        assert loaded_moa.json()["default_preset"] == "default"
        assert saved_moa.json()["default_preset"] == "fast"
        assert assignment.json()["task"] == "vision"
        assert (
            "GET",
            "/api/model/recommended-default",
            {"provider": "nous", "profile": "research"},
            None,
        ) in backend.calls
        assert ("PUT", "/api/model/moa", {"profile": "research"}, moa) in backend.calls

    def test_model_switch_requires_provider_and_model(self, client_no_backend: TestClient):
        """domain_api.py raises HTTPException(422) when fields are missing."""
        resp = client_no_backend.post(
            "/api/v1/model/switch", headers=AUTH, json={}
        )
        assert resp.status_code == 422
        assert "provider and model are required" in resp.text

    def test_model_switch_partial_payload_422(self, client_no_backend: TestClient):
        resp = client_no_backend.post(
            "/api/v1/model/switch", headers=AUTH, json={"provider": "openai"}
        )
        assert resp.status_code == 422

    def test_model_get_ok_when_backend_up_or_503(self, client_no_backend: TestClient):
        resp = client_no_backend.get("/api/v1/model", headers=AUTH)
        assert resp.status_code == 503

    def test_skills_get_503(self, client_no_backend: TestClient):
        resp = client_no_backend.get("/api/v1/skills", headers=AUTH)
        assert resp.status_code == 503

    def test_tools_get_503(self, client_no_backend: TestClient):
        resp = client_no_backend.get("/api/v1/tools", headers=AUTH)
        assert resp.status_code == 503

    def test_computer_use_routes_need_backend(self, client_no_backend: TestClient):
        status = client_no_backend.get(
            "/api/v1/tools/computer-use/status", headers=AUTH
        )
        grant = client_no_backend.post(
            "/api/v1/tools/computer-use/permissions/grant", headers=AUTH
        )
        assert status.status_code == 503
        assert grant.status_code == 503

    def test_terminal_backend_routes_need_backend(
        self, client_no_backend: TestClient
    ):
        listed = client_no_backend.get(
            "/api/v1/tools/terminal/backends", headers=AUTH
        )
        selected = client_no_backend.put(
            "/api/v1/tools/terminal/backend",
            headers=AUTH,
            json={"backend": "docker"},
        )
        assert listed.status_code == 503
        assert selected.status_code == 503

    def test_skill_toggle_needs_body(self, client_no_backend: TestClient):
        resp = client_no_backend.put(
            "/api/v1/skills/webresearch/enabled", headers=AUTH
        )
        assert resp.status_code == 422

    def test_skill_content_get_503(self, client_no_backend: TestClient):
        resp = client_no_backend.get(
            "/api/v1/skills/content", params={"name": "webresearch"}, headers=AUTH
        )
        assert resp.status_code == 503

    def test_skill_content_needs_name(self, client_no_backend: TestClient):
        resp = client_no_backend.get("/api/v1/skills/content", headers=AUTH)
        assert resp.status_code == 422

    def test_skill_hub_sources_get_503(self, client_no_backend: TestClient):
        resp = client_no_backend.get("/api/v1/skills/hub/sources", headers=AUTH)
        assert resp.status_code == 503

    def test_skill_hub_search_get_503(self, client_no_backend: TestClient):
        resp = client_no_backend.get(
            "/api/v1/skills/hub/search", params={"q": "web"}, headers=AUTH
        )
        assert resp.status_code == 503

    def test_skill_hub_search_needs_q(self, client_no_backend: TestClient):
        resp = client_no_backend.get("/api/v1/skills/hub/search", headers=AUTH)
        assert resp.status_code == 422

    def test_skill_hub_preview_get_503(self, client_no_backend: TestClient):
        resp = client_no_backend.get(
            "/api/v1/skills/hub/preview",
            params={"identifier": "github:foo/bar"},
            headers=AUTH,
        )
        assert resp.status_code == 503

    def test_skill_hub_scan_get_503(self, client_no_backend: TestClient):
        resp = client_no_backend.get(
            "/api/v1/skills/hub/scan",
            params={"identifier": "github:foo/bar"},
            headers=AUTH,
        )
        assert resp.status_code == 503

    def test_skill_hub_install_needs_body(self, client_no_backend: TestClient):
        resp = client_no_backend.post("/api/v1/skills/hub/install", headers=AUTH)
        assert resp.status_code == 422

    def test_skill_hub_install_503(self, client_no_backend: TestClient):
        resp = client_no_backend.post(
            "/api/v1/skills/hub/install",
            headers=AUTH,
            json={"identifier": "github:foo/bar"},
        )
        assert resp.status_code == 503

    def test_skill_hub_uninstall_503(self, client_no_backend: TestClient):
        resp = client_no_backend.post(
            "/api/v1/skills/hub/uninstall", headers=AUTH, json={"name": "foo"}
        )
        assert resp.status_code == 503

    def test_skill_hub_update_503(self, client_no_backend: TestClient):
        resp = client_no_backend.post(
            "/api/v1/skills/hub/update", headers=AUTH, json={}
        )
        assert resp.status_code == 503


# ===========================================================================
# 5. FILES — including the newly added /files/upload
# ===========================================================================


class TestFiles:
    def test_list_files_path_required_422(self, client_no_backend: TestClient):
        resp = client_no_backend.get("/api/v1/files", headers=AUTH)
        assert resp.status_code == 422  # missing required Query `path`

    def test_read_file_path_required_422(self, client_no_backend: TestClient):
        resp = client_no_backend.get("/api/v1/files/read", headers=AUTH)
        assert resp.status_code == 422

    def test_write_file_needs_body(self, client_no_backend: TestClient):
        resp = client_no_backend.post("/api/v1/files/write", headers=AUTH)
        assert resp.status_code == 422

    def test_upload_file_validates_locally_not_404(self, client_no_backend: TestClient):
        """Files are provided by mobile-server itself even without Hermes."""
        resp = client_no_backend.post(
            "/api/v1/files/upload",
            headers=AUTH,
            json={"path": "/tmp/x", "data_url": "data:text/plain;base64,AAA"},
        )
        assert resp.status_code != 404
        assert resp.status_code == 422  # malformed base64 is rejected locally

    def test_upload_generic_attachment_roundtrip(
        self, client_no_backend: TestClient, tmp_path
    ):
        """Composer attachment flow (A1/A2): arbitrary non-image files upload
        to /hm-attachments/ via the generic data-URL route and read back."""
        import base64

        payload = b"generic attachment bytes"
        data_url = "data:application/octet-stream;base64," + base64.b64encode(
            payload
        ).decode()
        target = str(tmp_path / "hm-attachments" / "hm_attach_1_notes.bin")
        resp = client_no_backend.post(
            "/api/v1/files/upload",
            headers=AUTH,
            json={"path": target, "data_url": data_url},
        )
        assert resp.status_code == 200
        body = resp.json()
        # _path() resolves the value; compare the resolved form.
        assert body["path"].replace("\\", "/").endswith(
            "hm-attachments/hm_attach_1_notes.bin"
        )
        assert body["size"] == len(payload)
        # No-overwrite guard: a second upload to the same path is rejected.
        again = client_no_backend.post(
            "/api/v1/files/upload",
            headers=AUTH,
            json={"path": target, "data_url": data_url},
        )
        assert again.status_code == 422
        # The stored bytes are readable back verbatim.
        read_back = client_no_backend.get(
            "/api/v1/files/read-data-url", headers=AUTH, params={"path": target}
        )
        assert read_back.status_code == 200
        stored = read_back.json()["data_url"].split(",", 1)[1]
        assert base64.b64decode(stored) == payload

    def test_local_file_browser_routes_work_without_backend(
        self, client_no_backend: TestClient, tmp_path
    ):
        """Regression: these routes must not degrade to proxy-only 503s."""
        root = str(tmp_path)
        drives = client_no_backend.get("/api/v1/files/drives", headers=AUTH)
        assert drives.status_code == 200
        created = client_no_backend.post(
            "/api/v1/files/write",
            headers=AUTH,
            json={"path": str(tmp_path / "note.txt"), "content": "hello"},
        )
        assert created.status_code == 200
        listing = client_no_backend.get(
            "/api/v1/files/entries", headers=AUTH, params={"path": root}
        )
        assert listing.status_code == 200
        assert listing.json()["entries"][0]["name"] == "note.txt"
        read = client_no_backend.get(
            "/api/v1/files/read",
            headers=AUTH,
            params={"path": str(tmp_path / "note.txt")},
        )
        assert read.json()["text"] == "hello"
        download = client_no_backend.get(
            "/api/v1/files/download",
            headers=AUTH,
            params={"path": str(tmp_path / "note.txt")},
        )
        assert download.status_code == 200
        assert download.content == b"hello"
        assert "note.txt" in (download.headers.get("content-disposition") or "")

        nested = tmp_path / "pack"
        nested.mkdir()
        (nested / "a.txt").write_text("alpha", encoding="utf-8")
        (nested / "b.txt").write_text("beta", encoding="utf-8")
        folder_dl = client_no_backend.get(
            "/api/v1/files/download",
            headers=AUTH,
            params={"path": str(nested)},
        )
        assert folder_dl.status_code == 200
        assert "pack.zip" in (folder_dl.headers.get("content-disposition") or "")
        assert folder_dl.headers.get("content-type", "").startswith(
            "application/zip"
        )
        import io
        import zipfile

        with zipfile.ZipFile(io.BytesIO(folder_dl.content)) as zf:
            names = sorted(zf.namelist())
            assert names == ["pack/a.txt", "pack/b.txt"]
            assert zf.read("pack/a.txt") == b"alpha"
            assert zf.read("pack/b.txt") == b"beta"

    def test_reveal_uses_local_file_manager(
        self, client_no_backend: TestClient, tmp_path, monkeypatch
    ):
        calls: list[list[str]] = []

        class Process:
            pass

        monkeypatch.setattr(
            "hermes_mobile_server.local_workspace.subprocess.Popen",
            lambda args: calls.append(args) or Process(),
        )
        target = tmp_path / "note.txt"
        target.write_text("hello", encoding="utf-8")

        response = client_no_backend.post(
            "/api/v1/files/reveal", headers=AUTH, json={"path": str(target)}
        )

        assert response.status_code == 200
        assert response.json()["path"] == str(target.resolve())
        assert calls

    def test_mkdir_needs_body(self, client_no_backend: TestClient):
        resp = client_no_backend.post("/api/v1/files/mkdir", headers=AUTH)
        assert resp.status_code == 422

    def test_move_needs_body(self, client_no_backend: TestClient):
        resp = client_no_backend.post("/api/v1/files/move", headers=AUTH)
        assert resp.status_code == 422

    def test_delete_needs_body(self, client_no_backend: TestClient):
        resp = client_no_backend.post("/api/v1/files/delete", headers=AUTH)
        assert resp.status_code == 422


class TestFilesAllowPaths:
    """``Settings.allow_paths`` must confine the local file API (422)."""

    def test_restricted_roots(self, tmp_path):
        allowed = tmp_path / "allowed"
        allowed.mkdir()
        settings = Settings(
            api_key="test-key-42",
            backend_ready_timeout=0.01,
            hermes_root_override="Z:\\nonexistent\\hermes\\definitely\\not\\here",
            allow_paths=[str(allowed)],
        )
        try:
            client = TestClient(
                create_app(settings, task_store=TaskStore(tmp_path / "tasks.db"))
            )
            inside = client.get(
                "/api/v1/files", headers=AUTH, params={"path": str(allowed)}
            )
            assert inside.status_code == 200

            outside = client.get(
                "/api/v1/files", headers=AUTH, params={"path": str(tmp_path)}
            )
            assert outside.status_code == 422
            assert "outside allowed roots" in outside.json()["detail"]

            escape = client.get(
                "/api/v1/files",
                headers=AUTH,
                params={"path": str(allowed / ".." / "..")},
            )
            assert escape.status_code == 422
        finally:
            local_workspace.configure_allowed_roots(None)


# ===========================================================================
# 6. AUDIO / CRON / MEMORY / PROJECTS
# ===========================================================================


class TestAudioCronMemoryProjects:
    def test_transcribe_needs_body(self, client_no_backend: TestClient):
        resp = client_no_backend.post("/api/v1/audio/transcribe", headers=AUTH)
        assert resp.status_code == 422

    def test_speak_needs_body(self, client_no_backend: TestClient):
        resp = client_no_backend.post("/api/v1/audio/speak", headers=AUTH)
        assert resp.status_code == 422

    def test_cron_get_503(self, client_no_backend: TestClient):
        resp = client_no_backend.get("/api/v1/cron", headers=AUTH)
        assert resp.status_code == 503

    def test_cron_create_needs_body(self, client_no_backend: TestClient):
        resp = client_no_backend.post("/api/v1/cron", headers=AUTH)
        assert resp.status_code == 422

    def test_cron_update_needs_body(self, client_no_backend: TestClient):
        resp = client_no_backend.put("/api/v1/cron/j1", headers=AUTH)
        assert resp.status_code == 422

    def test_cron_runs_503(self, client_no_backend: TestClient):
        resp = client_no_backend.get("/api/v1/cron/j1/runs", headers=AUTH)
        assert resp.status_code == 503

    def test_memory_get_503(self, client_no_backend: TestClient):
        resp = client_no_backend.get("/api/v1/memory", headers=AUTH)
        assert resp.status_code == 503

    def test_memory_reset_503(self, client_no_backend: TestClient):
        resp = client_no_backend.post("/api/v1/memory/reset", headers=AUTH, json={})
        assert resp.status_code == 503

    def test_memory_provider_put_needs_body(self, client_no_backend: TestClient):
        resp = client_no_backend.put("/api/v1/memory/provider", headers=AUTH)
        assert resp.status_code == 422

    def test_projects_503(self, client_no_backend: TestClient):
        resp = client_no_backend.get("/api/v1/projects", headers=AUTH)
        assert resp.status_code == 503


class TestTranscribeSttNotConfigured:
    """The 409 must be a top-level structured error the Flutter client can
    decode, not a map-valued ``detail`` it renders as a raw toString."""

    class _Client:
        async def request(self, method, path, params=None, json=None, headers=None):
            if method == "GET" and path == "/api/config":
                return httpx.Response(200, json={"stt": {"enabled": False}})
            return httpx.Response(200, json={"ok": True})

    class _Backend:
        is_running = True

        async def http_client(self):
            return TestTranscribeSttNotConfigured._Client()

    def test_transcribe_409_is_structured(self):
        settings = Settings(api_key="test-key-42")
        app = FastAPI()
        app.include_router(build_domain_router(settings, self._Backend()))
        client = TestClient(app)

        resp = client.post(
            "/api/v1/audio/transcribe",
            headers=AUTH,
            json={"data_url": "x", "mime_type": "wav"},
        )

        assert resp.status_code == 409
        assert resp.json() == {
            "error": {
                "code": "stt_not_configured",
                "message": "Speech-to-text provider is not configured",
            }
        }


class TestCanonicalCronCatalogBridge:
    """Static Cron catalog paths must not be swallowed by /cron/{job_id}."""

    class _Client:
        def __init__(self, backend) -> None:
            self.backend = backend

        async def request(self, method, path, params=None, json=None, headers=None):
            self.backend.calls.append((method, path, params or {}, json))
            if path == "/api/cron/blueprints":
                return httpx.Response(200, json={"blueprints": [{"key": "morning-brief"}]})
            if path == "/api/cron/delivery-targets":
                return httpx.Response(200, json={"targets": [{"id": "local"}]})
            return httpx.Response(200, json={"id": "job-from-blueprint"})

    class _Backend:
        is_running = True

        def __init__(self) -> None:
            self.calls: list[tuple] = []
            self.client = TestCanonicalCronCatalogBridge._Client(self)

        async def http_client(self):
            return self.client

    def test_catalog_targets_and_instantiate_use_canonical_paths(self):
        backend = self._Backend()
        app = FastAPI()
        app.include_router(
            build_domain_router(Settings(api_key="test-key-42"), backend)
        )
        with TestClient(app) as client:
            blueprints = client.get("/api/v1/cron/blueprints", headers=AUTH)
            targets = client.get("/api/v1/cron/delivery-targets", headers=AUTH)
            created = client.post(
                "/api/v1/cron/blueprints/instantiate",
                headers=AUTH,
                json={"blueprint": "morning-brief", "values": {"time": "08:00"}},
            )

        assert blueprints.status_code == 200
        assert blueprints.json()["blueprints"][0]["key"] == "morning-brief"
        assert targets.status_code == 200
        assert created.status_code == 200
        assert ("GET", "/api/cron/blueprints", {}, None) in backend.calls
        assert ("GET", "/api/cron/delivery-targets", {}, None) in backend.calls
        assert (
            "POST",
            "/api/cron/blueprints/instantiate",
            {},
            {"blueprint": "morning-brief", "values": {"time": "08:00"}},
        ) in backend.calls


# ===========================================================================
# 7. GIT ENDPOINTS
# ===========================================================================


class TestGit:
    REQUIRED_PATH = [
        ("/api/v1/git/status", "get"),
        ("/api/v1/git/branches", "get"),
        ("/api/v1/git/base-branches", "get"),
        ("/api/v1/git/worktrees", "get"),
        ("/api/v1/git/review/list", "get"),
        ("/api/v1/git/review/diff", "get"),
        ("/api/v1/git/file-diff", "get"),
        ("/api/v1/git/review/commit-context", "get"),
        ("/api/v1/git/review/rev-parse", "get"),
        ("/api/v1/git/review/ship-info", "get"),
    ]

    NEED_BODY = [
        ("/api/v1/git/review/stage", "post"),
        ("/api/v1/git/review/unstage", "post"),
        ("/api/v1/git/review/revert", "post"),
        ("/api/v1/git/review/commit", "post"),
        ("/api/v1/git/review/push", "post"),
        ("/api/v1/git/review/pr-list", "post"),
        ("/api/v1/git/review/create-pr", "post"),
        ("/api/v1/git/branch/switch", "post"),
        ("/api/v1/git/worktree/add", "post"),
        ("/api/v1/git/worktree/remove", "post"),
        ("/api/v1/git/commit-message", "post"),
        ("/api/v1/git/pr/create", "post"),
    ]

    def test_git_required_path_param(self, client_no_backend: TestClient):
        for path, method in self.REQUIRED_PATH:
            fn = getattr(client_no_backend, method)
            resp = fn(path, headers=AUTH)
            assert resp.status_code == 422, f"{method.upper()} {path}"


class TestCanonicalGitBridge:
    class _Client:
        def __init__(self, backend) -> None:
            self.backend = backend

        async def request(self, method, path, params=None, json=None):
            self.backend.calls.append((method, path, params or {}, json))
            if method == "GET" and path == "/api/git/status":
                return httpx.Response(200, json={"branch": "main", "files": []})
            if method == "GET" and path == "/api/git/review/commit-context":
                return httpx.Response(
                    200, json={"diff": "+new line", "recent": ["old commit"]}
                )
            if method == "POST" and path == "/api/git/review/create-pr":
                return httpx.Response(200, json={"url": "https://example.test/pr/1"})
            if method == "GET" and path == "/api/git/review/ship-info":
                return httpx.Response(
                    200,
                    json={"ghReady": True, "pr": {"number": 1, "url": "https://example.test/pr/1"}},
                )
            return httpx.Response(200, json={"ok": True})

    class _Backend:
        is_running = True

        def __init__(self) -> None:
            self.calls = []
            self.client = TestCanonicalGitBridge._Client(self)

        async def http_client(self):
            return self.client

        async def gateway_rpc(self, method, params=None, timeout=60.0):
            self.calls.append(("RPC", method, {}, params or {}))
            assert method == "llm.oneshot"
            return {"text": "feat: add new line"}

    def test_git_actions_use_desktop_routes_and_oneshot(self):
        backend = self._Backend()
        app = FastAPI()
        app.include_router(
            build_domain_router(Settings(api_key="test-key-42"), backend)
        )
        with TestClient(app) as client:
            status = client.get(
                "/api/v1/git/status", headers=AUTH, params={"path": "D:/repo"}
            )
            message = client.post(
                "/api/v1/git/commit-message",
                headers=AUTH,
                json={"path": "D:/repo"},
            )
            pr = client.post(
                "/api/v1/git/review/create-pr",
                headers=AUTH,
                json={"path": "D:/repo"},
            )
            ship = client.get(
                "/api/v1/git/review/ship-info",
                headers=AUTH,
                params={"path": "D:/repo"},
            )

        assert status.status_code == 200
        assert message.json()["message"] == "feat: add new line"
        assert pr.json()["url"] == "https://example.test/pr/1"
        assert ship.json()["pr"]["number"] == 1
        assert (
            "POST", "/api/git/review/create-pr", {}, {"path": "D:/repo"}
        ) in backend.calls
        oneshot = next(call for call in backend.calls if call[1] == "llm.oneshot")
        assert oneshot[3]["template"] == "commit_message"
        assert oneshot[3]["variables"]["diff"] == "+new line"

    def test_git_file_diff_needs_file(self, client_no_backend: TestClient):
        resp = client_no_backend.get(
            "/api/v1/git/file-diff", headers=AUTH, params={"path": "/tmp"}
        )
        assert resp.status_code == 422

    def test_git_review_diff_needs_file(self, client_no_backend: TestClient):
        resp = client_no_backend.get(
            "/api/v1/git/review/diff", headers=AUTH, params={"path": "/tmp"}
        )
        assert resp.status_code == 422

    def test_git_body_endpoints(self, client_no_backend: TestClient):
        for path, method in TestGit.NEED_BODY:
            fn = getattr(client_no_backend, method)
            resp = fn(path, headers=AUTH)
            assert resp.status_code == 422, f"{method.upper()} {path}"

    def test_worktree_and_base_branch_routes_forward_to_upstream(self):
        """The Dart client's gitWorktrees/gitWorktreeAdd previously hit
        /api/git/worktrees (no /v1) — a route the mobile server never
        registered, so "新建 Worktree" always 404'd. This locks in the fixed
        /api/v1/git/... contract and its forward to hermes_cli's real routes
        (hermes_cli/web_routers/git.py)."""
        backend = self._Backend()
        app = FastAPI()
        app.include_router(
            build_domain_router(Settings(api_key="test-key-42"), backend)
        )
        with TestClient(app) as client:
            assert client.get(
                "/api/v1/git/worktrees", headers=AUTH, params={"path": "/repo"}
            ).status_code == 200
            assert client.get(
                "/api/v1/git/base-branches", headers=AUTH, params={"path": "/repo"}
            ).status_code == 200
            assert client.post(
                "/api/v1/git/worktree/add",
                headers=AUTH,
                json={"path": "/repo", "name": "feature-x", "base": "main"},
            ).status_code == 200
            assert client.post(
                "/api/v1/git/worktree/remove",
                headers=AUTH,
                json={"path": "/repo", "worktreePath": "/repo/.worktrees/feature-x", "force": True},
            ).status_code == 200

        assert ("GET", "/api/git/worktrees", {"path": "/repo"}, None) in backend.calls
        assert (
            "GET",
            "/api/git/base-branches",
            {"path": "/repo"},
            None,
        ) in backend.calls
        assert (
            "POST",
            "/api/git/worktree/add",
            {},
            {"path": "/repo", "name": "feature-x", "base": "main"},
        ) in backend.calls
        assert (
            "POST",
            "/api/git/worktree/remove",
            {},
            {"path": "/repo", "worktreePath": "/repo/.worktrees/feature-x", "force": True},
        ) in backend.calls


# ===========================================================================
# 8. ANALYTICS
# ===========================================================================


class TestAnalytics:
    def test_analytics_usage_days_bounds(self, client_no_backend: TestClient):
        resp = client_no_backend.get(
            "/api/v1/analytics/usage", headers=AUTH, params={"days": 0}
        )
        assert resp.status_code == 422
        resp = client_no_backend.get(
            "/api/v1/analytics/usage", headers=AUTH, params={"days": 1000}
        )
        assert resp.status_code == 422
        resp = client_no_backend.get(
            "/api/v1/analytics/usage", headers=AUTH, params={"days": 30}
        )
        assert resp.status_code == 503

    def test_analytics_models_days_bounds(self, client_no_backend: TestClient):
        resp = client_no_backend.get(
            "/api/v1/analytics/models", headers=AUTH, params={"days": 366}
        )
        assert resp.status_code == 422


class TestOps:
    """Command Center's Maintenance tab — thin proxies to /api/ops/*."""

    def test_doctor_503_without_backend(self, client_no_backend: TestClient):
        resp = client_no_backend.post("/api/v1/ops/doctor", headers=AUTH)
        assert resp.status_code == 503

    def test_security_audit_503_without_backend(self, client_no_backend: TestClient):
        resp = client_no_backend.post("/api/v1/ops/security-audit", headers=AUTH)
        assert resp.status_code == 503

    def test_backup_503_without_backend(self, client_no_backend: TestClient):
        resp = client_no_backend.post("/api/v1/ops/backup", headers=AUTH)
        assert resp.status_code == 503

    def test_debug_share_503_without_backend(self, client_no_backend: TestClient):
        resp = client_no_backend.post("/api/v1/ops/debug-share", headers=AUTH)
        assert resp.status_code == 503


# ===========================================================================
# 9. KNOWLEDGE / STARMAP
# ===========================================================================


class TestKnowledgeStarmap:
    def test_knowledge_node_id_required(self, client_no_backend: TestClient):
        resp = client_no_backend.get("/api/v1/knowledge/node", headers=AUTH)
        assert resp.status_code == 422
        resp = client_no_backend.delete("/api/v1/knowledge/node", headers=AUTH)
        assert resp.status_code == 422

    def test_knowledge_put_needs_body(self, client_no_backend: TestClient):
        resp = client_no_backend.put("/api/v1/knowledge/node", headers=AUTH)
        assert resp.status_code == 422

    def test_starmap_node_id_required(self, client_no_backend: TestClient):
        resp = client_no_backend.get("/api/v1/starmap/node", headers=AUTH)
        assert resp.status_code == 422
        resp = client_no_backend.delete("/api/v1/starmap/node", headers=AUTH)
        assert resp.status_code == 422

    def test_starmap_put_needs_body(self, client_no_backend: TestClient):
        resp = client_no_backend.put("/api/v1/starmap/node", headers=AUTH)
        assert resp.status_code == 422

    def test_starmap_graph_503(self, client_no_backend: TestClient):
        resp = client_no_backend.get("/api/v1/starmap/graph", headers=AUTH)
        assert resp.status_code == 503


# ===========================================================================
# 10. MCP / PLUGINS
# ===========================================================================


class TestMcpPlugins:
    def test_mcp_servers_503(self, client_no_backend: TestClient):
        resp = client_no_backend.get("/api/v1/mcp/servers", headers=AUTH)
        assert resp.status_code == 503

    def test_mcp_server_create_needs_body(self, client_no_backend: TestClient):
        resp = client_no_backend.post("/api/v1/mcp/servers", headers=AUTH)
        assert resp.status_code == 422

    def test_mcp_toggle_needs_body(self, client_no_backend: TestClient):
        resp = client_no_backend.put(
            "/api/v1/mcp/servers/foo/enabled", headers=AUTH
        )
        assert resp.status_code == 422

    def test_mcp_replace_and_catalog_install_need_body(
        self, client_no_backend: TestClient
    ):
        assert client_no_backend.put(
            "/api/v1/mcp/servers", headers=AUTH
        ).status_code == 422
        assert client_no_backend.post(
            "/api/v1/mcp/catalog/install", headers=AUTH
        ).status_code == 422

    def test_oauth_callback_relay_is_public(self, client_no_backend: TestClient):
        response = client_no_backend.get(
            "/api/v1/api/mcp/oauth/callback/remote",
            params={"code": "x", "state": "y"},
        )
        assert response.status_code == 503
        assert response.status_code != 401

    def test_plugins_503(self, client_no_backend: TestClient):
        resp = client_no_backend.get("/api/v1/plugins", headers=AUTH)
        assert resp.status_code == 503

    def test_plugins_toggle_needs_body(self, client_no_backend: TestClient):
        resp = client_no_backend.put(
            "/api/v1/plugins/foo/enabled", headers=AUTH
        )
        assert resp.status_code == 422


class TestCanonicalMcpBridge:
    class _Client:
        def __init__(self, backend) -> None:
            self.backend = backend

        async def request(self, method, path, params=None, json=None, headers=None):
            self.backend.calls.append((method, path, params or {}, json))
            if headers:
                self.backend.forwarded_headers = headers
            return httpx.Response(200, json={"ok": True})

    class _Backend:
        is_running = True

        def __init__(self) -> None:
            self.calls: list[tuple] = []
            self.forwarded_headers: dict[str, str] = {}
            self.client = TestCanonicalMcpBridge._Client(self)

        async def http_client(self):
            return self.client

    def test_mutations_and_oauth_use_current_hermes_routes(self):
        settings = Settings(api_key="test-key-42")
        backend = self._Backend()
        app = FastAPI()
        app.include_router(build_domain_router(settings, backend))

        with TestClient(app) as client:
            assert client.put(
                "/api/v1/mcp/servers",
                headers=AUTH,
                json={"servers": {"remote": {"url": "https://mcp.example"}}},
            ).status_code == 200
            assert client.delete(
                "/api/v1/mcp/servers/remote", headers=AUTH
            ).status_code == 200
            assert client.post(
                "/api/v1/mcp/servers/remote/auth", headers=AUTH
            ).status_code == 200
            assert client.get(
                "/api/v1/mcp/oauth/flows/flow-1", headers=AUTH
            ).status_code == 200
            assert client.post(
                "/api/v1/mcp/catalog/install",
                headers=AUTH,
                json={"name": "github", "env": {}, "enable": True},
            ).status_code == 200
            assert client.get(
                "/api/v1/actions/mcp-install-github/status",
                headers=AUTH,
                params={"lines": 50},
            ).status_code == 200

        assert (
            "PUT",
            "/api/mcp/servers",
            {},
            {"servers": {"remote": {"url": "https://mcp.example"}}},
        ) in backend.calls
        assert ("DELETE", "/api/mcp/servers/remote", {}, None) in backend.calls
        assert ("POST", "/api/mcp/servers/remote/auth", {}, None) in backend.calls
        assert backend.forwarded_headers == {
            "host": "testserver",
            "x-forwarded-host": "testserver",
            "x-forwarded-proto": "http",
            "x-forwarded-prefix": "/api/v1",
        }
        assert ("GET", "/api/mcp/oauth/flows/flow-1", {}, None) in backend.calls
        assert (
            "POST",
            "/api/mcp/catalog/install",
            {},
            {"name": "github", "env": {}, "enable": True},
        ) in backend.calls
        assert (
            "GET",
            "/api/actions/mcp-install-github/status",
            {"lines": 50},
            None,
        ) in backend.calls

    def test_profile_query_param_forwards_to_every_mcp_route(self):
        """Command Center's Profile scope override (mobile's ProfileScopeStore,
        desktop's SettingsProfileScope/Capabilities scope parity) relies on
        every /mcp/* route forwarding ?profile= to the upstream request —
        omitted entirely (not "profile": None) when no override is active."""
        settings = Settings(api_key="test-key-42")
        backend = self._Backend()
        app = FastAPI()
        app.include_router(build_domain_router(settings, backend))

        with TestClient(app) as client:
            assert client.get(
                "/api/v1/mcp/servers", headers=AUTH, params={"profile": "work"}
            ).status_code == 200
            assert client.get(
                "/api/v1/mcp/servers", headers=AUTH
            ).status_code == 200
            assert client.get(
                "/api/v1/mcp/servers/remote/test",
                headers=AUTH,
                params={"profile": "work"},
            ).status_code == 200
            assert client.put(
                "/api/v1/mcp/servers/remote/enabled",
                headers=AUTH,
                params={"profile": "work"},
                json={"enabled": True},
            ).status_code == 200
            assert client.get(
                "/api/v1/mcp/catalog", headers=AUTH, params={"profile": "work"}
            ).status_code == 200
            assert client.post(
                "/api/v1/mcp/servers",
                headers=AUTH,
                params={"profile": "work"},
                json={"name": "remote", "url": "https://mcp.example"},
            ).status_code == 200

        assert ("GET", "/api/mcp/servers", {"profile": "work"}, None) in backend.calls
        assert ("GET", "/api/mcp/servers", {}, None) in backend.calls
        assert (
            "POST",
            "/api/mcp/servers/remote/test",
            {"profile": "work"},
            None,
        ) in backend.calls
        assert (
            "PUT",
            "/api/mcp/servers/remote/enabled",
            {"profile": "work"},
            {"enabled": True},
        ) in backend.calls
        assert ("GET", "/api/mcp/catalog", {"profile": "work"}, None) in backend.calls
        assert (
            "POST",
            "/api/mcp/servers",
            {"profile": "work"},
            {"name": "remote", "url": "https://mcp.example"},
        ) in backend.calls

    def test_profile_query_param_forwards_to_skills_and_tools(self):
        settings = Settings(api_key="test-key-42")
        backend = self._Backend()
        app = FastAPI()
        app.include_router(build_domain_router(settings, backend))

        with TestClient(app) as client:
            assert client.get(
                "/api/v1/skills", headers=AUTH, params={"profile": "work"}
            ).status_code == 200
            assert client.get(
                "/api/v1/tools", headers=AUTH, params={"profile": "work"}
            ).status_code == 200
            assert client.get(
                "/api/v1/tools/terminal/backends",
                headers=AUTH,
                params={"profile": "work"},
            ).status_code == 200
            assert client.put(
                "/api/v1/tools/terminal/backend",
                headers=AUTH,
                params={"profile": "work"},
                json={"backend": "docker"},
            ).status_code == 200

        assert ("GET", "/api/skills", {"profile": "work"}, None) in backend.calls
        assert (
            "GET",
            "/api/tools/toolsets",
            {"profile": "work"},
            None,
        ) in backend.calls
        assert (
            "GET",
            "/api/tools/terminal/backends",
            {"profile": "work"},
            None,
        ) in backend.calls
        assert (
            "PUT",
            "/api/tools/terminal/backend",
            {"profile": "work"},
            {"backend": "docker"},
        ) in backend.calls


# ===========================================================================
# 11. TASKS — full CRUD (no backend needed; TaskStore is in-process)
# ===========================================================================


class TestTasks:
    def _create(self, c: TestClient, **kw: Any) -> dict:
        return c.post("/api/v1/tasks", headers=AUTH, json=kw).json()

    def test_task_stores_are_isolated_between_app_instances(self, tmp_path):
        """Regression: tests must never seed the user's real board database."""
        settings = Settings(
            api_key="test-key-42",
            backend_ready_timeout=0.01,
            hermes_root_override="Z:\\nonexistent\\hermes\\definitely\\not\\here",
        )
        first = TestClient(
            create_app(settings, task_store=TaskStore(tmp_path / "first.db"))
        )
        second = TestClient(
            create_app(settings, task_store=TaskStore(tmp_path / "second.db"))
        )
        created = self._create(first, title="only-in-first-store")
        assert created["title"] == "only-in-first-store"
        assert second.get("/api/v1/tasks", headers=AUTH).json()["tasks"] == []

    def test_task_create_minimal(self, client_no_backend: TestClient):
        resp = client_no_backend.post(
            "/api/v1/tasks", headers=AUTH, json={"title": " Test me "}
        )
        assert resp.status_code == 200
        t = resp.json()
        assert t["id"]
        assert t["title"] == "Test me"
        assert t["status"] == "inbox"
        assert t["priority"] == "normal"

    def test_task_create_empty_title_422(self, client_no_backend: TestClient):
        resp = client_no_backend.post(
            "/api/v1/tasks", headers=AUTH, json={"title": "   "}
        )
        assert resp.status_code == 422

    def test_task_create_bad_priority_still_defaults(self, client_no_backend: TestClient):
        """Unknown priorities fall through to default in TaskStore."""
        resp = client_no_backend.post(
            "/api/v1/tasks",
            headers=AUTH,
            json={"title": "T", "priority": "astronomical"},
        )
        # TaskStore.create doesn't explicitly validate; we just ensure no 500.
        assert resp.status_code == 200

    def test_task_list_all(self, client_no_backend: TestClient):
        self._create(client_no_backend, title="A")
        self._create(client_no_backend, title="B")
        resp = client_no_backend.get("/api/v1/tasks", headers=AUTH)
        assert resp.status_code == 200
        body = resp.json()
        assert "tasks" in body
        assert len(body["tasks"]) >= 2

    def test_task_list_filter_status_invalid_422(self, client_no_backend: TestClient):
        resp = client_no_backend.get(
            "/api/v1/tasks", headers=AUTH, params={"status": "bogus"}
        )
        assert resp.status_code == 422

    def test_task_list_filter_valid_status(self, client_no_backend: TestClient):
        self._create(client_no_backend, title="running-task-test")
        # Filter by a real status even if no tasks match.
        for s in ("inbox", "running", "done", "archived", "blocked", "review"):
            resp = client_no_backend.get(
                "/api/v1/tasks", headers=AUTH, params={"status": s}
            )
            assert resp.status_code == 200

    def test_task_list_limit_bounds(self, client_no_backend: TestClient):
        resp = client_no_backend.get(
            "/api/v1/tasks", headers=AUTH, params={"limit": 501}
        )
        assert resp.status_code == 422
        resp = client_no_backend.get(
            "/api/v1/tasks", headers=AUTH, params={"limit": 0}
        )
        assert resp.status_code == 422

    def test_task_get(self, client_no_backend: TestClient):
        created = self._create(client_no_backend, title="fetch-me", prompt="P")
        resp = client_no_backend.get(
            f"/api/v1/tasks/{created['id']}", headers=AUTH
        )
        assert resp.status_code == 200
        t = resp.json()
        assert t["title"] == "fetch-me"
        assert t["prompt"] == "P"

    def test_task_get_missing_404(self, client_no_backend: TestClient):
        resp = client_no_backend.get("/api/v1/tasks/nope-id", headers=AUTH)
        assert resp.status_code == 404

    def test_task_patch_update(self, client_no_backend: TestClient):
        created = self._create(client_no_backend, title="orig")
        resp = client_no_backend.patch(
            f"/api/v1/tasks/{created['id']}",
            headers=AUTH,
            json={"title": "new", "status": "done"},
        )
        assert resp.status_code == 200
        updated = resp.json()
        assert updated["title"] == "new"
        assert updated["status"] == "done"
        assert updated["completed_at"] is not None

    def test_task_patch_missing_404(self, client_no_backend: TestClient):
        resp = client_no_backend.patch(
            "/api/v1/tasks/ghost", headers=AUTH, json={"title": "x"}
        )
        assert resp.status_code == 404

    def test_task_delete(self, client_no_backend: TestClient):
        created = self._create(client_no_backend, title="gonna-delete")
        del_resp = client_no_backend.delete(
            f"/api/v1/tasks/{created['id']}", headers=AUTH
        )
        assert del_resp.status_code == 200
        # Confirm it's gone.
        resp = client_no_backend.get(
            f"/api/v1/tasks/{created['id']}", headers=AUTH
        )
        assert resp.status_code == 404

    def test_task_delete_missing_404(self, client_no_backend: TestClient):
        resp = client_no_backend.delete("/api/v1/tasks/ghost", headers=AUTH)
        assert resp.status_code == 404

    def test_task_run_missing_404(self, client_no_backend: TestClient):
        resp = client_no_backend.post("/api/v1/tasks/ghost/run", headers=AUTH)
        assert resp.status_code == 404

    def test_task_run_no_backend_503(self, client_no_backend: TestClient):
        created = self._create(client_no_backend, title="run-me")
        resp = client_no_backend.post(
            f"/api/v1/tasks/{created['id']}/run", headers=AUTH
        )
        # The task exists but the backend call to session.create fails → 502 or 503
        assert resp.status_code in (502, 503)
        # Task status should still be inbox (never transitioned to running)
        state = client_no_backend.get(
            f"/api/v1/tasks/{created['id']}", headers=AUTH
        ).json()
        assert state["status"] != "done"


class TestCanonicalHermesKanbanBridge:
    """Production task endpoints must delegate to Hermes' Kanban plugin."""

    class _Client:
        def __init__(self, backend: "TestCanonicalHermesKanbanBridge._Backend") -> None:
            self._backend = backend

        async def request(self, method: str, path: str, *, params=None, json=None):
            self._backend.calls.append((method, path, params or {}, json))
            task = self._backend.task
            if method == "GET" and path == "/api/plugins/kanban/board":
                return httpx.Response(200, json={
                    "columns": [{"name": task["status"], "tasks": [task]}],
                })
            if method == "GET" and path == f"/api/plugins/kanban/tasks/{task['id']}":
                return httpx.Response(200, json={"task": task})
            if method == "POST" and path == "/api/plugins/kanban/tasks":
                self._backend.task = {
                    **task,
                    "title": json["title"],
                    "body": json["body"],
                    "priority": json["priority"],
                    "status": "triage",
                }
                return httpx.Response(200, json={"task": self._backend.task})
            if method == "PATCH" and path == f"/api/plugins/kanban/tasks/{task['id']}":
                if "title" in json:
                    task["title"] = json["title"]
                if "body" in json:
                    task["body"] = json["body"]
                if "priority" in json:
                    task["priority"] = json["priority"]
                if "status" in json:
                    task["status"] = json["status"]
                return httpx.Response(200, json={"task": task})
            if method == "POST" and path == "/api/plugins/kanban/dispatch":
                return httpx.Response(200, json={"spawned": []})
            if method == "DELETE" and path == f"/api/plugins/kanban/tasks/{task['id']}":
                return httpx.Response(200, json={"deleted": True})
            return httpx.Response(404, json={"detail": "missing fake route"})

    class _Backend:
        is_running = True

        def __init__(self) -> None:
            self.calls: list[tuple] = []
            self.task = {
                "id": "hermes-task-1",
                "title": "Canonical Hermes task",
                "body": "Actual board body",
                "priority": 1,
                "status": "todo",
                "session_id": None,
                "created_at": 1_700_000_000,
                "started_at": None,
                "completed_at": None,
            }
            self.client = TestCanonicalHermesKanbanBridge._Client(self)

        async def http_client(self):
            return self.client

    def test_tasks_proxy_the_hermes_kanban_plugin(self):
        settings = Settings(api_key="test-key-42")
        backend = self._Backend()
        app = FastAPI()
        app.include_router(build_domain_router(settings, backend))
        with TestClient(app) as client:
            listed = client.get("/api/v1/tasks", headers=AUTH)
            assert listed.status_code == 200
            task = listed.json()["tasks"][0]
            assert task["id"] == "hermes-task-1"
            assert task["prompt"] == "Actual board body"
            assert task["status"] == "todo"
            assert task["priority"] == "high"

            updated = client.patch(
                "/api/v1/tasks/hermes-task-1", headers=AUTH,
                json={"prompt": "Edited in mobile", "priority": "urgent", "status": "ready"},
            )
            assert updated.status_code == 200
            assert updated.json()["status"] == "ready"

            ran = client.post("/api/v1/tasks/hermes-task-1/run", headers=AUTH)
            assert ran.status_code == 200
            assert ran.json()["dispatch"] == {"spawned": []}

        assert ("GET", "/api/plugins/kanban/board", {"include_archived": "true"}, None) in backend.calls
        assert any(
            method == "PATCH" and path == "/api/plugins/kanban/tasks/hermes-task-1"
            and body == {"body": "Edited in mobile", "priority": 2, "status": "ready"}
            for method, path, _params, body in backend.calls
        )
        assert any(path == "/api/plugins/kanban/dispatch" for _method, path, _params, _body in backend.calls)


# ===========================================================================
# 12. ARTIFACTS — parameter validation + extraction helpers
# ===========================================================================


class TestArtifacts:
    def test_artifacts_route_exists_not_404(self, client_no_backend: TestClient):
        """Reproduces the reported `GET /artifacts 404` bug. With no backend
        we get 503, but never 404."""
        resp = client_no_backend.get(
            "/api/v1/artifacts",
            headers=AUTH,
            params={"limit": 100, "offset": 0},
        )
        assert resp.status_code != 404
        assert resp.status_code == 503

    def test_artifacts_limit_too_high_422(self, client_no_backend: TestClient):
        resp = client_no_backend.get(
            "/api/v1/artifacts", headers=AUTH, params={"limit": 201}
        )
        assert resp.status_code == 422

    def test_artifacts_limit_zero_422(self, client_no_backend: TestClient):
        resp = client_no_backend.get(
            "/api/v1/artifacts", headers=AUTH, params={"limit": 0}
        )
        assert resp.status_code == 422

    def test_artifacts_offset_negative_422(self, client_no_backend: TestClient):
        resp = client_no_backend.get(
            "/api/v1/artifacts", headers=AUTH, params={"offset": -1}
        )
        assert resp.status_code == 422

    def test_artifacts_limit_boundary_ok(self, client_no_backend: TestClient):
        resp = client_no_backend.get(
            "/api/v1/artifacts", headers=AUTH, params={"limit": 200}
        )
        # 200 is max → validation passes → backend 503
        assert resp.status_code == 503

    def test_artifact_extraction_helpers(self):
        """Pure-function tests for the artifact extraction utilities."""
        from hermes_mobile_server.domain_api import (
            _artifact_kind,
            _artifact_label,
            _collect_artifacts_from_text,
            _extract_message_text,
            _looks_like_artifact,
            _normalize_artifact_value,
            _try_parse_json,
        )

        # Text extraction.
        assert _extract_message_text({"text": "hello"}) == "hello"
        assert _extract_message_text({"content": "hi"}) == "hi"
        assert _extract_message_text({"role": "user"}) == ""

        # Looks like an artifact.
        assert _looks_like_artifact("https://example.com/x.png")
        assert _looks_like_artifact("/tmp/foo.py")
        assert not _looks_like_artifact("just-a-word")

        # MD image — returns list of found artifacts.
        found = _collect_artifacts_from_text("![pic](/a/b.png)")
        assert "/a/b.png" in found

        # MD link.
        found = _collect_artifacts_from_text("[doc](/report.pdf)")
        assert "/report.pdf" in found

        # Bare URL.
        found = _collect_artifacts_from_text("see https://foo.com/z?q=1 for info")
        assert any("https://foo.com" in x for x in found)

        # Bare path with extension.
        found = _collect_artifacts_from_text("output saved to ./data/results.csv now")
        assert any("results.csv" in x for x in found)

        # Kind classification.
        assert _artifact_kind("https://foo.com/a.jpg") == "image"
        assert _artifact_kind("/tmp/x.pdf") == "file"
        assert _artifact_kind("https://blog.example.com/") == "link"
        assert _artifact_kind("/src/app/main.py") == "file"
        assert _artifact_kind("/var/log/app.log") == "file"

        # Persisted tool results may carry literal JSON escape sequences. They
        # must not leak into artifact values or labels.
        assert _normalize_artifact_value(
            r"https://github.com/flutter/flutter.git\nFramework"
        ) == "https://github.com/flutter/flutter.git"
        assert not _looks_like_artifact("http://`/`ws://`")

        # Label sanitiser.
        lbl = _artifact_label("/a/b/c/long-name-here.py")
        assert lbl == "long-name-here.py"

        # JSON try-parse.
        assert _try_parse_json('{"a": 1}') == {"a": 1}
        assert _try_parse_json("not json") is None
        assert _try_parse_json("") is None


# ===========================================================================
# 13. SUBAGENTS / PET
# ===========================================================================


class TestSubagentsPet:
    def test_subagents_session_id_required_422(self, client_no_backend: TestClient):
        resp = client_no_backend.get("/api/v1/subagents", headers=AUTH)
        assert resp.status_code == 422

    def test_subagents_with_session_503(self, client_no_backend: TestClient):
        resp = client_no_backend.get(
            "/api/v1/subagents", headers=AUTH, params={"session_id": "s1"}
        )
        assert resp.status_code == 503

    def test_active_processes_503(self, client_no_backend: TestClient):
        resp = client_no_backend.get("/api/v1/subagents/active", headers=AUTH)
        assert resp.status_code == 503

    def test_interrupt_503_not_404(self, client_no_backend: TestClient):
        resp = client_no_backend.post(
            "/api/v1/subagents/sa-1/interrupt", headers=AUTH
        )
        assert resp.status_code == 503

    def test_pet_routes_all_exist(self, client_no_backend: TestClient):
        routes = [
            ("GET", "/api/v1/pet", None, None),
            ("GET", "/api/v1/pet/gallery", None, None),
            ("GET", "/api/v1/pet/generate/status", None, None),
            ("POST", "/api/v1/pet/select", None, {"slug": "fox"}),
            ("POST", "/api/v1/pet/hatch", None, {}),
            ("POST", "/api/v1/pet/generate", None, {}),
            ("POST", "/api/v1/pet/disable", None, None),
            ("POST", "/api/v1/pet/rename", None, {"name": "Rex"}),
            ("POST", "/api/v1/pet/cancel", None, {"token": "job-1"}),
            ("POST", "/api/v1/pet/remove", None, {"slug": "fox"}),
        ]
        for method, path, params, body in routes:
            fn = getattr(client_no_backend, method.lower())
            kwargs: dict = {"headers": AUTH}
            if params is not None:
                kwargs["params"] = params
            if body is not None:  # explicit None = no body at all
                kwargs["json"] = body
            resp = fn(path, **kwargs)
            assert resp.status_code != 404, f"{method} {path} returned 404"
            # All need backend.
            assert resp.status_code == 503, f"{method} {path} -> {resp.status_code}"


# ===========================================================================
# 14. BILLING / SUBSCRIPTION / CREDENTIALS
# ===========================================================================


class TestBillingSubscriptionCredentials:
    def test_billing_state_503(self, client_no_backend: TestClient):
        assert client_no_backend.get("/api/v1/billing", headers=AUTH).status_code == 503

    def test_billing_charge_needs_body(self, client_no_backend: TestClient):
        resp = client_no_backend.post("/api/v1/billing/charge", headers=AUTH)
        assert resp.status_code == 422

    def test_billing_step_up_exists_and_needs_body(
        self, client_no_backend: TestClient
    ):
        missing = client_no_backend.post("/api/v1/billing/step-up", headers=AUTH)
        response = client_no_backend.post(
            "/api/v1/billing/step-up", headers=AUTH, json={}
        )
        assert missing.status_code == 422
        assert response.status_code == 503

    def test_usage_bars_503(self, client_no_backend: TestClient):
        assert (
            client_no_backend.get("/api/v1/billing/usage-bars", headers=AUTH).status_code
            == 503
        )

    def test_subscription_state_503(self, client_no_backend: TestClient):
        assert (
            client_no_backend.get("/api/v1/subscription", headers=AUTH).status_code
            == 503
        )

    def test_subscription_preview_needs_body(self, client_no_backend: TestClient):
        resp = client_no_backend.post(
            "/api/v1/subscription/preview", headers=AUTH
        )
        assert resp.status_code == 422

    def test_subscription_change_needs_body(self, client_no_backend: TestClient):
        resp = client_no_backend.post(
            "/api/v1/subscription/change", headers=AUTH
        )
        assert resp.status_code == 422

    def test_subscription_upgrade_needs_body(self, client_no_backend: TestClient):
        resp = client_no_backend.post(
            "/api/v1/subscription/upgrade", headers=AUTH
        )
        assert resp.status_code == 422

    def test_credentials_providers_503(self, client_no_backend: TestClient):
        assert (
            client_no_backend.get(
                "/api/v1/credentials/providers", headers=AUTH
            ).status_code
            == 503
        )

    def test_credentials_save_key_needs_body(self, client_no_backend: TestClient):
        resp = client_no_backend.post(
            "/api/v1/credentials/save-key", headers=AUTH
        )
        assert resp.status_code == 422

    def test_credentials_disconnect_needs_body(self, client_no_backend: TestClient):
        resp = client_no_backend.post(
            "/api/v1/credentials/disconnect", headers=AUTH
        )
        assert resp.status_code == 422


# ===========================================================================
# 15. MESSAGING / WEBHOOKS / TERMINAL
# ===========================================================================


class TestMessagingWebhooksTerminal:
    def test_messaging_platforms_503(self, client_no_backend: TestClient):
        assert (
            client_no_backend.get(
                "/api/v1/messaging/platforms", headers=AUTH
            ).status_code
            == 503
        )

    def test_messaging_config_get_503(self, client_no_backend: TestClient):
        resp = client_no_backend.get(
            "/api/v1/messaging/telegram/config", headers=AUTH
        )
        assert resp.status_code == 503

    def test_messaging_env_put_needs_body(self, client_no_backend: TestClient):
        resp = client_no_backend.post(
            "/api/v1/messaging/telegram/env", headers=AUTH
        )
        assert resp.status_code == 422

    def test_webhooks_get_503(self, client_no_backend: TestClient):
        assert (
            client_no_backend.get("/api/v1/webhooks", headers=AUTH).status_code == 503
        )

    def test_webhook_create_needs_body(self, client_no_backend: TestClient):
        resp = client_no_backend.post("/api/v1/webhooks", headers=AUTH)
        assert resp.status_code == 422

    def test_webhook_update_needs_body(self, client_no_backend: TestClient):
        resp = client_no_backend.put(
            "/api/v1/webhooks/w1/enabled", headers=AUTH
        )
        assert resp.status_code == 422

class TestCanonicalMessagingBridge:
    class _Client:
        def __init__(self, backend) -> None:
            self.backend = backend

        async def request(self, method, path, params=None, json=None):
            self.backend.calls.append((method, path, params or {}, json))
            if method == "GET" and path == "/api/messaging/platforms":
                return httpx.Response(
                    200,
                    json={
                        "platforms": [
                            {"id": "telegram", "enabled": True, "state": "connected"}
                        ]
                    },
                )
            if method == "GET" and path == "/api/pairing":
                return httpx.Response(
                    200,
                    json={
                        "pending": [
                            {
                                "platform": "telegram",
                                "request_id": "request-1",
                                "user_id": "user-1",
                            },
                            {"platform": "discord", "request_id": "request-2"},
                        ],
                        "approved": [],
                    },
                )
            return httpx.Response(200, json={"ok": True})

    class _Backend:
        is_running = True

        def __init__(self) -> None:
            self.calls = []
            self.client = TestCanonicalMessagingBridge._Client(self)

        async def http_client(self):
            return self.client

    def test_mobile_routes_use_current_messaging_and_pairing_endpoints(self):
        backend = self._Backend()
        settings = Settings(api_key="test-key-42")
        app = FastAPI()
        app.include_router(build_domain_router(settings, backend))
        with TestClient(app) as client:
            config = client.get(
                "/api/v1/messaging/telegram/config", headers=AUTH
            )
            pending = client.get(
                "/api/v1/messaging/telegram/pending", headers=AUTH
            )
            saved = client.post(
                "/api/v1/messaging/telegram/env",
                headers=AUTH,
                json={"key": "TELEGRAM_BOT_TOKEN", "value": "secret"},
            )
            approved = client.post(
                "/api/v1/messaging/telegram/pair/request-1/approve", headers=AUTH
            )

        assert config.status_code == 200
        assert config.json()["id"] == "telegram"
        assert pending.status_code == 200
        assert [row["request_id"] for row in pending.json()["pending"]] == ["request-1"]
        assert saved.status_code == 200
        assert approved.status_code == 200
        assert (
            "PUT",
            "/api/messaging/platforms/telegram",
            {},
            {"env": {"TELEGRAM_BOT_TOKEN": "secret"}},
        ) in backend.calls
        assert (
            "POST",
            "/api/pairing/approve",
            {},
            {"platform": "telegram", "request_id": "request-1"},
        ) in backend.calls

    def test_canonical_messaging_routes_preserve_profile_and_body(self):
        backend = self._Backend()
        app = FastAPI()
        app.include_router(
            build_domain_router(Settings(api_key="test-key-42"), backend)
        )
        with TestClient(app) as client:
            platforms = client.get(
                "/api/v1/messaging/platforms?profile=work", headers=AUTH
            )
            updated = client.put(
                "/api/v1/messaging/platforms/telegram?profile=work",
                headers=AUTH,
                json={"enabled": True, "clear_env": ["TELEGRAM_BOT_TOKEN"]},
            )
            tested = client.post(
                "/api/v1/messaging/platforms/telegram/test?profile=work",
                headers=AUTH,
            )
            pairing = client.get(
                "/api/v1/pairing?profile=work", headers=AUTH
            )
            revoked = client.post(
                "/api/v1/pairing/revoke",
                headers=AUTH,
                json={"platform": "telegram", "user_id": "u1", "profile": "work"},
            )
            restarted = client.post("/api/v1/gateway/restart", headers=AUTH)

        assert all(
            response.status_code == 200
            for response in (platforms, updated, tested, pairing, revoked, restarted)
        )
        assert (
            "PUT",
            "/api/messaging/platforms/telegram",
            {"profile": "work"},
            {"enabled": True, "clear_env": ["TELEGRAM_BOT_TOKEN"]},
        ) in backend.calls
        assert (
            "POST",
            "/api/messaging/platforms/telegram/test",
            {"profile": "work"},
            None,
        ) in backend.calls
        assert (
            "POST",
            "/api/pairing/revoke",
            {},
            {"platform": "telegram", "user_id": "u1", "profile": "work"},
        ) in backend.calls
        assert ("POST", "/api/gateway/restart", {}, None) in backend.calls


class TestCanonicalWebhookBridge:
    class _Client:
        def __init__(self, backend) -> None:
            self.backend = backend

        async def request(self, method, path, params=None, json=None):
            self.backend.calls.append((method, path, params or {}, json))
            if method == "GET" and path == "/api/webhooks":
                return httpx.Response(
                    200,
                    json={
                        "enabled": True,
                        "base_url": "http://localhost:8642",
                        "subscriptions": [
                            {
                                "name": "build-done",
                                "url": "http://localhost:8642/webhooks/build-done",
                                "events": ["build.done"],
                                "enabled": True,
                            }
                        ],
                    },
                )
            return httpx.Response(200, json={"ok": True})

    class _Backend:
        is_running = True

        def __init__(self) -> None:
            self.calls = []
            self.client = TestCanonicalWebhookBridge._Client(self)

        async def http_client(self):
            return self.client

    def test_list_enable_and_toggle_use_current_webhook_routes(self):
        backend = self._Backend()
        app = FastAPI()
        app.include_router(
            build_domain_router(Settings(api_key="test-key-42"), backend)
        )
        with TestClient(app) as client:
            listed = client.get("/api/v1/webhooks", headers=AUTH)
            enabled = client.post("/api/v1/webhooks/enable", headers=AUTH)
            toggled = client.put(
                "/api/v1/webhooks/build-done/enabled",
                headers=AUTH,
                json={"enabled": False},
            )

        assert listed.status_code == 200
        assert listed.json()["webhooks"][0]["name"] == "build-done"
        assert enabled.status_code == 200
        assert toggled.status_code == 200
        assert ("POST", "/api/webhooks/enable", {}, None) in backend.calls
        assert (
            "PUT",
            "/api/webhooks/build-done/enabled",
            {},
            {"enabled": False},
        ) in backend.calls


# ===========================================================================
# 16. ROUTE EXISTENCE — catch-all that enumerates what api_client.dart calls
# ===========================================================================


class TestAllMobileClientRoutes:
    """Every REST call the Dart ApiClient makes must resolve to a route.

    Entries are (METHOD, PATH, PARAMS_DICT_OR_NONE, BODY_DICT_OR_NONE).
    We accept 200/422/503 but never 404 for well-formed requests."""

    # (method, path, query_params, json_body) — use None for absent.
    DART_CALLS = [
        # management
        ("GET", "/api/v1/status", None, None),
        ("POST", "/api/v1/backend/restart", None, None),
        # audio
        ("POST", "/api/v1/audio/speak", None, {"text": "hi"}),
        ("POST", "/api/v1/audio/transcribe", None, {"data_url": "x", "mime_type": "wav"}),
        # sessions
        ("GET", "/api/v1/sessions", {"limit": "10"}, None),
        ("GET", "/api/v1/sessions/s1/messages", None, None),
        ("GET", "/api/v1/sessions/s1", None, None),
        ("POST", "/api/v1/sessions/s1/open", None, None),
        ("DELETE", "/api/v1/sessions/s1", None, None),
        ("PATCH", "/api/v1/sessions/s1", None, {"title": "t"}),
        # model
        ("GET", "/api/v1/model", None, None),
        ("GET", "/api/v1/model/recommended-default", {"provider": "p"}, None),
        ("GET", "/api/v1/model/auxiliary", None, None),
        ("GET", "/api/v1/model/moa", None, None),
        ("PUT", "/api/v1/model/moa", None, {}),
        (
            "POST",
            "/api/v1/model/set",
            None,
            {"scope": "auxiliary", "task": "vision", "provider": "auto", "model": ""},
        ),
        ("POST", "/api/v1/model/switch", None, {"provider": "p", "model": "m"}),
        # skills / tools
        ("GET", "/api/v1/skills", None, None),
        ("PUT", "/api/v1/skills/foo/enabled", None, {"enabled": True}),
        ("GET", "/api/v1/skills/content", {"name": "foo"}, None),
        ("GET", "/api/v1/skills/hub/sources", None, None),
        ("GET", "/api/v1/skills/hub/search", {"q": "foo"}, None),
        ("GET", "/api/v1/skills/hub/preview", {"identifier": "foo"}, None),
        ("GET", "/api/v1/skills/hub/scan", {"identifier": "foo"}, None),
        ("POST", "/api/v1/skills/hub/install", None, {"identifier": "foo"}),
        ("POST", "/api/v1/skills/hub/uninstall", None, {"name": "foo"}),
        ("POST", "/api/v1/skills/hub/update", None, {}),
        ("GET", "/api/v1/tools", None, None),
        ("GET", "/api/v1/tools/terminal/backends", None, None),
        ("PUT", "/api/v1/tools/terminal/backend", None, {"backend": "docker"}),
        ("GET", "/api/v1/tools/computer-use/status", None, None),
        ("POST", "/api/v1/tools/computer-use/permissions/grant", None, {}),
        ("PUT", "/api/v1/tools/foo/enabled", None, {"enabled": True}),
        # cron
        ("GET", "/api/v1/cron", None, None),
        ("POST", "/api/v1/cron/j1/resume", None, None),
        ("POST", "/api/v1/cron/j1/pause", None, None),
        ("POST", "/api/v1/cron/j1/trigger", None, None),
        ("POST", "/api/v1/cron", None, {"prompt": "x", "schedule": "*"}),
        ("PUT", "/api/v1/cron/j1", None, {"name": "n"}),
        ("DELETE", "/api/v1/cron/j1", None, None),
        ("GET", "/api/v1/cron/j1/runs", {"limit": "5"}, None),
        ("GET", "/api/v1/cron/delivery-targets", None, None),
        ("GET", "/api/v1/cron/blueprints", None, None),
        (
            "POST",
            "/api/v1/cron/blueprints/instantiate",
            None,
            {"blueprint": "daily-summary", "values": {}},
        ),
        # memory
        ("GET", "/api/v1/memory", None, None),
        ("PUT", "/api/v1/memory/provider", None, {"provider": "x"}),
        ("POST", "/api/v1/memory/reset", None, {}),
        # knowledge
        ("GET", "/api/v1/knowledge/graph", None, None),
        ("GET", "/api/v1/knowledge/node", {"id": "n1"}, None),
        ("PUT", "/api/v1/knowledge/node", None, {"id": "n1", "content": "c"}),
        ("DELETE", "/api/v1/knowledge/node", {"id": "n1"}, None),
        # config / analytics (read by the MCP edit-in-place + cost overlay)
        ("GET", "/api/v1/config", None, None),
        ("GET", "/api/v1/analytics/usage", {"days": "30"}, None),
        # mcp
        ("GET", "/api/v1/mcp/servers", None, None),
        (
            "POST",
            "/api/v1/mcp/servers",
            None,
            {"name": "s1", "url": "https://mcp.example"},
        ),
        (
            "PUT",
            "/api/v1/mcp/servers",
            None,
            {"servers": {"s1": {"url": "https://mcp.example"}}},
        ),
        ("DELETE", "/api/v1/mcp/servers/s1", None, None),
        ("PUT", "/api/v1/mcp/servers/s1/enabled", None, {"enabled": True}),
        ("GET", "/api/v1/mcp/servers/s1/test", None, None),
        ("POST", "/api/v1/mcp/servers/s1/auth", None, None),
        ("GET", "/api/v1/mcp/oauth/flows/f1", None, None),
        ("GET", "/api/v1/mcp/catalog", None, None),
        (
            "POST",
            "/api/v1/mcp/catalog/install",
            None,
            {"name": "github", "env": {}, "enable": True},
        ),
        ("GET", "/api/v1/actions/mcp-install-github/status", {"lines": "50"}, None),
        # plugins
        ("GET", "/api/v1/plugins", None, None),
        ("PUT", "/api/v1/plugins/p1/enabled", None, {"enabled": True}),
        # files
        ("GET", "/api/v1/files", {"path": "/"}, None),
        ("GET", "/api/v1/files/read", {"path": "/x"}, None),
        ("POST", "/api/v1/files/write", None, {"path": "/x", "content": ""}),
        ("GET", "/api/v1/files/default-cwd", None, None),
        ("GET", "/api/v1/files/read-data-url", {"path": "/x"}, None),
        ("GET", "/api/v1/files/download", {"path": "/x"}, None),
        ("POST", "/api/v1/files/upload", None, {"path": "/x", "data_url": ""}),
        ("POST", "/api/v1/files/move", None, {"path": "/a", "dest": "/b"}),
        ("POST", "/api/v1/files/mkdir", None, {"path": "/d"}),
        ("POST", "/api/v1/files/delete", None, {"path": "/x"}),
        # git
        ("GET", "/api/v1/git/status", {"path": "/p"}, None),
        ("GET", "/api/v1/git/branches", {"path": "/p"}, None),
        ("GET", "/api/v1/git/base-branches", {"path": "/p"}, None),
        ("GET", "/api/v1/git/worktrees", {"path": "/p"}, None),
        ("POST", "/api/v1/git/worktree/add", None, {"path": "/p", "name": "n"}),
        (
            "POST",
            "/api/v1/git/worktree/remove",
            None,
            {"path": "/p", "worktreePath": "/p/.worktrees/n"},
        ),
        ("GET", "/api/v1/git/review/list", {"path": "/p"}, None),
        ("GET", "/api/v1/git/file-diff", {"path": "/p", "file": "f"}, None),
        ("POST", "/api/v1/git/review/stage", None, {"path": "/p", "file": "f"}),
        ("POST", "/api/v1/git/review/unstage", None, {"path": "/p", "file": "f"}),
        ("POST", "/api/v1/git/review/commit", None, {"path": "/p", "message": "m"}),
        ("POST", "/api/v1/git/review/revert", None, {"path": "/p", "file": "f"}),
        # "revert all" — mobile omits `file` entirely, matching the backend's
        # Optional[str] = None ("revert everything") contract.
        ("POST", "/api/v1/git/review/revert", None, {"path": "/p"}),
        ("POST", "/api/v1/git/branch/switch", None, {"path": "/p", "branch": "b"}),
        # tasks
        ("GET", "/api/v1/tasks", None, None),
        ("POST", "/api/v1/tasks", None, {"title": "t"}),
        ("GET", "/api/v1/tasks/t1", None, None),
        ("PATCH", "/api/v1/tasks/t1", None, {"status": "done"}),
        ("DELETE", "/api/v1/tasks/t1", None, None),
        ("POST", "/api/v1/tasks/t1/run", None, None),
        # artifacts / starmap
        ("GET", "/api/v1/artifacts", {"limit": "50", "offset": "0"}, None),
        ("GET", "/api/v1/starmap/graph", None, None),
        ("GET", "/api/v1/starmap/node", {"id": "n1"}, None),
        # subagents
        ("GET", "/api/v1/subagents", {"session_id": "s1"}, None),
        ("GET", "/api/v1/subagents/active", None, None),
        ("POST", "/api/v1/subagents/sa1/interrupt", None, None),
        # pet
        ("GET", "/api/v1/pet", None, None),
        ("GET", "/api/v1/pet/gallery", None, None),
        ("POST", "/api/v1/pet/select", None, {"slug": "x"}),
        ("POST", "/api/v1/pet/hatch", None, {}),
        ("POST", "/api/v1/pet/generate", None, {}),
        ("GET", "/api/v1/pet/generate/status", None, None),
        ("POST", "/api/v1/pet/disable", None, None),
        ("POST", "/api/v1/pet/rename", None, {"name": "n"}),
        ("POST", "/api/v1/pet/cancel", None, {"token": "job-1"}),
        ("POST", "/api/v1/pet/remove", None, {"slug": "x"}),
        # billing
        ("GET", "/api/v1/billing", None, None),
        ("POST", "/api/v1/billing/charge", None, {"amount": 1}),
        ("POST", "/api/v1/billing/step-up", None, {}),
        ("GET", "/api/v1/billing/usage-bars", None, None),
        ("GET", "/api/v1/subscription", None, None),
        # credentials
        ("GET", "/api/v1/credentials/providers", None, None),
        ("POST", "/api/v1/credentials/save-key", None, {"slug": "s", "key": "k"}),
        ("POST", "/api/v1/credentials/disconnect", None, {"slug": "s"}),
        # messaging
        ("GET", "/api/v1/messaging/platforms", None, None),
        ("GET", "/api/v1/messaging/telegram/config", None, None),
        ("POST", "/api/v1/messaging/telegram/env", None, {}),
        ("GET", "/api/v1/messaging/telegram/pending", None, None),
        ("POST", "/api/v1/messaging/telegram/pair/p1/approve", None, None),
        # webhooks
        ("GET", "/api/v1/webhooks", None, None),
        ("POST", "/api/v1/webhooks", None, {"name": "n", "url": "u", "events": []}),
        ("POST", "/api/v1/webhooks/enable", None, None),
        ("PUT", "/api/v1/webhooks/w1/enabled", None, {"enabled": True}),
        ("DELETE", "/api/v1/webhooks/w1", None, None),
        # git extended
        ("POST", "/api/v1/git/commit-message", None, {"path": "/p"}),
        ("POST", "/api/v1/git/pr/create", None, {"path": "/p"}),
        # terminal
        # ops (Command Center's Maintenance tab)
        ("POST", "/api/v1/ops/doctor", None, None),
        ("POST", "/api/v1/ops/security-audit", None, None),
        ("POST", "/api/v1/ops/backup", None, None),
        ("POST", "/api/v1/ops/debug-share", None, None),
    ]

    def test_no_route_returns_404(self, client_no_backend: TestClient):
        # Pre-create a real task so /tasks/{task_id} sub-routes resolve the
        # resource (not just route) — otherwise they legitimately 404 from
        # the in-process TaskStore, not from a missing FastAPI route.
        created = client_no_backend.post(
            "/api/v1/tasks", headers=AUTH, json={"title": "route-exists-probe"}
        ).json()
        tid = created["id"]

        failures: list[str] = []
        for method, path, params, body in self.DART_CALLS:
            # /tasks/{id}/run is already exhaustively tested in TestTasks.
            # In-process asyncio + TestClient can introduce flaky 404 here
            # because task_store writes are async; skip it for route-existence.
            if path.startswith("/api/v1/tasks/t1/run"):
                continue
            # Replace placeholder task id with real one for task sub-routes.
            if path.startswith("/api/v1/tasks/t1"):
                path = path.replace("/tasks/t1", f"/tasks/{tid}")
            fn = getattr(client_no_backend, method.lower())
            kwargs: dict = {"headers": AUTH}
            if params is not None:
                kwargs["params"] = params
            if body is not None:
                kwargs["json"] = body
            resp = fn(path, **kwargs)
            if resp.status_code == 404:
                failures.append(f"{method} {path}")
        assert not failures, f"These API routes are MISSING (404):\n" + "\n".join(
            failures
        )
