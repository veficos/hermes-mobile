"""Regression tests for the multi-device concurrency work (P0-P2).

Covers:
- P0: `BoundedExecutor` (concurrency.py) actually bounds concurrency and,
  critically, does not stall the asyncio event loop while a call runs — the
  bug that made one slow local file/Git op block every other concurrent
  request (REST + WS relay) on this single-process server.
- P1: `PtyManager`'s server-side terminal session cap, and the WS route
  surfacing a limit hit as a clean error frame instead of crashing the
  connection.
- P2/config: the new `Settings` fields load from their environment
  variables.

Run with::

    uv run pytest tests/test_concurrency.py -v
"""

from __future__ import annotations

import asyncio
import threading
import time
from typing import Any

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient

from hermes_mobile_server import config as server_config
from hermes_mobile_server import local_workspace
from hermes_mobile_server.app import create_app
from hermes_mobile_server.concurrency import BoundedExecutor
from hermes_mobile_server.config import Settings
from hermes_mobile_server.terminal_pty import PtyManager, PtySessionLimitError
from hermes_mobile_server.terminal_ws import build_terminal_router

AUTH = {"Authorization": "Bearer test-key-concurrency"}

# A hermes root that can never resolve, on any platform — keeps these tests
# deterministic and fast: no real backend subprocess is ever spawned, and
# `local()`/file routes (which don't need a backend) still work.
_NO_BACKEND_ROOT = "Z:\\nonexistent\\hermes\\definitely\\not\\here"


# ===========================================================================
# BoundedExecutor
# ===========================================================================


def test_bounded_executor_caps_concurrency():
    async def exercise() -> None:
        executor = BoundedExecutor(max_workers=2, thread_name_prefix="test-cap")
        lock = threading.Lock()
        current = 0
        peak = 0

        def work() -> None:
            nonlocal current, peak
            with lock:
                current += 1
                peak = max(peak, current)
            time.sleep(0.05)
            with lock:
                current -= 1

        await asyncio.gather(*(executor.run(work) for _ in range(6)))

        assert peak == 2  # never exceeded the cap
        snapshot = executor.snapshot()
        assert snapshot["completed"] == 6
        assert snapshot["in_flight"] == 0
        assert snapshot["waiting"] == 0
        executor.shutdown(wait=True)

    asyncio.run(exercise())


def test_bounded_executor_does_not_block_event_loop():
    """The core P0 regression test.

    Before the fix, `domain_api.local()` ran the blocking call directly on
    the event-loop thread. Here, a concurrent lightweight coroutine (a
    stand-in for "some other device's request") must keep making progress
    while a slow call is in flight on the executor.
    """

    async def exercise() -> None:
        executor = BoundedExecutor(max_workers=2, thread_name_prefix="test-noblock")
        ticks = 0

        async def heartbeat() -> None:
            nonlocal ticks
            for _ in range(20):
                await asyncio.sleep(0.01)
                ticks += 1

        started = time.monotonic()
        await asyncio.gather(executor.run(time.sleep, 0.3), heartbeat())
        elapsed = time.monotonic() - started

        assert ticks == 20
        # Blocked: ~0.3 (slow call) + ~0.2 (20 * 0.01 heartbeat) serialized.
        # Not blocked: ~0.3, dominated by the slow call running in parallel.
        assert elapsed < 0.4, f"event loop was stalled: took {elapsed:.3f}s"
        executor.shutdown(wait=True)

    asyncio.run(exercise())


def test_slow_file_route_does_not_block_health_endpoint(monkeypatch, tmp_path):
    """End-to-end version of the same regression, through the real ASGI app.

    Monkeypatches `local_workspace.entries` (backing `GET /api/v1/files`) to
    block until released, then fires a concurrent `GET /api/v1/health` from
    another thread and asserts it returns promptly rather than waiting for
    the slow request to finish.
    """
    release = threading.Event()
    original_entries = local_workspace.entries

    def slow_entries(path: str) -> Any:
        assert release.wait(timeout=5), "test setup bug: never released"
        return original_entries(path)

    monkeypatch.setattr(local_workspace, "entries", slow_entries)

    settings = Settings(
        api_key="test-key-concurrency",
        backend_ready_timeout=0.01,
        hermes_root_override=_NO_BACKEND_ROOT,
    )
    with TestClient(create_app(settings)) as client:
        results: dict[str, Any] = {}

        def call_files() -> None:
            results["files"] = client.get(
                "/api/v1/files", headers=AUTH, params={"path": str(tmp_path)}
            )

        def call_health() -> None:
            time.sleep(0.1)  # let the /files request get in flight first
            started = time.monotonic()
            results["health"] = client.get("/api/v1/health")
            results["health_elapsed"] = time.monotonic() - started

        files_thread = threading.Thread(target=call_files)
        health_thread = threading.Thread(target=call_health)
        files_thread.start()
        health_thread.start()
        health_thread.join(timeout=5)
        release.set()
        files_thread.join(timeout=5)

        assert results["health"].status_code == 200
        assert results["health_elapsed"] < 1.0, (
            "/api/v1/health waited on the in-flight /api/v1/files call — "
            "the event loop was blocked"
        )
        assert results["files"].status_code == 200


# ===========================================================================
# PtyManager session cap
# ===========================================================================


