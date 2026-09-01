"""Tests for the /api/v1/profiles resolution chain.

The mobile server serves profiles from the first real source available:
upstream ``/api/profiles`` → ``/api/config`` profiles field → the durable
local ``profiles.json`` fallback.  Every mode must keep list/save/activate/
delete functional; the local mode must persist across store instances.
"""

from __future__ import annotations

import json

import httpx
import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient

from hermes_mobile_server.config import Settings
from hermes_mobile_server.domain_api import build_domain_router
from hermes_mobile_server.profiles import ProfileStore

AUTH = {"Authorization": "Bearer test-key-42"}


class _Client:
    """Minimal stand-in for the backend's httpx.AsyncClient."""

    def __init__(self, backend) -> None:
        self.backend = backend

    async def request(self, method, path, params=None, json=None, headers=None):
        self.backend.calls.append((method, path, params or {}, json))
        return self.backend.handler(method, path, params or {}, json)


class _Backend:
    is_running = True

    def __init__(self, handler) -> None:
        self.calls: list[tuple] = []
        self.handler = handler
        self.client = _Client(self)

    async def http_client(self):
        return self.client


def _app(backend, profile_store) -> TestClient:
    settings = Settings(api_key="test-key-42")
    app = FastAPI()
    app.include_router(
        build_domain_router(settings, backend, profile_store=profile_store)
    )
    return TestClient(app)


# ---------------------------------------------------------------------------
# Upstream /api/profiles proxy mode
# ---------------------------------------------------------------------------


