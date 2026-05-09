# Gemini wrapper reference

The `scripts/run_gemini.sh` and `scripts/run_gemini.ps1` wrappers run Gemini CLI synchronously, detect quota / rate-limit failures, optionally verify expected output files exist after exit, and emit a machine-readable `<log>.result.json`.

## What the wrapper enforces

These three rules are non-negotiable. The wrapper enforces all of them; if you write your own wrapper, preserve all three:

1. **Run from the target working directory** (`pushd`/`Push-Location`) instead of using a fake `-C`. Gemini CLI does not have a `-C` flag.
2. **Pass `--approval-mode yolo`**. Without it, Gemini blocks on file-write approvals.
3. **Pipe the prompt through stdin** (`< $promptFile`). Passing it as a positional argument can hang the CLI.

The wrapper additionally verifies expected files when `--verify-file` is supplied.

## Invocation

### From Claude Code Bash

```bash
bash scripts/run_gemini.sh \
  --prompt "Read .ai/gemini_task_<name>.md and execute all instructions inside." \
  --log-file .ai/gemini_log_<name>.txt \
  --verify-file docs/output_zh-TW.md
```

Optional flags:

- `--repo <path>`: project root (default: `$HOME/mispricing-engine`)
- `--model <name>`: model string for `gemini -m`
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

- `GEMINI_PATH` — override the Gemini executable
- `PYTHON_BIN` (bash only) — override Python used for JSON escaping

## Sentinels written by the wrapper

| File | Written when |
|---|---|
| `<log>.done` | Wrapper exited 0 (success or fallback). **Not** written on `verify_failed` or hard error. |
| `<log>.error` | Hard failure, quota error, or verification failure |
| `<log>.fallback_claude` | Quota exceeded; Claude must take over |
| `<log>.result.json` | Always written — check this first |

Treat `.result.json` as the canonical signal; the other files are convenience for shell scripts that prefer file-existence checks.
