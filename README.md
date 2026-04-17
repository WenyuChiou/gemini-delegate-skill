# Gemini CLI Delegation Skill

> [繁體中文版](README_zh-TW.md)

A Claude skill for delegating token-heavy tasks to Google's Gemini CLI agent. Claude plans and reviews; Gemini executes.

## Features

**Task Delegation** — Non-interactive headless execution via `gemini -p` with YOLO auto-approval

**CJK Content** — Native support for Chinese/Japanese/Korean text generation, financial reports, social media posts

**Multi-File Operations** — Batch refactoring, code generation, and documentation across multiple files

**Context Piping** — Write detailed task files and pipe them to Gemini for complex multi-step work

**Cross-Platform** — Windows-specific workarounds included (cmd shell routing, UTF-8 handling)

## Setup

Gemini CLI must be installed globally:

```bash
npm install -g @anthropic-ai/gemini-cli
# or
npm install -g @anthropic-ai/gemini
```

Verify: `gemini --version` (tested with v0.36.0)

## Project Structure

```
gemini-delegate/
├── SKILL.md              # Main skill instructions
├── README.md             # English documentation
├── README_zh-TW.md       # 繁體中文文件
├── scripts/
│   └── run_gemini.ps1    # PowerShell helper for launching Gemini
└── references/
    └── examples.md       # Complete delegation examples
```

## Usage

This skill is designed for Claude (or any AI orchestrator) to read and follow. When Claude encounters a task that fits the delegation criteria, it:

1. Writes a context file describing the task
2. Launches Gemini CLI with the context
3. Reviews and validates the output
4. Reports results to the user

## Known Limitations

Gemini CLI 0.37+ occasionally exits with rc=0 even when its `write_file` tool failed mid-execution (`Error executing tool write_file: params must have required property 'file_path'`) or wrote partial / corrupted output silently. Always verify expected files exist on disk + are non-empty after `gemini` exits.

This skill's wrapper scripts include `--verify-file PATH` (and optionally `--verify-sentinel TEXT`) to do this check automatically. See [SKILL.md → "Fourth rule"](SKILL.md) for the full failure-mode discussion.

For translation tasks specifically: Gemini's output is reliably **B-grade**. Use it for first-draft generation, then have Claude do a polish pass for tone, banned words, and terminology consistency before shipping.

## License

MIT
