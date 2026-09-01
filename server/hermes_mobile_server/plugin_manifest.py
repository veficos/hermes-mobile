"""Safe manifest-only adapter for declarative mobile plugin contributions.

The Hermes gateway owns plugin lifecycle and inventory.  This module only
enriches those inventory rows with bounded, host-rendered UI data read from
the same plugin directories.  It never imports or evaluates plugin code.
"""

from __future__ import annotations

import json
import logging
import math
import re
from pathlib import Path
from typing import Any, Mapping
from urllib.parse import urlparse

import yaml

logger = logging.getLogger("hermes_mobile_server.plugins")

MAX_MANIFEST_BYTES = 512 * 1024
MAX_CONTRIBUTIONS = 64
MAX_FIELDS = 64
MAX_VIEW_ACTIONS = 32
MAX_OPTIONS = 100
MAX_LOCALES = 16
MAX_LOCALE_MESSAGES = 512
MAX_JSON_NODES = 512
MAX_JSON_DEPTH = 6
MAX_JSON_BYTES = 64 * 1024

_BUNDLED_SKIP = frozenset({"memory", "context_engine", "model-providers"})
_AREAS = frozenset(
    {"navigation", "command", "settings", "composer", "detail", "transcript", "pane"}
)
_COLORS = frozenset({"green", "orange", "red", "blue", "gray", "purple"})
_FIELD_TYPES = frozenset({"text", "multiline", "number", "boolean", "select", "secret"})
_VIEW_TYPES = frozenset({"action", "form", "list"})
_READ_ACTIONS = frozenset({"get", "list", "show", "status"})
_NOTIFY_LEVELS = frozenset({"info", "success", "warning", "error"})
_ACTION_TONES = frozenset({"default", "primary", "neutral", "success", "warning", "danger"})
_ID_RE = re.compile(r"^[a-z0-9][a-z0-9._-]{0,127}$")
_KEY_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9_.-]{0,127}$")
_METHOD_RE = re.compile(r"^[a-z][a-z0-9_.-]{0,127}$")
_PATH_SEGMENT_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]{0,159}$")
_ICON_RE = re.compile(r"^[a-z0-9][a-z0-9_-]{0,63}$")
_PLATFORM_RE = re.compile(r"^[a-z0-9][a-z0-9_-]{0,31}$")
_LOCALE_RE = re.compile(r"^[A-Za-z]{2,8}(?:[-_][A-Za-z0-9]{1,8}){0,3}$")


class _InvalidManifest(ValueError):
    pass


def _inside(path: Path, root: Path) -> bool:
    try:
        path.relative_to(root)
        return True
    except ValueError:
        return False


def profile_plugins_root(hermes_home: Path, profile: str | None) -> Path:
    """Resolve a profile's plugin root without permitting path traversal."""
    home = hermes_home.expanduser().resolve(strict=False)
    name = (profile or "").strip()
    if not name or name == "default":
        return home / "plugins"
    if (
        len(name) > 160
        or name in {".", ".."}
        or any(char in name for char in ("/", "\\", "\x00"))
    ):
        raise ValueError("invalid profile name")
    profiles = (home / "profiles").resolve(strict=False)
    resolved = (profiles / name).resolve(strict=False)
    if not _inside(resolved, profiles):
        raise ValueError("invalid profile path")
    return resolved / "plugins"


def _text(value: Any, limit: int, *, allow_empty: bool = False) -> str | None:
    if not isinstance(value, str) or "\x00" in value:
        return None
    result = value.strip()
    if (not result and not allow_empty) or len(result) > limit:
        return None
    return result


def _key(value: Any, *, limit: int = 128) -> str | None:
    result = _text(value, limit)
    return result if result is not None and _KEY_RE.fullmatch(result) else None


