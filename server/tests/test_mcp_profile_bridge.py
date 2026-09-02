import asyncio

import httpx
from starlette.requests import Request

from hermes_mobile_server.config import Settings
from hermes_mobile_server.domain_api import build_domain_router


class _BackendClient:
    def __init__(self, calls):
        self.calls = calls

    async def request(self, method, path, params=None, json=None, headers=None):
        self.calls.append((method, path, params or {}, json, headers))
        return httpx.Response(200, json={"ok": True, "servers": []})


class _Backend:
    is_running = True

    def __init__(self):
        self.calls = []
        self.client = _BackendClient(self.calls)

    async def http_client(self):
        return self.client


def test_mcp_mutations_and_oauth_cancel_preserve_profile():
    asyncio.run(_exercise_routes())


async def _exercise_routes():
    backend = _Backend()
    router = build_domain_router(Settings(api_key="test-key-42"), backend)
    endpoints = {
        (method, route.path): route.endpoint
        for route in router.routes
        for method in route.methods
    }

    await endpoints[("GET", "/api/v1/mcp/servers")]("work")
    await endpoints[("POST", "/api/v1/mcp/servers")](
        {"name": "remote", "url": "https://mcp.example"}, "work"
    )
    await endpoints[("PUT", "/api/v1/mcp/servers")](
        {"servers": {"remote": {"url": "https://mcp.example"}}},
        "work",
    )
    await endpoints[("PUT", "/api/v1/mcp/servers/{name}/enabled")](
        "remote", {"enabled": False}, "work"
    )
    await endpoints[("GET", "/api/v1/mcp/servers/{name}/test")](
        "remote", "work"
    )
    request = Request(
        {
            "type": "http",
            "method": "POST",
            "scheme": "https",
            "server": ("mobile.example", 443),
            "path": "/api/v1/mcp/servers/remote/auth",
            "root_path": "",
            "query_string": b"",
            "headers": [],
        }
    )
    await endpoints[("POST", "/api/v1/mcp/servers/{name}/auth")](
        "remote", request, "work"
    )
    await endpoints[("DELETE", "/api/v1/mcp/oauth/flows/{flow_id}")](
        "flow-1", "work"
    )
    await endpoints[("GET", "/api/v1/actions/{name}/status")](
        "mcp-install-remote", 50, "work"
    )
    await endpoints[("GET", "/api/v1/analytics/usage")](30, "work")
    await endpoints[("DELETE", "/api/v1/mcp/servers/{name}")](
        "remote", "work"
    )

    calls = {(method, path): (params, body) for method, path, params, body, _ in backend.calls}
    assert calls[("GET", "/api/mcp/servers")][0] == {"profile": "work"}
    assert calls[("POST", "/api/mcp/servers")] == (
        {"profile": "work"},
        {"name": "remote", "url": "https://mcp.example"},
    )
    assert calls[("PUT", "/api/mcp/servers")][0] == {"profile": "work"}
    assert calls[("PUT", "/api/mcp/servers/remote/enabled")] == (
        {"profile": "work"},
        {"enabled": False},
    )
    assert calls[("POST", "/api/mcp/servers/remote/test")][0] == {"profile": "work"}
    assert calls[("POST", "/api/mcp/servers/remote/auth")][0] == {"profile": "work"}
    assert calls[("DELETE", "/api/mcp/oauth/flows/flow-1")][0] == {"profile": "work"}
    assert calls[("GET", "/api/actions/mcp-install-remote/status")][0] == {
        "lines": 50,
        "profile": "work",
    }
    assert calls[("GET", "/api/analytics/usage")][0] == {
        "days": 30,
        "profile": "work",
    }
    assert calls[("DELETE", "/api/mcp/servers/remote")][0] == {"profile": "work"}
