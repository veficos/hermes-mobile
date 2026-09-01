from hermes_mobile_server.session_shares import SessionShareStore, render_share_html


def test_share_snapshot_refresh_revokes_old_token_and_renders_safely(tmp_path):
    store = SessionShareStore(tmp_path / "shares.json")
    first = store.create(
        "session-1",
        {"id": "session-1", "title": "<unsafe>"},
        [{"role": "user", "content": "hello <script>alert(1)</script>"}],
    )
    refreshed = store.create(
        "session-1",
        {"id": "session-1", "title": "Updated"},
        [{"role": "assistant", "content": "real reply"}],
    )

    assert first["token"] != refreshed["token"]
    assert store.get(first["token"]) is None
    assert store.for_session("session-1")["token"] == refreshed["token"]
    page = render_share_html(refreshed)
    assert "real reply" in page
    assert store.revoke("session-1") is True
    assert store.get(refreshed["token"]) is None


def test_share_html_escapes_title_and_message_content(tmp_path):
    store = SessionShareStore(tmp_path / "shares.json")
    snapshot = store.create(
        "session-2",
        {"id": "session-2", "title": "<b>title</b>"},
        [{"role": "user", "content": "<script>bad()</script>"}],
    )

    page = render_share_html(snapshot)
    assert "<b>title</b>" not in page
    assert "<script>bad()</script>" not in page
    assert "&lt;script&gt;bad()&lt;/script&gt;" in page
