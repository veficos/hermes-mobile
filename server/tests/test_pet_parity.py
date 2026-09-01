"""Pet operation contracts that must match the Desktop gateway client."""

from __future__ import annotations

import asyncio

from hermes_mobile_server.config import Settings
from hermes_mobile_server.domain_api import build_domain_router


class _Backend:
    is_running = True

    def __init__(self) -> None:
        self.calls: list[tuple[str, dict]] = []

    async def gateway_rpc(self, method: str, params: dict):
        self.calls.append((method, params))
        return {"ok": True}


def _call_endpoint(backend: _Backend, path: str, payload: dict):
    router = build_domain_router(Settings(api_key="test-key-42"), backend)
    endpoint = next(route.endpoint for route in router.routes if route.path == path)
    return asyncio.run(endpoint(payload))


def test_cancel_forwards_generation_token_unchanged():
    backend = _Backend()
    payload = {"token": "job-1"}

    response = _call_endpoint(backend, "/api/v1/pet/cancel", payload)

    assert response == {"ok": True}
    assert backend.calls == [("pet.cancel", payload)]


def test_remove_forwards_pet_slug_unchanged():
    backend = _Backend()
    payload = {"slug": "fox"}

    response = _call_endpoint(backend, "/api/v1/pet/remove", payload)

    assert response == {"ok": True}
    assert backend.calls == [("pet.remove", payload)]
