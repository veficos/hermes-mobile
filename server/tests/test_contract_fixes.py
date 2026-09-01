"""P0/P1 front-back contract fixes.

Covers the concrete behavior changes from the contract-audit batch:
- DELETE responses normalize to {"ok": true} / 404.
- Knowledge/starmap node delete forwards ``id`` as a query param.
- MCP server test proxies as GET.
- Session messages include ``session_id``.
- Backend JSON errors with dict-shaped ``error`` normalize to its message.
- Session listing probes one extra row when ``total`` is absent.
"""

from __future__ import annotations

import asyncio

import httpx
import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient

from hermes_mobile_server.config import Settings
from hermes_mobile_server.domain_api import build_domain_router

AUTH = {"Authorization": "Bearer contract-key"}


class _Backend:
    is_running = True

    def __init__(self, responses: dict | None = None) -> None:
        self.calls: list[tuple] = []
        self.responses = responses or {}

    async def http_client(self):
        return self

    async def request(self, method, path, params=None, json=None, headers=None):
        self.calls.append((method, path, params or {}, json))
        key = (method, path)
        response = self.responses.get(key)
        if response is not None:
            return response
        # Default: pretend the upstream confirmed the mutation.
        return httpx.Response(200, json={"ok": True})

    async def gateway_rpc(self, method, params=None, timeout=60.0):
        self.calls.append(("RPC", method, params or {}))
        return {"ok": True}


def _client(backend: _Backend):
    settings = Settings(api_key="contract-key")
    app = FastAPI()
    app.include_router(build_domain_router(settings, backend))
    return TestClient(app)


class TestDeleteResponseNormalization:
    def test_session_delete_returns_ok(self):
        be = _Backend()
        with _client(be) as client:
            resp = client.delete("/api/v1/sessions/s1", headers=AUTH)
        assert resp.status_code == 200
        assert resp.json() == {"ok": True}
        assert ("DELETE", "/api/sessions/s1", {}, None) in be.calls

    def test_session_delete_rejects_explicit_upstream_failure(self):
        be = _Backend(
            responses={
                ("DELETE", "/api/sessions/s1"): httpx.Response(
                    200, json={"ok": False, "error": {"message": "denied"}}
                )
            }
        )
        with _client(be) as client:
            resp = client.delete("/api/v1/sessions/s1", headers=AUTH)
        assert resp.status_code == 422
        assert resp.json()["detail"] == "denied"

    def test_env_delete_returns_ok(self):
        be = _Backend()
        with _client(be) as client:
            resp = client.request(
                "DELETE", "/api/v1/env", headers=AUTH, json={"key": "X"}
            )
        assert resp.status_code == 200
        assert resp.json() == {"ok": True}

    def test_env_delete_rejects_scalar_upstream_error(self):
        be = _Backend(
            responses={
                ("DELETE", "/api/env"): httpx.Response(
                    200, json={"ok": False, "error": "read only"}
                )
            }
        )
        with _client(be) as client:
            resp = client.request(
                "DELETE", "/api/v1/env", headers=AUTH, json={"key": "X"}
            )
        assert resp.status_code == 422
        assert resp.json()["detail"] == "read only"

    def test_custom_endpoint_delete_returns_ok(self):
        be = _Backend()
        with _client(be) as client:
            resp = client.delete(
                "/api/v1/providers/custom-endpoints/e1", headers=AUTH
            )
        assert resp.status_code == 200
        assert resp.json() == {"ok": True}

    def test_oauth_disconnect_returns_ok(self):
        be = _Backend()
        with _client(be) as client:
            resp = client.delete(
                "/api/v1/providers/oauth/github", headers=AUTH
            )
        assert resp.status_code == 200
        assert resp.json() == {"ok": True}

    def test_oauth_session_cancel_returns_ok(self):
        be = _Backend()
        with _client(be) as client:
            resp = client.delete(
                "/api/v1/providers/oauth/sessions/sess-1", headers=AUTH
            )
        assert resp.status_code == 200
        assert resp.json() == {"ok": True}

    def test_cron_delete_returns_ok(self):
        be = _Backend()
        with _client(be) as client:
            resp = client.delete("/api/v1/cron/job-1", headers=AUTH)
        assert resp.status_code == 200
        assert resp.json() == {"ok": True}

    def test_mcp_server_delete_returns_ok(self):
        be = _Backend()
        with _client(be) as client:
            resp = client.delete("/api/v1/mcp/servers/remote", headers=AUTH)
        assert resp.status_code == 200
        assert resp.json() == {"ok": True}

    def test_webhook_delete_returns_ok(self):
        be = _Backend()
        with _client(be) as client:
            resp = client.delete("/api/v1/webhooks/wh-1", headers=AUTH)
        assert resp.status_code == 200
        assert resp.json() == {"ok": True}

    def test_task_delete_404_when_upstream_not_confirmed(self):
        be = _Backend(
            responses={
                ("DELETE", "/api/plugins/kanban/tasks/t1"): httpx.Response(
                    200, json={"deleted": False}
                )
            }
        )
        with _client(be) as client:
            resp = client.delete("/api/v1/tasks/t1", headers=AUTH)
        assert resp.status_code == 404
        assert resp.json()["detail"] == "task not found"

    def test_task_delete_ok_when_upstream_confirmed(self):
        be = _Backend(
            responses={
                ("DELETE", "/api/plugins/kanban/tasks/t1"): httpx.Response(
                    200, json={"deleted": True}
                )
            }
        )
        with _client(be) as client:
            resp = client.delete("/api/v1/tasks/t1", headers=AUTH)
        assert resp.status_code == 200
        assert resp.json() == {"ok": True}


