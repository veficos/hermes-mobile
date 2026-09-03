"""Lifecycle management of the local Hermes backend process.

The backend is the exact same headless server the Hermes Desktop app drives:

    python -m hermes_cli.main serve --host 127.0.0.1 --port 0

``serve`` boots the JSON-RPC/WebSocket gateway (``tui_gateway``) *and* the
REST API surface (``hermes_cli.web_server``) in one process. It announces the
OS-assigned port on stdout with the sentinel ``HERMES_BACKEND_READY port=N``,
which this module parses — same contract the Electron main process uses.
"""

from __future__ import annotations

import asyncio
import json
import logging
import os
import re
import secrets
import signal
import socket
import subprocess
import sys
import time
from collections.abc import Awaitable, Callable
from pathlib import Path

import httpx
import websockets

from .config import HERMES_HOME_ENV, Settings
from .runtime import HermesRuntime, get_hermes_home

logger = logging.getLogger("hermes_mobile_server.backend")

#: Sentinel printed by ``hermes serve`` once the port is bound.
_READY_RE = re.compile(r"HERMES_BACKEND_READY port=(\d+)")
#: Fallback for older runtimes that only have ``dashboard --no-open``.
_LEGACY_READY_RE = re.compile(r"HERMES_DASHBOARD_READY port=(\d+)")

#: Header the backend expects for authenticated REST calls.
_SESSION_HEADER = "X-Hermes-Session-Token"


def _iter_site_packages(source_root: Path, python: Path | None) -> list[Path]:
    """Discover existing venv site-packages dirs without hardcoding a Python minor."""
    found: list[Path] = []
    seen: set[Path] = set()

    def _add(path: Path) -> None:
        try:
            resolved = path.resolve(strict=False)
        except OSError:
            resolved = path
        if resolved in seen or not path.is_dir():
            return
        seen.add(resolved)
        found.append(path)

    # Prefer the interpreter's own prefix when we know it (covers /opt/hermes/venv).
    if python is not None:
        # <venv>/bin/python → <venv>/lib/pythonX.Y/site-packages
        # <venv>/Scripts/python.exe → <venv>/Lib/site-packages
        venv_root = python.parent.parent
        _add(venv_root / "Lib" / "site-packages")
        lib_dir = venv_root / "lib"
        if lib_dir.is_dir():
            for child in sorted(lib_dir.glob("python3.*/site-packages")):
                _add(child)

    for venv_name in ("venv", ".venv"):
        venv_root = source_root / venv_name
        _add(venv_root / "Lib" / "site-packages")
        lib_dir = venv_root / "lib"
        if lib_dir.is_dir():
            for child in sorted(lib_dir.glob("python3.*/site-packages")):
                _add(child)
    return found


def _iter_venv_bin_dirs(source_root: Path, python: Path | None) -> list[Path]:
    """Return venv executable dirs (``bin`` / ``Scripts``) that exist."""
    found: list[Path] = []
    seen: set[Path] = set()

    def _add(path: Path) -> None:
        try:
            resolved = path.resolve(strict=False)
        except OSError:
            resolved = path
        if resolved in seen or not path.is_dir():
            return
        seen.add(resolved)
        found.append(path)

    if python is not None:
        _add(python.parent)  # .../bin or .../Scripts
    for venv_name in ("venv", ".venv"):
        venv_root = source_root / venv_name
        _add(venv_root / "bin")
        _add(venv_root / "Scripts")
    return found


def _dashboard_public_url(settings: Settings) -> str:
    """Return the public prefix Hermes should embed in browser callbacks."""
    explicit = (settings.public_url or "").strip().rstrip("/")
    if explicit:
        return f"{explicit}/api/v1"

    host = settings.host.strip()
    if host in {"", "0.0.0.0", "::", "[::]"}:
        try:
            probe = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            try:
                # UDP connect performs route selection without sending data.
                probe.connect(("8.8.8.8", 80))
                host = str(probe.getsockname()[0])
            finally:
                probe.close()
        except OSError:
            try:
                host = socket.gethostbyname(socket.gethostname())
            except OSError:
                host = "127.0.0.1"
    if ":" in host and not host.startswith("["):
        host = f"[{host}]"
    return f"http://{host}:{settings.port}/api/v1"


class BackendError(RuntimeError):
    """Raised when the Hermes backend cannot be started or probed."""


