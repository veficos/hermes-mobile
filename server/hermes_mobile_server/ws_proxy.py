"""WebSocket JSON-RPC proxy to the Hermes gateway.

The mobile app opens a single WebSocket to this server:

    ws://<server>:8877/api/v1/ws?token=<api-key>

which is authenticated with the mobile API key, then relayed to the backend
gateway (``ws://127.0.0.1:<port>/api/ws?token=<backend-token>``). Frames are
newline-delimited JSON-RPC 2.0 and are forwarded verbatim in both directions,
so the mobile client gets the *entire* gateway surface — session create /
resume, ``prompt.submit`` streaming, ``message.delta`` / ``tool.complete``
events, approval/clarify requests, config, projects, cron, and so on.

Backend restarts are tolerated: if the upstream connection drops, the proxy
reconnects before the client notices; the client's own reconnection logic
(e.g. ``session.resume`` after a reconnect) then works as designed.
"""

from __future__ import annotations

import asyncio
import hmac
import logging
import re
from urllib.parse import quote, urlencode

import websockets
from fastapi import APIRouter, Depends, WebSocket, WebSocketDisconnect

from .backend import BackendError, BackendManager
from .config import Settings

logger = logging.getLogger("hermes_mobile_server.ws")

#: Seconds to keep retrying the upstream gateway connection.
_UPSTREAM_RETRY_WINDOW = 15.0
_PLUGIN_ID = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$")


def build_ws_router(settings: Settings, backend: BackendManager | None) -> APIRouter:
    router = APIRouter(tags=["gateway-proxy"])

    @router.websocket("/api/v1/ws")
    async def gateway_ws(ws: WebSocket) -> None:
        # -- authenticate ---------------------------------------------------
        if not await _authenticate(ws, settings):
            return

        await ws.accept()
        await _pipe(ws, backend)

    @router.websocket("/api/v1/plugins/{plugin_id}/{event_path:path}")
    async def plugin_ws(ws: WebSocket, plugin_id: str, event_path: str) -> None:
        if not await _authenticate(ws, settings):
            return
        if not _valid_plugin_path(plugin_id, event_path):
            await ws.accept()
            await ws.close(code=4400, reason="invalid plugin socket path")
            return
        await ws.accept()
        await _pipe_plugin(ws, backend, plugin_id, event_path)

    return router


async def _authenticate(ws: WebSocket, settings: Settings) -> bool:
    token = ws.query_params.get("token", "")
    authz = ws.headers.get("authorization", "")
    api_key_header = ws.headers.get("x-api-key", "")
    presented = token or api_key_header or (
        authz[7:] if authz.startswith("Bearer ") else authz
    )
    if hmac.compare_digest(presented.encode(), settings.api_key.encode()):
        return True
    # Accept before close so clients receive the application close code.
    await ws.accept()
    await ws.close(code=4401, reason="invalid api key")
    return False


def _valid_plugin_path(plugin_id: str, event_path: str) -> bool:
    if not _PLUGIN_ID.fullmatch(plugin_id) or not event_path:
        return False
    parts = event_path.split("/")
    return all(
        part not in {"", ".", ".."} and len(part) <= 160 for part in parts
    )


def _plugin_upstream_url(
    backend: BackendManager,
    plugin_id: str,
    event_path: str,
    query: dict[str, str] | None = None,
) -> str:
    if backend.port is None:
        raise BackendError("Backend not started")
    params = {
        key: value
        for key, value in (query or {}).items()
        if key.lower() != "token"
    }
    params["token"] = backend.session_token
    encoded_path = "/".join(quote(part, safe="") for part in event_path.split("/"))
    return (
        f"ws://127.0.0.1:{backend.port}/api/plugins/"
        f"{quote(plugin_id, safe='')}/{encoded_path}?{urlencode(params)}"
    )


