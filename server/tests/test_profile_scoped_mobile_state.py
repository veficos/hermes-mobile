from pathlib import Path
import json

from hermes_mobile_server.drafts import DraftStore
from hermes_mobile_server.session_shares import SessionShareStore


def test_drafts_are_isolated_by_profile_and_adopt_legacy_value(tmp_path: Path) -> None:
    store = DraftStore(tmp_path / "drafts.json")
    (tmp_path / "drafts.json").write_text(
        json.dumps({"same": {"text": "legacy", "files": []}}),
        encoding="utf-8",
    )

    assert store.get("same", profile="alpha")["text"] == "legacy"
    assert store.get("same", profile="beta") == {}
    store.save("same", text="alpha", files=[], profile="alpha")
    store.save("same", text="beta", files=[], profile="beta")

    assert store.get("same", profile="alpha")["text"] == "alpha"
    assert store.get("same", profile="beta")["text"] == "beta"


def test_share_tokens_are_isolated_by_profile(tmp_path: Path) -> None:
    store = SessionShareStore(tmp_path / "shares.json")
    alpha = store.create(
        "same", {"title": "alpha"}, [{"role": "user"}], profile="alpha"
    )
    beta = store.create(
        "same", {"title": "beta"}, [{"role": "user"}], profile="beta"
    )

    assert alpha["token"] != beta["token"]
    assert store.for_session("same", profile="alpha")["title"] == "alpha"
    assert store.for_session("same", profile="beta")["title"] == "beta"
    assert store.revoke("same", profile="alpha") is True
    assert store.for_session("same", profile="alpha") is None
    assert store.for_session("same", profile="beta")["token"] == beta["token"]
