# Gemini Delegation Examples

The wrapper auto-detects `agy` (Antigravity CLI) or `gemini` (legacy). Examples show wrapper invocations that work with either backend.

All examples use bash syntax (Claude Code Bash tool = git-bash on Windows). Never use `cd /d` or `type`; those are CMD-only. Use `cd /c/path` and `cat` instead. For prompt-template skeletons of common shapes, see `task-template.md`. For when not to delegate to Gemini / Antigravity CLI, see `delegation-targets.md`.

## Recommended: use the wrapper

The `run_gemini.sh` script enforces all three hard rules automatically (`pushd` instead of `-C`, backend-specific approval flags, stdin pipe), plus quota fallback and file-write verification. Prefer it over raw CLI calls.

`--repo` defaults to the caller's `$PWD`. Pass it explicitly only if you want to be defensive.

## Example 1: Long-context summarization

Summarize a 60-page English design doc into a one-page brief.

Context file (`.ai/gemini_task_summary.md`):

```markdown
# Task: Summarize the design doc

## Context
- Repo: ~/myproject
- Read these files first:
  - docs/design/system_overview.md
  - docs/design/data_flow.md
  - docs/design/security_model.md
- Output file:
  - .ai/gemini_result_summary.md

## Goal
A one-page (~400 word) executive brief covering:
1. What the system does in one paragraph
2. Three architectural decisions and why
3. Two risks and mitigations
4. One open question

## Language
- English, executive tone, no jargon
- Audience: VP-level reader who has not seen the docs

## Constraints
- Do not invent facts missing from the sources
- Preserve all proper nouns and dates exactly
- Hedge any inference with "likely" / "appears to"
```

Launch:

```bash
cd ~/myproject
bash ~/.claude/skills/gemini-delegate/scripts/run_gemini.sh \
  --prompt "Read .ai/gemini_task_summary.md and execute all instructions inside." \
  --log-file .ai/gemini_log_summary.txt \
  --verify-file .ai/gemini_result_summary.md
```

## Example 2: Chinese financial report

A Traditional Chinese weekly market update that benefits from long-context CJK drafting.

Context file (`.ai/gemini_task_report.md`):

```markdown
# Task: Generate Weekly Americas Update

## Goal
Write a ~800 word Threads post in Traditional Chinese covering this week's macro developments.

## Structure
1. Key observation with framework reference
2. Data interpretation with hedged language and no absolutes
3. What this means for credit-spread positioning
4. Upcoming events to watch

## Data Points
- SPY: 525.31 (+1.1%), VIX: 14.2 (-3.8)
- 10Y yield: 4.35% (-0.28%)
- Fed minutes: dovish tilt, 2 cuts still priced

## Style Rules
- Use hedged language
- Reference frameworks by name
- Preserve proper nouns and dates exactly
- Output file: .ai/gemini_result_report.md
```

Launch:

```bash
cd ~/mispricing-engine
bash ~/.claude/skills/gemini-delegate/scripts/run_gemini.sh \
  --prompt "Read .ai/gemini_task_report.md and execute all instructions inside." \
  --log-file .ai/gemini_log_report.txt \
  --verify-file .ai/gemini_result_report.md
```

## Example 3: Bilingual README

Mirror an English README into Traditional Chinese while preserving structure.

```bash
cd ~/myproject
bash ~/.claude/skills/gemini-delegate/scripts/run_gemini.sh \
  --prompt "Read README.md (English). Create README_zh-TW.md (Traditional Chinese) with: language toggle link at top, identical section structure, identical code blocks unchanged, terminology matching docs/glossary.md if present. Do not translate proper nouns or filenames." \
  --log-file .ai/gemini_log_zh.txt \
  --verify-file README_zh-TW.md
```

Claude reviews terminology consistency and any over-translated proper nouns before publishing.

## Example 4: Second-opinion review

Have the backend review a design doc Claude already drafted.

```bash
cd ~/myproject
bash ~/.claude/skills/gemini-delegate/scripts/run_gemini.sh \
  --prompt "Read docs/design/auth_redesign.md. Provide a reviewer-style critique covering: (a) load-bearing assumptions that aren't stated, (b) edge cases the doc misses, (c) terminology that drifts mid-doc, (d) anything that contradicts docs/architecture.md. Output: .ai/gemini_review_auth.md with one section per category, each with concrete line references." \
  --log-file .ai/gemini_log_review.txt \
  --verify-file .ai/gemini_review_auth.md
```

Treat the review as a hint, not a verdict; Claude still owns acceptance.

## Raw invocation (skip the wrapper)

If you skip the wrapper, you must enforce the three hard rules yourself:

```bash
cd ~/myproject

# Antigravity CLI: pipe via stdin, use --yolo, append "-" to read stdin.
cat .ai/gemini_task_summary.md | agy -m gemini-2.5-pro --yolo - > .ai/gemini_log_summary.txt 2>&1

# Legacy Gemini CLI: pipe via stdin, use --approval-mode yolo, run from project dir.
gemini --approval-mode yolo < .ai/gemini_task_summary.md > .ai/gemini_log_summary.txt 2>&1
```

The wrapper is preferred because it also writes `result.json`, the `.fallback_claude` quota sentinel, and runs `--verify-file` checks after exit.

## What does NOT belong here

These were in earlier versions of this file but contradict `delegation-targets.md`:

- Multi-file Python refactors: route to `codex-delegate`.
- React component generation: route to `codex-delegate`.
- Test scaffolding: route to `codex-delegate`.

Code generation in general is a Codex job, not a Gemini / Antigravity CLI job.
