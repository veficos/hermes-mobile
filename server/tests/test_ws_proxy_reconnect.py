"""Weak-network regression tests for `ws_proxy.py`'s upstream reconnect.

Before this change, ANY upstream gateway drop (e.g. a brief local
`hermes serve` hiccup that self-heals within seconds on its own — see
`push.py`'s gateway monitor) immediately closed every connected mobile
client's WebSocket with code 1011, forcing a full client-side reconnect +
resync cycle. These tests pin down the new behavior: a transient upstream
drop gets one short reconnect attempt on the SAME client socket, and only a
genuine client disconnect (or an upstream that never comes back within the
grace window) closes the client's connection.

Run with::

    uv run pytest tests/test_ws_proxy_reconnect.py -v
"""

from __future__ import annotations

import asyncio

from fastapi import WebSocketDisconnect

from hermes_mobile_server.ws_proxy import _pipe, _reconnect_upstream_within_grace


class _FakeUpstream:
    """Minimal stand-in for a `websockets.ClientConnection`.

    By default the frame iterator ends after the scripted frames, which
    `_read_upstream` treats exactly like a real disconnect (this is what
    lets the "transient drop" test simulate one). Pass ``terminates=False``
    for an upstream that should stay open/idle after its scripted frames —
    otherwise it would immediately look like a SECOND drop.
    """

    def __init__(self, frames: list[str], *, terminates: bool = True) -> None:
        self._frames = list(frames)
        self._terminates = terminates
        self.closed = False

    def __aiter__(self):
        async def frames():
            for value in self._frames:
                yield value
            if not self._terminates:
                await asyncio.Event().wait()

        return frames()

    async def send(self, _frame: str) -> None:
        return None

    async def close(self) -> None:
        self.closed = True


class _FakeBackend:
    """Scripts a sequence of `connect_gateway_ws` outcomes."""

    def __init__(self, connections: list) -> None:
        self._connections = list(connections)
        self.calls = 0

    async def connect_gateway_ws(self, consume_ready: bool = False):  # noqa: ARG002
        self.calls += 1
        item = self._connections.pop(0)
        if isinstance(item, Exception):
            raise item
        return item


class _FakeClientWs:
    """Minimal stand-in for the client-facing `WebSocket`."""

    def __init__(self, incoming: list[str] | None = None, *, disconnect_after: int = -1) -> None:
        self._incoming = list(incoming or [])
        self._disconnect_after = disconnect_after
        self._received = 0
        self.sent: list[str] = []
        self.closed = False
        self.close_code: int | None = None

    async def receive_text(self) -> str:
        if self._disconnect_after >= 0 and self._received >= self._disconnect_after:
            raise WebSocketDisconnect()
        if self._incoming:
            self._received += 1
            return self._incoming.pop(0)
        # Idle client: block like a real socket with nothing more to send,
        # until the caller cancels us.
        await asyncio.Event().wait()
        raise AssertionError("unreachable")

    async def send_text(self, text: str) -> None:
        self.sent.append(text)

    async def close(self, code: int | None = None, reason: str | None = None) -> None:  # noqa: ARG002
        self.closed = True
        self.close_code = code


def test_transient_upstream_drop_reconnects_without_closing_client():
    upstream1 = _FakeUpstream(["gateway.ready#1"])
    upstream2 = _FakeUpstream(["gateway.ready#2", "session.info"], terminates=False)
    backend = _FakeBackend([upstream1, RuntimeError("still down"), upstream2])
    client = _FakeClientWs()

    async def exercise() -> bool:
        task = asyncio.create_task(_pipe(client, backend))
        deadline = asyncio.get_running_loop().time() + 5.0
        while (
            len(client.sent) < 3
            and asyncio.get_running_loop().time() < deadline
        ):
            await asyncio.sleep(0.01)
        # Snapshot before cancelling: the still-running task's own teardown
        # closes the client socket too (normal cleanup), which would
        # otherwise make this assertion meaningless.
        closed_before_teardown = client.closed
        task.cancel()
        try:
            await task
        except asyncio.CancelledError:
            pass
        return closed_before_teardown

    closed_before_teardown = asyncio.run(exercise())

    # Frames from BOTH upstream generations reached the client...
    assert client.sent == ["gateway.ready#1", "gateway.ready#2", "session.info"]
    # ...and the client's own socket was never closed OVER THE BLIP ITSELF:
    # one failed retry (RuntimeError) plus one successful one, on top of
    # the initial connect — the disruptive 1011 close path was never taken.
    assert backend.calls == 3
    assert not closed_before_teardown, "a transient upstream drop must not close the client"
    assert client.close_code != 1011


def test_client_disconnect_does_not_trigger_upstream_reconnect():
    upstream = _FakeUpstream([])  # never sends anything; client goes first
    backend = _FakeBackend([upstream])
    client = _FakeClientWs(disconnect_after=0)

    async def exercise() -> None:
        await asyncio.wait_for(_pipe(client, backend), timeout=5.0)

    asyncio.run(exercise())

    assert backend.calls == 1, "a genuine client disconnect must not retry the upstream"
    assert client.closed


def test_reconnect_within_grace_gives_up_after_deadline():
    backend = _FakeBackend([RuntimeError("down"), RuntimeError("down"), RuntimeError("down")])

    async def exercise():
        return await _reconnect_upstream_within_grace(backend, grace=0.05)

    result = asyncio.run(exercise())
    assert result is None


def test_reconnect_within_grace_returns_first_success():
    upstream = _FakeUpstream(["hi"])
    backend = _FakeBackend([RuntimeError("down"), upstream])

    async def exercise():
        return await _reconnect_upstream_within_grace(backend, grace=5.0)

    result = asyncio.run(exercise())
    assert result is upstream
