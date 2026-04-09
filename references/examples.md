# Gemini Delegation Examples

All examples use bash syntax (Claude Code Bash tool = git-bash on Windows).
Never use `cd /d` or `type` — those are CMD-only. Use `cd ~/path` and `cat` instead.

## Example 1: Chinese Financial Report

**Context file** (`.ai/gemini_task_report.md`):
```markdown
# Task: Generate Weekly Americas Update (美洲更新)

## Goal
Write a ~800 word Threads post in 繁體中文 covering this week's macro developments.

## Structure
1. 本週觀察 — key observation with framework reference
2. 數據解讀 — data interpretation (hedged language, no absolutes)
3. 策略思考 — what this means for credit spread positioning
4. 下週關注 — upcoming events to watch

## Data Points
- SPY: 525→531 (+1.1%), VIX: 14.2→13.8
- 10Y yield: 4.35%→4.28%
- Fed minutes: dovish tilt, 2 cuts still priced

## Style Rules
- Use hedged language: 可能、或許、值得觀察
- Reference frameworks by name (they ARE the hook)
- No sensitive words: use 遠程武器 not 飛彈, 地緣緊張 not 戰爭
```

**Launch**:
```bash
cat .ai/gemini_task_report.md | gemini -p "" -y > .ai/gemini_result_report.md 2>&1
```

## Example 2: Multi-File Python Refactor

**Context file** (`.ai/gemini_task_refactor.md`):
```markdown
# Task: Extract Constants from Strategy Files

## Goal
Move all magic numbers from these files into strategy_constants.py:
- pipeline/allocation_engine.py
- pipeline/risk_controls.py
- pipeline/position_sizer.py

## Requirements
- Create named constants with descriptive names (e.g., MAX_POSITION_SIZE_PCT = 0.08)
- Add docstring comments explaining each constant
- Update all imports in the source files
- Don't change any logic, only extract constants

## Working Directory
~/mispricing-engine
```

**Launch** (from project directory):
```bash
cd ~/mispricing-engine && cat .ai/gemini_task_refactor.md | gemini -p "" -y
```

## Example 3: Bilingual README

```bash
cd ~/mispricing-engine && gemini -p "Read the SKILL.md in the current directory. Create README.md (English) and README_zh-TW.md (Traditional Chinese) with: language toggle link at top, Features section (5 categories), Setup instructions, Project Structure tree. Keep both versions structurally identical." -y
```

## Example 4: React Component Generation

```bash
gemini -p "Create a React component at src/components/PortfolioHeatmap.jsx that displays a heatmap of ETF returns. Props: data (array of {ticker, return_1d, return_1w, return_1m}). Use Tailwind for styling. Include color scale from red (-5%) through white (0%) to green (+5%). Add a tooltip on hover showing exact values." -y
```
