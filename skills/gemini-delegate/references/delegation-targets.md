# Gemini delegation targets

## Routing summary

| Route to | Best for | Avoid |
|----------|----------|-------|
| `Gemini / Antigravity CLI` | Large-context summarization, English or zh-TW / CJK writing, bilingual synthesis, reviewer-style second opinion, release-note drafting | Bulk code generation, architecture decisions, security-sensitive coding |
| `Codex` | Mechanical implementation, refactors, test scaffolding, batch edits | Large-context reading and nuanced synthesis |
| `Claude` | Requirements, acceptance judgment, debugging root cause, final publication review | Long repetitive drafting |

## Good delegation targets

- Summarize a long English report into concise English or zh-TW
- Compare multiple docs and produce one synthesized brief
- Rewrite translated content into more natural Traditional Chinese
- Draft release notes, updates, or FAQs from source material in English or Chinese
- Provide a second-opinion review over a long design or doc set
- Align terminology across bilingual documents

## Bad delegation targets

- Generate or refactor production code across many files
- Diagnose a flaky test or deep runtime bug
- Decide architecture or API boundaries
- Review auth, secret handling, or validation logic
- Publish translation output without Claude review

## Decision rule of thumb

If the task is "read a lot, synthesize, compare, or rewrite carefully in English or Chinese," Gemini / Antigravity CLI is a good candidate. If the task is "decide" or "execute code changes," it isn't.
