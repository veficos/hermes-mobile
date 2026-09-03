"""Weak-network regression tests for push delivery retry.

Before this change, ANY push delivery failure (including a purely
transient one — the provider timing out, a 503, a 429) was dropped with no
retry. That's specifically the wrong failure mode for the scenario push
exists to cover: the mobile device is unreachable over WS/REST because of a
network blip, and that same kind of blip can also make the push provider
itself transiently unreachable. These tests pin down the fix: transient
failures (`_is_transient_push_failure`) get a couple of retries with
backoff; permanent ones (invalid token, other 4xx) still don't.

Run with::

    uv run pytest tests/test_push_retry.py -v
"""

from __future__ import annotations

import asyncio
from pathlib import Path

import httpx
import pytest

from hermes_mobile_server.push import (
    DeliveryResult,
    DeviceRegistration,
    DeviceSubscription,
    PushDispatcher,
    PushMessage,
    PushStore,
    _is_transient_push_failure,
)


def registration(
    token: str = "android-device-token-0001", *, profile: str | None = "work"
) -> DeviceRegistration:
    return DeviceRegistration(
        device_id="device-installation-0001",
        platform="android",
        token=token,
        connection_id="primary",
        profile=profile,
        locale="en",
        app_version="1.0.0+1",
    )


class _ScriptedProvider:
    """Returns/raises a scripted sequence of outcomes, one per `send` call."""

    platform = "android"

    def __init__(self, outcomes: list) -> None:
        self._outcomes = list(outcomes)
        self.calls = 0

    async def send(
        self, subscription: DeviceSubscription, message: PushMessage
    ) -> DeliveryResult:
        self.calls += 1
        outcome = self._outcomes.pop(0)
        if isinstance(outcome, Exception):
            raise outcome
        return outcome

    async def close(self) -> None:
        return None


def _dispatcher(tmp_path: Path, provider: _ScriptedProvider) -> PushDispatcher:
    store = PushStore(tmp_path / "push.json")
    store.upsert(registration())
    return PushDispatcher(store, [provider])


@pytest.mark.parametrize(
    "status_code,expected",
    [(429, True), (500, True), (503, True), (400, False), (404, False), (410, False)],
)
def test_is_transient_push_failure_status_codes(status_code, expected):
    result = DeliveryResult(False, status_code=status_code)
    assert _is_transient_push_failure(result) is expected


def test_transient_failure_retried_and_eventually_delivered(tmp_path: Path):
    provider = _ScriptedProvider(
        [
            DeliveryResult(False, status_code=503, detail="FCM 503"),
            DeliveryResult(False, status_code=429, detail="FCM 429"),
            DeliveryResult(True),
        ]
    )
    dispatcher = _dispatcher(tmp_path, provider)

    result = asyncio.run(dispatcher.send(PushMessage("id", "Title", "Body", {})))

    assert result == {"matched": 1, "delivered": 1, "failed": 0, "removed": 0}
    assert provider.calls == 3


def test_transient_failure_exhausts_retries_and_reports_failed(tmp_path: Path):
    provider = _ScriptedProvider(
        [
            DeliveryResult(False, status_code=503),
            DeliveryResult(False, status_code=503),
            DeliveryResult(False, status_code=503),
        ]
    )
    dispatcher = _dispatcher(tmp_path, provider)

    result = asyncio.run(dispatcher.send(PushMessage("id", "Title", "Body", {})))

    assert result == {"matched": 1, "delivered": 0, "failed": 1, "removed": 0}
    assert provider.calls == 3  # capped, not retried forever
    # A transient failure must not be mistaken for a dead registration.
    assert PushStore(tmp_path / "push.json").list() != []


def test_raised_transport_error_is_retried(tmp_path: Path):
    provider = _ScriptedProvider(
        [httpx.ConnectTimeout("timed out"), DeliveryResult(True)]
    )
    dispatcher = _dispatcher(tmp_path, provider)

    result = asyncio.run(dispatcher.send(PushMessage("id", "Title", "Body", {})))

    assert result == {"matched": 1, "delivered": 1, "failed": 0, "removed": 0}
    assert provider.calls == 2


def test_permanent_failure_is_not_retried(tmp_path: Path):
    provider = _ScriptedProvider(
        [DeliveryResult(False, invalid_token=True, status_code=410, detail="APNs 410")]
    )
    dispatcher = _dispatcher(tmp_path, provider)

    result = asyncio.run(dispatcher.send(PushMessage("id", "Title", "Body", {})))

    assert result == {"matched": 1, "delivered": 0, "failed": 1, "removed": 1}
    assert provider.calls == 1  # no retry for a permanent failure
