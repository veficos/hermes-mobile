"""Locate a runnable local Hermes Agent installation.

This replicates the resolution ladder the Hermes Desktop app uses
(``apps/desktop/electron/main.ts`` ``resolveHermesBackend``), adapted for a
server process:

1. ``HERMES_DESKTOP_HERMES_ROOT`` (explicit source checkout)
2. the managed install at ``$HERMES_HOME/hermes-agent``
3. ``hermes`` on ``PATH`` (venv console-scripts are unwrapped to their
   underlying Python)
4. a system Python that can import ``hermes_cli``

A candidate is trusted only after it is *probed* — the desktop rule "existence
is not proof". Every candidate must actually be able to run the Hermes CLI.
"""

from __future__ import annotations

import os
import re
import shutil
import subprocess
import sys
from dataclasses import dataclass, field
from pathlib import Path

from .config import HERMES_HOME_ENV

#: Windows default HERMES_HOME (mirrors the desktop's resolution).
def _default_hermes_home() -> Path:
    local_app_data = os.environ.get("LOCALAPPDATA")
    if local_app_data:
        return Path(local_app_data) / "hermes"
    return Path.home() / ".hermes"


def get_hermes_home() -> Path:
    """Resolve HERMES_HOME (env var wins, then platform default)."""
    env = os.environ.get(HERMES_HOME_ENV, "").strip()
    if env:
        return Path(env)
    return _default_hermes_home()


#: Source files that must exist for a directory to count as a Hermes checkout.
_SOURCE_MARKERS = ("hermes_cli/main.py", "hermes_cli/config.py", "pyproject.toml")

#: venv interpreter relative to a checkout root (Windows layout).
_VENV_PYTHON_CANDIDATES = (
    "venv/Scripts/python.exe",
    "venv/bin/python",
    ".venv/Scripts/python.exe",
    ".venv/bin/python",
)


@dataclass
class HermesRuntime:
    """A resolved, probed Hermes runtime."""

    #: Where the runtime came from (for status display).
    kind: str
    #: Source/checkout root of hermes-agent.
    source_root: Path
    #: Python interpreter that can run ``python -m hermes_cli.main``.
    python: Path | None
    #: Path to a ``hermes`` launcher when the runtime is a PATH shim.
    launcher: Path | None = None
    #: Full argv prefix used to invoke the CLI.
    argv: list[str] = field(default_factory=list)
    #: Whether this runtime came from a managed install (bootstrap semantics).
    bootstrap: bool = False
    #: Human-readable failure when the candidate was rejected.
    rejection: str | None = None
    #: D7 capability contract: ``full`` | ``legacy`` | ``missing``.
    capability: str = "full"


def _can_import_hermes_cli(python: Path | str, timeout: float = 30.0) -> bool:
    """Probe: does this interpreter import the Hermes CLI package?"""
    code = "import hermes_cli, hermes_cli.config"
    try:
        result = subprocess.run(
            [str(python), "-c", code],
            capture_output=True,
            timeout=timeout,
            env=os.environ.copy(),
        )
        return result.returncode == 0
    except (OSError, subprocess.TimeoutExpired):
        return False


def _is_source_root(path: Path) -> bool:
    return all((path / marker).is_file() for marker in _SOURCE_MARKERS)


def _find_venv_python(source_root: Path) -> Path | None:
    for candidate in _VENV_PYTHON_CANDIDATES:
        python = source_root / candidate
        if python.is_file():
            return python
    return None


def _make_python_runtime(kind: str, source_root: Path, python: Path) -> HermesRuntime:
    return HermesRuntime(
        kind=kind,
        source_root=source_root,
        python=python,
        launcher=None,
        argv=[str(python), "-m", "hermes_cli.main"],
        bootstrap=False,
    )


def _resolve_managed_install(hermes_home: Path) -> HermesRuntime | None:
    """Candidate 2: the managed install inside HERMES_HOME."""
    root = hermes_home / "hermes-agent"
    if not root.is_dir() or not _is_source_root(root):
        return None
    python = _find_venv_python(root)
    if python is None:
        return None
    if not _can_import_hermes_cli(python):
        return HermesRuntime(
            kind="managed",
            source_root=root,
            python=python,
            rejection="venv exists but cannot import hermes_cli",
        )
    return _make_python_runtime("managed", root, python)


def _unwrap_windows_venv_shim(launcher: Path) -> Path | None:
    """Resolve a venv console-script (``Scripts\\hermes.exe``) to its Python.

    Returns the venv ``python.exe`` when the launcher lives inside a venv's
    ``Scripts`` directory, else ``None``.
    """
    parent = launcher.parent
    if parent.name != "Scripts":
        return None
    venv_root = parent.parent
    python = venv_root / "Scripts" / "python.exe"
    return python if python.is_file() else None


