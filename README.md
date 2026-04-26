# Gemini Delegate Skill

> [繁體中文](README_zh-TW.md)

`gemini-delegate` is a Claude-oriented skill for using Gemini as a specialist for large-context synthesis, long-form drafting, English or bilingual/CJK writing, and second-opinion review.

## Positioning

This skill is not the Gemini version of `codex-delegate`.

Its job is different:

- summarize large source material into English or zh-TW
- synthesize across multiple files
- draft English, bilingual, or CJK-facing updates
- perform reviewer-style second-opinion passes on long docs
- align terminology across translated content

It is not intended for bulk code generation or architecture work.

## What Changed In This Version

- narrower scope: synthesis and CJK writing, not general execution
- clearer boundary versus Codex and Claude
- machine-readable wrapper output via `<log>.result.json`
- verification-oriented wrapper tests

## Core Pattern

1. Claude prepares a context file with source paths, output paths, language, and constraints.
2. Claude launches Gemini through the wrapper.
3. The wrapper can verify required output files after execution.
4. Claude performs factual, terminology, and tone review before shipping.

Gemini may produce useful drafts. Claude still decides whether the result is publishable.

## Repository Layout

```text
gemini-delegate-skill/
├── SKILL.md
├── README.md
├── README_zh-TW.md
├── scripts/
│   ├── run_gemini.sh
│   └── run_gemini.ps1
├── tests/
│   └── test_wrappers.py
└── references/
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

Default scope is `user` (this OS account, all projects). Add
`--scope project` to install only for the current project.

**2. Make sure Gemini CLI is on `$PATH`:**

```bash
npm install -g @google/gemini-cli
gemini --version
```

## License

MIT
