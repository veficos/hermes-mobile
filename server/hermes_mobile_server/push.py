"""Remote push subscriptions and APNs/FCM delivery."""

from __future__ import annotations

import asyncio
import hashlib
import json
import logging
import os
import re
import stat
import time
import uuid
from collections import deque
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Protocol

import httpx
import jwt
from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel, Field, field_validator

from .auth import api_key_dependency
from .backend import BackendManager
from .config import DEFAULT_CONFIG_DIR, Settings

logger = logging.getLogger("hermes_mobile_server.push")

_DEVICE_ID = re.compile(r"^[A-Za-z0-9._:-]{8,160}$")
_APNS_TOKEN = re.compile(r"^[0-9a-fA-F]{64}$")
_MAX_TOKEN_LENGTH = 4096
_PUSH_EVENTS = {
    "message.complete",
    "approval.request",
    "background.complete",
    "notification.show",
    "error",
}

#: Total attempts (including the first) for a transiently-failing push.
_PUSH_RETRY_ATTEMPTS = 3
#: Delay before attempt 2 and attempt 3 respectively.
_PUSH_RETRY_DELAYS = (0.5, 1.5)


@dataclass(frozen=True)
class DeviceSubscription:
    device_id: str
    platform: str
    token: str
    connection_id: str
    profile: str | None
    locale: str
    app_version: str
    updated_at: int

    @property
    def key(self) -> str:
        return f"{self.device_id}\0{self.connection_id}\0{self.profile or ''}"

    def public_json(self) -> dict:
        return {
            "device_id": self.device_id,
            "platform": self.platform,
            "connection_id": self.connection_id,
            "profile": self.profile,
            "locale": self.locale,
            "app_version": self.app_version,
            "updated_at": self.updated_at,
            "token_suffix": self.token[-6:] if len(self.token) >= 6 else "",
        }


class DeviceRegistration(BaseModel):
    device_id: str = Field(min_length=8, max_length=160)
    platform: str
    token: str = Field(min_length=16, max_length=_MAX_TOKEN_LENGTH)
    connection_id: str = Field(default="primary", min_length=1, max_length=160)
    profile: str | None = Field(default=None, max_length=160)
    locale: str = Field(default="en", min_length=2, max_length=32)
    app_version: str = Field(default="", max_length=64)

    @field_validator("device_id")
    @classmethod
    def valid_device_id(cls, value: str) -> str:
        value = value.strip()
        if not _DEVICE_ID.fullmatch(value):
            raise ValueError("device_id contains unsupported characters")
        return value

    @field_validator("platform")
    @classmethod
    def valid_platform(cls, value: str) -> str:
        value = value.strip().lower()
        if value not in {"android", "ios"}:
            raise ValueError("platform must be android or ios")
        return value

    @field_validator("token")
    @classmethod
    def valid_token(cls, value: str) -> str:
        value = value.strip()
        if not value or any(char.isspace() for char in value):
            raise ValueError("token must not contain whitespace")
        return value

    @field_validator("connection_id", "locale", "app_version")
    @classmethod
    def trimmed(cls, value: str) -> str:
        return value.strip()

    @field_validator("profile")
    @classmethod
    def normalized_profile(cls, value: str | None) -> str | None:
        normalized = (value or "").strip()
        return normalized or None


class TestPushRequest(BaseModel):
    device_id: str | None = Field(default=None, max_length=160)
    title: str = Field(default="Hermes Mobile", min_length=1, max_length=120)
    message: str = Field(default="Push delivery is configured.", max_length=500)


