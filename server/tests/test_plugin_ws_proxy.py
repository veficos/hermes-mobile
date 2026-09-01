from types import SimpleNamespace
from urllib.parse import parse_qs, urlparse

from hermes_mobile_server.ws_proxy import _plugin_upstream_url, _valid_plugin_path


def test_plugin_socket_path_is_bounded_and_cannot_traverse_namespaces():
    assert _valid_plugin_path("kanban", "events/live")
    assert _valid_plugin_path("my.plugin-2", "v1/updates")
    assert not _valid_plugin_path("bad/plugin", "events")
    assert not _valid_plugin_path("kanban", "../events")
    assert not _valid_plugin_path("kanban", "events//live")
    assert not _valid_plugin_path("kanban", "")


def test_plugin_socket_upstream_replaces_mobile_token_and_preserves_query():
    backend = SimpleNamespace(port=8642, session_token="backend-secret")

    raw = _plugin_upstream_url(
        backend,
        "kanban",
        "events/live",
        {"token": "mobile-secret", "board": "release"},
    )

    parsed = urlparse(raw)
    assert parsed.scheme == "ws"
    assert parsed.netloc == "127.0.0.1:8642"
    assert parsed.path == "/api/plugins/kanban/events/live"
    assert parse_qs(parsed.query) == {
        "token": ["backend-secret"],
        "board": ["release"],
    }

