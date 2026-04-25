import json
import os
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def to_bash_path(path: Path) -> str:
    resolved = path.resolve()
    drive = resolved.drive.rstrip(":").lower()
    tail = resolved.as_posix().split(":", 1)[1]
    return f"/mnt/{drive}{tail}"


def test_run_gemini_sh_writes_result_contract(tmp_path: Path) -> None:
    repo = tmp_path / "repo"
    repo.mkdir()

    fake_gemini = tmp_path / "fake_gemini.sh"
    fake_gemini.write_text("#!/usr/bin/env bash\necho 'gemini ok'\n", encoding="utf-8", newline="\n")
    os.chmod(fake_gemini, 0o755)

    verified = repo / "verified.txt"
    verified.write_text("SENTINEL\ncontent\n", encoding="utf-8")
    log_file = repo / ".ai" / "gemini_log.txt"

    env = os.environ.copy()
    env["GEMINI_PATH"] = to_bash_path(fake_gemini)

    proc = subprocess.run(
        [
            "bash",
            "-lc",
            (
                f"chmod +x '{to_bash_path(fake_gemini)}' && "
                f"GEMINI_PATH='{to_bash_path(fake_gemini)}' "
                f"bash '{to_bash_path(ROOT / 'scripts' / 'run_gemini.sh')}' "
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