class PushStore:
    def __init__(self, path: Path | None = None) -> None:
        self.path = path or (DEFAULT_CONFIG_DIR / "push_devices.json")
        self._items: dict[str, DeviceSubscription] = {}
        self._load()

    def _load(self) -> None:
        try:
            raw = json.loads(self.path.read_text(encoding="utf-8"))
            for item in raw.get("devices", []):
                subscription = DeviceSubscription(**item)
                self._items[subscription.key] = subscription
        except (OSError, TypeError, ValueError):
            self._items = {}

    def _save(self) -> None:
        self.path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
        self.path.parent.chmod(0o700)
        temporary = self.path.with_suffix(".tmp")
        temporary.write_text(
            json.dumps(
                {"version": 1, "devices": [asdict(item) for item in self._items.values()]},
                ensure_ascii=False,
                separators=(",", ":"),
            ),
            encoding="utf-8",
        )
        temporary.chmod(stat.S_IRUSR | stat.S_IWUSR)
        os.replace(temporary, self.path)
        self.path.chmod(stat.S_IRUSR | stat.S_IWUSR)

    def upsert(self, registration: DeviceRegistration) -> tuple[DeviceSubscription, bool]:
        subscription = DeviceSubscription(
            device_id=registration.device_id,
            platform=registration.platform,
            token=registration.token,
            connection_id=registration.connection_id,
            profile=registration.profile,
            locale=registration.locale,
            app_version=registration.app_version,
            updated_at=int(time.time()),
        )
        previous = self._items.get(subscription.key)
        rotated = previous is not None and previous.token != subscription.token
        # A provider token identifies one app installation. Remove stale scopes
        # that reuse the same token before writing the current registration.
        self._items = {
            key: item
            for key, item in self._items.items()
            if item.token != subscription.token or key == subscription.key
        }
        self._items[subscription.key] = subscription
        self._save()
        return subscription, rotated

    def list(self) -> list[DeviceSubscription]:
        return sorted(self._items.values(), key=lambda item: item.updated_at, reverse=True)

    def remove(self, device_id: str, *, connection_id: str | None = None) -> int:
        keys = [
            key
            for key, item in self._items.items()
            if item.device_id == device_id
            and (connection_id is None or item.connection_id == connection_id)
        ]
        for key in keys:
            self._items.pop(key, None)
        if keys:
            self._save()
        return len(keys)

    def remove_token(self, token: str) -> int:
        keys = [key for key, item in self._items.items() if item.token == token]
        for key in keys:
            self._items.pop(key, None)
        if keys:
            self._save()
        return len(keys)


@dataclass(frozen=True)
class PushMessage:
    event_id: str
    title: str
    body: str
    data: dict[str, str]
    priority: bool = False


@dataclass(frozen=True)
class DeliveryResult:
    delivered: bool
    invalid_token: bool = False
    detail: str = ""
    #: The provider's HTTP status code, when the failure came from one
    #: (`None` for a locally-detected bad token, or on success). Lets the
    #: dispatcher tell a transient failure (429/5xx — worth retrying) apart
    #: from a permanent one (other 4xx) without parsing `detail`.
    status_code: int | None = None


def _is_transient_push_failure(result: DeliveryResult) -> bool:
    """A failure worth retrying: rate-limited or a provider-side error.

    Never true for `invalid_token` (permanent — retrying a dead
    registration is pointless) or any other 4xx (a malformed request won't
    fix itself either).
    """
    if result.invalid_token or result.status_code is None:
        return False
    return result.status_code == 429 or result.status_code >= 500


class PushProvider(Protocol):
    platform: str

    async def send(self, subscription: DeviceSubscription, message: PushMessage) -> DeliveryResult: ...

    async def close(self) -> None: ...