def _bounded_json(value: Any) -> Any:
    nodes = 0

    def visit(current: Any, depth: int) -> Any:
        nonlocal nodes
        nodes += 1
        if nodes > MAX_JSON_NODES or depth > MAX_JSON_DEPTH:
            raise _InvalidManifest("JSON value is too complex")
        if current is None or isinstance(current, bool):
            return current
        if isinstance(current, int) and not isinstance(current, bool):
            return current
        if isinstance(current, float):
            if not math.isfinite(current):
                raise _InvalidManifest("JSON number must be finite")
            return current
        if isinstance(current, str):
            if len(current) > 16_384 or "\x00" in current:
                raise _InvalidManifest("JSON string is too large")
            return current
        if isinstance(current, list):
            if len(current) > 100:
                raise _InvalidManifest("JSON list is too large")
            return [visit(item, depth + 1) for item in current]
        if isinstance(current, Mapping):
            if len(current) > 64:
                raise _InvalidManifest("JSON object is too large")
            result: dict[str, Any] = {}
            for raw_key, item in current.items():
                if not isinstance(raw_key, str) or not raw_key or len(raw_key) > 128:
                    raise _InvalidManifest("JSON object key is invalid")
                result[raw_key] = visit(item, depth + 1)
            return result
        raise _InvalidManifest("value is not JSON compatible")

    result = visit(value, 0)
    if len(json.dumps(result, ensure_ascii=False, separators=(",", ":")).encode()) > MAX_JSON_BYTES:
        raise _InvalidManifest("JSON value is too large")
    return result


def _mapping(value: Any) -> dict[str, Any] | None:
    if not isinstance(value, Mapping):
        return None
    try:
        result = _bounded_json(value)
    except _InvalidManifest:
        return None
    return result if isinstance(result, dict) else None


def _safe_path(value: Any) -> str | None:
    path = _text(value, 512)
    if path is None:
        return None
    path = path.lstrip("/")
    parts = path.split("/")
    if not parts or any(not _PATH_SEGMENT_RE.fullmatch(part) for part in parts):
        return None
    return "/".join(parts)


def _normalize_action(raw: Any, *, automatic: bool = False) -> dict[str, Any] | None:
    action = _mapping(raw)
    if action is None:
        return None
    kind = _text(action.get("kind"), 32)
    kind = kind.lower() if kind else ""
    if kind == "gateway":
        method = _text(action.get("method"), 128)
        if method is None or not _METHOD_RE.fullmatch(method):
            return None
        params = _mapping(action.get("params", {}))
        if params is None:
            return None
        if automatic:
            verb = method.rsplit(".", 1)[-1]
            requested = str(params.get("action") or verb).strip().lower()
            if verb not in _READ_ACTIONS and not (
                verb == "manage" and requested in _READ_ACTIONS
            ):
                return None
        return {"kind": kind, "method": method, "params": params}
    if kind == "rest":
        path = _safe_path(action.get("path"))
        method = str(action.get("method") or "GET").strip().upper()
        if path is None or method not in {"GET", "POST", "PUT", "PATCH", "DELETE"}:
            return None
        if automatic and method != "GET":
            return None
        result: dict[str, Any] = {"kind": kind, "method": method, "path": path}
        for field in ("query", "body"):
            if field not in action:
                continue
            value = _mapping(action[field])
            if value is None:
                return None
            result[field] = value
        return result
    if automatic:
        return None
    if kind == "open-external":
        url = _text(action.get("url"), 2048)
        if url is None:
            return None
        parsed = urlparse(url)
        if parsed.scheme.lower() in {"http", "https"} and parsed.netloc:
            return {"kind": kind, "url": url}
        if parsed.scheme.lower() == "mailto" and parsed.path:
            return {"kind": kind, "url": url}
        return None
    if kind == "clipboard":
        value = action.get("text")
        if not isinstance(value, str) or not value or len(value) > 16_384 or "\x00" in value:
            return None
        return {"kind": kind, "text": value}
    if kind == "notify":
        title = _text(action.get("title"), 160)
        message = _text(action.get("message"), 4000)
        if title is None or message is None:
            return None
        result = {"kind": kind, "title": title, "message": message}
        key = _key(action.get("key"), limit=64)
        level = _text(action.get("level"), 16)
        if key is not None:
            result["key"] = key
        if level is not None and level.lower() in _NOTIFY_LEVELS:
            result["level"] = level.lower()
        return result
    return None


