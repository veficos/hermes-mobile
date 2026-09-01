"""FastAPI application for Hermes Mobile Server."""

from __future__ import annotations

import logging
from contextlib import asynccontextmanager
from urllib.parse import quote

from fastapi import Depends, FastAPI, HTTPException, Request, Response
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from . import local_workspace
from .auth import api_key_dependency
from .backend import BackendError, BackendManager
from .config import SERVER_VERSION, Settings, load_settings
from .domain_api import build_domain_router
from .runtime import get_hermes_home, resolve_runtime
from .session_shares import render_share_html, share_store
from .tasks import TaskStore
from .terminal_pty import PtyManager
from .terminal_ws import build_terminal_router
from .ws_proxy import build_ws_router
from .kanban_proxy import build_kanban_router
from .push import PushCoordinator, PushDispatcher, PushStore, build_push_router

logger = logging.getLogger("hermes_mobile_server")


class AppState:
    def __init__(self) -> None:
        self.settings: Settings | None = None
        self.backend: BackendManager | None = None
        self.ready_error: str | None = None
        #: D7 capability contract: full | legacy | missing.
        self.capability: str = "missing"


def create_app(
    settings: Settings | None = None,
    *,
    task_store: TaskStore | None = None,
    push_store: PushStore | None = None,
    push_dispatcher: PushDispatcher | None = None,
) -> FastAPI:
    settings = settings or load_settings()
    state = AppState()
    state.settings = settings
    terminal_manager = PtyManager()
    push_store = push_store or PushStore()
    push_dispatcher = push_dispatcher or PushDispatcher.from_settings(
        settings, push_store
    )

    # Confine the local file API to the configured roots (no-op when unset).
    local_workspace.configure_allowed_roots(settings.allow_paths)

    # Resolve the local Hermes runtime up front so the routers can be wired
    # regardless of whether the backend is already booted.
    try:
        runtime = resolve_runtime(settings.hermes_root_override)
        if runtime is None:
            state.ready_error = (
                "No runnable Hermes Agent found. Install hermes-agent "
                "(https://github.com/NousResearch/hermes-agent) or set "
                "HERMES_HOME / HERMES_DESKTOP_HERMES_ROOT."
            )
            logger.error(state.ready_error)
        else:
            if runtime.rejection:
                logger.warning("Runtime candidate rejected: %s", runtime.rejection)
            state.backend = BackendManager(settings, runtime)
            state.capability = runtime.capability
    except Exception as exc:  # noqa: BLE001
        state.ready_error = f"runtime resolution failed: {exc}"
        logger.exception("Runtime resolution failed")

    push_coordinator = PushCoordinator(state.backend, push_dispatcher)

    @asynccontextmanager
    async def lifespan(app: FastAPI):
        # Boot the local Hermes backend at startup.
        if state.backend is not None:
            try:
                await state.backend.start()
                state.ready_error = None
            except BackendError as exc:
                state.ready_error = str(exc)
                logger.error("Backend startup failed: %s", exc)
        await push_coordinator.start()
        try:
            yield
        finally:
            await push_coordinator.stop()
            await terminal_manager.close_all()
            if state.backend is not None:
                await state.backend.stop()

    app = FastAPI(
        title="Hermes Mobile Server",
        version=SERVER_VERSION,
        lifespan=lifespan,
        docs_url="/api/v1/docs",
        openapi_url="/api/v1/openapi.json",
    )

    # Browser clients (Flutter web on another origin/port) send CORS preflight
    # OPTIONS requests; without this middleware they get 405 and cannot connect.
    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],
        allow_credentials=False,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    # -- management endpoints ----------------------------------------------
    @app.get("/api/v1/health", tags=["management"])
    async def health() -> dict:
        backend = state.backend
        running = backend is not None and backend.is_running
        return {
            "status": "ok" if running else "degraded",
            "backend_running": running,
            "ready_error": state.ready_error,
        }

    @app.get(
        "/api/v1/api/mcp/oauth/callback/{server_name:path}",
        tags=["mcp-oauth"],
    )
    async def mcp_oauth_callback_relay(server_name: str, request: Request) -> Response:
        """Relay the provider callback from a phone browser to local Hermes.

        This endpoint intentionally has no mobile API-key dependency: OAuth
        providers cannot supply it. Hermes validates the one-time ``state``
        value and rejects expired/replayed callbacks.
        """
        backend = state.backend
        if backend is None or not backend.is_running:
            return Response("Hermes backend is unavailable", status_code=503)
        client = await backend.http_client()
        upstream = await client.get(
            f"/api/mcp/oauth/callback/{quote(server_name, safe='')}",
            params=dict(request.query_params),
        )
        return Response(
            content=upstream.content,
            status_code=upstream.status_code,
            media_type=upstream.headers.get("content-type", "text/html"),
        )

    @app.get(
        "/api/v1/status",
        tags=["management"],
        dependencies=[Depends(api_key_dependency(state.settings))],
    )
    async def status() -> dict:
        settings = state.settings
        backend = state.backend
        runtime_info = None
        backend_info = None
        if backend is not None:
            runtime_info = {
                "kind": backend.runtime.kind,
                "source_root": str(backend.runtime.source_root),
                "hermes_home": str(get_hermes_home()),
                "capability": state.capability,
            }
            backend_info = await backend.backend_status()
        return {
            "server": {
                "name": "hermes-mobile-server",
                "version": SERVER_VERSION,
                "api_key_configured": bool(settings.api_key),
                "host": settings.host,
                "port": settings.port,
            },
            "capability": state.capability,
            "runtime": runtime_info,
            "backend": backend_info,
            "ready_error": state.ready_error,
        }

    @app.post(
        "/api/v1/backend/restart",
        tags=["management"],
        dependencies=[Depends(api_key_dependency(state.settings))],
    )
    async def restart_backend() -> dict:
        backend = state.backend
        if backend is None:
            return JSONResponse(
                {"error": state.ready_error or "backend not initialized"},
                status_code=503,
            )
        try:
            await backend.restart()
            state.ready_error = None
            return {"status": "restarted", "port": backend.port}
        except BackendError as exc:
            state.ready_error = str(exc)
            return JSONResponse({"error": str(exc)}, status_code=500)

    @app.get("/share/{token}", tags=["sharing"])
    async def public_session_share(token: str) -> Response:
        """Expose WebUI's immutable public share snapshot on the LAN server.

        Share tokens are bearer capabilities, matching WebUI. This route is
        deliberately outside the mobile API-key dependency so a recipient can
        open the copied link in a browser.
        """
        if not token or len(token) > 160 or not token.replace("-", "").replace("_", "").isalnum():
            raise HTTPException(status_code=404, detail="share not found")
        snapshot = share_store.get(token)
        if snapshot is not None:
            return Response(
                content=render_share_html(snapshot),
                media_type="text/html; charset=utf-8",
                headers={"Cache-Control": "public, max-age=300"},
            )
        backend = state.backend
        if backend is None or not backend.is_running:
            raise HTTPException(status_code=503, detail="Hermes backend is not running")
        client = await backend.http_client()
        upstream = await client.get(f"/share/{token}")
        if upstream.status_code >= 400:
            raise HTTPException(status_code=upstream.status_code, detail="share not found")
        return Response(
            content=upstream.content,
            media_type=upstream.headers.get("content-type", "text/html; charset=utf-8"),
            headers={"Cache-Control": upstream.headers.get("cache-control", "no-store")},
        )

    @app.get(
        "/api/v1/methods",
        tags=["management"],
        dependencies=[Depends(api_key_dependency(state.settings))],
    )
    async def methods(request: Request) -> dict:
        """Document the API surface for the mobile app."""
        def route_paths(routes) -> set[str]:
            found: set[str] = set()
            for route in routes:
                path = getattr(route, "path", None)
                if isinstance(path, str) and path.startswith("/api/v1"):
                    found.add(path)
                nested = getattr(route, "routes", None)
                if nested is None:
                    nested = getattr(getattr(route, "router", None), "routes", None)
                if nested is None:
                    nested = getattr(
                        getattr(route, "original_router", None), "routes", None
                    )
                if nested:
                    found.update(route_paths(nested))
            return found

        # Use the owning FastAPI app directly. TestClient/proxy deployments can
        # expose a wrapper as request.app whose route list omits included
        # routers, producing an incomplete self-description.
        discovered_resources = sorted(route_paths(app.routes))
        return {
            "rest": {
                "resources": discovered_resources,
                "note": "Generated from the live FastAPI route table.",
            },
            "ws": {
                "url": "/api/v1/ws?token=<api-key>",
                "protocol": "JSON-RPC 2.0 over newline-delimited WebSocket frames",
                "methods": [
                    "session.create",
                    "session.resume",
                    "session.branch",
                    "session.close",
                    "session.interrupt",
                    "message.send",
                    "message.steer",
                    "approval.respond",
                    "clarify.respond",
                    "tools.configure",
                    "projects.list",
                    "projects.create",
                ],
                "events": [
                    "gateway.ready",
                    "session.info",
                    "message.start",
                    "message.delta",
                    "message.interim",
                    "message.complete",
                    "reasoning.delta",
                    "tool.start",
                    "tool.progress",
                    "tool.complete",
                    "status.update",
                    "approval.request",
                    "clarify.request",
                    "sudo.request",
                    "secret.request",
                    "terminal.read.request",
                    "notification.show",
                    "sessions.changed",
                    "cron.changed",
                    "background.complete",
                    "pet.changed",
                    "platforms.changed",
                    "subagent.start",
                    "subagent.spawn_requested",
                    "subagent.text",
                    "subagent.thinking",
                    "subagent.tool",
                    "subagent.progress",
                    "subagent.complete",
                    "skin.changed",
                    "wake.detected",
                    "voice.transcript",
                    "voice.status",
                    "reaction",
                ],
            },
            "management": {
                "GET /api/v1/status": "server + runtime + backend status",
                "GET /api/v1/health": "liveness",
                "GET /api/v1/logs": "proxy Hermes agent logs",
                "POST /api/v1/backend/restart": "restart the Hermes backend",
            },
        }

    # -- routers ------------------------------------------------------------
    # Routers are wired unconditionally; they report 503 until the backend
    # finishes booting in the lifespan.
    app.include_router(
        build_domain_router(settings, state.backend, task_store=task_store)
    )
    app.include_router(build_ws_router(settings, state.backend))
    app.include_router(build_kanban_router(settings, state.backend))
    app.include_router(build_terminal_router(settings, terminal_manager))
    app.include_router(build_push_router(settings, push_store, push_dispatcher))

    @app.exception_handler(RequestValidationError)
    async def validation_exception(
        request: Request, exc: RequestValidationError
    ) -> JSONResponse:
        messages = []
        for error in exc.errors():
            location = ".".join(str(part) for part in error.get("loc", ()))
            message = str(error.get("msg") or "invalid value")
            messages.append(f"{location}: {message}" if location else message)
        return JSONResponse({"detail": "; ".join(messages)}, status_code=422)

    @app.exception_handler(Exception)
    async def unhandled_exception(request: Request, exc: Exception) -> JSONResponse:
        logger.exception("Unhandled error on %s %s", request.method, request.url.path)
        return JSONResponse({"error": f"internal error: {exc.__class__.__name__}"}, status_code=500)

    return app
