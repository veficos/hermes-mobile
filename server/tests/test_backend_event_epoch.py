from __future__ import annotations

import asyncio
import json

from hermes_mobile_server.backend import BackendManager
from hermes_mobile_server.config import Settings
from hermes_mobile_server.runtime import HermesRuntime


class _Frames:
    def __init__(self, frames: list[dict]) -> None:
        self.frames = frames

    def __aiter__(self):
        async def iterate():
            for frame in self.frames:
                yield json.dumps(frame)

        return iterate()


def test_stale_gateway_reader_epoch_cannot_publish_events(tmp_path) -> None:
    manager = BackendManager(
        Settings(),
        HermesRuntime(
            kind="test",
            source_root=tmp_path,
            python=None,
            argv=[],
        ),
    )
    received: list[dict] = []

    async def listener(event: dict) -> None:
        received.append(event)

    manager.add_event_listener(listener)
    manager._gw_ws = _Frames(  # type: ignore[assignment]
        [
            {
                "method": "event",
                "params": {
                    "type": "message.start",
                    "session_id": "old-runtime",
                },
            }
        ]
    )
    manager._backend_epoch = 2

    asyncio.run(manager._gw_read_loop(1))

    assert received == []


def test_gateway_rpc_waits_do_not_serialize_independent_requests(tmp_path) -> None:
    manager = BackendManager(
        Settings(),
        HermesRuntime(kind="test", source_root=tmp_path, python=None, argv=[]),
    )

    class Socket:
        def __init__(self) -> None:
            self.frames: list[dict] = []

        async def send(self, raw: str) -> None:
            self.frames.append(json.loads(raw))

    socket = Socket()
    manager._gw_ws = socket  # type: ignore[assignment]

    async def already_connected() -> None:
        return None

    manager._ensure_gateway_rpc = already_connected  # type: ignore[method-assign]

    async def exercise() -> tuple[list[dict], list[dict]]:
        first = asyncio.create_task(manager.gateway_rpc("slow.first"))
        second = asyncio.create_task(manager.gateway_rpc("fast.second"))
        await asyncio.sleep(0)
        await asyncio.sleep(0)
        sent = list(socket.frames)
        assert len(sent) == 2
        for frame in reversed(sent):
            manager._gw_pending[frame["id"]].set_result({"method": frame["method"]})
        return sent, await asyncio.gather(first, second)

    sent, results = asyncio.run(exercise())
    assert [frame["method"] for frame in sent] == ["slow.first", "fast.second"]
    assert results == [{"method": "slow.first"}, {"method": "fast.second"}]


def test_gateway_rpc_send_failure_invalidates_socket(tmp_path) -> None:
    manager = BackendManager(
        Settings(),
        HermesRuntime(kind="test", source_root=tmp_path, python=None, argv=[]),
    )

    class BrokenSocket:
        closed = False

        async def send(self, raw: str) -> None:
            raise OSError("network reset")

        async def close(self) -> None:
            self.closed = True

    socket = BrokenSocket()
    manager._gw_ws = socket  # type: ignore[assignment]

    async def already_connected() -> None:
        return None

    manager._ensure_gateway_rpc = already_connected  # type: ignore[method-assign]

    async def exercise() -> None:
        try:
            await manager.gateway_rpc("test.method")
        except OSError:
            pass
        else:
            raise AssertionError("send failure must propagate")

    asyncio.run(exercise())
    assert manager._gw_ws is None
    assert socket.closed is True
    assert manager._gw_pending == {}