class BackendManager:
    """Owns the backend subprocess, its port and its session token."""

    def __init__(self, settings: Settings, runtime: HermesRuntime) -> None:
        self.settings = settings
        self.runtime = runtime
        #: Ephemeral token minted for THIS backend process (dies with it).
        self.session_token: str = secrets.token_urlsafe(32)
        self.port: int | None = None
        self.process: asyncio.subprocess.Process | None = None
        self._http: httpx.AsyncClient | None = None
        self._log_tail: asyncio.Task | None = None
        self.last_stdout_tail: list[str] = []
        #: Subscribers for gateway broadcast events (task completion, …).
        self._event_listeners: list[Callable[[dict], Awaitable[None]]] = []
        self._lifecycle_listeners: list[Callable[[], None]] = []
        self._backend_epoch = 0
        # These must be instance-owned: class-level mutable connection state
        # can leak pending RPCs between multiple managers in one process.
        self._gw_ws: websockets.ClientConnection | None = None
        self._gw_reader: asyncio.Task | None = None
        self._gw_lock: asyncio.Lock | None = None
        self._gw_next_id = 1
        self._gw_pending: dict[int, asyncio.Future] = {}

    def add_event_listener(self, listener: Callable[[dict], Awaitable[None]]) -> None:
        """Register a coroutine to receive every gateway broadcast event dict."""
        if listener not in self._event_listeners:
            self._event_listeners.append(listener)

    def add_lifecycle_listener(self, listener: Callable[[], None]) -> None:
        """Register a callback invoked whenever the backend process resets."""
        if listener not in self._lifecycle_listeners:
            self._lifecycle_listeners.append(listener)

    def _emit_lifecycle_reset(self) -> None:
        for listener in list(self._lifecycle_listeners):
            try:
                listener()
            except Exception:  # noqa: BLE001
                logger.exception("backend lifecycle listener failed")

    async def _emit_event(self, event: dict) -> None:
        for listener in list(self._event_listeners):
            try:
                await listener(event)
            except Exception:  # noqa: BLE001
                logger.exception("gateway event listener failed")

    # ------------------------------------------------------------------ env
    def _build_env(self) -> dict[str, str]:
        env = os.environ.copy()
        source_root = self.runtime.source_root
        hermes_home = get_hermes_home()

        env[HERMES_HOME_ENV] = str(hermes_home)
        env["HERMES_DASHBOARD_SESSION_TOKEN"] = self.session_token
        if self.settings.public_url:
            env["HERMES_DASHBOARD_PUBLIC_URL"] = _dashboard_public_url(self.settings)
        else:
            env.setdefault(
                "HERMES_DASHBOARD_PUBLIC_URL",
                _dashboard_public_url(self.settings),
            )
        # Run the desktop cron scheduling loop just like the desktop app does.
        env.setdefault("HERMES_DESKTOP", "1")
        # PEP 540: force UTF-8 so GBK/other locales never garble traces.
        env.setdefault("PYTHONUTF8", "1")

        # PYTHONPATH: source root + venv site-packages + inherited value.
        entries: list[str] = [str(source_root)]
        if self.runtime.python is not None:
            for site_packages in _iter_site_packages(source_root, self.runtime.python):
                entries.append(str(site_packages))
        inherited_pythonpath = env.get("PYTHONPATH", "")
        if inherited_pythonpath:
            entries.append(inherited_pythonpath)
        env["PYTHONPATH"] = os.pathsep.join(entries)

        # PATH: venv bin/Scripts first (mirrors the desktop env builder).
        for bin_dir in _iter_venv_bin_dirs(source_root, self.runtime.python):
            env["PATH"] = str(bin_dir) + os.pathsep + env.get("PATH", "")

        return env

    # ------------------------------------------------------------- process
    async def start(self) -> None:
        """Spawn the backend and wait for its port announcement."""
        await self.stop()
        # Drop any log lines from the previous backend run so a stale READY
        # sentinel can never be matched for the new process.
        self.last_stdout_tail = []

        argv = list(self.runtime.argv) + [
            "serve",
            "--host",
            self.settings.backend_host,
            "--port",
            str(self.settings.backend_port),
        ]
        logger.info("Starting backend: %s", " ".join(argv))
        logger.info("HERMES_HOME=%s", get_hermes_home())

        self.process = await asyncio.create_subprocess_exec(
            *argv,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.STDOUT,
            env=self._build_env(),
        )

        # Drain stdout in a task so we can detect the READY sentinel and keep
        # a log tail for diagnostics.
        self._log_tail = asyncio.create_task(self._drain_stdout())

        try:
            port = await asyncio.wait_for(
                self._wait_for_ready(), timeout=self.settings.backend_ready_timeout
            )
        except asyncio.TimeoutError:
            tail = "\n".join(self.last_stdout_tail[-20:])
            await self._terminate()
            raise BackendError(
                "Hermes backend did not announce a port within "
                f"{self.settings.backend_ready_timeout:.0f}s.\n"
                f"Runtime: {self.runtime.kind} at {self.runtime.source_root}\n"
                f"Log tail:\n{tail}"
            ) from None

        self.port = port
        await self._wait_healthy(timeout=60.0)
        logger.info("Backend ready on port %s (token length %d)", port, len(self.session_token))

    async def _drain_stdout(self) -> None:
        assert self.process is not None and self.process.stdout is not None
        try:
            while True:
                raw = await self.process.stdout.readline()
                if not raw:
                    break
                line = raw.decode("utf-8", "replace").rstrip("\r\n")
                self.last_stdout_tail.append(line)
                if len(self.last_stdout_tail) > 500:
                    self.last_stdout_tail = self.last_stdout_tail[-500:]
                if line:
                    logger.debug("backend: %s", line)
        except (ValueError, OSError, asyncio.CancelledError):
            pass

    async def _wait_for_ready(self) -> int:
        """Poll the drained log lines until the port sentinel appears."""
        deadline = time.monotonic() + self.settings.backend_ready_timeout
        while time.monotonic() < deadline:
            if self.process is None:
                raise BackendError("Backend process vanished before becoming ready")
            if self.process.returncode is not None:
                raise BackendError(
                    f"Backend exited early (code {self.process.returncode})\n"
                    + "\n".join(self.last_stdout_tail[-20:])
                )
            for line in self.last_stdout_tail:
                match = _READY_RE.search(line) or _LEGACY_READY_RE.search(line)
                if match:
                    return int(match.group(1))
            await asyncio.sleep(0.2)
        raise BackendError("Timed out waiting for backend READY sentinel")

    async def _wait_healthy(self, timeout: float) -> None:
        """Wait until the backend answers a token-authenticated request."""
        deadline = time.monotonic() + timeout
        client = await self._http_client()
        while time.monotonic() < deadline:
            try:
                resp = await client.get(
                    self._url("/api/health"), headers=self.auth_headers, timeout=5.0
                )
                if resp.status_code == 200:
                    return
            except httpx.HTTPError:
                pass
            await asyncio.sleep(0.5)
        raise BackendError("Backend did not become healthy in time")

    # --------------------------------------------------------------- http
    @property
    def auth_headers(self) -> dict[str, str]:
        return {_SESSION_HEADER: self.session_token}

    def _url(self, path: str) -> str:
        if self.port is None:
            raise BackendError("Backend not started")
        return f"http://127.0.0.1:{self.port}{path}"

    async def http_client(self) -> httpx.AsyncClient:
        """Return a reusable AsyncClient pointed at the live backend."""
        if self._http is None or self._http.is_closed:
            if self.port is None:
                raise BackendError("Backend not started")
            self._http = httpx.AsyncClient(
                base_url=f"http://127.0.0.1:{self.port}",
                timeout=httpx.Timeout(300.0, connect=5.0),
                headers=self.auth_headers,
            )
        return self._http

    async def _http_client(self) -> httpx.AsyncClient:
        return await self.http_client()

    @property
    def is_running(self) -> bool:
        return (
            self.process is not None
            and self.process.returncode is None
            and self.port is not None
        )

    # ----------------------------------------------------------- lifecycle
    async def ensure_running(self) -> None:
        """Start (or restart) the backend if it is not currently usable."""
        if self.is_running:
            # Fast liveness probe; restart when the process is dead.
            try:
                client = await self._http_client()
                resp = await client.get("/api/health", timeout=3.0)
                if resp.status_code == 200:
                    return
            except httpx.HTTPError:
                pass
            logger.warning("Backend unhealthy; restarting")
        await self.start()

    async def restart(self) -> None:
        """Hard-restart the backend process."""
        logger.info("Restarting Hermes backend")
        await self.start()

    async def _terminate(self) -> None:
        if self.process is None:
            return
        process = self.process
        self.process = None
        self.port = None
        try:
            if process.returncode is None:
                process.terminate()
                try:
                    await asyncio.wait_for(process.wait(), timeout=8)
                except asyncio.TimeoutError:
                    process.kill()
                    await asyncio.wait_for(process.wait(), timeout=5)
        except (OSError, ProcessLookupError):
            pass

    async def stop(self) -> None:
        self._backend_epoch += 1
        reader = self._gw_reader
        self._gw_reader = None
        if reader is not None:
            reader.cancel()
            try:
                await reader
            except asyncio.CancelledError:
                pass
        ws = self._gw_ws
        self._gw_ws = None
        if ws is not None:
            try:
                await ws.close()
            except Exception:  # noqa: BLE001
                pass
        await self._terminate()
        if self._log_tail is not None:
            self._log_tail.cancel()
            self._log_tail = None
        if self._http is not None:
            await self._http.aclose()
            self._http = None
        self._emit_lifecycle_reset()

    async def backend_status(self) -> dict:
        """Rich status object merged into the mobile-facing /status endpoint."""
        base = {
            "running": self.is_running,
            "port": self.port,
            "runtime": self.runtime.kind,
            "source_root": str(self.runtime.source_root),
            "hermes_home": str(get_hermes_home()),
            "model": None,
            "hermes_version": None,
            "gateway": None,
        }
        if not self.is_running:
            return base
        try:
            client = await self._http_client()
            status = (await client.get("/api/status", timeout=10.0)).json()
            base["hermes_version"] = status.get("version")
            base["gateway"] = {
                "running": status.get("gateway_running"),
                "state": status.get("gateway_state"),
                "platforms": status.get("gateway_platforms"),
                "active_agents": status.get("active_agents"),
                "gateway_busy": status.get("gateway_busy"),
            }
            model = (await client.get("/api/model/info", timeout=10.0)).json()
            base["model"] = {
                "model": model.get("model"),
                "provider": model.get("provider"),
                "context_length": model.get("effective_context_length"),
            }
        except (httpx.HTTPError, ValueError):
            base["error"] = "failed to query backend status"
        return base

    def rpc_concurrency_snapshot(self) -> dict:
        """Cheap, non-blocking snapshot of in-flight gateway JSON-RPC calls.

        ``gateway_rpc()`` lets concurrent callers run their RPCs in flight
        together (matched by request id in ``_gw_pending``); this just
        exposes how many are outstanding right now, for `/network/metrics`.
        """
        return {
            "gateway_connected": self._gw_ws is not None,
            "in_flight_rpcs": len(self._gw_pending),
        }

    # ------------------------------------------------------------ ws proxy
    @property
    def gateway_ws_url(self) -> str:
        if self.port is None:
            raise BackendError("Backend not started")
        return f"ws://127.0.0.1:{self.port}/api/ws?token={self.session_token}"

    async def connect_gateway_ws(
        self, consume_ready: bool = True
    ) -> websockets.ClientConnection:
        """Open (and handshake) a WebSocket to the backend gateway.

        Reuses the retry logic the ws proxy uses. When ``consume_ready`` is
        true the ``gateway.ready`` handshake frame is consumed (needed by the
        server-side RPC connection); when false the frame is left on the wire
        so the pass-through proxy can relay it to the client.
        """
        last_error: Exception | None = None
        deadline = asyncio.get_running_loop().time() + 15.0
        while asyncio.get_running_loop().time() < deadline:
            ws: websockets.ClientConnection | None = None
            try:
                ws = await websockets.connect(
                    self.gateway_ws_url,
                    max_size=None,
                    open_timeout=10.0,
                    ping_interval=20,
                    ping_timeout=20,
                )
                if consume_ready:
                    # Consume the gateway.ready handshake frame.
                    await asyncio.wait_for(ws.recv(), timeout=10.0)
                return ws
            except Exception as exc:  # noqa: BLE001
                last_error = exc
                if ws is not None:
                    try:
                        await ws.close()
                    except Exception:  # noqa: BLE001
                        pass
                await asyncio.sleep(0.5)
        raise BackendError(f"could not reach backend gateway: {last_error}")

    # ------------------------------------------------- gateway JSON-RPC
    # A long-lived upstream connection used by the domain API to call
    # gateway-only methods (session.create, projects.list, …). The connection
    # is separate from the per-client pass-through pipes in ws_proxy.py.
    def _gateway_lock(self) -> asyncio.Lock:
        if self._gw_lock is None:
            self._gw_lock = asyncio.Lock()
        return self._gw_lock

    async def _ensure_gateway_rpc(self) -> None:
        if self._gw_ws is None or self._gw_ws.state == websockets.protocol.State.CLOSED:
            self._gw_ws = await self.connect_gateway_ws()
            epoch = self._backend_epoch
            self._gw_reader = asyncio.create_task(self._gw_read_loop(epoch))

    async def ensure_gateway_event_stream(self) -> None:
        """Keep the server-owned event stream alive even without active RPC calls."""
        async with self._gateway_lock():
            await self._ensure_gateway_rpc()

    async def _gw_read_loop(self, epoch: int) -> None:
        ws = self._gw_ws
        if ws is None:
            return
        try:
            async for raw in ws:
                try:
                    frame = json.loads(raw)
                except (ValueError, TypeError):
                    continue
                if frame.get("method") == "event":
                    # Broadcast events are dispatched to subscribers (e.g. the
                    # task store watches message.complete / session.info to
                    # write back Task completion, ADR 0003).
                    if epoch == self._backend_epoch:
                        await self._emit_event(frame.get("params") or {})
                    continue
                req_id = frame.get("id")
                if isinstance(req_id, int) and req_id in self._gw_pending:
                    future = self._gw_pending.pop(req_id)
                    if not future.done():
                        if "error" in frame:
                            future.set_exception(
                                BackendError(
                                    f"gateway rpc {frame['error'].get('message', 'error')}"
                                )
                            )
                        else:
                            future.set_result(frame.get("result") or {})
        except (websockets.ConnectionClosed, OSError, asyncio.CancelledError):
            pass
        finally:
            if self._gw_ws is ws:
                self._gw_ws = None
                # Only the reader which still owns the active socket may fail
                # its pending requests. A late reader from a replaced socket
                # must not tear down requests sent on the new generation.
                pending, self._gw_pending = self._gw_pending, {}
                for future in pending.values():
                    if not future.done():
                        future.set_exception(
                            BackendError("gateway rpc connection lost")
                        )

    async def gateway_rpc(
        self, method: str, params: dict | None = None, timeout: float | None = None
    ) -> dict:
        """Call a JSON-RPC method on the backend gateway and await its result."""
        timeout = timeout if timeout is not None else _gateway_rpc_timeout(method)
        async with self._gateway_lock():
            await self._ensure_gateway_rpc()
            ws = self._gw_ws
            assert ws is not None
            req_id = self._gw_next_id
            self._gw_next_id += 1
            loop = asyncio.get_running_loop()
            future: asyncio.Future = loop.create_future()
            self._gw_pending[req_id] = future
            try:
                await ws.send(
                    json.dumps(
                        {
                            "jsonrpc": "2.0",
                            "id": req_id,
                            "method": method,
                            "params": params or {},
                        }
                    )
                )
            except Exception:
                self._gw_pending.pop(req_id, None)
                if self._gw_ws is ws:
                    self._gw_ws = None
                try:
                    await ws.close()
                except Exception:  # noqa: BLE001
                    pass
                raise
        # Do not serialize the response wait. The reader dispatches results by
        # id, so independent slow RPCs can safely remain in flight together.
        try:
            return await asyncio.wait_for(future, timeout=timeout)
        except asyncio.TimeoutError:
            self._gw_pending.pop(req_id, None)
            raise BackendError(f"gateway rpc {method} timed out") from None

    def describe(self) -> dict:
        return {
            "api_key_persisted_at": str(
                Path.home() / ".hermes-mobile-server" / "config.json"
            ),
        }


def _gateway_rpc_timeout(method: str) -> float:
    """Timeout by operation class: probes are fast, execution stays roomy."""
    if method.endswith((".status", ".state", ".info")) or method in {
        "projects.list",
        "agents.list",
        "model.options",
        "usage.bars",
        "delegation.status",
    }:
        return 15.0
    if method.startswith(("shell.", "files.", "pet.generate")) or method in {
        "prompt.submit",
        "session.generate_title",
    }:
        return 300.0
    return 60.0
