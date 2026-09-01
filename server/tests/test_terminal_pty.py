from __future__ import annotations

import asyncio
import os
import sys

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
