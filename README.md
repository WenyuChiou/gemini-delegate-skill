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

## License

MIT
