"""Static App ↔ Mobile Server route-contract checks."""

from __future__ import annotations

import re
import asyncio
from pathlib import Path

from hermes_mobile_server.config import Settings
from hermes_mobile_server.domain_api import build_domain_router
from hermes_mobile_server.ws_proxy import _read_upstream
from hermes_mobile_server.kanban_proxy import build_kanban_router
from hermes_mobile_server.push import PushDispatcher, PushStore, build_push_router


ROOT = Path(__file__).resolve().parents[2]


def _normalize_app_path(path: str) -> str:
    path = re.sub(r"\$\{[^}]+\}", "{value}", path)
    path = re.sub(r"\$[A-Za-z_][A-Za-z0-9_]*", "{value}", path)
    return path


def _same_route(app_path: str, server_path: str) -> bool:
    if server_path.endswith("/{path:path}"):
        return app_path.startswith(server_path.removesuffix("/{path:path}"))
    app_parts = app_path.strip("/").split("/")
    server_parts = server_path.strip("/").split("/")
    if len(app_parts) != len(server_parts):
        return False
    return all(
        left == right or left.startswith("{") or right.startswith("{")
        for left, right in zip(app_parts, server_parts)
    )


def _app_rest_calls() -> set[tuple[str, str]]:
    pattern = re.compile(
        r"\b(get|post|put|patch|delete)\(\s*(['\"])(/api/v1/[^'\"]+)\2"
    )
    calls: set[tuple[str, str]] = set()
    for source in (ROOT / "lib").rglob("*.dart"):
        text = source.read_text(encoding="utf-8")
        for match in pattern.finditer(text):
            path = match.group(3)
            # A Dart interpolation containing a conditional expands to one of
            # separately registered routes and cannot be normalized statically.
            if "?" in path:
                continue
            calls.add((match.group(1).upper(), _normalize_app_path(path)))
    # ApiClient.health uses the raw HTTP client rather than the get wrapper.
    calls.add(("GET", "/api/v1/health"))
    return calls


def _server_rest_routes() -> set[tuple[str, str]]:
    router = build_domain_router(Settings(api_key="contract-key"), None)
    routes = {
        (method, route.path)
        for route in router.routes
        for method in (getattr(route, "methods", None) or set())
    }
    routes.update(
        {
            ("GET", "/api/v1/health"),
            ("GET", "/api/v1/status"),
            ("GET", "/api/v1/methods"),
            ("POST", "/api/v1/backend/restart"),
        }
    )
    routes.update(
        (method, route.path)
        for route in build_kanban_router(Settings(api_key="contract-key"), None).routes
        for method in (getattr(route, "methods", None) or set())
    )
    push_store = PushStore(ROOT / "build" / "contract-push-devices.json")
    routes.update(
        (method, route.path)
        for route in build_push_router(
            Settings(api_key="contract-key"),
            push_store,
            PushDispatcher(push_store, []),
        ).routes
        for method in (getattr(route, "methods", None) or set())
    )
    return routes


def test_every_app_rest_call_has_a_mobile_server_route() -> None:
    server = _server_rest_routes()
    missing = [
        (method, path)
        for method, path in sorted(_app_rest_calls())
        if not any(
            method == server_method and _same_route(path, server_path)
            for server_method, server_path in server
        )
    ]
    assert missing == [], f"App REST calls missing on Mobile Server: {missing}"


def test_realtime_contract_paths_are_registered() -> None:
    # These are deliberately explicit: they use WebSocket rather than OpenAPI.
    gateway = (ROOT / "server/hermes_mobile_server/ws_proxy.py").read_text()
    terminal = (ROOT / "server/hermes_mobile_server/terminal_ws.py").read_text()
    assert '@router.websocket("/api/v1/ws")' in gateway
    assert '@router.websocket("/api/v1/terminal/ws")' in terminal
    kanban = (ROOT / "server/hermes_mobile_server/kanban_proxy.py").read_text()
    assert '@router.websocket("/api/v1/kanban/events")' in kanban


def test_gateway_proxy_backpressures_without_dropping_frames() -> None:
    class Upstream:
        def __aiter__(self):
            async def frames():
                for value in ("delta-1", "delta-2", "approval"):
                    yield value

            return frames()

    async def exercise() -> list[str | None]:
        queue: asyncio.Queue[str | None] = asyncio.Queue(maxsize=1)
        reader = asyncio.create_task(_read_upstream(Upstream(), queue))
        await asyncio.sleep(0)
        assert not reader.done(), "reader must wait for a slow mobile client"
        received = [await queue.get()]
        await asyncio.sleep(0)
        received.append(await queue.get())
        await asyncio.sleep(0)
        received.append(await queue.get())
        received.append(await queue.get())  # disconnect sentinel
        await reader
        return received

    assert asyncio.run(exercise()) == ["delta-1", "delta-2", "approval", None]
