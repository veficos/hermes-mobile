"""Local filesystem and Git implementation for Hermes Mobile Server.

The upstream Agent REST surface differs between releases: some versions omit
``/api/filesystem/*`` entirely and expose only a read-only subset of Git.
These helpers make the mobile server a complete provider for the file/Git
features it presents to authenticated clients instead of a brittle proxy.
"""

from __future__ import annotations

import base64
import mimetypes
import os
import shutil
import subprocess
import sys
import tempfile
import zipfile
from pathlib import Path
from typing import Any


class WorkspaceError(RuntimeError):
    """A user-actionable local workspace failure."""


#: Resolved filesystem roots local file operations are confined to.
#: Empty (the default) means unrestricted.
_ALLOWED_ROOTS: tuple[Path, ...] = ()


def configure_allowed_roots(paths: list[str] | None) -> None:
    """Restrict local file operations to the given roots.

    ``None``/empty restores the default unrestricted behavior. Roots are
    resolved up front so symlinks and ``..`` cannot escape the allow-list.
    """
    global _ALLOWED_ROOTS
    _ALLOWED_ROOTS = tuple(
        Path(raw).expanduser().resolve(strict=False)
        for raw in (paths or [])
        if str(raw).strip()
    )


def _check_allowed(path: Path) -> None:
    if not _ALLOWED_ROOTS:
        return
    if any(path == root or root in path.parents for root in _ALLOWED_ROOTS):
        return
    raise WorkspaceError(f"path outside allowed roots: {path}")


ALWAYS_EXCLUDED = frozenset(
    {
        ".git", ".hg", ".svn", "node_modules", "bower_components",
        ".venv", "venv", "env", "__pycache__", ".mypy_cache",
        ".pytest_cache", ".ruff_cache", ".tox", ".gradle", ".idea",
        "dist", "build", "out", "target", "vendor", "Pods", ".next",
        ".nuxt", ".svelte-kit", ".output", ".turbo", ".parcel-cache",
        ".cache", ".terraform", ".expo", ".angular", "coverage",
        ".DS_Store", "Thumbs.db",
    }
)


def _path(value: str) -> Path:
    if not isinstance(value, str) or not value.strip():
        raise WorkspaceError("path is required")
    raw = value.strip()
    # Clients may send Windows-styled separators while the server runs on
    # POSIX (or the reverse for mixed tooling). Normalize to the host style
    # before resolving so "go up" / join mistakes cannot create ghost paths.
    if os.name == "nt":
        raw = raw.replace("/", "\\")
    else:
        raw = raw.replace("\\", "/")
    resolved = Path(raw).expanduser().resolve(strict=False)
    _check_allowed(resolved)
    return resolved


def _timestamp(path: Path) -> int:
    return int(path.stat().st_mtime * 1000)


def drives() -> dict[str, list[dict[str, str]]]:
    values: list[dict[str, str]] = []
    if os.name == "nt":
        for letter in "ABCDEFGHIJKLMNOPQRSTUVWXYZ":
            root = Path(f"{letter}:\\")
            if root.exists():
                values.append({"name": f"{letter}:\\", "path": str(root), "root": str(root)})
    else:
        values.append({"name": "/", "path": "/", "root": "/"})
    return {"drives": values}


def entries(value: str) -> dict[str, Any]:
    root = _path(value)
    if not root.exists():
        raise WorkspaceError(f"path does not exist: {root}")
    if not root.is_dir():
        raise WorkspaceError(f"path is not a directory: {root}")
    rows: list[dict[str, Any]] = []
    try:
        children = sorted(root.iterdir(), key=lambda item: (not item.is_dir(), item.name.casefold()))
    except OSError as exc:
        raise WorkspaceError(f"cannot read directory: {exc}") from exc
    for child in children:
        try:
            stat = child.stat()
            rows.append(
                {
                    "name": child.name,
                    "path": str(child),
                    "type": "directory" if child.is_dir() else "file",
                    "is_link": child.is_symlink(),
                    "size": stat.st_size,
                    "modified_at": int(stat.st_mtime * 1000),
                    "readable": os.access(child, os.R_OK),
                    "writable": os.access(child, os.W_OK),
                }
            )
        except OSError:
            # A file can disappear while a directory is being refreshed.
            continue
    return {
        "path": str(root),
        "parent_path": None if root.parent == root else str(root.parent),
        "is_git_repo": (root / ".git").exists(),
        "entries": rows,
    }


