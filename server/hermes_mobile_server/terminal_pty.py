"""Interactive PTY sessions matching the Desktop terminal IPC contract."""

from __future__ import annotations

import asyncio
import os
import shutil
import shlex
import subprocess
import sys
import uuid
from dataclasses import dataclass
from pathlib import Path
from typing import Any


# After the owning WebSocket drops, keep the PTY alive briefly so a flaky
# mobile reconnect can reattach instead of spawning a fresh shell.
_ORPHAN_GRACE_SECONDS = 90.0


@dataclass
class PtySession:
    id: str
    process: Any
    cwd: str
    shell: str
    output: asyncio.Queue[dict[str, Any]]
    reader: asyncio.Task[None]


@dataclass
class _Orphan:
    session: PtySession
    handle: asyncio.TimerHandle


class PtyManager:
    """Own interactive shells for authenticated mobile WebSocket clients."""

    def __init__(self) -> None:
        self._sessions: dict[str, PtySession] = {}
        self._orphans: dict[str, _Orphan] = {}

    async def start(
        self,
        output: asyncio.Queue[dict[str, Any]],
        *,
        cwd: str | None,
        cols: int,
        rows: int,
    ) -> dict[str, Any]:
        resolved_cwd = self._safe_cwd(cwd)
        process, shell = self._spawn(resolved_cwd, cols, rows)
        session_id = str(uuid.uuid4())
        reader = asyncio.create_task(
            self._read_loop(session_id, process),
            name=f"terminal-reader-{session_id}",
        )
        self._sessions[session_id] = PtySession(
            session_id, process, resolved_cwd, shell, output, reader
        )
        return {"id": session_id, "cwd": resolved_cwd, "shell": shell}

    async def start_ssh(
        self,
        output: asyncio.Queue[dict[str, Any]],
        *,
        host: str,
        user: str,
        port: int | None,
        identity_file: str,
        cwd: str | None,
        cols: int,
        rows: int,
    ) -> dict[str, Any]:
        """Start an interactive SSH PTY using server-side SSH credentials."""
        if sys.platform == "win32":
            raise RuntimeError("SSH terminal is not supported by this server platform")
        ssh = shutil.which("ssh")
        if ssh is None:
            raise RuntimeError("OpenSSH client is not installed on the Hermes server")
        host = host.strip()
        user = user.strip()
        if (not host or host.startswith("-") or any(ch in host for ch in "\r\n\0") or
                any(ch in user for ch in "\r\n\0@")):
            raise ValueError("invalid SSH host or user")
        if port is not None and not 1 <= port <= 65535:
            raise ValueError("invalid SSH port")
        target = f"{user}@{host}" if user and "@" not in host else host
        args = [
            ssh, "-tt", "-o", "BatchMode=yes", "-o", "ConnectTimeout=15",
            "-o", "StrictHostKeyChecking=accept-new",
        ]
        if port is not None:
            args += ["-p", str(port)]
        if identity_file.strip():
            args += ["-i", str(Path(identity_file).expanduser())]
        args.append(target)
        if cwd and cwd.strip():
            args.append(f"cd -- {shlex.quote(cwd.strip())} && exec ${{SHELL:-/bin/sh}} -l")
        process = self._spawn_argv(args, str(Path.home()), cols, rows)
        session_id = str(uuid.uuid4())
        reader = asyncio.create_task(self._read_loop(session_id, process), name=f"ssh-terminal-reader-{session_id}")
        remote_cwd = cwd.strip() if cwd else ""
        self._sessions[session_id] = PtySession(
            session_id, process, remote_cwd, f"ssh:{host}", output, reader
        )
        return {"id": session_id, "cwd": remote_cwd, "shell": f"SSH {host}"}

    def write(self, session_id: str, data: str) -> bool:
        session = self._lookup(session_id)
        if session is None or not self._alive(session.process):
            return False
        session.process.write(data)
        return True

    def resize(self, session_id: str, cols: int, rows: int) -> bool:
        session = self._lookup(session_id)
        if session is None or not self._alive(session.process):
            return False
        session.process.setwinsize(max(2, rows), max(2, cols))
        return True

    def cwd(self, session_id: str) -> str | None:
        session = self._lookup(session_id)
        if session is None:
            return None
        live = self._probe_process_cwd(session.process)
        if live:
            session.cwd = live
        return session.cwd

    def reattach(
        self,
        session_id: str,
        output: asyncio.Queue[dict[str, Any]],
    ) -> dict[str, Any] | None:
        """Reclaim an orphaned PTY after a brief WebSocket drop."""
        orphan = self._orphans.pop(session_id, None)
        if orphan is None:
            return None
        orphan.handle.cancel()
        session = orphan.session
        if not self._alive(session.process):
            asyncio.create_task(self._finalize_session(session))
            return None
        session.output = output
        self._sessions[session.id] = session
        live = self._probe_process_cwd(session.process) or session.cwd
        session.cwd = live
        return {"id": session.id, "cwd": live, "shell": session.shell}

    def orphan(self, session_id: str) -> bool:
        """Detach ownership but keep the process for a short grace window."""
        session = self._sessions.pop(session_id, None)
        if session is None:
            return False
        if not self._alive(session.process):
            asyncio.create_task(self._finalize_session(session))
            return False
        loop = asyncio.get_running_loop()
        handle = loop.call_later(
            _ORPHAN_GRACE_SECONDS,
            lambda sid=session_id: asyncio.create_task(self._expire_orphan(sid)),
        )
        self._orphans[session_id] = _Orphan(session, handle)
        return True

    async def orphan_many(self, session_ids: set[str]) -> None:
        for sid in list(session_ids):
            self.orphan(sid)

    async def dispose(self, session_id: str) -> bool:
        orphan = self._orphans.pop(session_id, None)
        if orphan is not None:
            orphan.handle.cancel()
            await self._finalize_session(orphan.session)
            return True
        session = self._sessions.pop(session_id, None)
        if session is None:
            return False
        await self._finalize_session(session)
        return True

    async def dispose_many(self, session_ids: set[str]) -> None:
        await asyncio.gather(
            *(self.dispose(session_id) for session_id in list(session_ids)),
            return_exceptions=True,
        )

    async def close_all(self) -> None:
        ids = set(self._sessions) | set(self._orphans)
        await self.dispose_many(ids)

    def _lookup(self, session_id: str) -> PtySession | None:
        return self._sessions.get(session_id)

    async def _expire_orphan(self, session_id: str) -> None:
        orphan = self._orphans.pop(session_id, None)
        if orphan is None:
            return
        await self._finalize_session(orphan.session)

    async def _finalize_session(self, session: PtySession) -> None:
        self._terminate(session.process)
        if session.reader is not asyncio.current_task() and not session.reader.done():
            session.reader.cancel()
            try:
                await session.reader
            except (asyncio.CancelledError, Exception):
                pass

    async def _read_loop(self, session_id: str, process: Any) -> None:
        exit_code: int | None = None
        last_queue: asyncio.Queue[dict[str, Any]] | None = None
        try:
            while self._alive(process):
                session = self._sessions.get(session_id) or (
                    self._orphans[session_id].session
                    if session_id in self._orphans
                    else None
                )
                if session is None:
                    break
                last_queue = session.output
                chunk = await asyncio.to_thread(process.read, 4096)
                if chunk:
                    await session.output.put(
                        {"event": "data", "id": session_id, "data": chunk}
                    )
                elif not self._alive(process):
                    break
            try:
                exit_code = process.wait()
            except Exception:
                exit_code = getattr(process, "exitstatus", None)
        except asyncio.CancelledError:
            raise
        except Exception as exc:
            session = self._sessions.get(session_id) or (
                self._orphans[session_id].session
                if session_id in self._orphans
                else None
            )
            if session is not None:
                last_queue = session.output
                await session.output.put(
                    {"event": "error", "id": session_id, "message": str(exc)}
                )
        finally:
            self._sessions.pop(session_id, None)
            orphan = self._orphans.pop(session_id, None)
            if orphan is not None:
                orphan.handle.cancel()
                last_queue = orphan.session.output
            if last_queue is not None:
                await last_queue.put(
                    {
                        "event": "exit",
                        "id": session_id,
                        "code": exit_code,
                        "signal": None,
                    }
                )

    @staticmethod
    def _safe_cwd(value: str | None) -> str:
        candidate = Path(value).expanduser() if value else Path.home()
        try:
            resolved = candidate.resolve(strict=True)
        except (OSError, RuntimeError):
            resolved = Path.home().resolve()
        return str(resolved if resolved.is_dir() else Path.home().resolve())

    @staticmethod
    def _probe_process_cwd(process: Any) -> str | None:
        """Best-effort live cwd (Linux /proc; macOS lsof; else None)."""
        pid = getattr(process, "pid", None)
        if not isinstance(pid, int) or pid <= 0:
            return None
        if sys.platform.startswith("linux"):
            try:
                return str(Path(f"/proc/{pid}/cwd").resolve(strict=True))
            except (OSError, RuntimeError):
                return None
        if sys.platform == "darwin":
            try:
                result = subprocess.run(
                    ["lsof", "-a", "-p", str(pid), "-d", "cwd", "-Fn"],
                    capture_output=True,
                    text=True,
                    timeout=1.5,
                    check=False,
                )
                for line in result.stdout.splitlines():
                    if line.startswith("n"):
                        path = line[1:].strip()
                        if path:
                            return path
            except (OSError, subprocess.SubprocessError):
                return None
        return None

    @staticmethod
    def _spawn(cwd: str, cols: int, rows: int) -> tuple[Any, str]:
        env = {
            **os.environ,
            "TERM": "xterm-256color",
            "COLORTERM": "truecolor",
            "TERM_PROGRAM": "Hermes Mobile",
            "HERMES_DESKTOP_TERMINAL": "1",
        }
        if sys.platform == "win32":
            from winpty import PtyProcess

            executable = shutil.which("pwsh") or shutil.which("powershell")
            if executable is None:
                raise RuntimeError("PowerShell is not installed")
            process = PtyProcess.spawn(
                [executable, "-NoLogo"],
                cwd=cwd,
                env=env,
                dimensions=(max(2, rows), max(2, cols)),
            )
            return process, Path(executable).stem

        import ptyprocess

        executable = os.environ.get("SHELL") or shutil.which("bash") or "/bin/sh"
        process = ptyprocess.PtyProcessUnicode.spawn(
            [executable],
            cwd=cwd,
            env=env,
            dimensions=(max(2, rows), max(2, cols)),
        )
        return process, Path(executable).name

    @staticmethod
    def _spawn_argv(argv: list[str], cwd: str, cols: int, rows: int) -> Any:
        import ptyprocess

        env = {
            **os.environ,
            "TERM": "xterm-256color",
            "COLORTERM": "truecolor",
            "TERM_PROGRAM": "Hermes Mobile",
        }
        return ptyprocess.PtyProcessUnicode.spawn(
            argv, cwd=cwd, env=env, dimensions=(max(2, rows), max(2, cols))
        )

    @staticmethod
    def _alive(process: Any) -> bool:
        try:
            return bool(process.isalive())
        except Exception:
            return False

    @staticmethod
    def _terminate(process: Any) -> None:
        try:
            process.terminate(force=True)
        except TypeError:
            try:
                process.terminate()
            except Exception:
                pass
        except Exception:
            try:
                process.close(force=True)
            except Exception:
                pass