class _FakeProcess:
    """Stand-in for a real PTY process — avoids spawning real shells."""

    def __init__(self) -> None:
        self.pid = 0
        self._alive = True

    def isalive(self) -> bool:
        return self._alive

    def read(self, _n: int) -> str:
        time.sleep(0.01)
        return ""

    def write(self, _data: str) -> None:
        return None

    def setwinsize(self, _rows: int, _cols: int) -> None:
        return None

    def terminate(self, force: bool = False) -> None:  # noqa: ARG002
        self._alive = False

    def wait(self) -> int:
        return 0


def _patch_fake_spawn(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(
        PtyManager,
        "_spawn",
        staticmethod(lambda cwd, cols, rows: (_FakeProcess(), "fake-shell")),  # noqa: ARG005
    )


def test_pty_manager_enforces_session_limit(monkeypatch, tmp_path):
    _patch_fake_spawn(monkeypatch)

    async def exercise() -> None:
        manager = PtyManager(max_sessions=2)
        try:
            s1 = await manager.start(asyncio.Queue(), cwd=str(tmp_path), cols=80, rows=24)
            await manager.start(asyncio.Queue(), cwd=str(tmp_path), cols=80, rows=24)
            assert manager.snapshot() == {
                "active": 2,
                "orphaned": 0,
                "max_sessions": 2,
            }

            with pytest.raises(PtySessionLimitError):
                await manager.start(asyncio.Queue(), cwd=str(tmp_path), cols=80, rows=24)

            # Freeing a slot must let a new session through again.
            assert await manager.dispose(s1["id"])
            s3 = await manager.start(asyncio.Queue(), cwd=str(tmp_path), cols=80, rows=24)
            assert s3["id"]
        finally:
            await manager.close_all()

    asyncio.run(exercise())


def test_pty_manager_unlimited_by_default(monkeypatch, tmp_path):
    """No `max_sessions` (the pre-existing default) means no cap."""
    _patch_fake_spawn(monkeypatch)

    async def exercise() -> None:
        manager = PtyManager()
        try:
            for _ in range(5):
                await manager.start(asyncio.Queue(), cwd=str(tmp_path), cols=80, rows=24)
            assert manager.snapshot()["active"] == 5
        finally:
            await manager.close_all()

    asyncio.run(exercise())


def test_terminal_ws_reports_session_limit_as_error_frame(monkeypatch):
    """The limit must surface as a clean `error` event, not a dropped socket."""
    _patch_fake_spawn(monkeypatch)

    settings = Settings(api_key="test-key-concurrency")
    manager = PtyManager(max_sessions=1)
    app = FastAPI()
    app.include_router(build_terminal_router(settings, manager))

    with TestClient(app) as client:
        with client.websocket_connect(
            "/api/v1/terminal/ws?token=test-key-concurrency"
        ) as ws1:
            ws1.send_json({"op": "start", "request_id": "1"})
            frame1 = ws1.receive_json()
            assert frame1["event"] == "started"

            with client.websocket_connect(
                "/api/v1/terminal/ws?token=test-key-concurrency"
            ) as ws2:
                ws2.send_json({"op": "start", "request_id": "2"})
                frame2 = ws2.receive_json()
                assert frame2["event"] == "error"
                assert "limit" in frame2["message"]

                # The connection must stay usable after the error frame.
                ws2.send_json(
                    {
                        "op": "resize",
                        "id": "nonexistent",
                        "cols": 80,
                        "rows": 24,
                        "request_id": "3",
                    }
                )
                ack = ws2.receive_json()
                assert ack["event"] == "ack"
                assert ack["ok"] is False


# ===========================================================================
# Settings
# ===========================================================================


def test_concurrency_settings_load_from_environment(monkeypatch):
    monkeypatch.setenv("HERMES_MOBILE_API_KEY", "test-key")
    monkeypatch.setenv("HERMES_MOBILE_LOCAL_FS_WORKERS", "9")
    monkeypatch.setenv("HERMES_MOBILE_TERMINAL_SESSION_LIMIT", "3")
    monkeypatch.setenv("HERMES_MOBILE_CONCURRENCY_LIMIT", "50")

    settings = server_config.load_settings()

    assert settings.local_fs_max_workers == 9
    assert settings.terminal_session_limit == 3
    assert settings.request_concurrency_limit == 50


def test_concurrency_settings_defaults():
    settings = Settings(api_key="test-key")
    assert settings.local_fs_max_workers == 4
    assert settings.terminal_session_limit == 8
    assert settings.request_concurrency_limit == 200


# ===========================================================================
# /api/v1/network/metrics exposes the new concurrency snapshot (P3)
# ===========================================================================


def test_network_metrics_exposes_concurrency_snapshot():
    settings = Settings(
        api_key="test-key-concurrency",
        backend_ready_timeout=0.01,
        hermes_root_override=_NO_BACKEND_ROOT,
    )
    with TestClient(create_app(settings)) as client:
        resp = client.get("/api/v1/network/metrics", headers=AUTH)
        assert resp.status_code == 200
        body = resp.json()
        assert "concurrency" in body
        concurrency = body["concurrency"]
        assert concurrency["local_workspace_pool"]["max_workers"] == 4
        assert concurrency["terminal_sessions"] == {
            "active": 0,
            "orphaned": 0,
            "max_sessions": 8,
        }
        # Whether a real hermes-agent install happens to resolve on the test
        # machine or not, the backend never actually starts (bogus override
        # / near-zero ready timeout): either no snapshot (`state.backend is
        # None`), or one reporting a disconnected gateway — never fabricated.
        gateway_rpc = concurrency["gateway_rpc"]
        if gateway_rpc is not None:
            assert gateway_rpc == {"gateway_connected": False, "in_flight_rpcs": 0}
