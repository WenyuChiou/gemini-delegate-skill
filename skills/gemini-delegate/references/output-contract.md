# Gemini wrapper output contract

Every wrapper run leaves machine-readable status at `<log-file>.result.json`. This is the *transport* contract; Claude still owns publication review.

## Schema

```json
{
  "status": "success|fallback|error|verify_failed",
  "delegate": "gemini",
  "model": "gemini/<model>",
  "log_file": "<path>",
  "summary": "",
  "risks": [],
  "files_changed": [],
  "tests_run": [],
  "timestamp_utc": "2026-04-24T00:00:00Z"
}
```

## Status semantics

| Status | Meaning | Claude's next move |
|---|---|---|
| `success` | Gemini exited 0, all `--verify-file` paths exist and are non-empty | Read the output, do publication review |
| `verify_failed` | Process exited but required output files are missing or empty | Treat as failure; re-run with sharper brief |
| `fallback` | Gemini hit quota / rate limit | Take the work over directly in Claude |
| `error` | Gemini exited non-zero with a hard failure | Read `<log>.error` and `<log>` to diagnose |

## What `success` does NOT cover

The wrapper contract is transport status only. Claude still owns:

- factual review against source files
- terminology consistency
- tone and audience fit
- banned or sensitive phrasing required by the project
- whether the result is publishable at all

Gemini can draft. Claude decides what ships.