def project_entries(value: str, root_value: str | None = None) -> dict[str, Any]:
    """Desktop project-tree listing, including exclusion and gitignore rules."""
    result = entries(value)
    rows = [row for row in result["entries"] if row["name"] not in ALWAYS_EXCLUDED]
    root = _path(root_value or value)
    try:
        probe = subprocess.run(
            ["git", "-C", str(root), "rev-parse", "--show-toplevel"],
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
            timeout=10,
            check=False,
        )
    except (OSError, subprocess.TimeoutExpired):
        result["entries"] = rows
        return result
    if probe.returncode == 0:
        repo_root = Path(probe.stdout.strip()).resolve(strict=False)
        candidates: list[tuple[dict[str, Any], str]] = []
        for row in rows:
            path = Path(row["path"])
            try:
                relative = path.relative_to(repo_root).as_posix()
            except ValueError:
                continue
            candidates.append((row, f"{relative}/" if row["type"] == "directory" else relative))
        if candidates:
            try:
                ignored = subprocess.run(
                    ["git", "-C", str(repo_root), "check-ignore", "--no-index", "-z", "--stdin"],
                    input="\0".join(candidate for _, candidate in candidates) + "\0",
                    capture_output=True,
                    text=True,
                    encoding="utf-8",
                    errors="replace",
                    timeout=10,
                    check=False,
                )
                ignored_paths = set(ignored.stdout.split("\0"))
            except (OSError, subprocess.TimeoutExpired):
                ignored_paths = set()
            ignored_rows = {id(row) for row, candidate in candidates if candidate in ignored_paths}
            rows = [row for row in rows if id(row) not in ignored_rows]
    result["entries"] = rows
    return result


def read_text(value: str) -> dict[str, str]:
    path = _path(value)
    if not path.is_file():
        raise WorkspaceError(f"file does not exist: {path}")
    try:
        return {"text": path.read_text(encoding="utf-8")}
    except UnicodeDecodeError as exc:
        raise WorkspaceError("file is not valid UTF-8 text") from exc
    except OSError as exc:
        raise WorkspaceError(f"cannot read file: {exc}") from exc


def write_text(value: str, content: str) -> dict[str, Any]:
    path = _path(value)
    try:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content, encoding="utf-8")
        return {"path": str(path), "size": path.stat().st_size, "modified_at": _timestamp(path)}
    except OSError as exc:
        raise WorkspaceError(f"cannot write file: {exc}") from exc


def read_data_url(value: str) -> dict[str, str]:
    path = _path(value)
    if not path.is_file():
        raise WorkspaceError(f"file does not exist: {path}")
    try:
        encoded = base64.b64encode(path.read_bytes()).decode("ascii")
    except OSError as exc:
        raise WorkspaceError(f"cannot read file: {exc}") from exc
    mime = mimetypes.guess_type(path.name)[0] or "application/octet-stream"
    return {"data_url": f"data:{mime};base64,{encoded}"}


def download_info(value: str) -> dict[str, Any]:
    """Resolve a readable file for streaming download to the client device."""
    path = _path(value)
    if not path.is_file():
        raise WorkspaceError(f"file does not exist: {path}")
    if not os.access(path, os.R_OK):
        raise WorkspaceError(f"file is not readable: {path}")
    mime = mimetypes.guess_type(path.name)[0] or "application/octet-stream"
    return {
        "path": str(path),
        "filename": path.name,
        "media_type": mime,
        "size": path.stat().st_size,
        "cleanup": False,
        "kind": "file",
    }


# Soft cap on uncompressed bytes walked into a folder zip (512 MiB).
_MAX_ARCHIVE_BYTES = 512 * 1024 * 1024
# Soft cap on file count inside a folder zip.
_MAX_ARCHIVE_FILES = 20_000


def _should_skip_name(name: str) -> bool:
    return name in ALWAYS_EXCLUDED or name.startswith(".git")


def archive_directory(value: str) -> dict[str, Any]:
    """Zip a directory (excluding common junk trees) into a temp archive.

    The returned ``path`` is a temporary zip the caller must delete after the
    response is sent (``cleanup=True``).
    """
    root = _path(value)
    if not root.is_dir():
        raise WorkspaceError(f"directory does not exist: {root}")
    if not os.access(root, os.R_OK):
        raise WorkspaceError(f"directory is not readable: {root}")

    total_bytes = 0
    file_count = 0
    fd, zip_path = tempfile.mkstemp(prefix="hm-dl-", suffix=".zip")
    os.close(fd)
    try:
        with zipfile.ZipFile(
            zip_path, "w", compression=zipfile.ZIP_DEFLATED
        ) as archive:
            for dirpath, dirnames, filenames in os.walk(root):
                dirnames[:] = sorted(
                    name for name in dirnames if not _should_skip_name(name)
                )
                for name in sorted(filenames):
                    if _should_skip_name(name):
                        continue
                    full = Path(dirpath) / name
                    if full.is_symlink() or not full.is_file():
                        continue
                    try:
                        size = full.stat().st_size
                    except OSError:
                        continue
                    total_bytes += size
                    file_count += 1
                    if file_count > _MAX_ARCHIVE_FILES:
                        raise WorkspaceError(
                            f"folder has too many files (>{_MAX_ARCHIVE_FILES}); "
                            "download a smaller subtree"
                        )
                    if total_bytes > _MAX_ARCHIVE_BYTES:
                        raise WorkspaceError(
                            "folder is too large to zip "
                            f"(>{_MAX_ARCHIVE_BYTES // (1024 * 1024)} MB uncompressed); "
                            "download a smaller subtree"
                        )
                    try:
                        arcname = str(Path(root.name) / full.relative_to(root))
                        archive.write(full, arcname)
                    except OSError as exc:
                        raise WorkspaceError(
                            f"cannot archive file {full}: {exc}"
                        ) from exc
        zip_size = Path(zip_path).stat().st_size
    except Exception:
        try:
            os.unlink(zip_path)
        except OSError:
            pass
        raise

    folder_name = root.name or "folder"
    return {
        "path": zip_path,
        "filename": f"{folder_name}.zip",
        "media_type": "application/zip",
        "size": zip_size,
        "cleanup": True,
        "kind": "directory",
        "file_count": file_count,
        "uncompressed_bytes": total_bytes,
    }


