"""Tests for /api/v1/prompts (saved prompts) and /api/v1/provider/quota.

Saved prompts follow the profiles resolution pattern: proxy the backend's
WebUI-compatible ``/api/prompts`` when it exists, otherwise read/write the
very same ``$HERMES_HOME/webui/saved_prompts.json`` file the desktop WebUI
uses.  The quota endpoint is a pure pass-through of ``/api/provider/quota``.
"""

from __future__ import annotations

import json

import httpx
from fastapi import FastAPI
from fastapi.testclient import TestClient

from hermes_mobile_server.config import Settings
from hermes_mobile_server.domain_api import build_domain_router
from hermes_mobile_server.prompts import SavedPromptsStore

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


def _app(backend, prompt_store) -> TestClient:
    settings = Settings(api_key="test-key-42")
    app = FastAPI()
    app.include_router(
        build_domain_router(settings, backend, prompt_store=prompt_store)
    )
    return TestClient(app)


def _no_prompts_backend() -> _Backend:
    """Backend without the legacy /api/prompts route."""

    def handler(method, path, params, body):
        return httpx.Response(404, json={"detail": "not found"})

    return _Backend(handler)


class TestLocalPromptsFallback:
    """Backend lacks /api/prompts → the WebUI-shared file store is used."""

    def test_crud_against_shared_file(self, tmp_path):
        store = SavedPromptsStore(tmp_path / "webui" / "saved_prompts.json")
        client = _app(_no_prompts_backend(), store)
        with client:
            assert client.get("/api/v1/prompts", headers=AUTH).json() == {
                "prompts": []
            }

            created = client.post(
                "/api/v1/prompts", headers=AUTH, json={"text": " 评审这段代码 "}
            )
            assert created.status_code == 200
            prompt = created.json()["prompt"]
            assert prompt["text"] == "评审这段代码"
            assert prompt["label"] == "评审这段代码"
            assert prompt["id"]

            listed = client.get("/api/v1/prompts", headers=AUTH).json()
            assert [p["id"] for p in listed["prompts"]] == [prompt["id"]]

            deleted = client.delete(
                f"/api/v1/prompts/{prompt['id']}", headers=AUTH
            )
            assert deleted.status_code == 200
            assert client.get("/api/v1/prompts", headers=AUTH).json() == {
                "prompts": []
            }

        # WebUI schema: a bare JSON list on disk, shared with the desktop UI.
        # After deleting the only entry the file holds an empty list.
        raw = json.loads((tmp_path / "webui" / "saved_prompts.json").read_text())
        assert raw == []

    def test_validation(self, tmp_path):
        store = SavedPromptsStore(tmp_path / "saved_prompts.json")
        client = _app(_no_prompts_backend(), store)
        with client:
            assert (
                client.post("/api/v1/prompts", headers=AUTH, json={"text": "  "})
                .status_code
                == 422
            )
            assert (
                client.post(
                    "/api/v1/prompts", headers=AUTH, json={"text": "x" * 8001}
                ).status_code
                == 422
            )

    def test_limit_enforced(self, tmp_path):
        store = SavedPromptsStore(tmp_path / "saved_prompts.json")
        client = _app(_no_prompts_backend(), store)
        with client:
            for i in range(200):
                resp = client.post(
                    "/api/v1/prompts", headers=AUTH, json={"text": f"p{i}"}
                )
                assert resp.status_code == 200
            assert (
                client.post("/api/v1/prompts", headers=AUTH, json={"text": "x"})
                .status_code
                == 422
            )


class TestUpstreamPromptsProxy:
    """When the backend exposes /api/prompts the mobile server proxies it."""

    def _backend(self) -> _Backend:
        def handler(method, path, params, body):
            if method == "GET" and path == "/api/prompts":
                return httpx.Response(
                    200,
                    json={
                        "prompts": [
                            {"id": "abc", "label": "L", "text": "T"},
                        ]
                    },
                )
            if method == "POST" and path == "/api/prompts":
                return httpx.Response(
                    200, json={"ok": True, "prompt": {"id": "n1", **(body or {})}}
                )
            if method == "DELETE" and path == "/api/prompts":
                return httpx.Response(200, json={"ok": True})
            return httpx.Response(404, json={"detail": "not found"})

        return _Backend(handler)

    def test_list_create_delete_proxy(self, tmp_path):
        backend = self._backend()
        store = SavedPromptsStore(tmp_path / "saved_prompts.json")
        client = _app(backend, store)
        with client:
            listed = client.get("/api/v1/prompts", headers=AUTH)
            assert listed.status_code == 200
            assert listed.json()["prompts"][0]["id"] == "abc"

            created = client.post(
                "/api/v1/prompts",
                headers=AUTH,
                json={"text": "hello", "label": "greet"},
            )
            assert created.status_code == 200
            assert created.json()["prompt"]["label"] == "greet"

            deleted = client.delete("/api/v1/prompts/abc", headers=AUTH)
            assert deleted.status_code == 200

        posts = [c for c in backend.calls if c[0] == "POST"]
        assert posts and posts[0][3] == {"text": "hello", "label": "greet"}
        deletes = [c for c in backend.calls if c[0] == "DELETE"]
        assert deletes and deletes[0][3] == {"id": "abc"}
        # Nothing touched the local fallback file.
        assert not (tmp_path / "saved_prompts.json").exists()


class TestProviderQuota:
    def test_pass_through_with_query(self, tmp_path):
        def handler(method, path, params, body):
            assert path == "/api/provider/quota"
            return httpx.Response(
                200,
                json={
                    "ok": True,
                    "provider": params.get("provider"),
                    "status": "available",
                    "quota": {"limit_remaining": 3.5, "usage": 1.0, "limit": 5.0},
                },
            )

        client = _app(_Backend(handler), SavedPromptsStore(tmp_path / "p.json"))
        with client:
            resp = client.get(
                "/api/v1/provider/quota",
                headers=AUTH,
                params={"provider": "openrouter", "refresh": "true"},
            )
        assert resp.status_code == 200
        body = resp.json()
        assert body["status"] == "available"
        assert body["quota"]["limit_remaining"] == 3.5

    def test_unsupported_backend_route_returns_unavailable(self, tmp_path):
        client = _app(_no_prompts_backend(), SavedPromptsStore(tmp_path / "p.json"))
        with client:
            resp = client.get("/api/v1/provider/quota", headers=AUTH)
        assert resp.status_code == 200
        assert resp.json() == {
            "supported": False,
            "status": "unavailable",
            "message": "Provider quota is not supported by this Hermes runtime.",
        }


class TestAuth:
    def test_prompts_and_quota_require_auth(self, tmp_path):
        client = _app(_no_prompts_backend(), SavedPromptsStore(tmp_path / "p.json"))
        with client:
            assert client.get("/api/v1/prompts").status_code == 401
            assert client.post("/api/v1/prompts", json={"text": "x"}).status_code == 401
            assert client.delete("/api/v1/prompts/abc").status_code == 401
            assert client.get("/api/v1/provider/quota").status_code == 401
