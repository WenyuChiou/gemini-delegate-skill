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
  "files_changed": ["docs/output_zh-TW.md"],
  "tests_run": [],
  "timestamp_utc": "2026-04-24T00:00:00Z"
}
```

## Which fields the wrapper fills

| Field | Source | Notes |
|---|---|---|
| `status` / `delegate` / `model` / `log_file` / `summary` / `timestamp_utc` | wrapper | always written |
| `files_changed` | wrapper, **auto-derived** | `git status --porcelain` snapshot diff (before vs after the Gemini run), so it attributes edits to *this run only*. Empty `[]` when the repo is not a git work tree, when git is absent, or when the run changed nothing. A file already dirty before the run, with an unchanged porcelain status line, is intentionally not re-reported — run `git diff HEAD` for the full picture. The wrapper's own log / sentinel / `result.json` files are written *after* the snapshot, so they never leak in. This complements `--verify-file`: `--verify-file` checks that *expected* outputs exist; `files_changed` reveals *everything* Gemini touched, catching scope drift. |
| `tests_run` | **not auto-filled** — stays `[]` | Gemini-delegate work is drafting / synthesis, not test execution; there is nothing for the wrapper to record here. Left in the schema for cross-delegate contract parity. |
| `risks` | **not auto-filled** — stays `[]` | Risk assessment is a judgment call; it stays Claude's job during publication review. |

## Status semantics

| Status | Meaning | Claude's next move |
|---|---|---|
| `success` | Gemini exited 0, all `--verify-file` paths exist and are non-empty | Read the output, do publication review |
| `verify_failed` | Process exited but required output files are missing or empty | Treat as failure; re-run with sharper brief |
| `fallback` | Gemini hit quota / rate limit | Take the work over directly in Claude |
| `error` | Gemini exited non-zero with a hard failure | Read `<log>.error` and `<log>` to diagnose |

## Quota fallback sentinel

When the wrapper detects a quota or rate-limit failure, it writes a sibling `<log-file>.fallback_claude` sentinel file alongside the log and sets `result.json` `status` to `fallback`. Claude must then:

1. Read the sentinel and `result.json` to confirm the fallback path.
2. Take the work over directly in the current session, using the same task brief — including the language, tone, and audience the brief specifies.
3. Not retry the Gemini call — quota errors do not resolve quickly, and retry loops just burn context.

The sentinel is a marker, not a payload. Its presence + the `fallback` status are the contract; its content is informational.

## What `success` does NOT cover

The wrapper contract is transport status only. Claude still owns:

- factual review against source files
- terminology consistency
- tone and audience fit
- banned or sensitive phrasing required by the project
- whether the result is publishable at all

Gemini can draft. Claude decides what ships.
