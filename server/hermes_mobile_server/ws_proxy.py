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
reconnects before the client notices — see ``_UPSTREAM_RECONNECT_GRACE``.
The reconnected upstream's ``gateway.ready`` handshake frame passes through
to the client like any other frame, which the client's existing
``gateway.ready``-triggered ``session.resume`` reconciliation (Flutter
``SessionStore``) already treats as "resync now" — so a brief local
``hermes serve`` hiccup (it self-heals on its own within seconds, see
``push.py``'s gateway monitor) no longer forces every connected mobile
device through a full WS reconnect + "reconnecting…" banner cycle. Only an
upstream outage that outlasts the grace window still closes the client
socket, which is when the client's own reconnection logic takes over.
"""

from __future__ import annotations

import asyncio
import hmac
import logging
import re
import time
from urllib.parse import quote, urlencode

import websockets
from fastapi import APIRouter, Depends, WebSocket, WebSocketDisconnect

from .backend import BackendError, BackendManager
from .config import Settings
from .network_observability import NetworkMetrics, WebSocketConnectionLimiter

logger = logging.getLogger("hermes_mobile_server.ws")

#: Seconds to keep retrying the upstream gateway connection.
_UPSTREAM_RETRY_WINDOW = 15.0

#: Seconds to retry the upstream gateway for an ALREADY-OPEN client pipe
#: before giving up and closing the client socket. Deliberately shorter
#: than `_UPSTREAM_RETRY_WINDOW` (that one covers the slow initial-boot
#: case): the gateway monitor in push.py reconnects a dropped upstream
#: within ~10s on its own, so this just needs to outlast a typical local
#: hiccup, not hold an already-connected client hostage indefinitely.
_UPSTREAM_RECONNECT_GRACE = 8.0

#: How long a reconnected upstream has to stay up before a later drop counts
#: as a NEW episode (its own fresh `_UPSTREAM_RECONNECT_GRACE`) rather than
#: a continuation of the current one. Keeps a rapidly connect-then-instantly
#: -die upstream from holding the client "reconnecting" forever one
#: technically-successful connect at a time.
_STABLE_CONNECTION_SECONDS = 2.0
_PLUGIN_ID = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$")


def build_ws_router(
    settings: Settings,
    backend: BackendManager | None,
    metrics: NetworkMetrics | None = None,
    limiter: WebSocketConnectionLimiter | None = None,
) -> APIRouter:
    metrics = metrics or NetworkMetrics()
    limiter = limiter or WebSocketConnectionLimiter(settings.websocket_max_per_client)
    router = APIRouter(tags=["gateway-proxy"])

    @router.websocket("/api/v1/ws")
    async def gateway_ws(ws: WebSocket) -> None:
        # -- authenticate ---------------------------------------------------
        if not await _authenticate(ws, settings):
            return

        async with limiter.slot(ws) as allowed:
            if not allowed:
                metrics.reject("gateway")
                await ws.accept()
                await ws.close(code=4429, reason="too many websocket connections")
                return
            await ws.accept()
            await _pipe(
                ws, backend, metrics=metrics, client_key=limiter.client_key(ws)
            )

    @router.websocket("/api/v1/plugins/{plugin_id}/{event_path:path}")
    async def plugin_ws(ws: WebSocket, plugin_id: str, event_path: str) -> None:
        if not await _authenticate(ws, settings):
            return
        if not _valid_plugin_path(plugin_id, event_path):
            await ws.accept()
            await ws.close(code=4400, reason="invalid plugin socket path")
            return
        async with limiter.slot(ws) as allowed:
            if not allowed:
                metrics.reject("plugin")
                await ws.accept()
                await ws.close(code=4429, reason="too many websocket connections")
                return
            await ws.accept()
            await _pipe_plugin(
                ws, backend, plugin_id, event_path, metrics, limiter.client_key(ws)
            )

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
    metrics: NetworkMetrics | None = None,
    client_key: str = "unknown",
) -> None:
    started = time.monotonic()
    reason = "client closed"
    if backend is None or not backend.is_running:
        if metrics is not None:
            metrics.handshake_failed("plugin", "upstream unavailable")
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
        if metrics is not None:
            metrics.handshake_failed("plugin", str(exc))
        logger.warning("Plugin socket connect failed for %s: %s", plugin_id, exc)
        await client_ws.close(code=1011, reason="plugin socket unavailable")
        return
    if metrics is not None:
        metrics.connected("plugin", time.monotonic() - started, client_key)

    try:
        reason = await relay_websockets(client_ws, upstream)
    finally:
        if metrics is not None:
            metrics.disconnected("plugin", reason)


async def relay_websockets(
    client_ws: WebSocket, upstream: websockets.ClientConnection
) -> str:
    """Shared bidirectional relay with prompt peer cleanup and backpressure."""
    upstream_task = asyncio.create_task(_copy_plugin_upstream(upstream, client_ws))
    client_task = asyncio.create_task(_copy_plugin_client(client_ws, upstream))
    done, pending = await asyncio.wait(
        {upstream_task, client_task},
        return_when=asyncio.FIRST_COMPLETED,
    )
    reason = "upstream closed" if upstream_task in done else "client closed"
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
    return reason


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


async def _pipe(
    client_ws: WebSocket,
    backend: BackendManager | None,
    *,
    metrics: NetworkMetrics | None = None,
    client_key: str = "unknown",
) -> None:
    """Connect to the upstream gateway and relay frames both ways.

    An upstream drop mid-session gets one short reconnect attempt (see
    `_UPSTREAM_RECONNECT_GRACE`) on the SAME client socket before giving up
    — see the module docstring for why that's safe and useful.

    Known trade-off: a client-sent frame that lands exactly during the
    reconnect gap (upstream already dead, new one not yet up) is not
    queued for replay — `_pipe_once` is torn down and rebuilt per upstream,
    same as `_read_client`. Unlike the upstream->client direction (an
    ordered event log the client can't reconstruct on its own), a lost
    client request is something the existing client-side timeout/retry
    path (chat send's manual retry, `gatewayTimeout`) already has to
    handle for other reasons, so it's an acceptable gap rather than one
    worth a fully gapless bidirectional buffer.
    """
    if backend is None:
        if metrics is not None:
            metrics.handshake_failed("gateway", "upstream unavailable")
        await client_ws.close(code=1011, reason="no hermes runtime available")
        return
    upstream: websockets.ClientConnection | None = None
    started = time.monotonic()
    disconnect_reason = "client closed"
    client_closed = False
    try:
        upstream = await _connect_upstream(backend)
    except Exception as exc:  # noqa: BLE001 - surface any upstream failure
        if metrics is not None:
            metrics.handshake_failed("gateway", str(exc))
        logger.error("Upstream gateway connect failed: %s", exc)
        await client_ws.close(code=1011, reason="backend gateway unavailable")
        return
    if metrics is not None:
        metrics.connected("gateway", time.monotonic() - started, client_key)

    loop = asyncio.get_running_loop()
    # Bounds an entire flappy-upstream EPISODE, not each individual retry
    # batch: a connection that comes back but dies again in well under
    # `_STABLE_CONNECTION_SECONDS` doesn't get a fresh full grace window —
    # otherwise a rapidly connect/immediately-die upstream could hold the
    # client "reconnecting" indefinitely, one instantly-successful connect
    # at a time, never actually hitting `_reconnect_upstream_within_grace`'s
    # own failure path.
    trouble_deadline: float | None = None
    try:
        while True:
            attempt_started = loop.time()
            outcome = await _pipe_once(client_ws, upstream)
            try:
                await upstream.close()
            except Exception:  # noqa: BLE001
                pass
            if outcome == "client_closed":
                return
            # outcome == "upstream_closed": the gateway went away, not the
            # client — give it a short window to come back on its own
            # (push.py's monitor usually beats us to it) before punting the
            # client into its own, more disruptive reconnect flow.
            now = loop.time()
            if now - attempt_started >= _STABLE_CONNECTION_SECONDS:
                trouble_deadline = None  # that connection had recovered
            if trouble_deadline is None:
                trouble_deadline = now + _UPSTREAM_RECONNECT_GRACE
            elif now >= trouble_deadline:
                disconnect_reason = "upstream closed"
                logger.warning(
                    "Upstream gateway kept dropping past the reconnect grace "
                    "window; closing mobile client"
                )
                await client_ws.close(code=1011, reason="backend gateway disconnected")
                client_closed = True
                return
            logger.warning(
                "Upstream gateway disconnected; attempting reconnect within %.1fs",
                trouble_deadline - now,
            )
            reconnected = await _reconnect_upstream_within_grace(
                backend, grace=trouble_deadline - now
            )
            if reconnected is None:
                disconnect_reason = "upstream closed"
                logger.warning(
                    "Upstream gateway did not return in time; closing mobile client"
                )
                await client_ws.close(code=1011, reason="backend gateway disconnected")
                client_closed = True
                return
            upstream = reconnected
    finally:
        if upstream is not None:
            try:
                await upstream.close()
            except Exception:  # noqa: BLE001
                pass
        if not client_closed:
            try:
                await client_ws.close()
            except Exception:  # noqa: BLE001
                pass
        if metrics is not None:
            metrics.disconnected("gateway", disconnect_reason)


async def _pipe_once(
    client_ws: WebSocket, upstream: websockets.ClientConnection
) -> str:
    """Relay frames for one upstream connection's lifetime.

    Returns ``"client_closed"`` if the mobile client went away, or
    ``"upstream_closed"`` if the *upstream* dropped while the client is
    still there — the caller uses this to tell those apart and only closes
    the client socket in the former case. Does not close either socket
    itself; the caller owns that.
    """
    client_queue: asyncio.Queue[str | None] = asyncio.Queue(maxsize=256)
    upstream_task = asyncio.create_task(_read_upstream(upstream, client_queue))
    client_task = asyncio.create_task(_read_client(client_ws, upstream))
    queue_task: asyncio.Task[str | None] | None = None
    try:
        while True:
            queue_task = asyncio.create_task(client_queue.get())
            done, _ = await asyncio.wait(
                {queue_task, client_task}, return_when=asyncio.FIRST_COMPLETED
            )
            if client_task in done:
                # Do not retain an upstream socket indefinitely when a mobile
                # client disappears while the gateway is otherwise idle.
                queue_task.cancel()
                try:
                    await queue_task
                except asyncio.CancelledError:
                    pass
                queue_task = None
                try:
                    client_outcome = client_task.result()
                except Exception:  # noqa: BLE001
                    client_outcome = "client_gone"
                return (
                    "upstream_closed"
                    if client_outcome == "upstream_gone"
                    else "client_closed"
                )
            frame = queue_task.result()
            queue_task = None
            if frame is None:
                return "upstream_closed"
            try:
                await client_ws.send_text(frame)
            except Exception:  # client went away
                return "client_closed"
    finally:
        if queue_task is not None:
            queue_task.cancel()
        client_task.cancel()
        upstream_task.cancel()
        for task in (client_task, upstream_task):
            try:
                await task
            except (asyncio.CancelledError, Exception):  # noqa: BLE001
                pass


async def _reconnect_upstream_within_grace(
    backend: BackendManager,
    *,
    grace: float | None = None,
) -> websockets.ClientConnection | None:
    """Best-effort short retry loop for an already-open client pipe.

    Distinct from `_connect_upstream`'s longer boot-time retry
    (`_UPSTREAM_RETRY_WINDOW`): this is for a client mid-session, so it
    gives up quickly rather than holding the client hostage.

    ``grace`` defaults to the module-level `_UPSTREAM_RECONNECT_GRACE`,
    looked up at call time rather than baked into the signature — tests
    can `monkeypatch` that module attribute to keep this fast without
    needing to thread an override through every caller (`_pipe` included).
    """
    if grace is None:
        grace = _UPSTREAM_RECONNECT_GRACE
    loop = asyncio.get_running_loop()
    deadline = loop.time() + grace
    delay = 0.5
    while loop.time() < deadline:
        try:
            return await backend.connect_gateway_ws(consume_ready=False)
        except Exception:  # noqa: BLE001
            remaining = deadline - loop.time()
            if remaining <= 0:
                break
            await asyncio.sleep(min(delay, remaining))
            delay = min(delay * 1.5, 2.0)
    return None


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
    cancelled = False
    try:
        async for message in upstream:
            if isinstance(message, bytes):
                message = message.decode("utf-8", "replace")
            # Gateway frames are an ordered event log, not replaceable state
            # snapshots: dropping a message.delta/tool.start/approval.request
            # corrupts the client transcript. Backpressure the upstream reader
            # until the mobile socket catches up instead of discarding frames.
            await queue.put(message)
    except asyncio.CancelledError:
        cancelled = True
        raise
    except websockets.ConnectionClosed:
        pass
    finally:
        # A cancelled reader belongs to a pipe that is already tearing down.
        # Blocking on a full queue here would deadlock cleanup because there is
        # no remaining mobile writer to drain it. Natural upstream closure
        # still uses an ordered sentinel after all queued frames.
        if not cancelled:
            await queue.put(None)


async def _read_client(client_ws: WebSocket, upstream: websockets.ClientConnection) -> str:
    """Relay client frames (RPC requests) to the upstream gateway.

    Returns ``"client_gone"`` if the client's socket closed/errored, or
    ``"upstream_gone"`` if a send to the upstream failed while the client
    itself is still there — `_pipe_once` uses this to avoid mistaking an
    upstream drop for the client disconnecting.
    """
    try:
        while True:
            frame = await client_ws.receive_text()
            try:
                await upstream.send(frame)
            except (websockets.ConnectionClosed, OSError):
                return "upstream_gone"
    except (WebSocketDisconnect, asyncio.CancelledError):
        return "client_gone"
    except Exception:  # noqa: BLE001
        return "client_gone"
