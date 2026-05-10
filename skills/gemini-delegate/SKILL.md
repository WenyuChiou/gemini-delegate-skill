---
name: gemini-delegate
description: Delegates large-context reading, bilingual or Chinese (CJK / 中文 / zh-TW) drafting, cross-file synthesis, and second-opinion review to Google Gemini CLI. Use when input exceeds Claude's working budget, when the user writes in Chinese, when terminology must align across long documents, or when a reviewer pass is needed. Trigger phrases include "summarize this in Chinese", "second-opinion review", "long-context synthesis", "draft this in zh-TW". Avoid for bulk code generation or security-sensitive coding.
license: MIT
compatibility: Designed for Claude Code. Portable across agentskills.io-compliant hosts; the wrapper script lives at <skill-root>/scripts/run_gemini.sh — adapt the example path to your host's skills directory (e.g. ~/.claude/skills/gemini-delegate/ on Claude Code, ~/.hermes/skills/<category>/gemini-delegate/ on Hermes).
---

# Gemini Delegate Skill

Claude is the supervisor. Gemini drafts and synthesizes. Claude reviews terminology, facts, tone, and decides what ships.

## Prerequisite check (do this first)

Before producing any task file, wrapper command, or handoff prompt, verify the binary is on `$PATH`:

```bash
gemini --version
```

If that command is **not found**, stop and tell the user:

> This skill needs the Gemini CLI. Install it with:
>
> ```bash
> npm install -g @google/gemini-cli
> gemini --version
> ```
>
> Then re-run your request.

Do **not** prepare a task prompt, write a wrapper command, or fabricate a `result.json`. Without the binary on PATH, every "successful" wrapper run is a hallucination.

## Hard rules

These three are non-negotiable. The wrapper enforces them; if you write your own wrapper, preserve all three:

1. **No `-C` flag**. `cd` into the target repo before invoking `gemini`. Gemini CLI does not have `-C`.
2. **Use `--approval-mode yolo`**. Without it, Gemini blocks on file-write approvals.
3. **Pipe the prompt through stdin**. Passing it as a positional argument can hang the CLI.

The wrapper additionally verifies expected files when `--verify-file` is supplied.

## When to delegate

Long-context synthesis or CJK writing → `gemini` · Code execution → `codex` · Judgment / review / final acceptance → `claude`.

Full routing table and examples: `references/delegation-targets.md`.

## Workflow

1. **Brief**: write `.ai/gemini_task_<name>.md` with Context / Goal / Language & tone / Constraints / Acceptance. Template: `references/task-template.md`. If the brief was queued by `agent-task-splitter` (from the `agent-collab-skills` marketplace), it lives at `.ai/gemini_task_<NNN>_<slug>.md`; read `.coord/plan.yml` for round context first.

2. **Run**: invoke the wrapper from `<skill-root>/scripts/run_gemini.sh`. On Claude Code that resolves to `~/.claude/skills/gemini-delegate/scripts/run_gemini.sh`; on other agentskills.io hosts substitute the host's skills directory.
   ```bash
   bash <skill-root>/scripts/run_gemini.sh \
     --prompt "Read .ai/gemini_task_<name>.md and execute all instructions inside." \
     --repo "$PWD" \
     --log-file .ai/gemini_log_<name>.txt \
     --verify-file <expected_output_path>
   ```
   `--repo` defaults to the caller's `$PWD`; pass `--repo "$PWD"` explicitly only if you want to be defensive about the working directory at invocation. PowerShell variant + env vars: `references/wrapper.md`.

3. **Read status**: `cat .ai/gemini_log_<name>.txt.result.json`.
   - `success` → output still needs Claude publication review.
   - `verify_failed` → process exited but expected files missing → treat as failure.
   - `fallback` → quota hit; Claude takes over.
   - `error` → hard failure; check `<log>.error`.

4. **Publication review**: factual accuracy, terminology consistency, dates / proper nouns, banned phrasing, audience fit. Extended checklist: `references/review-checklist.md`.

## Output contract

`.result.json` includes at minimum: `status` (success | verify_failed | fallback | error), `delegate` (always `"gemini"`), `model`, `log_file`, `summary`, `risks`, `files_changed`, `tests_run`, `timestamp_utc`. Full schema and status semantics: `references/output-contract.md`.

## Common drift to watch

Gemini may: drift terminology mid-document, over-translate proper nouns, miss project-specific banned phrases, invent dates if the brief is underspecified, switch between Simplified and Traditional Chinese mid-paragraph. Never ship its output unreviewed.

## Compatibility

- Tested with `@google/gemini-cli` 0.38.2 (May 2026). Approval modes available: `default`, `auto_edit`, `yolo`, `plan`.
- Default model: `gemini-2.5-pro` (override via `--model` or `-Model`). For long-form CJK quality, prefer the latest Pro model available on your CLI.
- Approval mode: `--approval-mode yolo` (the wrapper uses this). `-y, --yolo` is the boolean alias.
- Prompt MUST be piped via stdin. The CLI accepts a positional `query` and `-p/--prompt`, but feeding via stdin is what the wrapper enforces.
- No `-C` flag exists; the wrapper uses `pushd` / `Push-Location`. `--include-directories` exists but has known path-resolution bugs and is not recommended.
- PowerShell wrapper requires `$ErrorActionPreference` to NOT be `Stop` so the YOLO banner on stderr doesn't trip the catch block.

## See also

- `references/delegation-targets.md` — when to use vs avoid
- `references/wrapper.md` — full wrapper invocation, env vars, sentinels
- `references/task-template.md` — CJK-aware task brief template
- `references/output-contract.md` — full `.result.json` schema, status semantics, `.fallback_claude` quota sentinel
- `references/review-checklist.md` — extended publication gate
- `references/multi-agent.md` — leaf role in router/leaves architecture; when to route through `research-hub-multi-ai` or `agent-task-splitter`
- `references/examples.md` — concrete invocation examples (long-context summary, CJK report, bilingual README, second-opinion review)
