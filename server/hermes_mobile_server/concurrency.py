"""Bounded off-loop execution for blocking calls.

Several REST routes (local file/Git operations in ``domain_api.py``) shell
out via ``subprocess.run`` or walk large directory trees. Running those
directly inside an ``async def`` handler still executes them on the single
asyncio event-loop thread, which stalls *every* other concurrent request
(REST and WebSocket relay alike) for the duration of the call — the opposite
of what an async server is for.

:class:`BoundedExecutor` moves that work onto a small, dedicated thread pool
(kept separate from the default executor used by SQLite/PTY reads elsewhere
in this package, so a slow Git op can't starve those) and caps how many such
calls may run at once, so a burst of concurrent requests queues instead of
spawning unbounded threads.
"""

from __future__ import annotations

import asyncio
from concurrent.futures import ThreadPoolExecutor
from typing import Any, Callable, TypeVar

T = TypeVar("T")


class BoundedExecutor:
    """A dedicated thread pool + concurrency cap, with lightweight metrics."""

    def __init__(self, max_workers: int, *, thread_name_prefix: str) -> None:
        self._max_workers = max(1, max_workers)
        self._executor = ThreadPoolExecutor(
            max_workers=self._max_workers, thread_name_prefix=thread_name_prefix
        )
        self._semaphore = asyncio.Semaphore(self._max_workers)
        self._in_flight = 0
        self._waiting = 0
        self._completed = 0

    async def run(self, func: Callable[..., T], *args: Any) -> T:
        """Run ``func(*args)`` on the dedicated pool, queueing past the cap."""
        self._waiting += 1
        entered = False
        try:
            async with self._semaphore:
                entered = True
                self._waiting -= 1
                self._in_flight += 1
                try:
                    loop = asyncio.get_running_loop()
                    return await loop.run_in_executor(self._executor, func, *args)
                finally:
                    self._in_flight -= 1
                    self._completed += 1
        finally:
            # Cancelled while still queued: the `async with` body above never
            # ran, so `_waiting` was never decremented — undo it here rather
            # than leak the optimistic increment.
            if not entered:
                self._waiting = max(0, self._waiting - 1)

    def snapshot(self) -> dict:
        return {
            "max_workers": self._max_workers,
            "in_flight": self._in_flight,
            "waiting": self._waiting,
            "completed": self._completed,
        }

    def shutdown(self, *, wait: bool = False) -> None:
        self._executor.shutdown(wait=wait, cancel_futures=not wait)