class TestUpstreamProfiles:
    """When Hermes exposes /api/profiles, the mobile server proxies it."""

    def _backend(self) -> _Backend:
        def handler(method, path, params, body):
            if method == "GET" and path == "/api/profiles":
                return httpx.Response(
                    200,
                    json={
                        "profiles": [
                            {"name": "default", "model": "gpt-5"},
                            {"name": "research", "model": "claude"},
                        ],
                        "active": "default",
                    },
                )
            if method == "POST" and path == "/api/profiles":
                return httpx.Response(200, json={"ok": True, "profile": body})
            if method == "PUT" and path == "/api/profiles/research":
                return httpx.Response(200, json={"ok": True, "profile": body})
            if method == "POST" and path == "/api/profiles/active":
                return httpx.Response(200, json={"ok": True, "active": body.get("name")})
            if method == "DELETE" and path == "/api/profiles/research":
                return httpx.Response(200, json={"ok": True})
            return httpx.Response(404, json={"detail": "not found"})

        return _Backend(handler)

    def test_list_proxies_upstream(self, tmp_path):
        backend = self._backend()
        client = _app(backend, ProfileStore(tmp_path / "profiles.json"))
        with client:
            resp = client.get("/api/v1/profiles", headers=AUTH)
        assert resp.status_code == 200
        body = resp.json()
        assert body["source"] == "upstream"
        assert [p["name"] for p in body["profiles"]] == ["default", "research"]
        assert body["active"] == "default"
        assert body["current"] is None

    def test_list_uses_sticky_active_and_reports_current_runtime_profile(self, tmp_path):
        def handler(method, path, params, body):
            if (method, path) == ("GET", "/api/profiles"):
                return httpx.Response(
                    200,
                    json={"profiles": [{"name": "default"}, {"name": "experts"}]},
                )
            if (method, path) == ("GET", "/api/profiles/active"):
                return httpx.Response(
                    200, json={"active": "experts", "current": "default"}
                )
            return httpx.Response(404, json={"detail": "not found"})

        backend = _Backend(handler)
        client = _app(backend, ProfileStore(tmp_path / "profiles.json"))
        with client:
            body = client.get("/api/v1/profiles", headers=AUTH).json()

        assert body["active"] == "experts"
        assert body["current"] == "default"
        assert ("GET", "/api/profiles/active", {}, None) in backend.calls

    def test_config_forwards_profile_on_get_and_put(self, tmp_path):
        def handler(method, path, params, body):
            if path == "/api/config":
                if method == "GET":
                    return httpx.Response(200, json={"model": params.get("profile")})
                return httpx.Response(200, json={"ok": True})
            return httpx.Response(404, json={"detail": "not found"})

        backend = _Backend(handler)
        client = _app(backend, ProfileStore(tmp_path / "profiles.json"))
        with client:
            fetched = client.get("/api/v1/config?profile=experts", headers=AUTH)
            saved = client.put(
                "/api/v1/config?profile=experts",
                headers=AUTH,
                json={"config": {"reasoning": {"effort": "high"}}},
            )

        assert fetched.json() == {"config": {"model": "experts"}}
        assert saved.status_code == 200
        assert (
            "PUT",
            "/api/config",
            {"profile": "experts"},
            {"config": {"reasoning": {"effort": "high"}}},
        ) in backend.calls

    @pytest.mark.parametrize(
        ("payload", "expected"),
        [
            (
                {"profiles": [{"name": "default"}, {"name": "research"}],
                 "active_profile": "research"},
                "research",
            ),
            (
                {"profiles": [{"name": "default"}, {"name": "research"}],
                 "active": {"name": "research"}},
                "research",
            ),
            (
                {"data": {"profiles": [{"id": "default"}, {"id": "research"}],
                          "active_profile": {"id": "research"}}},
                "research",
            ),
        ],
    )
    def test_list_normalizes_real_active_shapes(self, tmp_path, payload, expected):
        backend = _Backend(
            lambda method, path, params, body: httpx.Response(200, json=payload)
            if (method, path) == ("GET", "/api/profiles")
            else httpx.Response(404, json={"detail": "not found"})
        )
        client = _app(backend, ProfileStore(tmp_path / "profiles.json"))
        with client:
            body = client.get("/api/v1/profiles", headers=AUTH).json()
        assert body["active"] == expected
        assert [profile["name"] for profile in body["profiles"]] == [
            "default", "research"
        ]

    def test_save_activate_delete_proxy_upstream(self, tmp_path):
        backend = self._backend()
        client = _app(backend, ProfileStore(tmp_path / "profiles.json"))
        with client:
            created = client.post(
                "/api/v1/profiles", headers=AUTH, json={"name": "writing"}
            )
            assert created.status_code == 200
            updated = client.put(
                "/api/v1/profiles/research", headers=AUTH, json={"model": "gpt-5"}
            )
            assert updated.status_code == 200
            activated = client.post(
                "/api/v1/profiles/research/activate", headers=AUTH
            )
            assert activated.status_code == 200
            deleted = client.delete("/api/v1/profiles/research", headers=AUTH)
            assert deleted.status_code == 200

        methods_paths = [(m, p) for m, p, _, _ in backend.calls]
        assert ("POST", "/api/profiles") in methods_paths
        assert ("PUT", "/api/profiles/research") in methods_paths
        # Upstream activation contract is POST /api/profiles/active {"name"}.
        assert ("POST", "/api/profiles/active") in methods_paths
        activate_body = next(
            body for m, p, _, body in backend.calls if (m, p) == ("POST", "/api/profiles/active")
        )
        assert activate_body == {"name": "research"}
        assert ("DELETE", "/api/profiles/research") in methods_paths
        # Path name wins over a conflicting body name.
        put_body = next(
            body for m, p, _, body in backend.calls if (m, p) == ("PUT", "/api/profiles/research")
        )
        assert put_body["name"] == "research"
        # Nothing leaked into the local fallback store.
        assert ProfileStore(tmp_path / "profiles.json").snapshot()["profiles"] == []


# ---------------------------------------------------------------------------
# Upstream lists but write routes are unsupported (405) — graceful fallback
# ---------------------------------------------------------------------------


class TestUpstreamWriteFallback:
    """Upstream exposes GET /api/profiles but no write/activate routes."""

    def _backend(self) -> _Backend:
        def handler(method, path, params, body):
            if method == "GET" and path == "/api/profiles":
                return httpx.Response(
                    200,
                    json={
                        "profiles": [{"name": "experts"}, {"name": "default"}],
                        "active": "default",
                    },
                )
            if path.startswith("/api/profiles"):
                return httpx.Response(405, json={"detail": "method not allowed"})
            return httpx.Response(404, json={"detail": "not found"})

        return _Backend(handler)

    def test_activate_falls_back_to_local_store(self, tmp_path):
        store_path = tmp_path / "profiles.json"
        store = ProfileStore(store_path)
        store.upsert({"name": "experts"})
        store.upsert({"name": "default"})
        backend = self._backend()
        client = _app(backend, ProfileStore(store_path))
        with client:
            resp = client.post("/api/v1/profiles/experts/activate", headers=AUTH)
        assert resp.status_code == 200
        assert resp.json()["source"] == "local"
        assert ProfileStore(store_path).snapshot()["active"] == "experts"

    def test_create_falls_back_to_local_store(self, tmp_path):
        store_path = tmp_path / "profiles.json"
        backend = self._backend()
        client = _app(backend, ProfileStore(store_path))
        with client:
            resp = client.post(
                "/api/v1/profiles", headers=AUTH, json={"name": "writing"}
            )
        assert resp.status_code == 200
        assert resp.json()["source"] == "local"
        assert [
            p["name"] for p in ProfileStore(store_path).snapshot()["profiles"]
        ] == ["writing"]