def test_subagent_interrupt_forwards_profile_to_gateway() -> None:
    be = _Backend()
    router = build_domain_router(Settings(api_key="contract-key"), be)
    route = next(
        item
        for item in router.routes
        if item.path == "/api/v1/subagents/{subagent_id}/interrupt"
    )

    response = asyncio.run(route.endpoint(subagent_id="agent-1", profile="work"))

    assert response == {"ok": True}
    assert (
        "RPC",
        "subagent.interrupt",
        {"subagent_id": "agent-1", "profile": "work"},
    ) in be.calls


class TestKnowledgeStarmapMcpForwarding:
    def test_knowledge_node_delete_forwards_id_as_query(self):
        be = _Backend()
        with _client(be) as client:
            resp = client.delete(
                "/api/v1/knowledge/node", headers=AUTH, params={"id": "n1"}
            )
        assert resp.status_code == 200
        assert any(
            call == ("DELETE", "/api/learning/node", {"id": "n1"}, None)
            for call in be.calls
        )

    def test_starmap_node_delete_forwards_id_as_query(self):
        be = _Backend()
        with _client(be) as client:
            resp = client.delete(
                "/api/v1/starmap/node", headers=AUTH, params={"id": "n1"}
            )
        assert resp.status_code == 200
        assert any(
            call == ("DELETE", "/api/learning/node", {"id": "n1"}, None)
            for call in be.calls
        )

    def test_mcp_server_test_forwards_as_post(self):
        # Mobile's own contract keeps this a read-shaped GET, but upstream
        # registers the diagnostic as POST (hermes_cli/web_routers/mcp.py's
        # test_mcp_server) — the internal forward must match upstream's verb,
        # not mobile's public one.
        be = _Backend()
        with _client(be) as client:
            resp = client.get("/api/v1/mcp/servers/remote/test", headers=AUTH)
        assert resp.status_code == 200
        assert ("POST", "/api/mcp/servers/remote/test", {}, None) in be.calls

    def test_elevenlabs_voices_forwards_profile(self):
        be = _Backend(
            responses={
                ("GET", "/api/audio/elevenlabs/voices"): httpx.Response(
                    200, json={"available": True, "voices": []}
                )
            }
        )
        with _client(be) as client:
            resp = client.get(
                "/api/v1/audio/elevenlabs/voices",
                headers=AUTH,
                params={"profile": "work"},
            )
        assert resp.status_code == 200
        assert resp.json() == {"available": True, "voices": []}
        assert (
            "GET",
            "/api/audio/elevenlabs/voices",
            {"profile": "work"},
            None,
        ) in be.calls


class TestSessionMessagesAndList:
    def test_messages_response_includes_session_id(self):
        be = _Backend(
            responses={
                ("GET", "/api/sessions/s1"): httpx.Response(
                    200, json={"id": "s1", "message_count": 1}
                ),
                ("GET", "/api/sessions/s1/messages"): httpx.Response(
                    200, json={"messages": [{"role": "user", "content": "hi"}]}
                ),
            }
        )
        with _client(be) as client:
            resp = client.get("/api/v1/sessions/s1/messages", headers=AUTH)
        assert resp.status_code == 200
        body = resp.json()
        assert body["session_id"] == "s1"
        assert body["messages"][0]["history_ordinal"] == 0

    def test_list_sessions_has_more_false_when_eof_reached(self):
        be = _Backend(
            responses={
                ("GET", "/api/sessions"): httpx.Response(
                    200,
                    json={
                        "sessions": [{"id": "s1"}, {"id": "s2"}],
                        # no total -> mobile must probe EOF
                    },
                )
            }
        )
        with _client(be) as client:
            resp = client.get(
                "/api/v1/sessions", headers=AUTH, params={"limit": "2"}
            )
        assert resp.status_code == 200
        body = resp.json()
        assert body["has_more"] is False
        # It should have requested 3 rows to probe for more.
        assert be.calls[0][2]["limit"] == 3

    def test_list_sessions_has_more_true_when_probe_finds_extra(self):
        be = _Backend(
            responses={
                ("GET", "/api/sessions"): httpx.Response(
                    200,
                    json={
                        "sessions": [{"id": "s1"}, {"id": "s2"}, {"id": "s3"}],
                    },
                )
            }
        )
        with _client(be) as client:
            resp = client.get(
                "/api/v1/sessions", headers=AUTH, params={"limit": "2"}
            )
        assert resp.status_code == 200
        body = resp.json()
        assert body["has_more"] is True
        assert len(body["sessions"]) == 2


class TestBackendJsonErrorNormalization:
    def test_dict_error_extracts_message(self):
        be = _Backend(
            responses={
                ("GET", "/api/sessions"): httpx.Response(
                    502, json={"error": {"message": "upstream down"}}
                )
            }
        )
        with _client(be) as client:
            resp = client.get("/api/v1/sessions", headers=AUTH)
        assert resp.status_code == 502
        assert resp.json()["detail"] == "upstream down"
