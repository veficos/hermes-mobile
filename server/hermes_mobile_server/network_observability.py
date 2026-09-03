"""Low-cardinality WebSocket metrics and per-client connection limits."""

from __future__ import annotations

import asyncio
import time
from collections import Counter, deque
from contextlib import asynccontextmanager
from typing import AsyncIterator

from fastapi import WebSocket


class NetworkMetrics:
    def __init__(self) -> None:
        self.started_at = time.time()
        self.active: Counter[str] = Counter()
        self.connections: Counter[str] = Counter()
        self.reconnects: Counter[str] = Counter()
        self.disconnects: Counter[str] = Counter()
        self.rejected: Counter[str] = Counter()
        self.handshake_count: Counter[str] = Counter()
        self.handshake_total_ms: Counter[str] = Counter()
        self.handshake_max_ms: Counter[str] = Counter()
        self.handshake_failures: Counter[str] = Counter()
        self._seen_clients: set[tuple[str, str]] = set()
        self._seen_order: deque[tuple[str, str]] = deque()

    def connected(self, kind: str, elapsed: float, client_key: str = "unknown") -> None:
        elapsed_ms = max(0, round(elapsed * 1000))
        self.active[kind] += 1
        self.connections[kind] += 1
        identity = (kind, client_key)
        if identity in self._seen_clients:
            self.reconnects[kind] += 1
        if identity not in self._seen_clients:
            self._seen_clients.add(identity)
            self._seen_order.append(identity)
            if len(self._seen_order) > 4096:
                self._seen_clients.discard(self._seen_order.popleft())
        self.handshake_count[kind] += 1
        self.handshake_total_ms[kind] += elapsed_ms
        self.handshake_max_ms[kind] = max(self.handshake_max_ms[kind], elapsed_ms)

    def disconnected(self, kind: str, reason: str) -> None:
        self.active[kind] = max(0, self.active[kind] - 1)
        self.disconnects[f"{kind}:{_reason(reason)}"] += 1

    def reject(self, kind: str) -> None:
        self.rejected[kind] += 1

    def handshake_failed(self, kind: str, reason: str = "error") -> None:
        self.handshake_failures[f"{kind}:{_reason(reason)}"] += 1

    def snapshot(self) -> dict:
        kinds = sorted(
            set(self.connections) | set(self.active) | set(self.handshake_count)
        )
        return {
            "uptime_seconds": round(time.time() - self.started_at),
            "active_proxies": dict(self.active),
            "connections_total": dict(self.connections),
            "reconnects_total": dict(self.reconnects),
            "disconnects_total": dict(self.disconnects),
            "connection_limit_rejections_total": dict(self.rejected),
            "handshake_failures_total": dict(self.handshake_failures),
            "handshake": {
                kind: {
                    "count": self.handshake_count[kind],
                    "average_ms": round(
                        self.handshake_total_ms[kind] / self.handshake_count[kind]
                    )
                    if self.handshake_count[kind]
                    else 0,
                    "max_ms": self.handshake_max_ms[kind],
                }
                for kind in kinds
            },
        }


def _reason(value: str) -> str:
    text = value.lower()
    for name in ("client", "upstream", "timeout", "auth", "limit", "error"):
        if name in text:
            return name
    return "closed"


class WebSocketConnectionLimiter:
    def __init__(
        self, max_per_client: int, *, trust_forwarded_for: bool = False
    ) -> None:
        self.max_per_client = max(1, max_per_client)
        self.trust_forwarded_for = trust_forwarded_for
        self._counts: Counter[str] = Counter()
        self._lock = asyncio.Lock()

    def client_key(self, ws: WebSocket) -> str:
        if self.trust_forwarded_for:
            forwarded = ws.headers.get("x-forwarded-for", "").split(",", 1)[0].strip()
            if forwarded:
                return forwarded
        return ws.client.host if ws.client else "unknown"

    @asynccontextmanager
    async def slot(self, ws: WebSocket) -> AsyncIterator[bool]:
        key = self.client_key(ws)
        async with self._lock:
            allowed = self._counts[key] < self.max_per_client
            if allowed:
                self._counts[key] += 1
        try:
            yield allowed
        finally:
            if allowed:
                async with self._lock:
                    self._counts[key] -= 1
                    if self._counts[key] <= 0:
                        self._counts.pop(key, None)
