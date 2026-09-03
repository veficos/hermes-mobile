"""Server configuration.

Configuration is read from environment variables first, then from a small
JSON config file (``~/.hermes-mobile-server/config.json``) used to persist
the generated API key across restarts so the mobile app does not have to be
reconfigured every time the server starts.
"""

from __future__ import annotations

import json
import os
import secrets
import stat
from dataclasses import dataclass, field
from pathlib import Path

SERVER_VERSION = "1.0.0"

#: Directory where this server persists its own state (generated API key…).
DEFAULT_CONFIG_DIR = Path(
    os.environ.get(
        "HERMES_MOBILE_CONFIG_DIR",
        str(Path.home() / ".hermes-mobile-server"),
    )
)
CONFIG_FILE = DEFAULT_CONFIG_DIR / "config.json"

#: Well-known environment variables understood by the Hermes runtime.
HERMES_HOME_ENV = "HERMES_HOME"


@dataclass
class Settings:
    """Effective server settings."""

    #: API key required on every request (Authorization: Bearer <key>).
    api_key: str = field(default_factory=lambda: _generate_api_key())
    #: Interface the mobile-facing HTTP server binds to. ``0.0.0.0`` lets the
    #: phone reach the server over the LAN.
    host: str = "127.0.0.1"
    #: Port of the mobile-facing HTTP server.
    port: int = 8877
    #: Host the local Hermes backend is told to bind.
    backend_host: str = "127.0.0.1"
    #: Port for the local Hermes backend; ``0`` asks the OS for a free port.
    backend_port: int = 0
    #: Override for the Hermes source root (equivalent to the desktop app's
    #: ``HERMES_DESKTOP_HERMES_ROOT``).
    hermes_root_override: str | None = None
    #: Optional allow-list of filesystem roots the local file API
    #: (``/api/v1/files/*``) may touch. ``None``/empty (default) leaves file
    #: operations unrestricted.
    allow_paths: list[str] | None = None
    #: Timeout (s) waiting for the backend to announce its port.
    backend_ready_timeout: float = 90.0
    #: Externally reachable mobile-server origin used for browser OAuth
    #: callbacks, e.g. ``http://192.168.1.20:8877``.
    public_url: str | None = None
    #: Log level for uvicorn.
    log_level: str = "info"
    #: FCM HTTP v1 service-account JSON file. Empty disables FCM delivery.
    fcm_service_account_file: str | None = None
    #: APNs token-auth credentials. All four values are required.
    apns_team_id: str | None = None
    apns_key_id: str | None = None
    apns_bundle_id: str | None = None
    apns_private_key_file: str | None = None
    #: Use Apple's sandbox endpoint for development-signed applications.
    apns_sandbox: bool = False
    #: Maximum simultaneous WebSockets accepted from one source address.
    websocket_max_per_client: int = 12
    #: Trust X-Forwarded-For for WebSocket limiting only behind a trusted proxy.
    trust_forwarded_for: bool = False
    #: Reverse-proxy WebSocket idle timeout, used for startup validation.
    reverse_proxy_idle_timeout: int | None = None
    #: Worker threads for local filesystem/Git operations (a dedicated pool,
    #: separate from the default executor used elsewhere, so a slow Git op
    #: can't starve SQLite/PTY reads — see ``concurrency.BoundedExecutor``).
    local_fs_max_workers: int = 4
    #: Maximum interactive terminal (PTY) sessions this server keeps alive
    #: at once, across all clients. ``None`` disables the cap.
    terminal_session_limit: int = 8
    #: Uvicorn's ``limit_concurrency``: a backstop that rejects new
    #: connections past this many in-flight ASGI requests, so a runaway
    #: client can't exhaust server memory. ``None`` leaves it unbounded.
    request_concurrency_limit: int | None = 200


def _env_str(name: str, default: str = "") -> str:
    value = os.environ.get(name, "").strip()
    return value or default


def _env_int(name: str, default: int) -> int:
    raw = os.environ.get(name, "").strip()
    if not raw:
        return default
    try:
        return int(raw)
    except ValueError:
        return default


def _env_bool(name: str, default: bool = False) -> bool:
    raw = os.environ.get(name, "").strip().lower()
    if not raw:
        return default
    return raw in {"1", "true", "yes", "on"}


def _generate_api_key() -> str:
    """Generate a random, URL-safe API key."""
    return "hm_" + secrets.token_urlsafe(32)


