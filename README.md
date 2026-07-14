# Gemini Delegate Skill

> **Status (2026-07): legacy lane, gemini backend fails closed.** The
> legacy Gemini CLI path is deprecated since 2026-06-18 — Google removed
> consumer/individual-tier CLI auth, after which the non-interactive CLI
> silently emits pseudo-code instead of doing the work; the wrapper now
> refuses to run it (override: `GEMINI_DEPRECATED_OVERRIDE=1`). The `agy`
> (Antigravity CLI) backend still works here, but the maintained,
> evidence-backed Antigravity lane is
> [**antigravity-delegate**](https://github.com/WenyuChiou/antigravity-delegate)
> (promoted 2026-07-11 on a pre-registered k=5 reliability gate). This repo
> is kept as lesson material and for the agy-via-gemini-delegate history.
>
> [Traditional Chinese](README_zh-TW.md)

`gemini-delegate` is a Claude-oriented skill for using Google Antigravity CLI (`agy`) or legacy Gemini CLI as a specialist for large-context synthesis, long-form drafting, English or bilingual / CJK writing, and second-opinion review.

> Part of the [**agentic AI learning roadmap**](https://github.com/WenyuChiou/awesome-agentic-ai-zh), a 7-stage curated path for building agentic AI, multilingual (zh-TW, zh-CN, English). This skill is referenced in Lesson 13 (Multi-LLM Delegation).

## Why this exists

Claude has a finite working context, and certain tasks are a bad fit even when Claude could technically do them. Two failure modes are common:

- **Long-form input does not fit cleanly.** When you need to summarize, compare, or rewrite content that spans many large source files, Gemini's larger context window lets it ingest the whole picture at once instead of forcing Claude to chunk and stitch.
- **CJK / bilingual writing is uneven.** For long-form Traditional Chinese or English/Chinese rewriting, Gemini often produces more natural cadence than Claude. This is a community observation, not an official benchmark, but it shows up enough that it is worth structuring around.

Routing those tasks to `agy` or legacy Gemini lets Claude stay in its strengths (judgment, terminology review, factual checking) and lets the delegate do what it is best at (large-context synthesis and CJK drafting).

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
2. Claude launches the wrapper, which auto-detects `agy` or legacy `gemini`.
3. The wrapper can verify required output files after execution.
4. Claude performs factual, terminology, and tone review before shipping.

The delegate may produce useful drafts. Claude still decides whether the result is publishable.

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
python -m pytest tests/ -q
```

Current wrapper tests cover:

- success-path `result.json` generation
- verification failure reporting
- `AGY_PATH` and `GEMINI_PATH` backend selection

## Installation

**1. Install the skill** via the [`ai-research-skills` Claude Code marketplace](https://github.com/WenyuChiou/ai-research-skills):

```bash
claude plugin marketplace add WenyuChiou/ai-research-skills
claude plugin install gemini-delegate@ai-research-skills
```

Default scope is `user` (this OS account, all projects). Add `--scope project` to install only for the current project.

**2. Install a supported backend. Antigravity CLI (`agy`) is preferred:**

```bash
curl -fsSL https://antigravity.google/cli/install.sh | bash
agy --version
```

The legacy Gemini CLI fallback is **fail-closed since 2026-06-18**: the
wrapper refuses to invoke a `gemini` backend and exits 1, because the
killed consumer tier makes the non-interactive CLI silently emit
pseudo-code. Enterprise/Cloud users who have verified their tier still
works must opt in explicitly:

```bash
npm install -g @google/gemini-cli
gemini --version
GEMINI_DEPRECATED_OVERRIDE=1 bash scripts/run_gemini.sh --prompt "..."
```

You can also point the wrapper at explicit binaries:

```bash
export AGY_PATH=/path/to/agy
export GEMINI_PATH=/path/to/gemini
```

Detection order is `AGY_PATH`, `GEMINI_PATH`, `agy` on PATH, then `gemini` on PATH.

## Migration from Gemini CLI

Gemini CLI was deprecated for free/Pro/Ultra individual users on 2026-06-18. The wrapper auto-detects `agy` first; the legacy Gemini CLI path is fail-closed (FATAL + exit 1) and requires an explicit `GEMINI_DEPRECATED_OVERRIDE=1` from enterprise users who have verified their tier still works. Existing wrapper commands, file names, and `.ai/gemini_task_*.md` task brief conventions do not change. Set `AGY_PATH` to force a specific Antigravity CLI binary.

## License

MIT
