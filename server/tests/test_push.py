from __future__ import annotations

import asyncio
import json
import stat
from pathlib import Path

import httpx
from fastapi.testclient import TestClient

from hermes_mobile_server.app import create_app
from hermes_mobile_server.config import Settings
from hermes_mobile_server.push import (
    ApnsProvider,
    DeliveryResult,
    DeviceRegistration,
    DeviceSubscription,
    FcmV1Provider,
    PushCoordinator,
    PushDispatcher,
    PushMessage,
    PushStore,
)


class FakeProvider:
    platform = "android"

    def __init__(self, *, invalid: bool = False) -> None:
        self.invalid = invalid
        self.sent: list[tuple[DeviceSubscription, PushMessage]] = []
        self.closed = False

    async def send(
        self, subscription: DeviceSubscription, message: PushMessage
    ) -> DeliveryResult:
        self.sent.append((subscription, message))
        return DeliveryResult(not self.invalid, invalid_token=self.invalid)

    async def close(self) -> None:
        self.closed = True


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


def test_push_store_rotates_tokens_atomically_and_redacts_public_data(tmp_path: Path):
    path = tmp_path / "state" / "push_devices.json"
    store = PushStore(path)

    first, rotated = store.upsert(registration())
    assert not rotated
    second, rotated = store.upsert(registration("android-device-token-0002"))
    assert rotated
    assert len(store.list()) == 1
    assert second.token.endswith("0002")
    assert "android-device-token" not in json.dumps(second.public_json())
    assert stat.S_IMODE(path.stat().st_mode) == 0o600
    assert stat.S_IMODE(path.parent.stat().st_mode) == 0o700

    restored = PushStore(path)
    assert restored.list() == [second]
    assert restored.remove(first.device_id, connection_id="other") == 0
    assert restored.remove(first.device_id, connection_id="primary") == 1
    assert restored.list() == []


def test_push_api_registers_rotates_lists_and_unregisters(tmp_path: Path):
    store = PushStore(tmp_path / "push.json")
    provider = FakeProvider()
    dispatcher = PushDispatcher(store, [provider])
    settings = Settings(
        api_key="push-test-key",
        hermes_root_override=str(tmp_path / "missing-hermes"),
    )
    headers = {"Authorization": "Bearer push-test-key"}

    with TestClient(
        create_app(settings, push_store=store, push_dispatcher=dispatcher)
    ) as client:
        assert client.get("/api/v1/push/status").status_code == 401
        response = client.post(
            "/api/v1/push/devices", headers=headers, json=registration().model_dump()
        )
        assert response.status_code == 200
        assert response.json()["rotated"] is False
        assert "android-device-token" not in response.text

        rotated = registration("android-device-token-0002")
        response = client.post(
            "/api/v1/push/devices", headers=headers, json=rotated.model_dump()
        )
        assert response.status_code == 200
        assert response.json()["rotated"] is True

        listed = client.get("/api/v1/push/devices", headers=headers).json()["devices"]
        assert len(listed) == 1
        assert set(listed[0]).isdisjoint({"token", "api_key"})

        delivered = client.post(
            "/api/v1/push/test",
            headers=headers,
            json={"device_id": rotated.device_id},
        ).json()
        assert delivered == {"matched": 1, "delivered": 1, "failed": 0, "removed": 0}

        removed = client.delete(
            f"/api/v1/push/devices/{rotated.device_id}", headers=headers
        ).json()
        assert removed == {"ok": True, "removed": 1}
    assert provider.closed


