#!/usr/bin/env bash
# run_gemini.sh — Run Gemini CLI with automatic fallback to Claude on quota errors
#
# Usage:
#   ./run_gemini.sh --prompt "your task here" [options]
#
# Options:
#   --prompt <text>             Task prompt (required)
#   --repo <path>               Repo working directory (default: ~/mispricing-engine)
#   --model <id>                Gemini model (default: gemini-2.5-pro)
#   --log-file <path>           Where to write output log (default: <repo>/.ai/gemini_output.txt)
#   --verify-file <path>        File path that MUST exist + be non-empty after gemini exits
#                               (repeatable; required because Gemini sometimes exits 0
#                                even when write_file calls fail mid-execution).
#   --verify-sentinel <text>    Optional: string that MUST appear in every --verify-file
#
# Fallback chain: Gemini → .fallback_claude sentinel (Claude handles it)
# Exit codes: 0 = success or fallback sentinel written, 1 = hard failure or verification failure

set -euo pipefail

# ── Defaults ──────────────────────────────────────────────────────────────────
PROMPT=""
REPO="${HOME}/mispricing-engine"
MODEL="gemini-2.5-pro"
LOG_FILE=""
VERIFY_FILES=()    # paths to verify exist + non-empty after gemini exits
VERIFY_SENTINEL="" # optional: string that MUST appear in each verified file

# ── Argument parsing ──────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case "$1" in
        --prompt)           PROMPT="$2";            shift 2 ;;
        --repo)             REPO="$2";              shift 2 ;;
        --model)            MODEL="$2";             shift 2 ;;
        --log-file)         LOG_FILE="$2";          shift 2 ;;
        --verify-file)      VERIFY_FILES+=("$2");   shift 2 ;;
        --verify-sentinel)  VERIFY_SENTINEL="$2";   shift 2 ;;
        *) echo "Unknown argument: $1" >&2; exit 1 ;;
    esac
done

if [[ -z "$PROMPT" ]]; then
    echo "Error: --prompt is required" >&2
    exit 1
fi

# ── Paths ─────────────────────────────────────────────────────────────────────
AI_DIR="$REPO/.ai"
LOG_PATH="${LOG_FILE:-$AI_DIR/gemini_output.txt}"
DONE_PATH="$LOG_PATH.done"
ERROR_PATH="$LOG_PATH.error"
FALLBACK_PATH="$LOG_PATH.fallback_claude"

mkdir -p "$AI_DIR"

# Clean up stale sentinel files from previous runs
rm -f "$FALLBACK_PATH" "$DONE_PATH" "$ERROR_PATH"

# ── Quota / rate-limit detection ──────────────────────────────────────────────
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

# ── Run Gemini ────────────────────────────────────────────────────────────────
PROMPT_FILE="$(mktemp /tmp/gemini_prompt_XXXXXX.txt)"
printf '%s' "$PROMPT" > "$PROMPT_FILE"

GEMINI_BIN="${GEMINI_PATH:-gemini}"
OUTPUT=""
EXIT_CODE=0

# Three critical rules for non-interactive Gemini CLI runs:
#   1. Gemini CLI has NO `-C <dir>` flag (that is Codex CLI syntax). You must
#      `pushd` into the target workspace so Gemini's sandbox allows writes there.
#   2. Must pass `--approval-mode yolo`. Default mode prompts for approval per
#      tool call; in non-interactive mode those calls are silently skipped and
#      Gemini falls back to emitting write_file() as pseudo-code comments
#      instead of actually writing files.
#   3. Pipe the prompt via stdin, not as a positional arg — positional args
#      hit the ~32 KB Windows command-line length limit for large briefs.
pushd "$REPO" > /dev/null
OUTPUT=$("$GEMINI_BIN" -m "$MODEL" --approval-mode yolo < "$PROMPT_FILE" 2>&1) || EXIT_CODE=$?
popd > /dev/null
rm -f "$PROMPT_FILE"

if is_quota_error "$OUTPUT" "$EXIT_CODE"; then
    echo "Gemini quota/rate-limit exceeded — creating .fallback_claude sentinel for Claude to handle" >&2
    {
        echo "[GEMINI QUOTA EXCEEDED at $(date -u +%Y-%m-%dT%H:%M:%SZ)]"
        echo "$OUTPUT"
    } > "$LOG_PATH"
    echo "ALL_QUOTA_EXCEEDED|$(date -u +%Y-%m-%dT%H:%M:%SZ)"  > "$ERROR_PATH"
    echo "FALLBACK_TO_CLAUDE|$(date -u +%Y-%m-%dT%H:%M:%SZ)"  > "$FALLBACK_PATH"
    echo "FALLBACK|$(date -u +%Y-%m-%dT%H:%M:%SZ)"            > "$DONE_PATH"
    exit 0
fi

if [[ "$EXIT_CODE" -ne 0 ]]; then
    echo "Gemini hard failure (exit $EXIT_CODE)" >&2
    echo "$OUTPUT" > "$ERROR_PATH"
    exit 1
fi

# Success — but FIRST verify expected files exist on disk
# (Gemini sometimes exits 0 even when write_file calls failed mid-execution
#  due to internal tool-schema bugs.)
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
        exit 1
    fi
    echo "Verified ${#VERIFY_FILES[@]} file(s) exist + non-empty${VERIFY_SENTINEL:+ + contain sentinel}." >&2
fi

# Success
{
    echo "[MODEL_USED: gemini/$MODEL]"
    echo "$OUTPUT"
} > "$LOG_PATH"
echo "DONE|gemini/$MODEL|$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$DONE_PATH"
