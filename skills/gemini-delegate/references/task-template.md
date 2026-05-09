# Gemini task brief template

Save the brief at `.ai/gemini_task_<name>.md`.

## Template

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

## CJK-aware filling

- Spell out the variant: **Traditional Chinese (zh-TW)** or **Simplified Chinese (zh-CN)**. "Chinese" alone leaves Gemini to guess.
- If you have a glossary, *cite the file path*, not just the rule. Gemini will follow a glossary file far better than abstract instructions.
- For mixed English / Chinese output, name which language gets which sections.

## Anti-patterns

- "Make it sound natural" — too vague; Gemini will pick its own definition
- Missing tone / register — Gemini defaults to mid-formal which is rarely right
- Asking Gemini to "decide" something instead of synthesizing what's already in the sources
- No acceptance file — wrapper can't verify output existed