# ---------------------------------------------------------------------------
# /api/config profiles-field fallback mode
# ---------------------------------------------------------------------------


class TestConfigProfiles:
    """Older runtimes carry profiles inside /api/config."""

    def _backend(self) -> _Backend:
        state = {
            "profiles": [
                {"name": "default", "is_active": True},
                {"name": "code", "is_active": False},
            ]
        }

        def handler(method, path, params, body):
            if path == "/api/profiles":
                return httpx.Response(404, json={"detail": "not found"})
            if method == "GET" and path == "/api/config":
                return httpx.Response(200, json=dict(state))
            if method == "PUT" and path == "/api/config":
                state["profiles"] = (body or {}).get("config", {}).get(
                    "profiles", state["profiles"]
                )
                return httpx.Response(200, json={"ok": True})
            return httpx.Response(404, json={"detail": "not found"})

        return _Backend(handler)

    def test_list_reads_config_field(self, tmp_path):
        backend = self._backend()
        client = _app(backend, ProfileStore(tmp_path / "profiles.json"))
        with client:
            resp = client.get("/api/v1/profiles", headers=AUTH)
        assert resp.status_code == 200
        body = resp.json()
        assert body["source"] == "config"
        assert [p["name"] for p in body["profiles"]] == ["default", "code"]
        assert body["active"] == "default"

    def test_activate_rewrites_config_with_active_flags(self, tmp_path):
        backend = self._backend()
        client = _app(backend, ProfileStore(tmp_path / "profiles.json"))
        with client:
            resp = client.post("/api/v1/profiles/code/activate", headers=AUTH)
            assert resp.status_code == 200
            assert resp.json()["active"] == "code"
            listed = client.get("/api/v1/profiles", headers=AUTH).json()
        assert listed["active"] == "code"
        put_bodies = [
            body for m, p, _, body in backend.calls if (m, p) == ("PUT", "/api/config")
        ]
        assert put_bodies, "activate must write back through PUT /api/config"
        written = put_bodies[-1]["config"]["profiles"]
        assert {p["name"]: p["is_active"] for p in written} == {
            "default": False,
            "code": True,
        }

    def test_create_and_delete_via_config(self, tmp_path):
        backend = self._backend()
        client = _app(backend, ProfileStore(tmp_path / "profiles.json"))
        with client:
            resp = client.post(
                "/api/v1/profiles", headers=AUTH, json={"name": "writing"}
            )
            assert resp.status_code == 200
            names = [
                p["name"]
                for p in client.get("/api/v1/profiles", headers=AUTH).json()[
                    "profiles"
                ]
            ]
            assert "writing" in names
            resp = client.delete("/api/v1/profiles/writing", headers=AUTH)
            assert resp.status_code == 200
            names = [
                p["name"]
                for p in client.get("/api/v1/profiles", headers=AUTH).json()[
                    "profiles"
                ]
            ]
            assert "writing" not in names

    def test_activate_unknown_profile_404(self, tmp_path):
        backend = self._backend()
        client = _app(backend, ProfileStore(tmp_path / "profiles.json"))
        with client:
            resp = client.post("/api/v1/profiles/ghost/activate", headers=AUTH)
        assert resp.status_code == 404


# ---------------------------------------------------------------------------
# Local durable fallback mode
# ---------------------------------------------------------------------------


