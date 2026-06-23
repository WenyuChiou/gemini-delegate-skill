---
name: gemini-delegate
description: Delegates large-context reading, bilingual or Chinese (CJK / zh-TW) drafting, cross-file synthesis, and second-opinion review to Google Antigravity CLI (`agy`) or legacy Gemini CLI. Use when input exceeds Claude's working budget, when the user writes in Chinese, when terminology must align across long documents, or when a reviewer pass is needed. Trigger phrases include "summarize this in Chinese", "second-opinion review", "long-context synthesis", "draft this in zh-TW". Avoid for bulk code generation or security-sensitive coding.
license: MIT
compatibility: Designed for Claude Code. Portable across agentskills.io-compliant hosts; the wrapper script lives at <skill-root>/scripts/run_gemini.sh - adapt the example path to your host's skills directory (e.g. ~/.claude/skills/gemini-delegate/ on Claude Code, ~/.hermes/skills/<category>/gemini-delegate/ on Hermes).
---

# Gemini Delegate Skill

Claude is the supervisor. Antigravity CLI (`agy`) or legacy Gemini CLI drafts and synthesizes. Claude reviews terminology, facts, tone, and decides what ships.
## Why use this instead of raw CLI calls

This wrapper exists because the Google CLI backends have **three footguns** that silently break shipping tasks if you bypass it:

| What the wrapper handles | What raw CLI calls cost you |
|---|---|
| **stdin-pipe instead of `-p` positional** | **F1 silent failure**. Legacy Gemini CLI honors `.gitignore` by default, so `gemini -p "Read .ai/foo.md"` can skip the brief entirely because `.ai/` is gitignored. The task appears to succeed, but the model never read the brief. |
| **Backend-specific approval flag** | `agy` needs `--yolo`; legacy `gemini` needs `--approval-mode yolo`. Without the right flag, file-write approvals can hang waiting for a TUI prompt that never gets answered. |
| **No `-C` flag** | Neither backend implements `-C <dir>`. Passing it silently does nothing; your task runs in the wrong working directory. |

### Measured token savings (real dogfood, not estimates)

From a 6-round mixed-workload session (`awesome-agentic-ai-zh` 2026-05-14, see `agent-collab-skills/docs/measured-benefits.md`):

| Workload | Saving vs Claude-inline | When it applies to you |
|---|---|---|
| **Mirror sync** (zh-TW, zh-Hans, and English, 8 files, 250 KB content) | **17-22% token reduction** | Trilingual curriculum, docs, and catalog work |
| **Long Chinese narrative draft** (daily report, weekly review, ~5k characters output) | ~10-17% extrapolated | MoodRing daily and long-form posts |
| **Multi-paper synthesis** (NotebookLM-style, 5-10 papers to 1 brief) | ~7-17% extrapolated | research-hub reading list, cross-paper terminology audit |
| **Second-opinion review** (Claude wrote a draft; Gemini reads it) | ~5% extrapolated | Adversarial review on academic abstracts and prompt engineering output |
| **Code generation** | 0% (skill not appropriate) | Use `codex-delegate` instead |
| **Security-sensitive / final acceptance** | 0% (skill cannot help) | Claude direct |
### Anti-patterns this skill prevents

- **F1**: `gemini -p "Read .ai/foo.md"` silently skips the brief because `.ai/` is gitignored. Prevented by the wrapper's stdin-pipe pattern (`cat .ai/foo.md | agy -m gemini-2.5-pro --yolo -` or `gemini -m gemini-2.5-pro --approval-mode yolo < .ai/foo.md`).
- **F13** ("liar mode"): Gemini reports task complete without actually writing output files. Prevented by the wrapper's `--verify-file` post-check that fails the run if the expected file is missing or unchanged.
- **F14**: Operator (Claude) defaults to `Bash("gemini -p ...")` despite the rule saying use `Skill("gemini-delegate")`. Prevented by a `PreToolUse` hook on the operator side (template below).

### CLAUDE.md snippet to enforce routing

Drop this into your `~/.claude/CLAUDE.md` (or repo-level `CLAUDE.md`) so the rule is operational, not aspirational:

```markdown
## Gemini routing rule (enforced)

For any task that is long-context CJK / Chinese narrative, multi-paper
synthesis, second-opinion review, or terminology audit across long docs:
invoke `Skill("gemini-delegate", args="brief=...")`. Do NOT use
`Bash("gemini -p ...")` or raw `agy` unless you also preserve the wrapper
contract. Raw calls trigger F1 (silent skip of .ai/ brief), F13 (liar mode
without --verify-file), and approval-mode hangs.

The wrapper auto-detects `agy` or legacy `gemini`. If you must use a raw
call, use one of these canonical stdin-pipe patterns and cap logs:

  cat .ai/gemini_task_<NNN>.md | agy -m gemini-2.5-pro --yolo - 2>&1 | head -c 10485760
  gemini -m gemini-2.5-pro --approval-mode yolo < .ai/gemini_task_<NNN>.md 2>&1 | head -c 10485760
Optional mechanical enforcement: a PreToolUse hook on Bash that nudges raw
`gemini -p` toward `Skill("gemini-delegate")`. Reference:
https://github.com/WenyuChiou/dotfiles-claude/blob/main/hooks/check_codex_skill_routing.py
(same hook covers codex + gemini).
```

The hook excludes the canonical stdin-pipe pattern, so legitimate raw use passes silently. Only the F1-prone `gemini -p "Read .ai/..."` shape triggers the nudge.

## Prerequisite check (do this first)

Before producing any task file, wrapper command, or handoff prompt, verify that at least one supported backend is on `$PATH`, checking `agy` first:

```bash
if command -v agy >/dev/null 2>&1; then
  agy --version
elif command -v gemini >/dev/null 2>&1; then
  gemini --version
else
  echo "Install Antigravity CLI: curl -fsSL https://antigravity.google/cli/install.sh | bash"
  echo "Enterprise fallback: npm install -g @google/gemini-cli"
fi
```

If neither command is found, stop and tell the user:
> This skill needs Antigravity CLI (`agy`) or legacy Gemini CLI. Install Antigravity CLI with:
>
> ```bash
> curl -fsSL https://antigravity.google/cli/install.sh | bash
> agy --version
> ```
>
> Enterprise users who still have Gemini CLI access can install the legacy fallback:
>
> ```bash
> npm install -g @google/gemini-cli
> gemini --version
> ```
>
> Then re-run your request.

Do **not** prepare a task prompt, write a wrapper command, or fabricate a `result.json`. Without a supported binary on PATH, every "successful" wrapper run is a hallucination.

## Migration from Gemini CLI

Gemini CLI was deprecated for free/Pro/Ultra individual users on 2026-06-18. The wrapper now supports a dual-backend path: it uses `AGY_PATH`, then `GEMINI_PATH`, then `agy` on PATH, then `gemini` on PATH. Existing wrapper commands, task brief names, and `.ai/gemini_task_*.md` conventions stay unchanged.

## Hard rules
These three are non-negotiable. The wrapper enforces them; if you write your own wrapper, preserve all three:

1. **No `-C` flag**. `cd` into the target repo before invoking the backend. Neither `agy` nor `gemini` has `-C`.
2. **Use `--yolo` for `agy` or `--approval-mode yolo` for `gemini`**. The wrapper handles this automatically.
3. **Pipe the prompt through stdin**. `agy` requires the trailing `-` to read stdin; legacy `gemini` reads from redirected stdin.

The wrapper additionally verifies expected files when `--verify-file` is supplied.

## When to delegate

Long-context synthesis or CJK writing -> Gemini / Antigravity CLI. Code execution -> Codex. Judgment / review / final acceptance -> Claude.

Full routing table and examples: `references/delegation-targets.md`.

## Workflow