def _normalize_locales(raw: Any) -> dict[str, dict[str, str]]:
    if not isinstance(raw, Mapping):
        return {}
    result: dict[str, dict[str, str]] = {}
    for raw_tag, raw_messages in list(raw.items())[:MAX_LOCALES]:
        if not isinstance(raw_tag, str) or not _LOCALE_RE.fullmatch(raw_tag):
            continue
        if not isinstance(raw_messages, Mapping):
            continue
        messages: dict[str, str] = {}
        for raw_key, raw_value in list(raw_messages.items())[:MAX_LOCALE_MESSAGES]:
            key = _key(raw_key)
            if key is None or not isinstance(raw_value, str):
                continue
            if not raw_value or len(raw_value) > 4000 or "\x00" in raw_value:
                continue
            messages[key] = raw_value
        if messages:
            result[raw_tag.replace("_", "-").lower()] = messages
    return result


def _normalize_option(raw: Any) -> dict[str, Any] | None:
    if isinstance(raw, Mapping):
        value = raw.get("value")
        label = _text(raw.get("label"), 160)
        label_key = _key(raw.get("label_key"))
    else:
        value = raw
        label = _text(raw, 160) if isinstance(raw, str) else None
        label_key = None
    try:
        value = _bounded_json(value)
    except _InvalidManifest:
        return None
    if label is None and label_key is None:
        if value is None or isinstance(value, (dict, list)):
            return None
        label = str(value)
        if len(label) > 160:
            return None
    result = {"value": value, "label": label or ""}
    if label_key is not None:
        result["label_key"] = label_key
    return result


def _normalize_field(raw: Any) -> dict[str, Any] | None:
    if not isinstance(raw, Mapping):
        return None
    field_id = _key(raw.get("id"), limit=64)
    label = _text(raw.get("label"), 160)
    label_key = _key(raw.get("label_key"))
    field_type = str(raw.get("type") or "text").strip().lower()
    if field_id is None or (label is None and label_key is None) or field_type not in _FIELD_TYPES:
        return None
    result: dict[str, Any] = {
        "id": field_id,
        "label": label or "",
        "type": field_type,
        "required": raw.get("required") is True,
    }
    if label_key is not None:
        result["label_key"] = label_key
    description = _text(raw.get("description"), 500)
    description_key = _key(raw.get("description_key"))
    if description is not None:
        result["description"] = description
    if description_key is not None:
        result["description_key"] = description_key
    if "default" in raw:
        try:
            result["default"] = _bounded_json(raw["default"])
        except _InvalidManifest:
            return None
    options: list[dict[str, Any]] = []
    if isinstance(raw.get("options"), list):
        for option in raw["options"][:MAX_OPTIONS]:
            normalized = _normalize_option(option)
            if normalized is not None:
                options.append(normalized)
    if field_type == "select":
        if not options:
            return None
        result["options"] = options
    for name in ("min", "max"):
        value = raw.get(name)
        if isinstance(value, (int, float)) and not isinstance(value, bool) and math.isfinite(value):
            result[name] = value
    if "min" in result and "max" in result and result["min"] > result["max"]:
        return None
    return result


def _localized_text(
    result: dict[str, Any], raw: Mapping[Any, Any], name: str, limit: int
) -> None:
    value = _text(raw.get(name), limit)
    key = _key(raw.get(f"{name}_key"))
    if value is not None:
        result[name] = value
    if key is not None:
        result[f"{name}_key"] = key


def _normalize_view_action(raw: Any) -> dict[str, Any] | None:
    if not isinstance(raw, Mapping):
        return None
    action_id = _key(raw.get("id"), limit=64)
    title = _text(raw.get("title"), 160)
    title_key = _key(raw.get("title_key"))
    action = _normalize_action(raw.get("action"))
    if action_id is None or (title is None and title_key is None) or action is None:
        return None
    result: dict[str, Any] = {
        "id": action_id,
        "title": title or "",
        "action": action,
        "primary": raw.get("primary") is True,
    }
    if title_key is not None:
        result["title_key"] = title_key
    _localized_text(result, raw, "description", 500)
    _localized_text(result, raw, "confirm_title", 160)
    _localized_text(result, raw, "confirm_message", 1000)
    tone = _text(raw.get("tone"), 16)
    if tone is not None and tone.lower() in _ACTION_TONES:
        result["tone"] = tone.lower()
    return result