class TestLocalProfiles:
    """No upstream surface at all → the mobile server's profiles.json wins."""

    def _backend(self) -> _Backend:
        def handler(method, path, params, body):
            return httpx.Response(404, json={"detail": "not found"})

        return _Backend(handler)

    def test_full_crud_and_activation(self, tmp_path):
        store = ProfileStore(tmp_path / "profiles.json")
        client = _app(self._backend(), store)
        with client:
            empty = client.get("/api/v1/profiles", headers=AUTH).json()
            assert empty == {"profiles": [], "active": None, "source": "local"}

            assert client.post(
                "/api/v1/profiles",
                headers=AUTH,
                json={"name": "默认助手", "model": "gpt-5", "temperature": 0.7},
            ).status_code == 200
            assert client.post(
                "/api/v1/profiles", headers=AUTH, json={"name": "代码专家"}
            ).status_code == 200
            activated = client.post(
                "/api/v1/profiles/代码专家/activate", headers=AUTH
            )
            assert activated.status_code == 200

            listed = client.get("/api/v1/profiles", headers=AUTH).json()
            assert listed["source"] == "local"
            assert [p["name"] for p in listed["profiles"]] == ["默认助手", "代码专家"]
            assert listed["active"] == "代码专家"

            # Update replaces by name.
            assert client.put(
                "/api/v1/profiles/默认助手",
                headers=AUTH,
                json={"model": "claude", "temperature": 0.2},
            ).status_code == 200
            listed = client.get("/api/v1/profiles", headers=AUTH).json()
            first = listed["profiles"][0]
            assert first["model"] == "claude"
            assert first["temperature"] == 0.2

            assert client.delete(
                "/api/v1/profiles/代码专家", headers=AUTH
            ).status_code == 200
            listed = client.get("/api/v1/profiles", headers=AUTH).json()
            assert [p["name"] for p in listed["profiles"]] == ["默认助手"]
            # Deleting the active profile clears the active pointer.
            assert listed["active"] is None

    def test_persists_across_store_instances(self, tmp_path):
        path = tmp_path / "profiles.json"
        client = _app(self._backend(), ProfileStore(path))
        with client:
            client.post(
                "/api/v1/profiles", headers=AUTH, json={"name": "persisted"}
            )
            client.post("/api/v1/profiles/persisted/activate", headers=AUTH)

        raw = json.loads(path.read_text(encoding="utf-8"))
        assert raw["active"] == "persisted"
        assert [p["name"] for p in raw["profiles"]] == ["persisted"]

        reloaded = _app(self._backend(), ProfileStore(path))
        with reloaded:
            listed = reloaded.get("/api/v1/profiles", headers=AUTH).json()
        assert listed["active"] == "persisted"
        assert [p["name"] for p in listed["profiles"]] == ["persisted"]

    def test_activate_unknown_profile_404(self, tmp_path):
        client = _app(self._backend(), ProfileStore(tmp_path / "profiles.json"))
        with client:
            assert (
                client.post("/api/v1/profiles/ghost/activate", headers=AUTH).status_code
                == 404
            )
            assert (
                client.delete("/api/v1/profiles/ghost", headers=AUTH).status_code
                == 404
            )

    def test_validation(self, tmp_path):
        client = _app(self._backend(), ProfileStore(tmp_path / "profiles.json"))
        with client:
            assert (
                client.post("/api/v1/profiles", headers=AUTH, json={}).status_code
                == 422
            )
            assert (
                client.post(
                    "/api/v1/profiles", headers=AUTH, json=["not", "a", "dict"]
                ).status_code
                == 422
            )

    def test_works_without_any_backend(self, tmp_path):
        """Backend down → local store still serves real persisted data."""
        settings = Settings(api_key="test-key-42")
        app = FastAPI()
        app.include_router(
            build_domain_router(
                settings, None, profile_store=ProfileStore(tmp_path / "profiles.json")
            )
        )
        client = TestClient(app)
        with client:
            assert client.post(
                "/api/v1/profiles", headers=AUTH, json={"name": "offline"}
            ).status_code == 200
            listed = client.get("/api/v1/profiles", headers=AUTH).json()
            assert listed["profiles"][0]["name"] == "offline"
            assert listed["source"] == "local"

    def test_requires_auth(self, tmp_path):
        client = _app(self._backend(), ProfileStore(tmp_path / "profiles.json"))
        with client:
            assert client.get("/api/v1/profiles").status_code == 401
            assert (
                client.post("/api/v1/profiles", json={"name": "x"}).status_code == 401
            )