def prepare_download(value: str) -> dict[str, Any]:
    """Prepare either a single file or a zipped directory for download."""
    path = _path(value)
    if path.is_dir():
        return archive_directory(str(path))
    if path.is_file():
        return download_info(str(path))
    raise WorkspaceError(f"path does not exist: {path}")


def reveal(value: str) -> dict[str, str]:
    """Reveal a local file or directory in the platform file manager."""
    path = _path(value)
    if not path.exists():
        raise WorkspaceError(f"path does not exist: {path}")
    try:
        if os.name == "nt":
            if path.is_dir():
                subprocess.Popen(["explorer.exe", str(path)])
            else:
                subprocess.Popen(["explorer.exe", "/select,", str(path)])
        elif sys.platform == "darwin":
            subprocess.Popen(["open", "-R", str(path)])
        else:
            target = path if path.is_dir() else path.parent
            subprocess.Popen(["xdg-open", str(target)])
    except OSError as exc:
        raise WorkspaceError(f"cannot reveal path: {exc}") from exc
    return {"path": str(path)}


def write_data_url(value: str, data_url: str, *, overwrite: bool = False) -> dict[str, Any]:
    path = _path(value)
    if path.exists() and not overwrite:
        raise WorkspaceError(f"destination already exists: {path}")
    if not isinstance(data_url, str) or ";base64," not in data_url:
        raise WorkspaceError("data_url must be a base64 data URL")
    try:
        data = base64.b64decode(data_url.split(",", 1)[1], validate=True)
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)
    except (OSError, ValueError) as exc:
        raise WorkspaceError(f"cannot upload file: {exc}") from exc
    return {"path": str(path), "size": len(data), "modified_at": _timestamp(path)}


def mkdir(value: str) -> dict[str, str]:
    path = _path(value)
    try:
        path.mkdir(parents=True, exist_ok=False)
    except OSError as exc:
        raise WorkspaceError(f"cannot create directory: {exc}") from exc
    return {"path": str(path)}


def copy(sources: list[str], destination: str, *, overwrite: bool = False) -> dict[str, list[str]]:
    dest = _path(destination)
    if not dest.is_dir():
        raise WorkspaceError(f"destination is not a directory: {dest}")
    copied: list[str] = []
    for raw in sources:
        source = _path(raw)
        if not source.exists():
            raise WorkspaceError(f"source does not exist: {source}")
        target = dest / source.name
        if source == target:
            raise WorkspaceError(f"source and destination are the same: {source}")
        if source.is_dir() and source in target.parents:
            raise WorkspaceError(f"cannot copy a directory into itself: {source}")
        if target.exists():
            if not overwrite:
                raise WorkspaceError(f"destination already exists: {target}")
            if target.is_dir():
                shutil.rmtree(target)
            else:
                target.unlink()
        try:
            if source.is_dir():
                shutil.copytree(source, target)
            else:
                shutil.copy2(source, target)
            copied.append(str(target))
        except OSError as exc:
            raise WorkspaceError(f"cannot copy {source}: {exc}") from exc
    return {"paths": copied}


def move(source_value: str, destination: str, *, overwrite: bool = False) -> dict[str, str]:
    source = _path(source_value)
    dest = _path(destination)
    target = dest / source.name if dest.is_dir() else dest
    if source == target:
        raise WorkspaceError(f"source and destination are the same: {source}")
    if source.is_dir() and source in target.parents:
        raise WorkspaceError(f"cannot move a directory into itself: {source}")
    if target.exists() and not overwrite:
        raise WorkspaceError(f"destination already exists: {target}")
    try:
        target.parent.mkdir(parents=True, exist_ok=True)
        if target.exists() and overwrite:
            if target.is_dir():
                shutil.rmtree(target)
            else:
                target.unlink()
        shutil.move(str(source), str(target))
    except OSError as exc:
        raise WorkspaceError(f"cannot move {source}: {exc}") from exc
    return {"path": str(target)}