1. **Brief**: write `.ai/gemini_task_<name>.md` with Context / Goal / Language & tone / Constraints / Acceptance. Template: `references/task-template.md`. For a drift-sensitive task (published report, bilingual mirror, long-context synthesis, second-opinion review) — where an invented fact, a slipped term, or a wrong language variant would hurt — also add the XML prompt blocks from `references/gemini-prompt-blocks.md` to the Goal/Language/Constraints. A tiny low-stakes draft does not need them. If the brief was queued by `agent-task-splitter` (from the `agent-collab-skills` marketplace), it lives at `.ai/gemini_task_<NNN>_<slug>.md`; read `.coord/plan.yml` for round context first.
2. **Run**: from Claude Code Bash, invoke the wrapper from its install location. The command stays the same; the wrapper auto-detects `agy` or legacy `gemini`.
   ```bash
   bash ~/.claude/skills/gemini-delegate/scripts/run_gemini.sh \
     --prompt "Read .ai/gemini_task_<name>.md and execute all instructions inside." \
     --repo "$PWD" \
     --log-file .ai/gemini_log_<name>.txt \
     --verify-file <expected_output_path>
   ```
   `--repo` defaults to the caller's `$PWD`; pass `--repo "$PWD"` explicitly only if you want to be defensive about the working directory at invocation. On non-Claude-Code agentskills.io hosts, substitute the host's skills directory (e.g. `~/.hermes/skills/<category>/gemini-delegate/scripts/run_gemini.sh`). PowerShell variant + env vars: `references/wrapper.md`.

3. **Read status**: `cat .ai/gemini_log_<name>.txt.result.json`.
   - `success` -> output still needs Claude publication review.
   - `verify_failed` -> process exited but expected files missing; treat as failure.
   - `fallback` -> quota hit; Claude takes over.
   - `error` -> hard failure; check `<log>.error`.

4. **Publication review**: factual accuracy, terminology consistency, dates / proper nouns, banned phrasing, audience fit. Extended checklist: `references/review-checklist.md`.

## Output contract
`.result.json` includes at minimum: `status` (success | verify_failed | fallback | error), `delegate` (`"agy"` or `"gemini"`), `model` (`"agy/<model>"` or `"gemini/<model>"`), `log_file`, `summary`, `risks`, `files_changed`, `tests_run`, `timestamp_utc`. Full schema and status semantics: `references/output-contract.md`.

## Common drift to watch

The model may drift terminology mid-document, over-translate proper nouns, miss project-specific banned phrases, invent dates if the brief is underspecified, or switch between Simplified and Traditional Chinese mid-paragraph. Never ship its output unreviewed.

## Compatibility

- Antigravity CLI (`agy`) is the preferred backend for free/Pro/Ultra individual users. It reads stdin with a trailing `-` and uses `--yolo` for approval.
- Legacy `@google/gemini-cli` remains supported for enterprise/Cloud users. Tested with `@google/gemini-cli` 0.38.2 (May 2026). Approval modes available: `default`, `auto_edit`, `yolo`, `plan`.
- Default model: `gemini-2.5-pro` (override via `--model` or `-Model`). For long-form CJK quality, prefer the latest Pro model available on your CLI.
- Backend detection order: `AGY_PATH`, `GEMINI_PATH`, `agy` on PATH, `gemini` on PATH.
- Prompt MUST be piped via stdin. The wrapper handles the backend-specific stdin pattern.
- No `-C` flag exists; the wrapper uses `pushd` / `Push-Location`. `--include-directories` exists on legacy Gemini CLI but has known path-resolution bugs and is not recommended.
- PowerShell wrapper requires `$ErrorActionPreference` to NOT be `Stop` so backend stderr banners do not trip the catch block.

## See also
- `references/delegation-targets.md` — when to use vs avoid
- `references/wrapper.md` — full wrapper invocation, env vars, sentinels
- `references/task-template.md` — CJK-aware task brief template
- `references/gemini-prompt-blocks.md` — XML prompt blocks + recipes + anti-patterns for drift-sensitive briefs
- `references/output-contract.md` — full `.result.json` schema, status semantics, `.fallback_claude` quota sentinel
- `references/review-checklist.md` — extended publication gate
- `references/multi-agent.md` — leaf role in router/leaves architecture; when to route through `research-hub-multi-ai` or `agent-task-splitter`
- `references/examples.md` — concrete invocation examples (long-context summary, CJK report, bilingual README, second-opinion review)