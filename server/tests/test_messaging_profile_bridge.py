import httpx
import asyncio

from hermes_mobile_server.config import Settings
from hermes_mobile_server.domain_api import build_domain_router


class _BackendClient:
    def __init__(self, calls):
        self.calls = calls

    async def request(self, method, path, params=None, json=None):
        self.calls.append((method, path, params or {}, json))
        if method == "GET" and path == "/api/messaging/platforms":
            return httpx.Response(
                200, json={"platforms": [{"id": "telegram"}]}
            )
        if method == "GET" and path == "/api/pairing":
            return httpx.Response(
                200,
                json={
                    "pending": [
                        {
                            "platform": "telegram",
                            "request_id": "request-1",
                        }
                    ]
                },
            )
        return httpx.Response(200, json={"ok": True})


class _Backend:
    is_running = True

    def __init__(self):
        self.calls = []
        self.client = _BackendClient(self.calls)

    async def http_client(self):
        return self.client


def test_legacy_messaging_routes_preserve_profile():
    asyncio.run(_exercise_legacy_messaging_routes())


async def _exercise_legacy_messaging_routes():
    backend = _Backend()
    router = build_domain_router(Settings(api_key="test-key-42"), backend)
    endpoints = {
        (method, route.path): route.endpoint
        for route in router.routes
        for method in route.methods
    }

    config = await endpoints[("GET", "/api/v1/messaging/{platform}/config")](
        "telegram", "work"
    )
    pending = await endpoints[("GET", "/api/v1/messaging/{platform}/pending")](
        "telegram", "work"
    )
    saved = await endpoints[("POST", "/api/v1/messaging/{platform}/env")](
        "telegram", {"key": "TELEGRAM_BOT_TOKEN", "value": "secret"}, "work"
    )
    approved = await endpoints[
        ("POST", "/api/v1/messaging/{platform}/pair/{pairing_id}/approve")
    ]("telegram", "request-1", "work")

    assert config["id"] == "telegram"
    assert pending["pending"][0]["request_id"] == "request-1"
    assert saved["ok"] is True
    assert approved["ok"] is True
    assert (
        "GET", "/api/messaging/platforms", {"profile": "work"}, None
    ) in backend.calls
    assert ("GET", "/api/pairing", {"profile": "work"}, None) in backend.calls
    assert (
        "PUT",
        "/api/messaging/platforms/telegram",
        {"profile": "work"},
        {"env": {"TELEGRAM_BOT_TOKEN": "secret"}},
    ) in backend.calls
    assert (
        "POST",
        "/api/pairing/approve",
        {},
        {
            "platform": "telegram",
            "request_id": "request-1",
            "profile": "work",
        },
    ) in backend.calls
