"""Unit tests for Hermes Mobile Server.

Run with::

    uv run pytest
"""

from __future__ import annotations

import hmac
import os
from pathlib import Path

import pytest
from fastapi.testclient import TestClient

from hermes_mobile_server.auth import _verify
from hermes_mobile_server.backend import _dashboard_public_url
from hermes_mobile_server.config import Settings
from hermes_mobile_server import config as server_config
from hermes_mobile_server.runtime import (
    _is_source_root,
    get_hermes_home,
    resolve_runtime,
)

# ---------------------------------------------------------------------------


def test_api_key_verification():
    settings = Settings(api_key="secret-123")
    _verify(settings, "Bearer secret-123", None)
    _verify(settings, None, "secret-123")
    with pytest.raises(Exception):
        _verify(settings, "Bearer wrong", None)
    with pytest.raises(Exception):
        _verify(settings, None, None)


def test_constant_time_compare():
    a = "abc123"
    b = "abc123"
    assert hmac.compare_digest(a.encode(), b.encode())
    assert not hmac.compare_digest("abc12".encode(), b.encode())


def test_api_key_is_persisted_with_private_permissions(tmp_path, monkeypatch):
    config_dir = tmp_path / "config"
    config_file = config_dir / "config.json"
    monkeypatch.setattr(server_config, "DEFAULT_CONFIG_DIR", config_dir)
    monkeypatch.setattr(server_config, "CONFIG_FILE", config_file)

    server_config._save_api_key("secret-123")

    assert config_dir.stat().st_mode & 0o777 == 0o700
    assert config_file.stat().st_mode & 0o777 == 0o600


def test_dashboard_public_url_uses_explicit_mobile_origin():
    settings = Settings(
        host="0.0.0.0",
        port=8877,
        public_url="https://hermes.example/mobile/",
    )
    assert (
        _dashboard_public_url(settings)
        == "https://hermes.example/mobile/api/v1"
    )


def test_dashboard_public_url_uses_bound_host_and_port():
    settings = Settings(host="127.0.0.1", port=9000)
    assert _dashboard_public_url(settings) == "http://127.0.0.1:9000/api/v1"


def test_runtime_capability_is_full_or_legacy():
    """The resolved runtime must carry a capability per D7."""
    runtime = resolve_runtime()
    if runtime is None:
        pytest.skip("no hermes runtime on this machine")
    assert runtime.capability in ("full", "legacy", "missing")


def test_runtime_resolution_finds_managed_install():
    """The dev machine should resolve a managed install (or at least something)."""
    runtime = resolve_runtime()
    if runtime is None:
        pytest.skip("no hermes runtime on this machine")
    assert runtime.argv
    assert runtime.source_root.exists()
    # The source root must look like a hermes checkout.
    assert _is_source_root(runtime.source_root)


def test_hermes_home_resolution():
    home = get_hermes_home()
    assert isinstance(home, Path)
    assert str(home)


def test_health_endpoint_unauthenticated():
    """/api/v1/health must be reachable without an API key."""
    from hermes_mobile_server.app import create_app

    settings = Settings(
        api_key="test-key",
        backend_ready_timeout=0.1,
    )
    with TestClient(create_app(settings)) as client:
        resp = client.get("/api/v1/health")
        assert resp.status_code == 200
        assert "backend_running" in resp.json()


def test_protected_endpoints_require_api_key():
    from hermes_mobile_server.app import create_app

    settings = Settings(api_key="test-key")
    with TestClient(create_app(settings)) as client:
        resp = client.get("/api/v1/status")
        assert resp.status_code == 401

        resp = client.get("/api/v1/status", headers={"Authorization": "Bearer test-key"})
        # Either 200 (backend up) or 503 (backend failed to boot) — but not 401.
        assert resp.status_code in (200, 503)
