import pytest
from fastapi import HTTPException

from hermes_mobile_server.domain_api import _config_document


def test_config_document_preserves_all_known_and_unknown_fields():
    payload = {
        "memory": {"memory_enabled": True},
        "compression": {"enabled": True},
        "context": {"engine": "default"},
        "display": {"personality": "helpful"},
        "stt": {"enabled": True},
        "agent": {"reasoning_effort": "high"},
        "unknown_client_field": 1,
    }
    out = _config_document(payload)
    assert out["memory"]["memory_enabled"] is True
    assert "compression" in out
    assert "context" in out
    assert "display" in out
    assert "stt" in out
    assert out["agent"]["reasoning_effort"] == "high"
    assert out["unknown_client_field"] == 1


def test_config_document_rejects_non_object():
    with pytest.raises(HTTPException) as error:
        _config_document([{"agent": {}}])
    assert error.value.status_code == 422
