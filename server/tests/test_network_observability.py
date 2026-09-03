from __future__ import annotations

import asyncio

import pytest
from fastapi import FastAPI, WebSocketDisconnect
from fastapi.testclient import TestClient

from hermes_mobile_server.backend import _gateway_rpc_timeout
from hermes_mobile_server.config import Settings
from hermes_mobile_server.network_observability import (
    NetworkMetrics,
    WebSocketConnectionLimiter,
)
from hermes_mobile_server.terminal_pty import PtyManager
from hermes_mobile_server.terminal_ws import build_terminal_router
from hermes_mobile_server.ws_proxy import build_ws_router


class _Client:
    host = "192.0.2.10"


class _WebSocket:
    client = _Client()
    headers = {"x-forwarded-for": "198.51.100.4, 10.0.0.1"}


def test_network_metrics_are_aggregated_without_client_addresses() -> None:
    metrics = NetworkMetrics()
    metrics.connected("gateway", 0.125, "private-client")
    metrics.disconnected("gateway", "upstream closed")
    metrics.handshake_failed("gateway", "timeout")
    metrics.connected("gateway", 0.075, "private-client")
    snapshot = metrics.snapshot()

    assert snapshot["active_proxies"] == {"gateway": 1}
    assert snapshot["connections_total"] == {"gateway": 2}
    assert snapshot["reconnects_total"] == {"gateway": 1}
    assert snapshot["disconnects_total"] == {"gateway:upstream": 1}
    assert snapshot["handshake_failures_total"] == {"gateway:timeout": 1}
    assert snapshot["handshake"]["gateway"] == {
        "count": 2, "average_ms": 100, "max_ms": 125
    }
    assert "private-client" not in str(snapshot)


def test_websocket_limit_is_shared_per_client_and_releases_slots() -> None:
    limiter = WebSocketConnectionLimiter(1)

    async def exercise() -> tuple[bool, bool, bool]:
        async with limiter.slot(_WebSocket()) as first:
            async with limiter.slot(_WebSocket()) as second:
                pass
        async with limiter.slot(_WebSocket()) as after_release:
            pass
        return first, second, after_release

    assert asyncio.run(exercise()) == (True, False, True)
    assert limiter.client_key(_WebSocket()) == "192.0.2.10"
    assert (
        WebSocketConnectionLimiter(1, trust_forwarded_for=True).client_key(
            _WebSocket()
        )
        == "198.51.100.4"
    )


def test_websocket_limit_is_shared_across_proxy_routes() -> None:
    settings = Settings(api_key="test-key", websocket_max_per_client=1)
    metrics = NetworkMetrics()
    limiter = WebSocketConnectionLimiter(1)
    app = FastAPI()
    app.include_router(
        build_terminal_router(settings, PtyManager(), metrics, limiter)
    )
    app.include_router(build_ws_router(settings, None, metrics, limiter))

    with TestClient(app) as client:
        with client.websocket_connect(
            "/api/v1/terminal/ws?token=test-key"
        ):
            with client.websocket_connect(
                "/api/v1/plugins/example/events?token=test-key"
            ) as rejected:
                with pytest.raises(WebSocketDisconnect) as closed:
                    rejected.receive_text()
                assert closed.value.code == 4429

    assert metrics.snapshot()["connection_limit_rejections_total"] == {
        "plugin": 1
    }


def test_gateway_rpc_timeouts_are_classified_by_operation() -> None:
    assert _gateway_rpc_timeout("billing.state") == 15.0
    assert _gateway_rpc_timeout("projects.list") == 15.0
    assert _gateway_rpc_timeout("files.upload") == 300.0
    assert _gateway_rpc_timeout("shell.exec") == 300.0
    assert _gateway_rpc_timeout("session.resume") == 60.0
