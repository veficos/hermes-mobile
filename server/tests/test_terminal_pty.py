from __future__ import annotations

import asyncio
import os
import sys
import threading
import time

import pytest

from hermes_mobile_server.terminal_pty import PtyManager


@pytest.mark.skipif(sys.platform != "win32", reason="Windows ConPTY regression")
def test_windows_pty_streams_ansi_resizes_and_disposes(tmp_path):
    async def exercise():
        manager = PtyManager()
        output: asyncio.Queue[dict] = asyncio.Queue()
        started = await manager.start(
            output, cwd=str(tmp_path), cols=80, rows=24
        )
        assert started["id"]
        assert started["cwd"] == str(tmp_path)
        assert manager.write(
            started["id"], "Write-Output '__TERMINAL_PTY_TEST__'\r"
        )

        transcript = ""
        for _ in range(200):
            frame = await asyncio.wait_for(output.get(), timeout=10)
            if frame["event"] == "data":
                transcript += frame["data"]
            if "__TERMINAL_PTY_TEST__" in transcript:
                break

        assert "__TERMINAL_PTY_TEST__" in transcript
        assert "\x1b[" in transcript
        assert manager.resize(started["id"], 100, 30)
        assert await manager.dispose(started["id"])
        assert not manager.write(started["id"], "echo orphan\r")

    asyncio.run(exercise())


def test_invalid_cwd_falls_back_to_real_home(tmp_path):
    missing = tmp_path / "missing"
    resolved = PtyManager._safe_cwd(str(missing))
    assert resolved
    assert resolved != str(missing)


def test_wrap_command_with_cwd_is_posix_safe():
    """Mirror domain_api terminal/execute cwd wrapping for non-Windows."""
    command = "echo hi"
    target = "/tmp/work's"
    if os.name == "nt":
        escaped = target.replace('"', '""')
        executable = f'cd /d "{escaped}" && {command}'
        assert "cd /d" in executable
    else:
        escaped = target.replace("'", "'\"'\"'")
        executable = f"cd '{escaped}' && {command}"
        assert executable.startswith("cd '/tmp/work'\"'\"'s'")
        assert executable.endswith(" && echo hi")


def test_probe_cwd_returns_none_for_missing_pid():
    class Fake:
        pid = -1

    assert PtyManager._probe_process_cwd(Fake()) is None


@pytest.mark.skipif(
    not sys.platform.startswith("linux"), reason="Linux /proc cwd"
)
def test_probe_cwd_reads_proc_for_self():
    class Fake:
        pid = os.getpid()

    cwd = PtyManager._probe_process_cwd(Fake())
    assert cwd is not None
    assert os.path.isdir(cwd)


class _ScriptedProcess:
    """A controllable stand-in PTY process — no real shell spawned.

    `.read()` returns queued chunks one at a time (via `push`), or "" (no
    data, matching a real non-blocking read) when the queue is empty.
    """

    def __init__(self) -> None:
        self.pid = 0
        self._alive = True
        self._chunks: list[str] = []
        self._lock = threading.Lock()

    def push(self, data: str) -> None:
        with self._lock:
            self._chunks.append(data)

    def isalive(self) -> bool:
        return self._alive

    def read(self, _n: int) -> str:
        with self._lock:
            if self._chunks:
                return self._chunks.pop(0)
        # Matches a real blocking read: don't spin the reader loop (and the
        # thread-pool submissions behind `asyncio.to_thread`) unbounded.
        time.sleep(0.005)
        return ""

    def write(self, _data: str) -> None:
        return None

    def setwinsize(self, _rows: int, _cols: int) -> None:
        return None

    def terminate(self, force: bool = False) -> None:  # noqa: ARG002
        self._alive = False

    def wait(self) -> int:
        return 0


def test_orphan_backlog_is_replayed_on_reattach(monkeypatch, tmp_path):
    """Weak-network regression: output produced during a WS drop must not
    silently vanish — see `_ORPHAN_BACKLOG_FRAMES` in terminal_pty.py."""
    processes: list[_ScriptedProcess] = []

    def fake_spawn(cwd, cols, rows):  # noqa: ARG001
        proc = _ScriptedProcess()
        processes.append(proc)
        return proc, "fake-shell"

    monkeypatch.setattr(PtyManager, "_spawn", staticmethod(fake_spawn))

    async def exercise() -> None:
        manager = PtyManager()
        try:
            first_output: asyncio.Queue = asyncio.Queue()
            started = await manager.start(
                first_output, cwd=str(tmp_path), cols=80, rows=24
            )
            sid = started["id"]
            proc = processes[0]

            # Simulate the mobile WS dropping: the session is orphaned, so
            # `first_output` has no consumer anymore.
            assert manager.orphan(sid)

            proc.push("line-1\n")
            proc.push("line-2\n")
            orphan_session = manager._orphans[sid].session
            for _ in range(200):
                if len(orphan_session.backlog) >= 2:
                    break
                await asyncio.sleep(0.005)
            assert list(f["data"] for f in orphan_session.backlog) == [
                "line-1\n",
                "line-2\n",
            ]
            # Nothing was pushed into the old (undrained) queue's consumer
            # side — it was captured in the backlog instead.
            assert first_output.empty()

            # Reattach with a brand-new queue: the backlog must replay into
            # it, in order, before live delivery resumes.
            second_output: asyncio.Queue = asyncio.Queue()
            reattached = manager.reattach(sid, second_output)
            assert reattached is not None and reattached["id"] == sid

            assert second_output.get_nowait()["data"] == "line-1\n"
            assert second_output.get_nowait()["data"] == "line-2\n"
            assert second_output.empty()
            assert len(orphan_session.backlog) == 0

            # Live delivery continues normally afterward.
            proc.push("line-3\n")
            frame = await asyncio.wait_for(second_output.get(), timeout=2)
            assert frame["data"] == "line-3\n"
        finally:
            await manager.close_all()

    asyncio.run(exercise())