class FcmV1Provider:
    platform = "android"

    def __init__(self, credentials_file: str, *, client: httpx.AsyncClient | None = None) -> None:
        credentials = json.loads(Path(credentials_file).read_text(encoding="utf-8"))
        self.project_id = credentials["project_id"]
        self.client_email = credentials["client_email"]
        self.private_key = credentials["private_key"]
        self.token_uri = credentials.get("token_uri", "https://oauth2.googleapis.com/token")
        self._client = client or httpx.AsyncClient(timeout=20.0)
        self._owns_client = client is None
        self._access_token: str | None = None
        self._expires_at = 0.0

    async def _oauth_token(self) -> str:
        now = time.time()
        if self._access_token and now < self._expires_at - 60:
            return self._access_token
        assertion = jwt.encode(
            {
                "iss": self.client_email,
                "scope": "https://www.googleapis.com/auth/firebase.messaging",
                "aud": self.token_uri,
                "iat": int(now),
                "exp": int(now) + 3600,
            },
            self.private_key,
            algorithm="RS256",
        )
        response = await self._client.post(
            self.token_uri,
            data={
                "grant_type": "urn:ietf:params:oauth:grant-type:jwt-bearer",
                "assertion": assertion,
            },
        )
        response.raise_for_status()
        payload = response.json()
        self._access_token = payload["access_token"]
        self._expires_at = now + int(payload.get("expires_in", 3600))
        return self._access_token

    async def send(self, subscription: DeviceSubscription, message: PushMessage) -> DeliveryResult:
        token = await self._oauth_token()
        response = await self._client.post(
            f"https://fcm.googleapis.com/v1/projects/{self.project_id}/messages:send",
            headers={"Authorization": f"Bearer {token}"},
            json={
                "message": {
                    "token": subscription.token,
                    "notification": {"title": message.title, "body": message.body},
                    "data": message.data,
                    "android": {"priority": "HIGH" if message.priority else "NORMAL"},
                }
            },
        )
        if response.status_code < 300:
            return DeliveryResult(True)
        text = response.text[:500]
        invalid = response.status_code in {400, 404} and any(
            marker in text for marker in ("UNREGISTERED", "INVALID_ARGUMENT")
        )
        return DeliveryResult(
            False,
            invalid_token=invalid,
            detail=f"FCM {response.status_code}",
            status_code=response.status_code,
        )

    async def close(self) -> None:
        if self._owns_client:
            await self._client.aclose()


class ApnsProvider:
    platform = "ios"

    def __init__(
        self,
        *,
        team_id: str,
        key_id: str,
        bundle_id: str,
        private_key_file: str,
        sandbox: bool,
        client: httpx.AsyncClient | None = None,
    ) -> None:
        self.team_id = team_id
        self.key_id = key_id
        self.bundle_id = bundle_id
        self.private_key = Path(private_key_file).read_text(encoding="utf-8")
        self._client = client or httpx.AsyncClient(
            base_url=(
                "https://api.sandbox.push.apple.com"
                if sandbox
                else "https://api.push.apple.com"
            ),
            http2=True,
            timeout=20.0,
        )
        self._owns_client = client is None
        self._provider_token: str | None = None
        self._token_created_at = 0.0

    def _jwt(self) -> str:
        now = time.time()
        if self._provider_token and now - self._token_created_at < 3000:
            return self._provider_token
        self._provider_token = jwt.encode(
            {"iss": self.team_id, "iat": int(now)},
            self.private_key,
            algorithm="ES256",
            headers={"kid": self.key_id},
        )
        self._token_created_at = now
        return self._provider_token

    async def send(self, subscription: DeviceSubscription, message: PushMessage) -> DeliveryResult:
        if not _APNS_TOKEN.fullmatch(subscription.token):
            return DeliveryResult(False, invalid_token=True, detail="invalid APNs token")
        response = await self._client.post(
            f"/3/device/{subscription.token}",
            headers={
                "authorization": f"bearer {self._jwt()}",
                "apns-topic": self.bundle_id,
                "apns-push-type": "alert",
                "apns-priority": "10" if message.priority else "5",
                "apns-id": message.event_id,
            },
            json={
                "aps": {
                    "alert": {"title": message.title, "body": message.body},
                    "sound": "default",
                },
                **message.data,
            },
        )
        if response.status_code == 200:
            return DeliveryResult(True)
        try:
            reason = response.json().get("reason", "")
        except ValueError:
            reason = ""
        return DeliveryResult(
            False,
            invalid_token=response.status_code == 410
            or reason in {"BadDeviceToken", "DeviceTokenNotForTopic", "Unregistered"},
            detail=f"APNs {response.status_code} {reason}".strip(),
            status_code=response.status_code,
        )

    async def close(self) -> None:
        if self._owns_client:
            await self._client.aclose()


