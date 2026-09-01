"""Authenticated bidirectional WebSocket for interactive PTY sessions."""

from __future__ import annotations

import asyncio
import hmac
import json
from typing import Any

from fastapi import APIRouter, WebSocket, WebSocketDisconnect

from .config import Settings
from .terminal_pty import PtyManager


def build_terminal_router(settings: Settings, manager: PtyManager) -> APIRouter:
    router = APIRouter(tags=["terminal"])

    @router.websocket("/api/v1/terminal/ws")
    async def terminal_ws(ws: WebSocket) -> None:
        token = ws.query_params.get("token", "")
        authz = ws.headers.get("authorization", "")
        api_key_header = ws.headers.get("x-api-key", "")
        presented = token or api_key_header or (authz[7:] if authz.startswith("Bearer ") else authz)
        if not hmac.compare_digest(presented.encode(), settings.api_key.encode()):
            # Must accept before close so the client receives the 4401 close code.
            await ws.accept()
            await ws.close(code=4401, reason="invalid api key")
            return
        await ws.accept()
        outgoing: asyncio.Queue[dict[str, Any]] = asyncio.Queue(maxsize=512)
        owned: set[str] = set()
        sender = asyncio.create_task(_send_frames(ws, outgoing))
        try:
            while True:
                request = json.loads(await ws.receive_text())
                if not isinstance(request, dict):
                    raise ValueError("terminal frame must be an object")
                op = str(request.get("op") or "")
                request_id = request.get("request_id")
                if op == "start":
                    started = await manager.start(
                        outgoing,
                        cwd=request.get("cwd") if isinstance(request.get("cwd"), str) else None,
                        cols=_dimension(request.get("cols"), 80),
                        rows=_dimension(request.get("rows"), 24),
                    )
                    owned.add(started["id"])
                    await outgoing.put({"event": "started", "request_id": request_id, **started})
                elif op == "ssh.start":
                    started = await manager.start_ssh(
                        outgoing,
                        host=str(request.get("host") or ""),
                        user=str(request.get("user") or ""),
                        port=_optional_port(request.get("port")),
                        identity_file=str(request.get("identity_file") or ""),
                        cwd=request.get("cwd") if isinstance(request.get("cwd"), str) else None,
                        cols=_dimension(request.get("cols"), 80),
                        rows=_dimension(request.get("rows"), 24),
                    )
                    owned.add(started["id"])
                    await outgoing.put({"event": "started", "request_id": request_id, **started})
                elif op == "reattach":
                    sid = str(request.get("id") or "")
                    reattached = manager.reattach(sid, outgoing) if sid else None
                    if reattached:
                        owned.add(reattached["id"])
                        await outgoing.put(
                            {"event": "started", "request_id": request_id, **reattached,
                             "reattached": True}
                        )
                    else:
                        await outgoing.put(
                            {
                                "event": "error",
                                "request_id": request_id,
                                "message": "pty not available for reattach",
                            }
                        )
                elif op == "write":
                    sid = str(request.get("id") or "")
                    ok = sid in owned and manager.write(sid, str(request.get("data") or ""))
                    await outgoing.put({"event": "ack", "op": op,
                                        "request_id": request_id, "ok": ok})
                elif op == "resize":
                    sid = str(request.get("id") or "")
                    ok = sid in owned and manager.resize(
                        sid, _dimension(request.get("cols"), 80),
                        _dimension(request.get("rows"), 24)
                    )
                    await outgoing.put({"event": "ack", "op": op,
                                        "request_id": request_id, "ok": ok})
                elif op == "cwd":
                    sid = str(request.get("id") or "")
                    await outgoing.put({"event": "cwd", "request_id": request_id,
                                        "id": sid, "cwd": manager.cwd(sid) if sid in owned else None})
                elif op == "dispose":
                    sid = str(request.get("id") or "")
                    ok = sid in owned and await manager.dispose(sid)
                    owned.discard(sid)
                    await outgoing.put({"event": "ack", "op": op,
                                        "request_id": request_id, "ok": ok})
                else:
                    await outgoing.put({"event": "error", "request_id": request_id,
                                        "message": f"unknown op: {op}"})
        except (WebSocketDisconnect, asyncio.CancelledError):
            pass
        except (ValueError, json.JSONDecodeError) as exc:
            await outgoing.put({"event": "error", "message": str(exc)})
        finally:
            # Prefer a short orphan window over immediate kill so mobile
            # reconnects can reattach within the grace period.
            await manager.orphan_many(owned)
            sender.cancel()
            try:
                await sender
            except (asyncio.CancelledError, Exception):
                pass

    return router


async def _send_frames(ws: WebSocket,
                       outgoing: asyncio.Queue[dict[str, Any]]) -> None:
    while True:
        await ws.send_json(await outgoing.get())


def _dimension(value: Any, fallback: int) -> int:
    try:
        return max(2, int(value))
    except (TypeError, ValueError):
        return fallback


def _optional_port(value: Any) -> int | None:
    if value in (None, ""):
        return None
    try:
        return int(value)
    except (TypeError, ValueError) as exc:
        raise ValueError("invalid SSH port") from exc
