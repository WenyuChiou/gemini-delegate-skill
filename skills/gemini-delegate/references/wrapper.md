# Gemini wrapper reference

The `scripts/run_gemini.sh` and `scripts/run_gemini.ps1` wrappers run Antigravity CLI (`agy`) or legacy Gemini CLI synchronously, detect quota / rate-limit failures, optionally verify expected output files exist after exit, and emit a machine-readable `<log>.result.json`.

## What the wrapper enforces

These three rules are non-negotiable. The wrapper enforces all of them; if you write your own wrapper, preserve all three:

1. **Run from the target working directory** (`pushd`/`Push-Location`) instead of using a fake `-C`. Neither backend has a `-C` flag.
2. **Pass the correct approval flag automatically**: `--yolo` for `agy` or `--approval-mode yolo` for legacy `gemini`.
3. **Pipe the prompt through stdin**. `agy` receives a trailing `-`; legacy `gemini` receives redirected stdin.

The wrapper additionally verifies expected files when `--verify-file` is supplied.

## Backend detection

The wrapper auto-detects the backend in this priority order:

1. `AGY_PATH`
2. `GEMINI_PATH`
3. `agy` on PATH
4. `gemini` on PATH

Invocation examples stay backend-agnostic; the wrapper chooses the concrete CLI and flags.

## Invocation

### From Claude Code Bash

```bash
bash scripts/run_gemini.sh \
  --prompt "Read .ai/gemini_task_<name>.md and execute all instructions inside." \
  --log-file .ai/gemini_log_<name>.txt \
  --verify-file docs/output_zh-TW.md
```

Optional flags:

- `--repo <path>`: project root (default: the caller's `$PWD`)
- `--model <name>`: model string passed to the selected backend with `-m`
- `--verify-file <path>`: repeat for multiple files; each must exist and be non-empty
- `--verify-sentinel <string>`: each verify file must also contain this substring

### From PowerShell

```powershell
& "C:\Users\wenyu\.claude\skills\gemini-delegate\scripts\run_gemini.ps1" `
    -Prompt "Read .ai/gemini_task_<name>.md and execute all instructions inside." `
    -LogFile "C:\Users\wenyu\<repo>\.ai\gemini_log_<name>.txt" `
    -VerifyFile "C:\Users\wenyu\<repo>\docs\output_zh-TW.md"
```

PowerShell parameters: `-Prompt` (required), `-Repo`, `-Model`, `-LogFile`, `-VerifyFile` (string array), `-VerifySentinel`.

## Environment variables

- `AGY_PATH` - override the Antigravity CLI executable
- `GEMINI_PATH` - override the legacy Gemini CLI executable
- `PYTHON_BIN` (bash only) - override Python used for JSON escaping

## Sentinels written by the wrapper

| File | Written when |
|---|---|
| `<log>.done` | Wrapper exited 0 (success or fallback). **Not** written on `verify_failed` or hard error. |
| `<log>.error` | Hard failure, quota error, or verification failure |
| `<log>.fallback_claude` | Quota exceeded; Claude must take over |
| `<log>.result.json` | Always written - check this first |

Treat `.result.json` as the canonical signal; the other files are convenience for shell scripts that prefer file-existence checks.
