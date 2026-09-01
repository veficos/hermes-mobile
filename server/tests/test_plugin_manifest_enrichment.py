from __future__ import annotations

from pathlib import Path

import pytest
import yaml
from fastapi import FastAPI
from fastapi.testclient import TestClient

from hermes_mobile_server.config import Settings
from hermes_mobile_server.domain_api import build_domain_router
from hermes_mobile_server.plugin_manifest import MAX_MANIFEST_BYTES
from hermes_mobile_server.runtime import HermesRuntime


AUTH = {"Authorization": "Bearer test-key-42"}


class _Backend:
    is_running = True

    def __init__(self, source_root: Path, payload: dict) -> None:
        self.runtime = HermesRuntime(
            kind="test",
            source_root=source_root,
            python=None,
            argv=[],
        )
        self.payload = payload
        self.calls: list[tuple[str, dict]] = []

    async def gateway_rpc(self, method, params=None, timeout=60.0):
        self.calls.append((method, params or {}))
        return self.payload


def _client(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
    payload: dict,
) -> tuple[_Backend, TestClient, Path, Path]:
    source_root = tmp_path / "runtime"
    source_root.mkdir()
    hermes_home = tmp_path / "home"
    hermes_home.mkdir()
    monkeypatch.setenv("HERMES_HOME", str(hermes_home))
    backend = _Backend(source_root, payload)
    app = FastAPI()
    app.include_router(
        build_domain_router(Settings(api_key="test-key-42"), backend)
    )
    return backend, TestClient(app), source_root, hermes_home


def _write_manifest(directory: Path, payload: dict) -> None:
    directory.mkdir(parents=True, exist_ok=True)
    (directory / "plugin.yaml").write_text(
        yaml.safe_dump(payload, allow_unicode=True, sort_keys=False),
        encoding="utf-8",
    )


def test_endpoint_rebuilds_v2_contributions_and_preserves_inventory_shape(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
):
    payload = {
        "plugins": [
            {
                "name": "demo",
                "key": "demo",
                "source": "bundled",
                "status": "enabled",
                "mobile_contributions": [{"id": "stale", "title": "Stale"}],
            },
            {
                "name": "wheel-plugin",
                "key": "wheel-plugin",
                "source": "entrypoint",
                "status": "enabled",
                "mobile_contributions": [{"id": "owned", "title": "Owned"}],
            },
        ],
        "user_count": 1,
        "bundled_count": 1,
        "future_stat": 9,
    }
    _, client, source_root, _ = _client(tmp_path, monkeypatch, payload)
    _write_manifest(
        source_root / "plugins" / "demo",
        {
            "name": "demo",
            "mobile_locales": {
                "zh_Hant": {"demo.title": "部署", "bad key": "ignored"}
            },
            "mobile_contributions": [
                {
                    "id": "configure",
                    "area": "settings",
                    "title_key": "demo.title",
                    "description_key": "demo.description",
                    "unknown_executable": "run()",
                    "badge_action": {
                        "kind": "gateway",
                        "method": "config.set",
                    },
                    "view": {
                        "type": "form",
                        "poll_seconds": 1,
                        "load_action": {
                            "kind": "gateway",
                            "method": "config.set",
                        },
                        "submit_action": {
                            "kind": "rest",
                            "method": "POST",
                            "path": "/deploy/run",
                        },
                        "fields": [
                            {
                                "id": "environment",
                                "label_key": "demo.environment",
                                "type": "select",
                                "required": True,
                                "options": [
                                    {"value": "prod", "label": "Production"}
                                ],
                            }
                        ],
                        "actions": [
                            {
                                "id": "notify",
                                "title": "Notify",
                                "confirm_message": "Continue?",
                                "action": {
                                    "kind": "notify",
                                    "title": "Deployment",
                                    "message": "Queued",
                                    "level": "success",
                                },
                            }
                        ],
                    },
                },
                {
                    "id": "dashboard",
                    "area": "pane",
                    "title": "Dashboard",
                    "view": {
                        "type": "list",
                        "load_action": {
                            "kind": "rest",
                            "method": "GET",
                            "path": "dashboard/items",
                        },
                    },
                },
            ],
        },
    )

    with client:
        response = client.get("/api/v1/plugins", headers=AUTH)

    assert response.status_code == 200
    body = response.json()
    assert body["user_count"] == 1
    assert body["bundled_count"] == 1
    assert body["future_stat"] == 9
    demo = body["plugins"][0]
    assert demo["mobile_locales"] == {"zh-hant": {"demo.title": "部署"}}
    contribution = demo["mobile_contributions"][0]
    assert contribution["title"] == ""
    assert contribution["title_key"] == "demo.title"
    assert "unknown_executable" not in contribution
    assert "badge_action" not in contribution
    view = contribution["view"]
    assert "load_action" not in view
    assert "poll_seconds" not in view
    assert view["submit_action"] == {
        "kind": "rest",
        "method": "POST",
        "path": "deploy/run",
    }
    assert view["fields"][0]["options"] == [
        {"value": "prod", "label": "Production"}
    ]
    assert view["actions"][0]["action"]["kind"] == "notify"
    assert demo["mobile_contributions"][1]["area"] == "pane"
    assert demo["mobile_contributions"][1]["view"]["load_action"] == {
        "kind": "rest",
        "method": "GET",
        "path": "dashboard/items",
    }
    # Entry points have no local manifest and remain byte-for-byte compatible.
    assert body["plugins"][1] == payload["plugins"][1]


