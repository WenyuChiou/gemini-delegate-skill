#!/usr/bin/env bash
# run_gemini.sh — Run Gemini CLI with automatic fallback to Claude on quota errors
#
# Usage:
#   ./run_gemini.sh --prompt "your task here" [options]
#
# Options:
#   --prompt <text>      Task prompt (required)
#   --repo <path>        Repo working directory (default: ~/mispricing-engine)
#   --model <id>         Gemini model (default: gemini-2.5-pro)
#   --log-file <path>    Where to write output log (default: <repo>/.ai/gemini_output.txt)
#
# Fallback chain: Gemini → .fallback_claude sentinel (Claude handles it)
# Exit codes: 0 = success or fallback sentinel written, 1 = hard failure

set -euo pipefail

# ── Defaults ──────────────────────────────────────────────────────────────────
PROMPT=""
REPO="${HOME}/mispricing-engine"
MODEL="gemini-2.5-pro"
LOG_FILE=""

# ── Argument parsing ──────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case "$1" in
        --prompt)       PROMPT="$2";      shift 2 ;;
        --repo)         REPO="$2";        shift 2 ;;
        --model)        MODEL="$2";       shift 2 ;;
        --log-file)     LOG_FILE="$2";    shift 2 ;;
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

# Gemini CLI invocation — adjust flags as needed for your Gemini CLI version
OUTPUT=$("$GEMINI_BIN" -m "$MODEL" -C "$REPO" "$(cat "$PROMPT_FILE")" 2>&1) || EXIT_CODE=$?
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

# Success
{
    echo "[MODEL_USED: gemini/$MODEL]"
    echo "$OUTPUT"
} > "$LOG_PATH"
echo "DONE|gemini/$MODEL|$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$DONE_PATH"
