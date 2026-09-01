"""API-key authentication for the mobile-facing endpoints."""

from __future__ import annotations

import hmac

from fastapi import Depends, Header, HTTPException

from .config import Settings

_BEARER_PREFIX = "Bearer "
_API_KEY_HEADER = "X-API-Key"


def _verify(settings: Settings, authorization: str | None, x_api_key: str | None) -> None:
    """Validate the caller's API key (constant-time compare)."""
    presented = ""
    if authorization and authorization.startswith(_BEARER_PREFIX):
        presented = authorization[len(_BEARER_PREFIX):].strip()
    elif authorization:
        presented = authorization.strip()
    elif x_api_key:
        presented = x_api_key.strip()

    if not presented or not hmac.compare_digest(
        presented.encode(), settings.api_key.encode()
    ):
        raise HTTPException(status_code=401, detail="Invalid or missing API key")


def api_key_dependency(settings: Settings):
    """Build a FastAPI dependency that validates the API key.

    Returns a closure whose signature FastAPI can introspect, so the
    ``Header`` parameters are injected properly.
    """

    def _dependency(
        authorization: str | None = Header(default=None),
        x_api_key: str | None = Header(default=None),
    ) -> None:
        _verify(settings, authorization, x_api_key)

    return _dependency