def test_push_coordinator_filters_profile_and_deduplicates_events(tmp_path: Path):
    store = PushStore(tmp_path / "push.json")
    store.upsert(registration(profile="work"))
    other = registration("android-device-token-personal", profile="personal")
    other.device_id = "device-installation-0002"
    store.upsert(other)
    provider = FakeProvider()
    dispatcher = PushDispatcher(store, [provider])
    coordinator = PushCoordinator(None, dispatcher)
    event = {
        "type": "message.complete",
        "session_id": "session-42",
        "profile": "work",
        "payload": {"title": "Build finished", "id": "event-42"},
    }

    async def run() -> None:
        await coordinator.handle_event(event)
        await coordinator.handle_event(event)
        await coordinator.stop()

    asyncio.run(run())
    assert len(provider.sent) == 1
    subscription, message = provider.sent[0]
    assert subscription.profile == "work"
    assert message.data["session_id"] == "session-42"
    assert message.data["profile"] == "work"


def test_invalid_provider_token_is_removed(tmp_path: Path):
    store = PushStore(tmp_path / "push.json")
    store.upsert(registration())
    dispatcher = PushDispatcher(store, [FakeProvider(invalid=True)])
    message = PushMessage("id", "Title", "Body", {})

    result = asyncio.run(dispatcher.send(message))

    assert result == {"matched": 1, "delivered": 0, "failed": 1, "removed": 1}
    assert store.list() == []


def test_fcm_v1_provider_uses_oauth_and_structured_message(tmp_path: Path):
    credentials = tmp_path / "service-account.json"
    credentials.write_text(
        json.dumps(
            {
                "project_id": "hermes-test",
                "client_email": "push@example.test",
                "private_key": "not-used-in-this-test",
            }
        ),
        encoding="utf-8",
    )

    def handler(request: httpx.Request) -> httpx.Response:
        assert request.url.path.endswith("/v1/projects/hermes-test/messages:send")
        assert request.headers["authorization"] == "Bearer oauth-token"
        payload = json.loads(request.content)
        assert payload["message"]["token"] == "android-device-token-0001"
        assert payload["message"]["data"]["session_id"] == "session-1"
        return httpx.Response(200, json={"name": "messages/1"})

    client = httpx.AsyncClient(transport=httpx.MockTransport(handler))
    provider = FcmV1Provider(str(credentials), client=client)

    async def oauth_token() -> str:
        return "oauth-token"

    provider._oauth_token = oauth_token  # type: ignore[method-assign]
    subscription, _ = PushStore(tmp_path / "push.json").upsert(registration())
    result = asyncio.run(
        provider.send(
            subscription,
            PushMessage("id", "Title", "Body", {"session_id": "session-1"}),
        )
    )
    asyncio.run(client.aclose())
    assert result.delivered


def test_apns_provider_uses_alert_headers_and_payload(tmp_path: Path):
    key = tmp_path / "AuthKey.p8"
    key.write_text("not-used-in-this-test", encoding="utf-8")

    def handler(request: httpx.Request) -> httpx.Response:
        assert request.url.path == f"/3/device/{'a' * 64}"
        assert request.headers["authorization"] == "bearer provider-token"
        assert request.headers["apns-topic"] == "com.hermes.mobile"
        payload = json.loads(request.content)
        assert payload["aps"]["alert"]["title"] == "Title"
        assert payload["session_id"] == "session-1"
        return httpx.Response(200)

    client = httpx.AsyncClient(
        transport=httpx.MockTransport(handler),
        base_url="https://api.push.apple.com",
    )
    provider = ApnsProvider(
        team_id="TEAM",
        key_id="KEY",
        bundle_id="com.hermes.mobile",
        private_key_file=str(key),
        sandbox=False,
        client=client,
    )
    provider._jwt = lambda: "provider-token"  # type: ignore[method-assign]
    subscription = DeviceSubscription(
        device_id="device-installation-ios",
        platform="ios",
        token="a" * 64,
        connection_id="primary",
        profile=None,
        locale="en",
        app_version="1",
        updated_at=1,
    )
    result = asyncio.run(
        provider.send(
            subscription,
            PushMessage("00000000-0000-0000-0000-000000000001", "Title", "Body", {"session_id": "session-1"}),
        )
    )
    asyncio.run(client.aclose())
    assert result.delivered
