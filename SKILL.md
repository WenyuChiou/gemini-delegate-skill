---
name: gemini-delegate
description: Use when the task is dominated by large-context reading, bilingual or CJK synthesis, long-form zh-TW writing, or second-opinion review rather than bulk code generation. Typical triggers include Chinese summaries of large English material, cross-file synthesis, terminology alignment, release-note drafting, and reviewer-style passes over documentation or generated output.
---

# Gemini Delegate Skill

Claude is the supervisor. Claude decides scope, supplies context, and performs final review. Gemini is the specialist for large-context synthesis, bilingual/CJK drafting, and second-opinion analysis.

## When to Use

Do not use Gemini as a mirror copy of Codex. Its value is different.

| Route to | Best for | Avoid |
|----------|----------|-------|
| `Gemini` | Large-context summarization, zh-TW/CJK writing, bilingual synthesis, reviewer-style second opinion, release-note drafting | Bulk code generation, architecture decisions, security-sensitive coding |
| `Codex` | Mechanical implementation, refactors, test scaffolding, batch edits | Large-context reading and nuanced synthesis |
| `Claude` | Requirements, acceptance judgment, debugging root cause, final publication review | Long repetitive drafting |

If the task is "read a lot, synthesize, compare, or rewrite in Chinese," Gemini is a good candidate.

## Required Output Contract

Every wrapper run must leave machine-readable status in:

`<log-file>.result.json`

Required fields:

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

The wrapper contract is transport status only. Claude still owns factual review, terminology checks, and publication quality.

## Good Delegation Targets

- Summarize a long English report into concise zh-TW
- Compare multiple docs and produce one synthesized brief
- Rewrite translated content into more natural Traditional Chinese
- Draft release notes, updates, or FAQs from source material
- Provide a second-opinion review over a long design or doc set
- Align terminology across bilingual documents

## Bad Delegation Targets

- Generate or refactor production code across many files
- Diagnose a flaky test or deep runtime bug
- Decide architecture or API boundaries
- Review auth, secret handling, or validation logic
- Publish translation output without Claude review

## Supervisor Workflow

### 1. Write a task file

Create `.ai/gemini_task_<name>.md`:

```markdown
# Task: <descriptive name>

## Context
- Repo: C:\path\to\repo
- Read these files first:
  - docs/spec.md
  - docs/changelog.md
- Output file(s):
  - docs/output_zh-TW.md

## Goal
<what Gemini should synthesize or draft>

## Language
- Output language: Traditional Chinese
- Tone: formal / concise / executive / technical
- Audience: <who will read it>

## Constraints
- Preserve dates and proper nouns exactly
- Keep terminology consistent with glossary.md
- Do not invent facts missing from the sources

## Acceptance
- Required verification files: <paths>
- Required sentinel string: <string if useful>
- Claude will perform a terminology and factual review before shipping
```

### 2. Launch Gemini synchronously

From Claude Code Bash:

```bash
bash .claude/skills/gemini-delegate/scripts/run_gemini.sh \
  --prompt "Read .ai/gemini_task_<name>.md and execute all instructions inside." \
  --log-file .ai/gemini_log_<name>.txt \
  --verify-file docs/output_zh-TW.md
```

PowerShell direct call is also supported:

```powershell
& "C:\Users\wenyu\mispricing-engine\.claude\skills\gemini-delegate\scripts\run_gemini.ps1" `
    -Prompt "Read .ai/gemini_task_<name>.md and execute all instructions inside." `
    -LogFile "C:\Users\wenyu\mispricing-engine\.ai\gemini_log_<name>.txt" `
    -VerifyFile "C:\Users\wenyu\mispricing-engine\docs\output_zh-TW.md"
```

### 3. Read wrapper status first

```bash
cat .ai/gemini_log_<name>.txt.result.json
```

If status is `verify_failed`, the process exited but required files were missing or incomplete. Treat that as failure.

### 4. Claude publication review

Claude must review:

- factual accuracy against source files
- dates, names, and terminology consistency
- tone and audience fit
- any banned or sensitive phrasing required by the project

Gemini can draft or synthesize. Claude decides whether the output is publishable.

## Non-Interactive Execution Rules

These wrappers already enforce the critical Gemini CLI rules:

- run from the target working directory instead of using a fake `-C`
- pass `--approval-mode yolo`
- pipe prompts through stdin instead of a giant positional argument
- verify expected files after exit when `--verify-file` is supplied

If you write your own wrapper, preserve all four behaviors.

## Quality Boundaries

Gemini is useful for first drafts and synthesis, but it can still:

- drift terminology across files
- over-translate proper nouns
- miss project-specific banned phrases
- guess dates or context if the prompt is underspecified

Do not ship its output unreviewed.

## Minimal Review Checklist

Before accepting delegate output:

- Did Gemini cite or preserve the correct source facts?
- Did it keep terminology consistent with project vocabulary?
- Did it stay within the requested language and tone?
- Did required output files actually exist on disk?
- Does the result belong to Gemini, or should this have stayed in Claude/Codex?

If the answer to the last question is wrong, fix your routing first.
