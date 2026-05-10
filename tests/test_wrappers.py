"""Wrapper contract tests.

Bash test:
- Linux / macOS: `bash` from PATH, POSIX paths.
- Windows: explicitly use git-bash at `C:\\Program Files\\Git\\bin\\bash.exe`
  if present. Avoids WSL bash on PATH which (when no distro is installed,
  e.g. on GitHub Actions windows-latest) emits UTF-16 banner output that
  pollutes subprocess pipes. Skipif when git-bash isn't found so plain
  Windows hosts without Git for Windows skip cleanly instead of failing.

PowerShell test:
- Skipif when `powershell` isn't on PATH so the test is a no-op on
  Linux / macOS runners.
"""

from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

import pytest


ROOT = Path(__file__).resolve().parents[1]


def _resolve_bash() -> str | None:
    """Return a path to a bash interpreter we trust for the wrapper test.

    On Windows we explicitly prefer git-bash at the standard
    Git-for-Windows install path, because `shutil.which("bash")` may
    return WSL bash and WSL bash on a host without an installed distro
    prints a UTF-16 banner that contaminates subprocess pipes.
    """
    if sys.platform == "win32":
        for candidate in (
            r"C:\Program Files\Git\bin\bash.exe",
            r"C:\Program Files\Git\usr\bin\bash.exe",
            r"C:\Program Files (x86)\Git\bin\bash.exe",
        ):
            if Path(candidate).is_file():
                return candidate
        return None
    return shutil.which("bash")


def to_bash_path(path: Path) -> str:
    """Convert a Path to a form bash can use on the current platform.

    Windows + git-bash: `C:\\Users\\foo` -> `/c/Users/foo`. Linux / macOS:
    POSIX path unchanged.
    """
    resolved = path.resolve()
    if sys.platform == "win32":
        drive = resolved.drive.rstrip(":").lower()
        tail = resolved.as_posix().split(":", 1)[1]
        return f"/{drive}{tail}"
    return resolved.as_posix()


_BASH = _resolve_bash()


@pytest.mark.skipif(_BASH is None, reason="bash (git-bash on Windows, system bash elsewhere) not available")
def test_run_gemini_sh_writes_result_contract(tmp_path: Path) -> None:
    repo = tmp_path / "repo"
    repo.mkdir()

    fake_gemini = tmp_path / "fake_gemini.sh"
    fake_gemini.write_text("#!/usr/bin/env bash\necho 'gemini ok'\n", encoding="utf-8", newline="\n")
    if sys.platform != "win32":
        os.chmod(fake_gemini, 0o755)

    verified = repo / "verified.txt"
    verified.write_text("SENTINEL\ncontent\n", encoding="utf-8")
    log_file = repo / ".ai" / "gemini_log.txt"

    env = os.environ.copy()
    env["GEMINI_PATH"] = to_bash_path(fake_gemini)

    proc = subprocess.run(
        [
            _BASH,
            "-lc",
            (
                f"chmod +x '{to_bash_path(fake_gemini)}' && "
                f"GEMINI_PATH='{to_bash_path(fake_gemini)}' "
                f"'{to_bash_path(Path(_BASH))}' '{to_bash_path(ROOT / 'scripts' / 'run_gemini.sh')}' "
                f"--prompt 'read and write' "
                f"--repo '{to_bash_path(repo)}' "
                f"--log-file '{to_bash_path(log_file)}' "
                f"--verify-file '{to_bash_path(verified)}' "
                f"--verify-sentinel 'SENTINEL'"
            ),
        ],
        capture_output=True,
        text=True,
        env=env,
        check=False,
    )

    assert proc.returncode == 0, proc.stderr
    result = json.loads(log_file.with_suffix(log_file.suffix + ".result.json").read_text(encoding="utf-8-sig"))
    assert result["status"] == "success"
    assert result["delegate"] == "gemini"
    assert result["model"] == "gemini/gemini-2.5-pro"


@pytest.mark.skipif(shutil.which("powershell") is None, reason="powershell not on PATH")
def test_run_gemini_ps1_reports_verify_failed(tmp_path: Path) -> None:
    repo = tmp_path / "repo"
    repo.mkdir()

    fake_gemini = tmp_path / "gemini.cmd"
    fake_gemini.write_text("@echo off\r\necho gemini ok\r\n", encoding="utf-8")

    missing = repo / "missing.txt"
    log_file = repo / ".ai" / "gemini_ps_log.txt"
    env = os.environ.copy()
    env["GEMINI_PATH"] = str(fake_gemini)

    proc = subprocess.run(
        [
            "powershell",
            "-ExecutionPolicy",
            "Bypass",
            "-File",
            str(ROOT / "scripts" / "run_gemini.ps1"),
            "-Prompt",
            "read and write",
            "-Repo",
            str(repo),
            "-LogFile",
            str(log_file),
            "-VerifyFile",
            str(missing),
        ],
        capture_output=True,
        text=True,
        env=env,
        check=False,
    )

    assert proc.returncode == 1
    result = json.loads(log_file.with_suffix(log_file.suffix + ".result.json").read_text(encoding="utf-8-sig"))
    assert result["status"] == "verify_failed"
    assert result["delegate"] == "gemini"
