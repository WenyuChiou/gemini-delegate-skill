# Gemini Delegate Skill

> [繁體中文](README_zh-TW.md)

`gemini-delegate` is a Claude-oriented skill for using Google Gemini as a specialist for large-context synthesis, long-form drafting, English or bilingual / CJK writing, and second-opinion review.

> 📚 Part of the [**agentic AI learning roadmap**](https://github.com/WenyuChiou/awesome-agentic-ai-zh) — a 7-stage curated path for building agentic AI, multilingual (zh-TW · zh-CN · English). This skill is referenced in §13 (Multi-LLM Delegation).

## Why this exists

Claude has a finite working context, and certain tasks are a bad fit even when Claude could technically do them. Two failure modes are common:

- **Long-form input doesn't fit cleanly.** When you need to summarize, compare, or rewrite content that spans many large source files, Gemini's larger context window lets it ingest the whole picture at once instead of forcing Claude to chunk and stitch.
- **CJK / bilingual writing is uneven.** For long-form Traditional Chinese or English↔Chinese rewriting, Gemini often produces more natural cadence than Claude. This is a community observation, not an official benchmark — but it shows up enough that it's worth structuring around.

Routing those tasks to Gemini lets Claude stay in its strengths (judgment, terminology review, factual checking) and lets Gemini do what it's actually best at (large-context synthesis and CJK drafting).

**This skill pays off when:**

- the source material exceeds Claude's comfortable working context
- you need long-form Traditional Chinese or bilingual writing
- you want a reviewer-style second opinion on long documents
- you need to align terminology across translated content
- you're drafting release notes, FAQs, or summaries from many sources

**It does not pay off when:**

- the task is bulk code generation (use `codex-delegate` instead)
- the task is architecture or security review (keep in Claude)
- the input fits in Claude's context and quality matters more than throughput
- factual accuracy outweighs draft fluency (Claude reviews before shipping anyway)

## Positioning

This skill is **not** the Gemini version of `codex-delegate`. Its job is different:

- summarize large source material into English or zh-TW
- synthesize across multiple files
- draft English, bilingual, or CJK-facing updates
- perform reviewer-style second-opinion passes on long docs
- align terminology across translated content

It is not intended for bulk code generation or architecture work.

## Core Pattern

1. Claude prepares a context file with source paths, output paths, language, and constraints.
2. Claude launches Gemini through the wrapper.
3. The wrapper can verify required output files after execution.
4. Claude performs factual, terminology, and tone review before shipping.

Gemini may produce useful drafts. Claude still decides whether the result is publishable.

## Repository Layout

```text
gemini-delegate-skill/
├── README.md
├── README_zh-TW.md
├── scripts/
│   ├── run_gemini.sh
│   └── run_gemini.ps1
├── skills/
│   └── gemini-delegate/
│       ├── SKILL.md
│       └── references/
│           ├── wrapper.md
│           ├── delegation-targets.md
│           ├── output-contract.md
│           ├── review-checklist.md
│           ├── task-template.md
│           └── examples.md
└── tests/
    └── test_wrappers.py
```

## Testing

```bash
python -m pytest -q
```

Current wrapper tests cover:

- success-path `result.json` generation
- verification failure reporting

## Installation

**1. Install the skill** via the [`ai-research-skills` Claude Code marketplace](https://github.com/WenyuChiou/ai-research-skills):

```bash
claude plugin marketplace add WenyuChiou/ai-research-skills
claude plugin install gemini-delegate@ai-research-skills
```

Default scope is `user` (this OS account, all projects). Add `--scope project` to install only for the current project.

**2. Make sure Gemini CLI is on `$PATH`:**

```bash
npm install -g @google/gemini-cli
gemini --version
```

## License

MIT
