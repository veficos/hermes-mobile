import asyncio

import pytest

from hermes_mobile_server.terminal_pty import PtyManager


class _Process:
    def isalive(self):
        return True

    def terminate(self, force=False):
        pass


def test_ssh_terminal_builds_noninteractive_pinned_command(monkeypatch):
    manager = PtyManager()
    captured = {}

    def spawn(argv, cwd, cols, rows):
        captured.update(argv=argv, cwd=cwd, cols=cols, rows=rows)
        return _Process()

    async def no_reader(*_args):
        return None

    monkeypatch.setattr(manager, "_spawn_argv", spawn)
    monkeypatch.setattr(manager, "_read_loop", no_reader)
    monkeypatch.setattr("shutil.which", lambda _: "/usr/bin/ssh")
    result = asyncio.run(manager.start_ssh(
        asyncio.Queue(), host="build-box", user="runner", port=2222,
        identity_file="~/.ssh/id_ed25519", cwd="/work/repo", cols=100, rows=30,
    ))

    assert result["shell"] == "SSH build-box"
    assert "BatchMode=yes" in captured["argv"]
    assert "StrictHostKeyChecking=accept-new" in captured["argv"]
    assert captured["argv"][-2] == "runner@build-box"
    assert captured["argv"][-1].startswith("cd -- /work/repo")


def test_ssh_terminal_rejects_option_injection(monkeypatch):
    manager = PtyManager()
    monkeypatch.setattr("shutil.which", lambda _: "/usr/bin/ssh")
    with pytest.raises(ValueError, match="invalid SSH host"):
        asyncio.run(manager.start_ssh(
            asyncio.Queue(), host="-oProxyCommand=bad", user="", port=None,
            identity_file="", cwd=None, cols=80, rows=24,
        ))
