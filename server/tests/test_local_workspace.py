from __future__ import annotations

import pytest
import subprocess

from hermes_mobile_server import local_workspace


@pytest.fixture(autouse=True)
def _reset_allowed_roots():
    """Allow-roots state is module-global; never leak it between tests."""
    local_workspace.configure_allowed_roots(None)
    yield
    local_workspace.configure_allowed_roots(None)


def test_copy_rejects_source_as_destination(tmp_path):
    source = tmp_path / "folder"
    source.mkdir()

    with pytest.raises(local_workspace.WorkspaceError, match="same"):
        local_workspace.copy([str(source)], str(tmp_path), overwrite=True)

    assert source.is_dir()


def test_copy_rejects_directory_into_itself(tmp_path):
    source = tmp_path / "folder"
    child = source / "child"
    child.mkdir(parents=True)

    with pytest.raises(local_workspace.WorkspaceError, match="into itself"):
        local_workspace.copy([str(source)], str(child))


def test_move_rejects_directory_into_itself(tmp_path):
    source = tmp_path / "folder"
    child = source / "child"
    child.mkdir(parents=True)

    with pytest.raises(local_workspace.WorkspaceError, match="into itself"):
        local_workspace.move(str(source), str(child))


def test_project_entries_applies_desktop_exclusions_and_nested_gitignore(tmp_path):
    subprocess.run(["git", "init", "-q", str(tmp_path)], check=True)
    (tmp_path / ".gitignore").write_text("*.log\n", encoding="utf-8")
    (tmp_path / "keep.txt").write_text("keep", encoding="utf-8")
    (tmp_path / "hidden.log").write_text("hidden", encoding="utf-8")
    (tmp_path / "node_modules").mkdir()
    nested = tmp_path / "nested"
    nested.mkdir()
    (nested / ".gitignore").write_text("private.txt\n", encoding="utf-8")
    (nested / "private.txt").write_text("hidden", encoding="utf-8")
    (nested / "public.txt").write_text("shown", encoding="utf-8")

    root_names = {row["name"] for row in local_workspace.project_entries(str(tmp_path))["entries"]}
    nested_names = {
        row["name"]
        for row in local_workspace.project_entries(str(nested), str(tmp_path))["entries"]
    }

    assert "keep.txt" in root_names
    assert "hidden.log" not in root_names
    assert "node_modules" not in root_names
    assert "public.txt" in nested_names
    assert "private.txt" not in nested_names


# ---------------------------------------------------------------------------
# allow_paths enforcement
# ---------------------------------------------------------------------------


def test_allow_paths_default_is_unrestricted(tmp_path):
    local_workspace.configure_allowed_roots(None)
    target = tmp_path / "note.txt"
    local_workspace.write_text(str(target), "hi")
    assert local_workspace.read_text(str(target))["text"] == "hi"


def test_allow_paths_permits_paths_inside_a_root(tmp_path):
    root = tmp_path / "workspace"
    root.mkdir()
    local_workspace.configure_allowed_roots([str(root)])

    target = root / "note.txt"
    local_workspace.write_text(str(target), "hi")
    assert local_workspace.read_text(str(target))["text"] == "hi"
    listing = local_workspace.entries(str(root))
    assert [row["name"] for row in listing["entries"]] == ["note.txt"]


def test_allow_paths_rejects_paths_outside_roots(tmp_path):
    allowed = tmp_path / "allowed"
    allowed.mkdir()
    other = tmp_path / "other"
    other.mkdir()
    local_workspace.configure_allowed_roots([str(allowed)])

    with pytest.raises(local_workspace.WorkspaceError, match="outside allowed roots"):
        local_workspace.entries(str(other))
    with pytest.raises(local_workspace.WorkspaceError, match="outside allowed roots"):
        local_workspace.write_text(str(other / "note.txt"), "hi")


def test_allow_paths_rejects_dotdot_escape(tmp_path):
    allowed = tmp_path / "allowed"
    allowed.mkdir()
    local_workspace.configure_allowed_roots([str(allowed)])

    with pytest.raises(local_workspace.WorkspaceError, match="outside allowed roots"):
        local_workspace.read_text(str(allowed / ".." / "secret.txt"))
