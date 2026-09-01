"""In-memory projection of Gateway activity onto durable session rows."""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any


_REQUEST_EVENTS = {
    "approval.request",
    "clarify.request",
    "mcp.setup.request",
    "secret.request",
    "sudo.request",
    "terminal.read.request",
}


def wire_bool(value: Any) -> bool:
    """Normalize the bool spellings used by older Hermes projections."""
    if isinstance(value, bool):
        return value
    if isinstance(value, (int, float)):
        return value != 0
    if isinstance(value, str):
        return value.strip().lower() in {"1", "true", "yes", "on"}
    return False


@dataclass
class _LiveSession:
    is_streaming: bool | None = None
    cron_running: bool | None = None
    pending_user_message: bool | None = None
    has_pending_user_message: bool | None = None
    active_stream_id: str | None = None
    pending_request_ids: set[str] = field(default_factory=set)


class SessionLiveState:
    """Tracks runtime events and exposes the mobile session-row contract."""

    def __init__(self) -> None:
        self._states: dict[tuple[str, str], _LiveSession] = {}
        self._runtime_to_durable: dict[tuple[str, str], str] = {}
        self._request_sessions: dict[tuple[str, str], tuple[str, str]] = {}

    def reset(self) -> None:
        """Discard projections owned by the previous backend process."""
        self._states.clear()
        self._runtime_to_durable.clear()
        self._request_sessions.clear()

    def _canonical(self, session_id: str, profile: str = "") -> tuple[str, str]:
        return (
            profile,
            self._runtime_to_durable.get((profile, session_id), session_id),
        )

    def _state(self, session_id: str, profile: str = "") -> _LiveSession:
        return self._states.setdefault(
            self._canonical(session_id, profile), _LiveSession()
        )

    def _remember_alias(
        self, runtime_id: str, durable_id: str, profile: str = ""
    ) -> None:
        if not runtime_id or not durable_id or runtime_id == durable_id:
            return
        self._runtime_to_durable[(profile, runtime_id)] = durable_id
        runtime_state = self._states.pop((profile, runtime_id), None)
        if runtime_state is None:
            return
        durable_state = self._states.setdefault((profile, durable_id), _LiveSession())
        if runtime_state.is_streaming is not None:
            durable_state.is_streaming = runtime_state.is_streaming
        if runtime_state.cron_running is not None:
            durable_state.cron_running = runtime_state.cron_running
        if runtime_state.pending_user_message is not None:
            durable_state.pending_user_message = runtime_state.pending_user_message
        if runtime_state.has_pending_user_message is not None:
            durable_state.has_pending_user_message = (
                runtime_state.has_pending_user_message
            )
        durable_state.active_stream_id = (
            runtime_state.active_stream_id or durable_state.active_stream_id
        )
        durable_state.pending_request_ids.update(runtime_state.pending_request_ids)

    def _clear_pending_requests(
        self, state_key: tuple[str, str], state: _LiveSession
    ) -> None:
        for request_key, owner in tuple(self._request_sessions.items()):
            if owner == state_key:
                self._request_sessions.pop(request_key, None)
        state.pending_request_ids.clear()

    async def on_backend_event(self, raw: dict[str, Any]) -> None:
        event_type = str(raw.get("type") or "")
        nested = raw.get("payload")
        payload = nested if isinstance(nested, dict) else raw
        profile = str(raw.get("profile") or payload.get("profile") or "")
        runtime_id = str(raw.get("session_id") or payload.get("session_id") or "")
        durable_id = str(
            payload.get("stored_session_id")
            or payload.get("durable_session_id")
            or ""
        )
        if runtime_id and durable_id:
            self._remember_alias(runtime_id, durable_id, profile)
        session_id = durable_id or self._canonical(runtime_id, profile)[1]
        if not session_id:
            return
        state_key = self._canonical(session_id, profile)
        state = self._state(session_id, profile)

        if event_type == "message.start":
            state.is_streaming = True
            stream_id = payload.get("stream_id") or payload.get("active_stream_id")
            state.active_stream_id = str(stream_id) if stream_id else None
            # A resumed turn proves any earlier interactive wait was resolved.
            self._clear_pending_requests(state_key, state)
        elif event_type in {"message.complete", "error"}:
            state.is_streaming = False
            state.active_stream_id = None
            self._clear_pending_requests(state_key, state)
        elif event_type == "session.info":
            if "running" in payload:
                state.is_streaming = wire_bool(payload.get("running"))
                if not state.is_streaming:
                    state.active_stream_id = None
            if "cron_running" in payload:
                state.cron_running = wire_bool(payload.get("cron_running"))
            if "pending_user_message" in payload:
                state.pending_user_message = wire_bool(
                    payload.get("pending_user_message")
                )
            if "has_pending_user_message" in payload:
                state.has_pending_user_message = wire_bool(
                    payload.get("has_pending_user_message")
                )
            if payload.get("active_stream_id"):
                state.active_stream_id = str(payload["active_stream_id"])
        elif event_type in {"cron.start", "cron.started"}:
            state.cron_running = True
        elif event_type in {"cron.complete", "cron.completed", "cron.error"}:
            state.cron_running = False
        elif event_type in _REQUEST_EVENTS:
            request_id = str(payload.get("request_id") or "")
            if request_id:
                request_key = (profile, request_id)
                previous = self._request_sessions.get(request_key)
                if previous and previous != state_key:
                    self._states.setdefault(previous, _LiveSession()).pending_request_ids.discard(
                        request_id
                    )
                self._request_sessions[request_key] = state_key
                state.pending_request_ids.add(request_id)
        elif event_type in {"interactive.expire", "interactive.expired"}:
            request_id = str(payload.get("request_id") or "")
            owner = self._request_sessions.pop((profile, request_id), None)
            if owner:
                self._states.setdefault(owner, _LiveSession()).pending_request_ids.discard(
                    request_id
                )

    def project(self, row: dict[str, Any]) -> dict[str, Any]:
        projected = dict(row)
        session_id = str(row.get("session_id") or row.get("id") or "")
        profile = str(row.get("profile") or "")
        state = self._states.get(self._canonical(session_id, profile))
        if state is None and profile:
            # Older gateway events did not carry a profile. They remain usable
            # as a fallback, while profile-aware events stay fully isolated.
            state = self._states.get(self._canonical(session_id))

        projected["is_streaming"] = (
            state.is_streaming
            if state is not None and state.is_streaming is not None
            else wire_bool(row.get("is_streaming"))
        )
        projected["cron_running"] = (
            state.cron_running
            if state is not None and state.cron_running is not None
            else wire_bool(row.get("cron_running"))
        )
        projected["pending_user_message"] = (
            state.pending_user_message
            if state is not None and state.pending_user_message is not None
            else wire_bool(row.get("pending_user_message"))
        )
        projected["has_pending_user_message"] = (
            state.has_pending_user_message
            if state is not None and state.has_pending_user_message is not None
            else wire_bool(row.get("has_pending_user_message"))
        ) or bool(state and state.pending_request_ids)
        projected["active_stream_id"] = (
            state.active_stream_id
            if state is not None and state.is_streaming is not None
            else row.get("active_stream_id")
        )
        return projected
