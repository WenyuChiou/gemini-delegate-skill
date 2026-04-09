---
name: gemini-delegate
description: "Delegate CJK/Chinese content tasks to Gemini CLI. Use this skill for writing Chinese reports, Threads posts (美洲更新), comments, translations, and any task requiring native-quality Traditional Chinese output. Gemini handles the content generation while Claude plans, reviews, and integrates."
---

# Gemini Delegate Skill

You are Claude acting as a **supervisor**. You plan, evaluate, and review. Gemini does the CJK/Chinese writing.

## ⛔ CRITICAL: Shell Compatibility (READ FIRST)

**Claude Code's Bash tool runs git-bash (Unix shell) on Windows — NOT cmd.exe, NOT PowerShell.**

### NEVER use these CMD-only commands in Bash:
| ❌ BANNED (cmd.exe only) | ✅ Use instead (bash) |
|--------------------------|----------------------|
| `cd /d C:\path` | `cd /c/Users/wenyu/path` or `cd "$HOME/path"` |
| `type file.txt` | `cat file.txt` |
| `dir` | `ls` |
| `copy src dst` | `cp src dst` |
| `del file` | `rm file` |
| `md dir` | `mkdir -p dir` |
| `set VAR=value` | `export VAR=value` |
| `%VAR%` | `$VAR` or `${VAR}` |
| `ren old new` | `mv old new` |
| `cls` | `clear` |

### Path format in Bash
- Windows: `C:\Users\wenyu\mispricing-engine` → Bash: `/c/Users/wenyu/mispricing-engine` or `~/mispricing-engine`
- **NEVER** use backslashes `\` in bash paths — always use forward slashes `/`
- **NEVER** use `cd /d` — this is CMD syntax and WILL fail in bash

### When to use PowerShell
Only use PowerShell syntax (with `powershell` code fence) when calling `.ps1` scripts directly via Desktop Commander or Windows-MCP. All other code blocks in this skill use Unix bash.

## When to Delegate to Gemini

### Delegate to Gemini (good for)
- Traditional Chinese content (reports, analyses, social media posts)
- 美洲更新 (Americas Update) weekly Threads series
- CJK translation with domain-specific terminology
- Chinese-language summaries of English analysis
- Any content requiring native-quality Chinese output
- Long-form Chinese writing (>200 characters)

### Keep in Claude (bad for Gemini)
- Architecture decisions, code review, debugging
- English-only content
- Tasks requiring conversation history or memory context
- Security-sensitive operations
- Multi-step workflows with complex dependencies
- Code generation (Gemini's coding is weaker)

## Core Workflow: Context File Pattern

### Step 1: Claude writes the context file
Save to `.ai/gemini_task_<name>.md` in the repo:

```markdown
# Task: <descriptive name>

## Context
- Repo: ~/mispricing-engine
- Key files to read: <list paths>
- Output file: <where to write result>

## Language
- Output language: Traditional Chinese (繁體中文)
- Tone: <formal/casual/hedged-framework-driven>
- Audience: <target audience>

## Instructions
<Clear, step-by-step instructions in English or Chinese>

## Constraints
- Do not modify files outside the listed paths
- Follow existing terminology conventions
- Use hedged language for market predictions (per feedback_threads_tone)

## Output
- Save output to <path>
```

### Step 2: Launch Gemini (synchronous, from Claude Code Bash)
```bash
# Direct synchronous call
bash .claude/skills/gemini-delegate/scripts/run_gemini.sh \
  --prompt "Read .ai/gemini_task_<name>.md and execute all instructions inside." \
  --log-file .ai/gemini_log_<name>.txt
```

Or call the PowerShell script directly:
```powershell
# From PowerShell only (NOT from Claude Code Bash)
& "C:\Users\wenyu\mispricing-engine\.claude\skills\gemini-delegate\scripts\run_gemini.ps1" `
    -Prompt "Read .ai/gemini_task_<name>.md and execute all instructions." `
    -LogFile "C:\Users\wenyu\mispricing-engine\.ai\gemini_log_<name>.txt"
```

### Step 3: Check result
```bash
# Check for fallback sentinel first
if [ -f ".ai/gemini_log_<name>.txt.fallback_claude" ]; then
    echo "Quota exceeded — doing task myself"
elif [ -f ".ai/gemini_log_<name>.txt.done" ]; then
    cat ".ai/gemini_log_<name>.txt"
fi
```

### Step 4: Claude reviews
- Read the output
- Check Chinese quality (terminology, tone, accuracy)
- Verify sensitive word replacements (per feedback_thread_sensitive_words)
- If 80%+ correct: fix remaining issues directly
- If fundamentally wrong: rewrite context file and re-run

## Script Parameters

### run_gemini.sh
| Parameter | Default | Description |
|-----------|---------|-------------|
| `--prompt` | (required) | Task prompt |
| `--repo` | `~/mispricing-engine` | Working directory |
| `--model` | `gemini-2.5-pro` | Gemini model |
| `--log-file` | `<repo>/.ai/gemini_output.txt` | Log file path |

### run_gemini.ps1
| Parameter | Default | Description |
|-----------|---------|-------------|
| `-Prompt` | (required) | Task prompt |
| `-Repo` | `C:\Users\wenyu\mispricing-engine` | Working directory |
| `-Model` | `gemini-2.5-pro` | Gemini model |
| `-LogFile` | `<Repo>\.ai\gemini_output.txt` | Log file path |

## Sensitive Word Replacements (Threads v4)

When generating Threads posts, apply these replacements:
- Check `feedback_thread_sensitive_words` memory for current list
- Common replacements: avoid absolute predictions, use hedged framework-driven language
- Never use "一定", "保證", "必然" — use "可能", "傾向", "框架顯示"

## Important Caveats

- Gemini has NO persistent memory — always give full context via file paths
- Gemini cannot read conversation history — summarize decisions in the context file
- Gemini's coding ability is weaker than Claude/Codex — do NOT delegate code tasks
- Always verify Gemini output for factual accuracy before publishing
- The `.ai/` directory is gitignored — safe for task files and logs
- If `.fallback_claude` sentinel appears, do the task yourself immediately