def _unwrap_posix_hermes_wrapper(launcher: Path) -> tuple[Path, Path] | None:
    """Resolve a POSIX ``hermes`` wrapper script to ``(python, source_root)``.

    Typical Nous install layout::

        #!/usr/bin/env bash
        exec "/opt/hermes/venv/bin/python" "/opt/hermes/hermes" "$@"

    Returns ``None`` when the file is not a readable text wrapper or does not
    point at an importable hermes-agent checkout.
    """
    try:
        text = launcher.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return None
    # Shebang + exec ".../python" ".../hermes"  (or -m hermes_cli.main).
    match = re.search(
        r"""exec\s+["']([^"']+/python(?:\d+(?:\.\d+)?)?)["']\s+["']([^"']+)["']""",
        text,
    )
    if match is None:
        match = re.search(
            r"""(?:^|\n)\s*(?:exec\s+)?["']?([^\s"']+/python(?:\d+(?:\.\d+)?)?)["']?\s+["']?([^\s"']*hermes[^"'\s]*)["']?""",
            text,
        )
    if match is None:
        return None
    python = Path(match.group(1)).expanduser()
    target = Path(match.group(2)).expanduser()
    if not python.is_file():
        return None
    # Prefer the directory that actually contains hermes_cli markers.
    for candidate in (target.parent, python.parent.parent.parent, python.parent.parent):
        if _is_source_root(candidate) and _can_import_hermes_cli(python):
            return python, candidate
    if _can_import_hermes_cli(python):
        # Fallback: venv lives at <root>/venv/bin/python → root is parents[2].
        root = python.parent.parent.parent
        return python, root if root.is_dir() else python.parent
    return None


def _find_on_path() -> HermesRuntime | None:
    """Candidate 3: a ``hermes`` executable on PATH."""
    if os.environ.get("HERMES_DESKTOP_IGNORE_EXISTING") == "1":
        return None
    launcher = shutil.which("hermes")
    if not launcher:
        return None
    launcher_path = Path(launcher)
    # Windows venv shims resolve to the venv Python (mirrors desktop logic).
    if os.name == "nt":
        python = _unwrap_windows_venv_shim(launcher_path)
        if python is not None:
            if not _can_import_hermes_cli(python):
                return HermesRuntime(
                    kind="path",
                    source_root=launcher_path.parent.parent.parent,
                    python=python,
                    launcher=launcher_path,
                    rejection="PATH venv shim cannot import hermes_cli",
                )
            return _make_python_runtime("path", launcher_path.parent.parent.parent, python)
    else:
        unwrapped = _unwrap_posix_hermes_wrapper(launcher_path)
        if unwrapped is not None:
            python, source_root = unwrapped
            return _make_python_runtime("path", source_root, python)
    if not _can_import_hermes_cli(launcher_path):
        # Probe the launcher itself (may be a real entry script).
        return None
    return HermesRuntime(
        kind="path",
        source_root=launcher_path.parent,
        python=None,
        launcher=launcher_path,
        argv=[str(launcher_path)],
        bootstrap=False,
    )


def _find_system_python() -> HermesRuntime | None:
    """Candidate 4: a system Python with hermes_cli importable."""
    candidates: list[str] = []
    for name in ("python", "python3"):
        found = shutil.which(name)
        if found:
            candidates.append(found)
    for python in candidates:
        if _can_import_hermes_cli(python):
            return HermesRuntime(
                kind="system-python",
                source_root=Path(python).parent.parent,
                python=Path(python),
                launcher=None,
                argv=[python, "-m", "hermes_cli.main"],
                bootstrap=False,
            )
    return None


def _detect_serve_capability(runtime: HermesRuntime) -> str:
    """Probe whether the runtime can run ``serve`` (D7 capability contract).

    Returns ``full`` when the runtime declares the ``serve`` subcommand,
    ``legacy`` when it only has ``dashboard`` (compatibility path), and
    ``missing`` when nothing can be determined. A quick source check covers
    the normal case; ``--help`` probing is the fallback for launcher-based
    runtimes.
    """
    # Fast path: the subcommand parser source declares `serve`.
    if runtime.source_root and runtime.source_root.is_dir():
        dash = runtime.source_root / "hermes_cli" / "subcommands" / "dashboard.py"
        if dash.is_file():
            try:
                text = dash.read_text(encoding="utf-8", errors="replace")
                if 'add_parser("serve"' in text or "add_parser('serve'" in text:
                    return "full"
            except OSError:
                pass

    env = os.environ.copy()
    for sub in ("serve", "dashboard"):
        try:
            result = subprocess.run(
                list(runtime.argv) + [sub, "--help"],
                capture_output=True,
                timeout=20,
                env=env,
            )
            if result.returncode == 0:
                return "full" if sub == "serve" else "legacy"
        except (OSError, subprocess.TimeoutExpired):
            continue
    return "missing"


def resolve_runtime(hermes_root_override: str | None = None) -> HermesRuntime | None:
    """Walk the resolution ladder and return the first usable runtime.

    ``hermes_root_override`` corresponds to the desktop's
    ``HERMES_DESKTOP_HERMES_ROOT`` and is probed first when provided.
    """
    runtime: HermesRuntime | None = None

    # Candidate 0: explicit override (source checkout).
    if hermes_root_override:
        root = Path(hermes_root_override).expanduser()
        if _is_source_root(root):
            python = _find_venv_python(root)
            if python is not None and _can_import_hermes_cli(python):
                runtime = _make_python_runtime("override", root, python)
            elif python is not None:
                runtime = HermesRuntime(
                    kind="override",
                    source_root=root,
                    python=python,
                    rejection="override venv cannot import hermes_cli",
                )
            else:
                # Fall back to any python that can import hermes_cli.
                for name in ("python", "python3"):
                    found = shutil.which(name)
                    if found and _can_import_hermes_cli(found):
                        runtime = _make_python_runtime("override", root, Path(found))
                        break

    # Candidate 2: managed install.
    if runtime is None:
        runtime = _resolve_managed_install(get_hermes_home())

    # Candidate 3: PATH.
    if runtime is None:
        runtime = _find_on_path()

    # Candidate 4: system python.
    if runtime is None:
        runtime = _find_system_python()

    if runtime is not None:
        runtime.capability = _detect_serve_capability(runtime)
    return runtime
