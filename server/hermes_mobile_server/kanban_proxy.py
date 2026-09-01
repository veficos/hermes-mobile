"""Authenticated transparent proxy for the Hermes Kanban plugin API."""
from __future__ import annotations
import asyncio
import hmac
from urllib.parse import urlencode
import httpx
import websockets
from fastapi import APIRouter, Depends, HTTPException, Request, Response, WebSocket
from .auth import api_key_dependency
from .backend import BackendManager
from .config import Settings

def build_kanban_router(settings: Settings, backend: BackendManager | None) -> APIRouter:
    router = APIRouter(tags=["kanban-proxy"])
    auth = Depends(api_key_dependency(settings))
    def require_backend() -> BackendManager:
        if backend is None or not backend.is_running:
            raise HTTPException(status_code=503, detail="Hermes backend is not running")
        return backend
    @router.api_route("/api/v1/kanban/{path:path}", methods=["GET", "POST", "PATCH", "PUT", "DELETE"], dependencies=[auth])
    async def proxy_http(path: str, request: Request) -> Response:
        if not path or ".." in path.split("/"):
            raise HTTPException(status_code=422, detail="invalid kanban path")
        client = await require_backend().http_client()
        headers = {"content-type": request.headers["content-type"]} if request.headers.get("content-type") else {}
        try:
            upstream = await client.request(request.method, f"/api/plugins/kanban/{path}", params=list(request.query_params.multi_items()), content=await request.body(), headers=headers)
        except httpx.HTTPError as exc:
            raise HTTPException(status_code=502, detail="kanban backend unreachable") from exc
        return Response(content=upstream.content, status_code=upstream.status_code, media_type=upstream.headers.get("content-type"), headers={k: upstream.headers[k] for k in ("content-disposition", "etag") if k in upstream.headers})
    @router.websocket("/api/v1/kanban/events")
    async def proxy_events(ws: WebSocket) -> None:
        presented = ws.query_params.get("token", "") or ws.headers.get("x-api-key", "")
        authz = ws.headers.get("authorization", "")
        presented = presented or (authz[7:] if authz.startswith("Bearer ") else authz)
        if not hmac.compare_digest(presented.encode(), settings.api_key.encode()):
            await ws.accept(); await ws.close(code=4401, reason="invalid api key"); return
        be = require_backend(); await ws.accept()
        params = [(k, v) for k, v in ws.query_params.multi_items() if k != "token"]
        params.append(("token", be.session_token))
        upstream = None
        try:
            upstream = await websockets.connect(f"ws://127.0.0.1:{be.port}/api/plugins/kanban/events?{urlencode(params)}", max_size=None, open_timeout=10, ping_interval=20, ping_timeout=20)
            async def c2b():
                async for message in ws.iter_text(): await upstream.send(message)
            async def b2c():
                async for message in upstream: await ws.send_bytes(message) if isinstance(message, bytes) else await ws.send_text(message)
            tasks = [asyncio.create_task(c2b()), asyncio.create_task(b2c())]
            _, pending = await asyncio.wait(tasks, return_when=asyncio.FIRST_COMPLETED)
            for task in pending: task.cancel()
        except Exception:
            try: await ws.close(code=1011, reason="kanban event stream unavailable")
            except Exception: pass
        finally:
            if upstream is not None: await upstream.close()
    return router