async def _pipe_plugin(
    client_ws: WebSocket,
    backend: BackendManager | None,
    plugin_id: str,
    event_path: str,
) -> None:
    if backend is None or not backend.is_running:
        await client_ws.close(code=1011, reason="no hermes runtime available")
        return
    try:
        upstream = await websockets.connect(
            _plugin_upstream_url(
                backend,
                plugin_id,
                event_path,
                dict(client_ws.query_params),
            ),
            open_timeout=10,
            max_size=4 * 1024 * 1024,
        )
    except Exception as exc:  # noqa: BLE001
        logger.warning("Plugin socket connect failed for %s: %s", plugin_id, exc)
        await client_ws.close(code=1011, reason="plugin socket unavailable")
        return

    upstream_task = asyncio.create_task(_copy_plugin_upstream(upstream, client_ws))
    client_task = asyncio.create_task(_copy_plugin_client(client_ws, upstream))
    done, pending = await asyncio.wait(
        {upstream_task, client_task},
        return_when=asyncio.FIRST_COMPLETED,
    )
    for task in pending:
        task.cancel()
    for task in done | pending:
        try:
            await task
        except (asyncio.CancelledError, Exception):  # noqa: BLE001
            pass
    try:
        await upstream.close()
    except Exception:  # noqa: BLE001
        pass
    try:
        await client_ws.close()
    except Exception:  # noqa: BLE001
        pass


async def _copy_plugin_upstream(
    upstream: websockets.ClientConnection,
    client_ws: WebSocket,
) -> None:
    async for message in upstream:
        if isinstance(message, bytes):
            await client_ws.send_bytes(message)
        else:
            await client_ws.send_text(message)


async def _copy_plugin_client(
    client_ws: WebSocket,
    upstream: websockets.ClientConnection,
) -> None:
    try:
        while True:
            frame = await client_ws.receive()
            if frame["type"] == "websocket.disconnect":
                return
            if frame.get("text") is not None:
                await upstream.send(frame["text"])
            elif frame.get("bytes") is not None:
                await upstream.send(frame["bytes"])
    except WebSocketDisconnect:
        return


async def _pipe(client_ws: WebSocket, backend: BackendManager | None) -> None:
    """Connect to the upstream gateway and relay frames both ways."""
    if backend is None:
        await client_ws.close(code=1011, reason="no hermes runtime available")
        return
    upstream: websockets.ClientConnection | None = None
    try:
        upstream = await _connect_upstream(backend)
    except Exception as exc:  # noqa: BLE001 - surface any upstream failure
        logger.error("Upstream gateway connect failed: %s", exc)
        await client_ws.close(code=1011, reason="backend gateway unavailable")
        return

    client_queue: asyncio.Queue[str | None] = asyncio.Queue(maxsize=256)
    upstream_task = asyncio.create_task(_read_upstream(upstream, client_queue))
    client_task = asyncio.create_task(_read_client(client_ws, upstream))
    client_closed = False

    try:
        while True:
            frame = await client_queue.get()
            if frame is None:
                logger.warning("Upstream gateway disconnected; closing mobile client")
                await client_ws.close(code=1011, reason="backend gateway disconnected")
                client_closed = True
                return
            try:
                await client_ws.send_text(frame)
            except Exception:  # client went away
                return
    finally:
        client_task.cancel()
        upstream_task.cancel()
        for task in (client_task, upstream_task):
            try:
                await task
            except (asyncio.CancelledError, Exception):  # noqa: BLE001
                pass
        try:
            await upstream.close()
        except Exception:  # noqa: BLE001
            pass
        if not client_closed:
            try:
                await client_ws.close()
            except Exception:  # noqa: BLE001
                pass


async def _connect_upstream(backend: BackendManager) -> websockets.ClientConnection:
    """Connect to the backend gateway, retrying briefly while it boots.

    The ``gateway.ready`` frame is left on the wire so the client receives it
    through the pass-through pipe (the client waits for it as the connection
    handshake).
    """
    return await backend.connect_gateway_ws(consume_ready=False)


async def _read_upstream(
    upstream: websockets.ClientConnection, queue: asyncio.Queue[str | None]
) -> None:
    """Relay upstream frames (events + RPC responses) into the client queue."""
    try:
        async for message in upstream:
            if isinstance(message, bytes):
                message = message.decode("utf-8", "replace")
            # Gateway frames are an ordered event log, not replaceable state
            # snapshots: dropping a message.delta/tool.start/approval.request
            # corrupts the client transcript. Backpressure the upstream reader
            # until the mobile socket catches up instead of discarding frames.
            await queue.put(message)
    except (websockets.ConnectionClosed, asyncio.CancelledError):
        pass
    finally:
        await queue.put(None)


async def _read_client(client_ws: WebSocket, upstream: websockets.ClientConnection) -> None:
    """Relay client frames (RPC requests) to the upstream gateway."""
    try:
        while True:
            frame = await client_ws.receive_text()
            try:
                await upstream.send(frame)
            except (websockets.ConnectionClosed, OSError):
                break
    except (WebSocketDisconnect, asyncio.CancelledError, Exception):  # noqa: BLE001
        pass