def _normalize_view(raw: Any) -> dict[str, Any] | None:
    if raw is None:
        return None
    if not isinstance(raw, Mapping):
        return None
    view_type = str(raw.get("type") or "action").strip().lower()
    if view_type not in _VIEW_TYPES:
        return None
    result: dict[str, Any] = {"type": view_type}
    fields: list[dict[str, Any]] = []
    seen_fields: set[str] = set()
    if isinstance(raw.get("fields"), list):
        for raw_field in raw["fields"][:MAX_FIELDS]:
            field = _normalize_field(raw_field)
            if field is None or field["id"] in seen_fields:
                continue
            seen_fields.add(field["id"])
            fields.append(field)
    if fields:
        result["fields"] = fields
    load_action = _normalize_action(raw.get("load_action"), automatic=True)
    submit_action = _normalize_action(raw.get("submit_action"))
    if load_action is not None:
        result["load_action"] = load_action
    if submit_action is not None:
        result["submit_action"] = submit_action
    actions: list[dict[str, Any]] = []
    seen_actions: set[str] = set()
    if isinstance(raw.get("actions"), list):
        for raw_action in raw["actions"][:MAX_VIEW_ACTIONS]:
            action = _normalize_view_action(raw_action)
            if action is None or action["id"] in seen_actions:
                continue
            seen_actions.add(action["id"])
            actions.append(action)
    if actions:
        result["actions"] = actions
    poll = raw.get("poll_seconds")
    if load_action is not None and isinstance(poll, (int, float)) and not isinstance(poll, bool):
        result["poll_seconds"] = max(5, min(3600, int(poll)))
    socket_path = _safe_path(raw.get("socket_path"))
    if socket_path is not None:
        result["socket_path"] = socket_path
    if raw.get("persist_inputs") is True:
        result["persist_inputs"] = True
    for name, fallback in (
        ("items_key", "items"),
        ("item_title_key", "title"),
        ("item_subtitle_key", "subtitle"),
    ):
        result[name] = _key(raw.get(name), limit=64) or fallback
    _localized_text(result, raw, "empty_message", 500)
    return result


def _normalize_contributions(raw: Any) -> list[dict[str, Any]]:
    if not isinstance(raw, list):
        return []
    result: list[dict[str, Any]] = []
    seen: set[str] = set()
    for item in raw[:MAX_CONTRIBUTIONS]:
        if not isinstance(item, Mapping):
            continue
        item_id = _text(item.get("id"), 128)
        item_id = item_id.lower() if item_id else ""
        title = _text(item.get("title"), 160)
        title_key = _key(item.get("title_key"))
        area = str(item.get("area") or "detail").strip().lower()
        view = _normalize_view(item.get("view"))
        action = _normalize_action(item.get("action"))
        view_type = str((view or {}).get("type") or "action")
        if (
            not _ID_RE.fullmatch(item_id)
            or item_id in seen
            or (title is None and title_key is None)
            or area not in _AREAS
            or (view_type == "action" and action is None)
        ):
            continue
        seen.add(item_id)
        row: dict[str, Any] = {
            "id": item_id,
            "area": area,
            "title": title or "",
        }
        if title_key is not None:
            row["title_key"] = title_key
        if action is not None:
            row["action"] = action
        _localized_text(row, item, "description", 500)
        icon = _text(item.get("icon"), 64)
        row["icon"] = icon.lower() if icon and _ICON_RE.fullmatch(icon.lower()) else "extension"
        try:
            order = int(item.get("order", 0))
        except (TypeError, ValueError):
            order = 0
        row["order"] = max(-10_000, min(10_000, order))
        platforms = item.get("platforms")
        if isinstance(platforms, list):
            normalized_platforms = []
            for platform in platforms[:16]:
                value = _text(platform, 32)
                value = value.lower() if value else ""
                if value and _PLATFORM_RE.fullmatch(value) and value not in normalized_platforms:
                    normalized_platforms.append(value)
            if normalized_platforms:
                row["platforms"] = normalized_platforms
        color = _text(item.get("color"), 16)
        if color is not None and color.lower() in _COLORS:
            row["color"] = color.lower()
        badge = _normalize_action(item.get("badge_action"), automatic=True)
        if badge is not None:
            row["badge_action"] = badge
        locales = _normalize_locales(item.get("locales"))
        if locales:
            row["locales"] = locales
        if view is not None:
            row["view"] = view
        result.append(row)
    return result


