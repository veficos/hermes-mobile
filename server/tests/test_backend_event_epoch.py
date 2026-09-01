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