class PushDispatcher:
    def __init__(self, store: PushStore, providers: list[PushProvider]) -> None:
        self.store = store
        self.providers = {provider.platform: provider for provider in providers}

    @classmethod
    def from_settings(cls, settings: Settings, store: PushStore) -> "PushDispatcher":
        providers: list[PushProvider] = []
        if settings.fcm_service_account_file:
            try:
                providers.append(FcmV1Provider(settings.fcm_service_account_file))
            except (OSError, KeyError, ValueError):
                logger.exception("FCM credentials could not be loaded")
        apns_values = (
            settings.apns_team_id,
            settings.apns_key_id,
            settings.apns_bundle_id,
            settings.apns_private_key_file,
        )
        if all(apns_values):
            try:
                providers.append(
                    ApnsProvider(
                        team_id=settings.apns_team_id or "",
                        key_id=settings.apns_key_id or "",
                        bundle_id=settings.apns_bundle_id or "",
                        private_key_file=settings.apns_private_key_file or "",
                        sandbox=settings.apns_sandbox,
                    )
                )
            except (OSError, ValueError):
                logger.exception("APNs credentials could not be loaded")
        return cls(store, providers)

    async def send(
        self,
        message: PushMessage,
        *,
        profile: str | None = None,
        device_id: str | None = None,
    ) -> dict[str, int]:
        results = {"matched": 0, "delivered": 0, "failed": 0, "removed": 0}
        for subscription in self.store.list():
            if device_id and subscription.device_id != device_id:
                continue
            if profile and subscription.profile and subscription.profile != profile:
                continue
            results["matched"] += 1
            provider = self.providers.get(subscription.platform)
            if provider is None:
                results["failed"] += 1
                continue
            result = await self._send_with_retry(provider, subscription, message)
            if result is None:
                results["failed"] += 1
                continue
            if result.delivered:
                results["delivered"] += 1
            else:
                results["failed"] += 1
                if result.invalid_token:
                    results["removed"] += self.store.remove_token(subscription.token)
        return results

    async def _send_with_retry(
        self,
        provider: PushProvider,
        subscription: DeviceSubscription,
        message: PushMessage,
    ) -> DeliveryResult | None:
        """Retry a TRANSIENT delivery failure a couple of times with backoff.

        The same connectivity blip that made the mobile client fall back to
        push in the first place can also make the push provider itself
        transiently unreachable (a raised `httpx.HTTPError`, or a 429/5xx
        response — see `_is_transient_push_failure`); this exists for that
        overlap specifically. A permanent failure (invalid/expired token,
        malformed request) is never retried — `send()` still handles token
        cleanup for those on the returned (or `None`, on an exception with
        no attempts left) result.
        """
        result: DeliveryResult | None = None
        for attempt in range(_PUSH_RETRY_ATTEMPTS):
            try:
                result = await provider.send(subscription, message)
            except (httpx.HTTPError, jwt.PyJWTError, ValueError):
                logger.exception(
                    "push delivery failed platform=%s device=%s attempt=%d/%d",
                    subscription.platform,
                    subscription.device_id,
                    attempt + 1,
                    _PUSH_RETRY_ATTEMPTS,
                )
                result = None
            if result is not None and (
                result.delivered or not _is_transient_push_failure(result)
            ):
                return result
            if attempt < _PUSH_RETRY_ATTEMPTS - 1:
                logger.info(
                    "retrying push delivery platform=%s device=%s attempt=%d/%d",
                    subscription.platform,
                    subscription.device_id,
                    attempt + 2,
                    _PUSH_RETRY_ATTEMPTS,
                )
                await asyncio.sleep(_PUSH_RETRY_DELAYS[attempt])
        return result

    async def close(self) -> None:
        await asyncio.gather(
            *(provider.close() for provider in self.providers.values()),
            return_exceptions=True,
        )


