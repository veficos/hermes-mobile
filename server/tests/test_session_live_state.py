from __future__ import annotations

import asyncio

from hermes_mobile_server.session_live_state import SessionLiveState, wire_bool


def dispatch(store: SessionLiveState, event: dict) -> None:
    asyncio.run(store.on_backend_event(event))


def test_wire_bool_normalizes_legacy_values() -> None:
    assert wire_bool(True)
    assert wire_bool(1)
    assert wire_bool("yes")
    assert wire_bool("TRUE")
    assert not wire_bool("false")
    assert not wire_bool(0)


def test_gateway_state_projects_from_runtime_to_durable_session() -> None:
    store = SessionLiveState()
    dispatch(
        store,
        {
            "type": "session.info",
            "session_id": "runtime-1",
            "payload": {
                "stored_session_id": "stored-1",
                "running": True,
                "cron_running": "yes",
                "active_stream_id": "stream-1",
            },
        },
    )
    projected = store.project({"id": "stored-1"})
    assert projected["is_streaming"] is True
    assert projected["cron_running"] is True
    assert projected["active_stream_id"] == "stream-1"
    assert projected["has_pending_user_message"] is False

    dispatch(
        store,
        {
            "type": "approval.request",
            "session_id": "runtime-1",
            "payload": {"request_id": "approval-1"},
        },
    )
    assert store.project({"id": "stored-1"})["has_pending_user_message"] is True

    dispatch(
        store,
        {
            "type": "interactive.expire",
            "session_id": "runtime-1",
            "payload": {"request_id": "approval-1"},
        },
    )
    dispatch(
        store,
        {"type": "message.complete", "session_id": "runtime-1", "payload": {}},
    )
    projected = store.project({"id": "stored-1"})
    assert projected["is_streaming"] is False
    assert projected["has_pending_user_message"] is False


def test_projection_normalizes_rest_fields_without_gateway_events() -> None:
    projected = SessionLiveState().project(
        {
            "id": "stored-1",
            "is_streaming": "true",
            "cron_running": 1,
            "pending_user_message": "yes",
            "has_pending_user_message": 0,
        }
    )
    assert projected["is_streaming"] is True
    assert projected["cron_running"] is True
    assert projected["pending_user_message"] is True
    assert projected["has_pending_user_message"] is False