def remove(sources: list[str], *, recursive: bool = False) -> dict[str, list[str]]:
    deleted: list[str] = []
    for raw in sources:
        path = _path(raw)
        if not path.exists() and not path.is_symlink():
            continue
        try:
            if path.is_dir() and not path.is_symlink():
                if not recursive:
                    path.rmdir()
                else:
                    shutil.rmtree(path)
            else:
                path.unlink()
            deleted.append(str(path))
        except OSError as exc:
            raise WorkspaceError(f"cannot delete {path}: {exc}") from exc
    return {"deleted": deleted}


def default_cwd() -> dict[str, str]:
    """Return the user's shared workspace, not the server install directory.

    The file browser and a session created from it must agree on one global
    workspace.  Operators may override it without changing code; the normal
    Windows installation uses ``%USERPROFILE%\\workspace``.
    """
    configured = os.environ.get("HERMES_MOBILE_WORKSPACE", "").strip()
    candidate = Path(configured).expanduser() if configured else Path.home() / "workspace"
    if candidate.is_dir():
        return {"cwd": str(candidate.resolve())}
    return {"cwd": str(Path.cwd())}


def _git(repo_value: str, args: list[str]) -> str:
    repo = _path(repo_value)
    result = subprocess.run(
        ["git", "-C", str(repo), *args],
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
        timeout=45,
        check=False,
    )
    if result.returncode != 0:
        detail = (result.stderr or result.stdout).strip() or "git command failed"
        raise WorkspaceError(detail)
    return result.stdout


def git_diff(repo: str, file: str, *, staged: bool = False, oid: str | None = None) -> dict[str, str]:
    args = ["diff"]
    if oid:
        args.extend([f"{oid}^", oid, "--"])
    else:
        if staged:
            args.append("--cached")
        args.extend(["--", file])
    return {"diff": _git(repo, args)}


def git_remotes(repo: str) -> dict[str, list[dict[str, str]]]:
    raw = _git(repo, ["remote", "-v"])
    rows: dict[str, dict[str, str]] = {}
    for line in raw.splitlines():
        parts = line.split()
        if len(parts) >= 2:
            rows.setdefault(parts[0], {"name": parts[0], "url": parts[1]})
    return {"remotes": list(rows.values())}


def git_stashes(repo: str) -> dict[str, list[dict[str, str]]]:
    raw = _git(repo, ["stash", "list", "--format=%gd%x1f%gs"])
    return {"stashes": [{"name": line.split("\x1f", 1)[0], "message": line.split("\x1f", 1)[-1]} for line in raw.splitlines() if line]}


def git_log(
    repo: str,
    limit: int,
    offset: int,
    search: str | None = None,
    author: str | None = None,
    branch: str | None = None,
) -> dict[str, Any]:
    args = ["log", f"--max-count={limit}", f"--skip={offset}", "--format=%H%x1f%an%x1f%aI%x1f%s%x1f%P"]
    if search:
        args.append(f"--grep={search}")
    if author:
        args.append(f"--author={author}")
    if branch:
        args.append(branch)
    raw = _git(repo, args)
    commits: list[dict[str, Any]] = []
    for line in raw.splitlines():
        parts = line.split("\x1f")
        if len(parts) < 5:
            continue
        commits.append({"sha": parts[0], "author": parts[1], "date": parts[2], "message": parts[3], "parents": parts[4].split() if parts[4] else []})
    total_args = ["rev-list", "--count", branch or "HEAD"]
    if search or author:
        total_args = ["log", "--format=%H"] + ([f"--grep={search}"] if search else []) + ([f"--author={author}"] if author else []) + ([branch] if branch else [])
        total = len(_git(repo, total_args).splitlines())
    else:
        total = int(_git(repo, total_args).strip() or "0")
    return {"commits": commits, "total": total}


def git_commit_detail(repo: str, sha: str) -> dict[str, Any]:
    header = _git(repo, ["show", "--no-patch", "--format=%H%x1f%an%x1f%ae%x1f%B", sha]).split("\x1f", 3)
    if len(header) < 4:
        raise WorkspaceError("commit was not found")
    files_raw = _git(repo, ["show", "--format=", "--name-status", sha])
    files = []
    for line in files_raw.splitlines():
        parts = line.split("\t")
        if len(parts) >= 2:
            files.append({"status": parts[0], "path": parts[-1]})
    return {"sha": header[0], "author": header[1], "email": header[2], "message": header[3].splitlines()[0] if header[3] else "", "body": header[3], "files": files, "diff": _git(repo, ["show", "--format=", sha])}