class PushCoordinator:
    def __init__(self, backend: BackendManager | None, dispatcher: PushDispatcher) -> None:
        self.backend = backend
        self.dispatcher = dispatcher
        self._monitor: asyncio.Task | None = None
        self._seen: set[str] = set()
        self._seen_order: deque[str] = deque()
        if backend is not None:
            backend.add_event_listener(self.handle_event)

    async def start(self) -> None:
        if self.backend is not None and self._monitor is None:
            self._monitor = asyncio.create_task(self._monitor_gateway())

    async def _monitor_gateway(self) -> None:
        while True:
            try:
                if self.backend is not None and self.backend.is_running:
                    await self.backend.ensure_gateway_event_stream()
            except (OSError, RuntimeError):
                logger.warning("push event stream unavailable", exc_info=True)
            await asyncio.sleep(10)

    async def stop(self) -> None:
        if self._monitor is not None:
            self._monitor.cancel()
            try:
                await self._monitor
            except asyncio.CancelledError:
                pass
            self._monitor = None
        await self.dispatcher.close()

    async def handle_event(self, raw: dict) -> None:
        event_type = str(raw.get("type") or "")
        if event_type not in _PUSH_EVENTS:
            return
        nested = raw.get("payload") if isinstance(raw.get("payload"), dict) else {}
        payload = {**nested, **raw}
        payload.pop("payload", None)
        session_id = str(payload.get("session_id") or "")
        profile = str(payload.get("profile") or "") or None
        event_key = str(payload.get("id") or payload.get("request_id") or "")
        digest = hashlib.sha256(
            json.dumps([event_type, session_id, profile, event_key, payload], sort_keys=True).encode()
        ).hexdigest()
        if digest in self._seen:
            return
        self._seen.add(digest)
        self._seen_order.append(digest)
        while len(self._seen_order) > 1024:
            self._seen.discard(self._seen_order.popleft())
        message = _message_for_event(event_type, payload, session_id, profile)
        await self.dispatcher.send(message, profile=profile)


def _message_for_event(
    event_type: str, payload: dict, session_id: str, profile: str | None
) -> PushMessage:
    title = "Hermes"
    body = "Agent activity needs your attention."
    priority = False
    approval = False
    if event_type == "message.complete":
        title = "Session complete"
        body = str(payload.get("title") or "Hermes finished the current response.")
    elif event_type == "approval.request":
        title = str(payload.get("title") or "Approval required")
        body = str(payload.get("message") or "Hermes is waiting for your approval.")
        priority = True
        approval = True
    elif event_type == "background.complete":
        title = "Background task complete"
        body = str(payload.get("title") or payload.get("message") or body)
    elif event_type == "notification.show":
        title = str(payload.get("title") or "Hermes")
        body = str(payload.get("text") or payload.get("message") or body)
        priority = str(payload.get("level") or "") in {"error", "warn"}
    elif event_type == "error":
        title = "Hermes error"
        body = str(payload.get("message") or payload.get("error") or body)
        priority = True
    body = body.strip()[:500]
    event_id = str(uuid.uuid5(uuid.NAMESPACE_URL, f"hermes:{event_type}:{session_id}:{body}"))
    return PushMessage(
        event_id=event_id,
        title=title.strip()[:120],
        body=body,
        priority=priority,
        data={
            "notification_id": event_id,
            "event_type": event_type,
            "session_id": session_id,
            "profile": profile or "",
            "approval": "true" if approval else "false",
        },
    )


def build_push_router(
    settings: Settings,
    store: PushStore,
    dispatcher: PushDispatcher,
) -> APIRouter:
    router = APIRouter(
        prefix="/api/v1/push",
        tags=["push"],
        dependencies=[Depends(api_key_dependency(settings))],
    )

    @router.get("/status")
    async def status() -> dict:
        return {
            "configured_platforms": sorted(dispatcher.providers),
            "device_count": len(store.list()),
        }

    @router.get("/devices")
    async def devices() -> dict:
        return {"devices": [item.public_json() for item in store.list()]}

    @router.post("/devices")
    async def register(registration: DeviceRegistration) -> dict:
        item, rotated = store.upsert(registration)
        return {"ok": True, "rotated": rotated, "device": item.public_json()}

    @router.delete("/devices/{device_id}")
    async def unregister(
        device_id: str,
        connection_id: str | None = Query(default=None, max_length=160),
    ) -> dict:
        if not _DEVICE_ID.fullmatch(device_id):
            raise HTTPException(status_code=400, detail="invalid device id")
        return {"ok": True, "removed": store.remove(device_id, connection_id=connection_id)}

    @router.post("/test")
    async def test_push(request: TestPushRequest) -> dict:
        message = PushMessage(
            event_id=str(uuid.uuid4()),
            title=request.title,
            body=request.message,
            data={"notification_id": str(uuid.uuid4()), "event_type": "test"},
            priority=True,
        )
        return await dispatcher.send(message, device_id=request.device_id)

    return router
