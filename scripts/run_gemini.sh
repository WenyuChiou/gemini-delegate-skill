#!/usr/bin/env bash
# run_gemini.sh - Run Gemini CLI with automatic fallback to Claude on quota errors.

set -euo pipefail

PYTHON_JSON_BIN="${PYTHON_BIN:-}"
if [[ -z "$PYTHON_JSON_BIN" ]]; then
    if command -v python3 >/dev/null 2>&1; then
        PYTHON_JSON_BIN="python3"
    elif command -v python >/dev/null 2>&1; then
        PYTHON_JSON_BIN="python"
    else
        echo "Error: python3 or python is required for JSON escaping" >&2
        exit 1
    fi
fi

json_escape() {
    "$PYTHON_JSON_BIN" -c 'import json,sys; print(json.dumps(sys.stdin.read()))'
}

# Snapshot the repo's changed-file set via `git status --porcelain`.
# Returns empty when the path is not a git work tree (or git is absent), so
# files_changed degrades to [] instead of failing the run.
git_status_snapshot() {
    git -C "$1" -c core.quotePath=false status --porcelain 2>/dev/null || true
}

# Diff two porcelain snapshots and emit a JSON array of paths that became
# changed during the run. A file already dirty before the run, with an
# unchanged porcelain status line, is intentionally not re-reported (it was
# not this run's doing). Falls back to [] on any error.
compute_files_changed_json() {
    "$PYTHON_JSON_BIN" -c '
import json, sys
before = set(sys.argv[1].splitlines())
after = set(sys.argv[2].splitlines())
paths = set()
for line in after - before:
    entry = line[3:] if len(line) > 3 else ""
    if " -> " in entry:                 # renamed: "old -> new"
        entry = entry.split(" -> ", 1)[1]
    entry = entry.strip().strip(chr(34))
    if entry:
        paths.add(entry)
print(json.dumps(sorted(paths)))
' "$1" "$2" 2>/dev/null || printf '[]'
}

write_result_json() {
    local status="$1"
    local model="$2"
    local summary="$3"
    local files_changed_json="${4:-[]}"
    local timestamp
    timestamp="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

    {
        printf '{\n'
        printf '  "status": %s,\n' "$(printf '%s' "$status" | json_escape)"
        printf '  "delegate": "gemini",\n'
        printf '  "model": %s,\n' "$(printf '%s' "$model" | json_escape)"
        printf '  "log_file": %s,\n' "$(printf '%s' "$LOG_PATH" | json_escape)"
        printf '  "summary": %s,\n' "$(printf '%s' "$summary" | json_escape)"
        printf '  "risks": [],\n'
        printf '  "files_changed": %s,\n' "$files_changed_json"
        printf '  "tests_run": [],\n'
        printf '  "timestamp_utc": %s\n' "$(printf '%s' "$timestamp" | json_escape)"
        printf '}\n'
    } > "$RESULT_PATH"
}

PROMPT=""
# Default --repo to the caller's working directory; previously hardcoded to
# the original author's mispricing-engine path, which broke fresh installs.
REPO="${PWD}"
MODEL="gemini-2.5-pro"
LOG_FILE=""
VERIFY_FILES=()
VERIFY_SENTINEL=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --prompt)           PROMPT="$2";          shift 2 ;;
        --repo)             REPO="$2";            shift 2 ;;
        --model)            MODEL="$2";           shift 2 ;;
        --log-file)         LOG_FILE="$2";        shift 2 ;;
        --verify-file)      VERIFY_FILES+=("$2"); shift 2 ;;
        --verify-sentinel)  VERIFY_SENTINEL="$2"; shift 2 ;;
        *) echo "Unknown argument: $1" >&2; exit 1 ;;
    esac
done

if [[ -z "$PROMPT" ]]; then
    echo "Error: --prompt is required" >&2
    exit 1
fi

AI_DIR="$REPO/.ai"
LOG_PATH="${LOG_FILE:-$AI_DIR/gemini_output.txt}"
DONE_PATH="$LOG_PATH.done"
ERROR_PATH="$LOG_PATH.error"
FALLBACK_PATH="$LOG_PATH.fallback_claude"
RESULT_PATH="$LOG_PATH.result.json"

mkdir -p "$AI_DIR"
rm -f "$FALLBACK_PATH" "$DONE_PATH" "$ERROR_PATH" "$RESULT_PATH"