def _persisted_api_key() -> str | None:
    """Load the API key previously persisted to the config file, if any."""
    try:
        if CONFIG_FILE.is_file():
            data = json.loads(CONFIG_FILE.read_text(encoding="utf-8"))
            key = data.get("api_key")
            return key if isinstance(key, str) and key else None
    except (OSError, ValueError):
        pass
    return None


def _save_api_key(api_key: str) -> None:
    """Persist the API key so restarts keep the same key."""
    try:
        DEFAULT_CONFIG_DIR.mkdir(parents=True, exist_ok=True, mode=0o700)
        DEFAULT_CONFIG_DIR.chmod(0o700)
        data: dict = {}
        if CONFIG_FILE.is_file():
            try:
                data = json.loads(CONFIG_FILE.read_text(encoding="utf-8"))
            except (OSError, ValueError):
                data = {}
        data["api_key"] = api_key
        CONFIG_FILE.write_text(
            json.dumps(data, indent=2, ensure_ascii=False), encoding="utf-8"
        )
        CONFIG_FILE.chmod(stat.S_IRUSR | stat.S_IWUSR)
    except OSError:
        # Persistence is best-effort; the key still works for this process.
        pass


def _resolve_api_key() -> str:
    """Resolve the API key: env var > persisted key > freshly generated."""
    env_key = _env_str("HERMES_MOBILE_API_KEY")
    if env_key:
        return env_key
    persisted = _persisted_api_key()
    if persisted:
        return persisted
    key = _generate_api_key()
    _save_api_key(key)
    return key


def load_settings() -> Settings:
    """Build :class:`Settings` from the environment."""
    hermes_root = _env_str("HERMES_DESKTOP_HERMES_ROOT") or _env_str(
        "HERMES_MOBILE_HERMES_ROOT"
    ) or None

    allow_raw = _env_str("HERMES_MOBILE_ALLOW_PATHS")
    allow_paths: list[str] | None = None
    if allow_raw:
        allow_paths = [p for p in (part.strip() for part in allow_raw.split(",")) if p]

    return Settings(
        api_key=_resolve_api_key(),
        host=_env_str("HERMES_MOBILE_HOST", "127.0.0.1"),
        port=_env_int("HERMES_MOBILE_PORT", 8877),
        backend_host=_env_str("HERMES_MOBILE_SERVE_HOST", "127.0.0.1"),
        backend_port=_env_int("HERMES_MOBILE_SERVE_PORT", 0),
        hermes_root_override=hermes_root,
        allow_paths=allow_paths,
        backend_ready_timeout=_env_int("HERMES_MOBILE_READY_TIMEOUT", 90),
        public_url=_env_str("HERMES_MOBILE_PUBLIC_URL") or None,
        log_level=_env_str("HERMES_MOBILE_LOG_LEVEL", "info"),
        fcm_service_account_file=(
            _env_str("HERMES_MOBILE_FCM_SERVICE_ACCOUNT_FILE") or None
        ),
        apns_team_id=_env_str("HERMES_MOBILE_APNS_TEAM_ID") or None,
        apns_key_id=_env_str("HERMES_MOBILE_APNS_KEY_ID") or None,
        apns_bundle_id=_env_str("HERMES_MOBILE_APNS_BUNDLE_ID") or None,
        apns_private_key_file=(
            _env_str("HERMES_MOBILE_APNS_PRIVATE_KEY_FILE") or None
        ),
        apns_sandbox=_env_bool("HERMES_MOBILE_APNS_SANDBOX"),
        websocket_max_per_client=_env_int(
            "HERMES_MOBILE_WS_MAX_PER_CLIENT", 12
        ),
        trust_forwarded_for=_env_bool("HERMES_MOBILE_TRUST_FORWARDED_FOR"),
        reverse_proxy_idle_timeout=(
            _env_int("HERMES_MOBILE_PROXY_IDLE_TIMEOUT", 0) or None
        ),
        local_fs_max_workers=_env_int("HERMES_MOBILE_LOCAL_FS_WORKERS", 4),
        terminal_session_limit=_env_int("HERMES_MOBILE_TERMINAL_SESSION_LIMIT", 8),
        request_concurrency_limit=(
            _env_int("HERMES_MOBILE_CONCURRENCY_LIMIT", 200) or None
        ),
    )
