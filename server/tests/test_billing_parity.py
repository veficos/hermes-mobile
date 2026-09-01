"""Remote Spending contracts that must match the Desktop gateway client."""

from __future__ import annotations

import asyncio

from fastapi import FastAPI
from fastapi.testclient import TestClient

from hermes_mobile_server.config import Settings
from hermes_mobile_server.domain_api import build_domain_router

AUTH = {"Authorization": "Bearer test-key-42"}


class _Backend:
    is_running = True

    def __init__(self) -> None:
        self.calls: list[tuple[str, dict]] = []

    async def gateway_rpc(self, method: str, params: dict):
        self.calls.append((method, params))
        return {"ok": True, "status": "succeeded"}


def _client(backend: _Backend) -> TestClient:
    app = FastAPI()
    app.include_router(
        build_domain_router(Settings(api_key="test-key-42"), backend)
    )
    return TestClient(app)


def _call_endpoint(backend: _Backend, path: str, payload: dict):
    router = build_domain_router(Settings(api_key="test-key-42"), backend)
    endpoint = next(route.endpoint for route in router.routes if route.path == path)
    return asyncio.run(endpoint(payload))


def test_charge_status_requires_and_forwards_charge_identity():
    backend = _Backend()
    client = _client(backend)

    with client:
        missing = client.get("/api/v1/billing/charge/status", headers=AUTH)
        response = client.get(
            "/api/v1/billing/charge/status",
            params={"charge_id": "charge-1"},
            headers=AUTH,
        )

    assert missing.status_code == 422
    assert response.status_code == 200
    assert backend.calls == [
        ("billing.charge_status", {"charge_id": "charge-1"})
    ]


def test_charge_preserves_money_string_and_idempotency_key():
    backend = _Backend()
    client = _client(backend)
    payload = {"amount_usd": "25.00", "idempotency_key": "mobile-1"}

    with client:
        response = client.post(
            "/api/v1/billing/charge", json=payload, headers=AUTH
        )

    assert response.status_code == 200
    assert backend.calls == [("billing.charge", payload)]


def test_step_up_forwards_optional_session_identity_unchanged():
    backend = _Backend()
    payload = {"session_id": "session-1"}

    response = _call_endpoint(backend, "/api/v1/billing/step-up", payload)

    assert response == {"ok": True, "status": "succeeded"}
    assert backend.calls == [("billing.step_up", payload)]


def test_step_up_accepts_empty_payload():
    backend = _Backend()

    response = _call_endpoint(backend, "/api/v1/billing/step-up", {})

    assert response == {"ok": True, "status": "succeeded"}
    assert backend.calls == [("billing.step_up", {})]