is_quota_error() {
    local output="$1"
    local exit_code="$2"

    [[ "$exit_code" -eq 429 ]] && return 0

    local patterns=(
        "quota exceeded"
        "rate limit"
        "rate_limit"
        "quota_exceeded"
        "insufficient_quota"
        "too many requests"
        "RateLimitError"
        "exceeded your current quota"
        "RESOURCE_EXHAUSTED"
        "429"
    )
    for p in "${patterns[@]}"; do
        if echo "$output" | grep -qi "$p"; then
            return 0
        fi
    done
    return 1
}

PROMPT_FILE="$(mktemp /tmp/gemini_prompt_XXXXXX.txt)"
printf '%s' "$PROMPT" > "$PROMPT_FILE"

GEMINI_BIN="${GEMINI_PATH:-gemini}"
OUTPUT=""
EXIT_CODE=0

# Snapshot the repo before the run so files_changed can attribute edits to
# this run only. The wrapper's own log / sentinel / result files are written
# after the after-snapshot, so they never leak in.
CHANGED_BEFORE="$(git_status_snapshot "$REPO")"

pushd "$REPO" > /dev/null
OUTPUT=$("$GEMINI_BIN" -m "$MODEL" --approval-mode yolo < "$PROMPT_FILE" 2>&1) || EXIT_CODE=$?
popd > /dev/null
rm -f "$PROMPT_FILE"

CHANGED_AFTER="$(git_status_snapshot "$REPO")"
FILES_CHANGED_JSON="$(compute_files_changed_json "$CHANGED_BEFORE" "$CHANGED_AFTER")"

if is_quota_error "$OUTPUT" "$EXIT_CODE"; then
    echo "Gemini quota/rate-limit exceeded; creating .fallback_claude sentinel for Claude to handle" >&2
    {
        echo "[GEMINI QUOTA EXCEEDED at $(date -u +%Y-%m-%dT%H:%M:%SZ)]"
        echo "$OUTPUT"
    } > "$LOG_PATH"
    echo "ALL_QUOTA_EXCEEDED|$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$ERROR_PATH"
    echo "FALLBACK_TO_CLAUDE|$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$FALLBACK_PATH"
    echo "FALLBACK|$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$DONE_PATH"
    write_result_json "fallback" "gemini/$MODEL" "Gemini quota exceeded; Claude must take over." "$FILES_CHANGED_JSON"
    exit 0
fi

if [[ "$EXIT_CODE" -ne 0 ]]; then
    echo "Gemini hard failure (exit $EXIT_CODE)" >&2
    echo "$OUTPUT" > "$ERROR_PATH"
    write_result_json "error" "gemini/$MODEL" "Gemini exited with a hard failure." "$FILES_CHANGED_JSON"
    exit 1
fi

if [[ "${#VERIFY_FILES[@]}" -gt 0 ]]; then
    VERIFY_FAIL=0
    for f in "${VERIFY_FILES[@]}"; do
        if [[ ! -s "$f" ]]; then
            echo "VERIFICATION FAILED: $f missing or empty" >&2
            VERIFY_FAIL=1
            continue
        fi
        if [[ -n "$VERIFY_SENTINEL" ]] && ! grep -q -- "$VERIFY_SENTINEL" "$f"; then
            echo "VERIFICATION FAILED: $f missing sentinel '$VERIFY_SENTINEL'" >&2
            VERIFY_FAIL=1
        fi
    done
    if [[ "$VERIFY_FAIL" -eq 1 ]]; then
        {
            echo "[VERIFICATION FAILED at $(date -u +%Y-%m-%dT%H:%M:%SZ)]"
            echo "[MODEL_USED: gemini/$MODEL]"
            echo "$OUTPUT"
        } > "$LOG_PATH"
        echo "VERIFY_FAILED|gemini/$MODEL|$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$ERROR_PATH"
        write_result_json "verify_failed" "gemini/$MODEL" "Gemini exited, but required output files failed verification." "$FILES_CHANGED_JSON"
        exit 1
    fi
fi

{
    echo "[MODEL_USED: gemini/$MODEL]"
    echo "$OUTPUT"
} > "$LOG_PATH"
echo "DONE|gemini/$MODEL|$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$DONE_PATH"
write_result_json "success" "gemini/$MODEL" "Gemini completed successfully. Claude must still review facts, terminology, and tone." "$FILES_CHANGED_JSON"