def _read_manifest(directory: Path, allowed_root: Path) -> Mapping[str, Any] | None:
    try:
        resolved_dir = directory.resolve(strict=True)
        if not _inside(resolved_dir, allowed_root):
            return None
        candidates = (directory / "plugin.yaml", directory / "plugin.yml")
        manifest = next((path for path in candidates if path.exists()), None)
        if manifest is None or manifest.is_symlink() or not manifest.is_file():
            return None
        resolved_manifest = manifest.resolve(strict=True)
        if not _inside(resolved_manifest, resolved_dir):
            return None
        size = manifest.stat().st_size
        if size <= 0 or size > MAX_MANIFEST_BYTES:
            return None
        source = manifest.read_text(encoding="utf-8")
        # Aliases can amplify a small YAML document into a huge object graph.
        if any(
            isinstance(token, (yaml.tokens.AnchorToken, yaml.tokens.AliasToken))
            for token in yaml.scan(source)
        ):
            return None
        parsed = yaml.safe_load(source)
        return parsed if isinstance(parsed, Mapping) else None
    except (OSError, UnicodeError, yaml.YAMLError):
        return None


def _scan_root(base: Path, *, skip: frozenset[str] = frozenset()) -> dict[str, dict[str, Any]]:
    try:
        allowed_root = base.expanduser().resolve(strict=True)
    except OSError:
        return {}
    if not allowed_root.is_dir():
        return {}
    found: dict[str, dict[str, Any]] = {}

    def scan(directory: Path, prefix: str, depth: int) -> None:
        try:
            children = sorted(directory.iterdir(), key=lambda path: path.name)
        except OSError:
            return
        for child in children:
            try:
                if not child.is_dir() or (depth == 0 and child.name in skip):
                    continue
                resolved = child.resolve(strict=True)
                if not _inside(resolved, allowed_root):
                    continue
                has_manifest = (child / "plugin.yaml").exists() or (child / "plugin.yml").exists()
                if has_manifest:
                    manifest = _read_manifest(child, allowed_root)
                    if manifest is None:
                        continue
                    name = _text(manifest.get("name"), 160)
                    if name is None:
                        continue
                    key = f"{prefix}/{child.name}" if prefix else name
                    found[key] = {
                        "mobile_contributions": _normalize_contributions(
                            manifest.get("mobile_contributions")
                        ),
                        "mobile_locales": _normalize_locales(
                            manifest.get("mobile_locales")
                        ),
                    }
                    continue
                if depth < 1:
                    next_prefix = f"{prefix}/{child.name}" if prefix else child.name
                    scan(child, next_prefix, depth + 1)
            except OSError:
                continue

    scan(base, "", 0)
    return found


def discover_mobile_manifests(
    *, source_root: Path, hermes_home: Path, profile: str | None = None
) -> dict[str, dict[str, Any]]:
    """Discover manifests with the same bundled-then-user precedence as Hermes."""
    found = _scan_root(source_root / "plugins", skip=_BUNDLED_SKIP)
    found.update(_scan_root(profile_plugins_root(hermes_home, profile)))
    return found


def enrich_plugin_inventory(
    payload: Any,
    *,
    source_root: Path,
    hermes_home: Path,
    profile: str | None = None,
) -> Any:
    """Return an inventory copy enriched from authoritative local manifests."""
    if not isinstance(payload, dict) or not isinstance(payload.get("plugins"), list):
        return payload
    manifests = discover_mobile_manifests(
        source_root=source_root,
        hermes_home=hermes_home,
        profile=profile,
    )
    rows: list[Any] = []
    for raw in payload["plugins"]:
        if not isinstance(raw, dict):
            rows.append(raw)
            continue
        key = str(raw.get("key") or raw.get("id") or raw.get("name") or "")
        manifest = manifests.get(key)
        if manifest is None:
            row = dict(raw)
            # Disk-backed rows are only trusted when this stricter reader saw
            # their manifest. This also removes gateway-v1 data sourced from a
            # symlink, oversized/aliased YAML, or an escaped plugin directory.
            if str(raw.get("source") or "").lower() in {"bundled", "user", "git"}:
                row["mobile_contributions"] = []
                row.pop("mobile_locales", None)
            rows.append(row)
            continue
        row = dict(raw)
        row["mobile_contributions"] = manifest["mobile_contributions"]
        if manifest["mobile_locales"]:
            row["mobile_locales"] = manifest["mobile_locales"]
        else:
            row.pop("mobile_locales", None)
        rows.append(row)
    return {**payload, "plugins": rows}
