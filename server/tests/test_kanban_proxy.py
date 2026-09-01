from pathlib import Path

from hermes_mobile_server.config import Settings
from hermes_mobile_server.kanban_proxy import build_kanban_router


def test_kanban_proxy_registers_all_http_methods_and_events() -> None:
    routes = build_kanban_router(Settings(api_key="test-key"), None).routes
    http = next(route for route in routes if route.path == "/api/v1/kanban/{path:path}")
    assert http.methods == {"GET", "POST", "PATCH", "PUT", "DELETE"}
    assert any(route.path == "/api/v1/kanban/events" for route in routes)


def test_proxy_source_forwards_board_query_and_plugin_namespace() -> None:
    source = (Path(__file__).parents[1] / "hermes_mobile_server" / "kanban_proxy.py").read_text(
        encoding="utf-8"
    )
    assert 'params=list(request.query_params.multi_items())' in source
    assert 'f"/api/plugins/kanban/{path}"' in source
    assert 'if k != "token"' in source
