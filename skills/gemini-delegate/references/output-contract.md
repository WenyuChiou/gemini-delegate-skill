# Gemini wrapper output contract

Every wrapper run leaves machine-readable status at `<log-file>.result.json`. This is the transport contract; Claude still owns publication review.

## Schema

```json
{
  "status": "success|fallback|error|verify_failed",
  "delegate": "agy|gemini",
  "model": "agy/<model>|gemini/<model>",
  "log_file": "<path>",
  "summary": "",
  "risks": [],
  "files_changed": [],
  "tests_run": [],
  "timestamp_utc": "2026-04-24T00:00:00Z"
}
```

## Backend fields

- `delegate` is `"agy"` or `"gemini"` depending on the backend detected by the wrapper.
- `model` is prefixed with the backend, e.g. `"agy/gemini-2.5-pro"` or `"gemini/gemini-2.5-pro"`.
- Consumers should check `delegate` when backend-specific diagnostics or follow-up instructions matter.

## Status semantics

| Status | Meaning | Claude's next move |
|---|---|---|
| `success` | Backend exited 0, all `--verify-file` paths exist and are non-empty | Read the output, do publication review |
| `verify_failed` | Process exited but required output files are missing or empty | Treat as failure; re-run with sharper brief |
| `fallback` | Backend hit quota / rate limit | Take the work over directly in Claude |
| `error` | Backend exited non-zero with a hard failure | Read `<log>.error` and `<log>` to diagnose |

## Quota fallback sentinel

When the wrapper detects a quota or rate-limit failure, it writes a sibling `<log-file>.fallback_claude` sentinel file alongside the log and sets `result.json` `status` to `fallback`. Claude must then:

1. Read the sentinel and `result.json` to confirm the fallback path.
2. Take the work over directly in the current session, using the same task brief including the language, tone, and audience the brief specifies.
3. Not retry the backend call; quota errors do not resolve quickly, and retry loops just burn context.

The sentinel is a marker, not a payload. Its presence plus the `fallback` status are the contract; its content is informational.

## What `success` does NOT cover

The wrapper contract is transport status only. Claude still owns:

- factual review against source files
- terminology consistency
- tone and audience fit
- banned or sensitive phrasing required by the project
- whether the result is publishable at all

The backend can draft. Claude decides what ships.
