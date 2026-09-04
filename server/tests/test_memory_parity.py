"""Desktop-parity contracts for memory provider setup and Curator controls."""

from __future__ import annotations

import httpx
from fastapi import FastAPI
from fastapi.testclient import TestClient

from hermes_mobile_server.config import Settings
from hermes_mobile_server.domain_api import build_domain_router

AUTH = {"Authorization": "Bearer test-key-42"}


class _Client:
    def __init__(self, backend) -> None:
        self.backend = backend

    async def request(self, method, path, params=None, json=None, headers=None):
        call = (method, path, params or {}, json)
        self.backend.calls.append(call)
        return httpx.Response(200, json={"ok": True, "call": list(call[:2])})


class _Backend:
    is_running = True

    def __init__(self) -> None:
        self.calls: list[tuple] = []
        self.client = _Client(self)

    async def http_client(self):
        return self.client


def _client(backend: _Backend) -> TestClient:
    app = FastAPI()
    app.include_router(
        build_domain_router(Settings(api_key="test-key-42"), backend)
    )
    return TestClient(app)


def test_memory_provider_and_curator_routes_proxy_canonical_contracts():
    backend = _Backend()
    client = _client(backend)

    with client:
        assert client.get(
            "/api/v1/memory", params={"profile": "work"}, headers=AUTH
        ).status_code == 200
        assert client.put(
            "/api/v1/memory/provider",
            params={"profile": "work"},
            json={"provider": "honcho"},
            headers=AUTH,
        ).status_code == 200
        assert client.post(
            "/api/v1/memory/providers/honcho/setup",
            params={"profile": "work"},
            json={"values": {}},
            headers=AUTH,
        ).status_code == 200
        assert client.post(
            "/api/v1/memory/reset",
            params={"profile": "work"},
            json={"target": "user"},
            headers=AUTH,
        ).status_code == 200
        assert client.get(
            "/api/v1/memory/providers/honcho/config",
            params={"profile": "work"},
            headers=AUTH,
        ).status_code == 200
        assert client.put(
            "/api/v1/memory/providers/honcho/config",
            params={"profile": "work"},
            json={"values": {"apiKey": "secret"}},
            headers=AUTH,
        ).status_code == 200
        assert client.post(
            "/api/v1/memory/providers/honcho/oauth/start",
            params={"profile": "work"},
            headers=AUTH,
        ).status_code == 200
        assert client.get(
            "/api/v1/memory/providers/honcho/oauth/status",
            params={"profile": "work"},
            headers=AUTH,
        ).status_code == 200
        assert client.get("/api/v1/curator", headers=AUTH).status_code == 200
        assert client.put(
            "/api/v1/curator/paused",
            json={"paused": True},
            headers=AUTH,
        ).status_code == 200
        assert client.post("/api/v1/curator/run", headers=AUTH).status_code == 200

    assert backend.calls == [
        ("GET", "/api/memory", {"profile": "work"}, None),
        (
            "PUT",
            "/api/memory/provider",
            {"profile": "work"},
            {"provider": "honcho"},
        ),
        (
            "POST",
            "/api/memory/providers/honcho/setup",
            {"profile": "work"},
            {"values": {}},
        ),
        (
            "POST",
            "/api/memory/reset",
            {"profile": "work"},
            {"target": "user"},
        ),
        (
            "GET",
            "/api/memory/providers/honcho/config",
            {"profile": "work"},
            None,
        ),
        (
            "GET",
            "/api/memory/providers/honcho/config",
            {"surface": "declared", "profile": "work"},
            None,
        ),
        (
            "PUT",
            "/api/memory/providers/honcho/config",
            {"profile": "work"},
            {"values": {"apiKey": "secret"}},
        ),
        (
            "POST",
            "/api/memory/providers/honcho/oauth/start",
            {"profile": "work"},
            None,
        ),
        (
            "GET",
            "/api/memory/providers/honcho/oauth/status",
            {"profile": "work"},
            None,
        ),
        ("GET", "/api/curator", {}, None),
        ("PUT", "/api/curator/paused", {}, {"paused": True}),
        ("POST", "/api/curator/run", {}, None),
    ]


def test_memory_parity_routes_require_mobile_auth():
    client = _client(_Backend())

    with client:
        assert client.get("/api/v1/curator").status_code == 401
        assert (
            client.get("/api/v1/memory/providers/honcho/config").status_code
            == 401
        )