def test_named_profile_nested_key_overrides_bundled_manifest(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
):
    payload = {
        "plugins": [
            {
                "name": "deploy",
                "key": "ops/deploy",
                "source": "user",
                "status": "enabled",
            }
        ],
        "user_count": 1,
        "bundled_count": 0,
    }
    backend, client, source_root, hermes_home = _client(
        tmp_path, monkeypatch, payload
    )
    _write_manifest(
        source_root / "plugins" / "ops" / "deploy",
        {
            "name": "deploy",
            "mobile_contributions": [
                {
                    "id": "open",
                    "title": "Bundled",
                    "action": {"kind": "clipboard", "text": "bundled"},
                }
            ],
        },
    )
    _write_manifest(
        hermes_home / "profiles" / "工作" / "plugins" / "ops" / "deploy",
        {
            "name": "different-display-name",
            "mobile_contributions": [
                {
                    "id": "open",
                    "title": "Profile override",
                    "action": {"kind": "clipboard", "text": "profile"},
                }
            ],
        },
    )

    with client:
        response = client.get(
            "/api/v1/plugins", headers=AUTH, params={"profile": "工作"}
        )

    assert response.status_code == 200
    row = response.json()["plugins"][0]
    assert row["mobile_contributions"][0]["title"] == "Profile override"
    assert backend.calls == [
        ("plugins.manage", {"action": "list", "profile": "工作"})
    ]


@pytest.mark.parametrize("profile", ["..", ".", "a/b", "a\\b", "x\x00y", "x" * 161])
def test_unsafe_profile_is_rejected_before_gateway_call(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
    profile: str,
):
    backend, client, _, _ = _client(tmp_path, monkeypatch, {"plugins": []})
    with client:
        response = client.get(
            "/api/v1/plugins", headers=AUTH, params={"profile": profile}
        )
    assert response.status_code == 422
    assert backend.calls == []


def test_untrusted_manifests_are_scrubbed_instead_of_passing_gateway_rows(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
):
    payload = {
        "plugins": [
            {
                "name": name,
                "key": name,
                "source": "bundled",
                "mobile_contributions": [
                    {
                        "id": "unsafe",
                        "title": "Gateway data",
                        "action": {"kind": "clipboard", "text": "unsafe"},
                    }
                ],
                "mobile_locales": {"en": {"unsafe": "Unsafe"}},
            }
            for name in ("oversized", "aliased", "linked")
        ]
    }
    _, client, source_root, _ = _client(tmp_path, monkeypatch, payload)
    plugins = source_root / "plugins"

    oversized = plugins / "oversized"
    oversized.mkdir(parents=True)
    (oversized / "plugin.yaml").write_bytes(b"x" * (MAX_MANIFEST_BYTES + 1))

    aliased = plugins / "aliased"
    aliased.mkdir()
    (aliased / "plugin.yaml").write_text(
        "name: aliased\nshared: &x [one]\ncopy: *x\n", encoding="utf-8"
    )

    linked = plugins / "linked"
    linked.mkdir()
    external = tmp_path / "external.yaml"
    external.write_text("name: linked\nmobile_contributions: []\n", encoding="utf-8")
    try:
        (linked / "plugin.yaml").symlink_to(external)
    except OSError:
        pytest.skip("symlinks are not available")

    with client:
        response = client.get("/api/v1/plugins", headers=AUTH)

    assert response.status_code == 200
    for row in response.json()["plugins"]:
        assert row["mobile_contributions"] == []
        assert "mobile_locales" not in row


def test_directory_symlink_escape_is_ignored_and_collections_are_bounded(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
):
    payload = {
        "plugins": [
            {"name": "escaped", "key": "escaped", "source": "user"},
            {"name": "bounded", "key": "bounded", "source": "user"},
        ]
    }
    _, client, _, hermes_home = _client(tmp_path, monkeypatch, payload)
    plugins = hermes_home / "plugins"
    plugins.mkdir()
    external = tmp_path / "outside-plugin"
    _write_manifest(
        external,
        {
            "name": "escaped",
            "mobile_contributions": [
                {
                    "id": "run",
                    "title": "Escaped",
                    "action": {"kind": "clipboard", "text": "bad"},
                }
            ],
        },
    )
    try:
        (plugins / "escaped").symlink_to(external, target_is_directory=True)
    except OSError:
        pytest.skip("symlinks are not available")

    fields = [
        {"id": f"field-{index}", "label": f"Field {index}"}
        for index in range(70)
    ]
    actions = [
        {
            "id": f"action-{index}",
            "title": f"Action {index}",
            "action": {"kind": "clipboard", "text": str(index)},
        }
        for index in range(40)
    ]
    locales = {
        f"x{index}": {f"key-{item}": "value" for item in range(520)}
        for index in range(20)
    }
    # Include valid locale tags after invalid ones so the manifest-level cap
    # itself, not just tag validation, is exercised deterministically.
    locales = {
        f"en-{index}": values for index, values in enumerate(locales.values())
    }
    _write_manifest(
        plugins / "bounded",
        {
            "name": "bounded",
            "mobile_locales": locales,
            "mobile_contributions": [
                {
                    "id": "form",
                    "title": "Bounded",
                    "view": {
                        "type": "form",
                        "fields": fields,
                        "actions": actions,
                    },
                }
            ],
        },
    )

    with client:
        response = client.get("/api/v1/plugins", headers=AUTH)

    rows = {row["key"]: row for row in response.json()["plugins"]}
    assert rows["escaped"]["mobile_contributions"] == []
    bounded = rows["bounded"]
    assert len(bounded["mobile_contributions"][0]["view"]["fields"]) == 64
    assert len(bounded["mobile_contributions"][0]["view"]["actions"]) == 32
    assert len(bounded["mobile_locales"]) == 16
    assert all(len(messages) == 512 for messages in bounded["mobile_locales"].values())
