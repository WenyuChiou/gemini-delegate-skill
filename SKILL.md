---
name: gemini-delegate
description: "Delegate token-heavy tasks to Gemini CLI (Google's coding agent). Use this skill whenever Claude needs to offload bulk code generation, file refactoring, Chinese/CJK content writing, research synthesis, or any task involving 100+ lines of output. Triggers: 'use gemini', 'delegate to gemini', 'gemini cli', batch file edits, large text generation, CJK reports, or when Claude is orchestrating and needs a worker agent. Also use when the CLAUDE.md delegation rules say to route work to Gemini."
---

# Gemini CLI Delegation

Gemini CLI is a coding agent from Google, installed locally via npm. Use it as a worker agent: Claude plans, writes context, launches Gemini, and reviews output.

## When to Delegate

- **Chinese/CJK content**: financial reports, Threads posts, translations — Gemini handles 繁體中文 fluently
- **Bulk code generation**: 100+ lines of new code, boilerplate, migrations
- **Multi-file refactors**: renaming across files, pattern replacement, batch edits
- **Research synthesis**: summarizing papers, generating literature reviews
- **README / documentation**: bilingual docs, long-form technical writing
- **JS/React/frontend work**: component generation, UI code

Keep in Claude: architecture decisions, security review, multi-subsystem debugging, final approval.

## Invocation Syntax (Windows — CRITICAL)

On Windows, Gemini CLI has a quirk: passing text directly to `-p` causes a
"positional + -p conflict" error. The reliable patterns are:

```bash
# Pattern 1: Pipe prompt via echo (short prompts)
echo Your prompt here | gemini -p "" -y

# Pattern 2: Pipe context file via type (complex tasks — PREFERRED)
type C:\path\to\task.md | gemini -p "" -y

# Pattern 3: Redirect output to file (avoids UTF-8 garbling)
type task.md | gemini -p "" -y > output.md 2>&1
```

**Key rules:**
- Always use `shell: "cmd"` in Desktop Commander (PowerShell can't find gemini)
- Always use `-p ""` (empty string) when piping stdin — never `-p "actual text"`
- Always include `-y` (YOLO mode) for non-interactive auto-approval
- Set `timeout_ms: 120000` or higher — Gemini tasks take 30-120+ seconds

## Delegation Workflow

### Step 1: Write a Context File

Create a task file with everything Gemini needs. Be explicit — Gemini has no access to Claude's conversation.

```markdown
# Task: [clear title]

## Goal
[What to produce]

## Context
[Relevant background, current state, constraints]

## Files to Modify
- `path/to/file.py` — what to change and why

## Requirements
- [Specific requirements, format, style]

## Output
- Save results to [specific paths]
```

### Step 2: Launch Gemini

```bash
# cd to the working directory first, then pipe the task
cd /d C:\Users\wenyu\project && type task.md | gemini -p "" -y
```

### Step 3: Review Output

Always verify Gemini's work before reporting to the user:
1. Check that target files were actually modified on disk (not just logged)
2. Run tests or linters if applicable
3. Fix any remaining issues Claude-side

## Cross-Platform Note (Claude Code Bash vs cmd.exe)

**The code blocks in this skill use cmd.exe syntax** — because Gemini CLI on Windows requires `shell: "cmd"` (PowerShell and git-bash can't find the `gemini` binary). These are **not** for Claude Code's Bash tool.

| Operation | cmd.exe (Desktop Commander — use this) | Claude Code Bash (git-bash — do NOT use for Gemini) |
|-----------|----------------------------------------|------------------------------------------------------|
| Read file | `type file.md` | `cat file.md` |
| Change dir | `cd /d C:\path` | `cd /c/path` |
| Pipe to Gemini | `type task.md \| gemini -p "" -y` | N/A — launch via Desktop Commander |

When invoking Gemini from a Claude Code session, use the Bash tool to call Desktop Commander or write the task file, then trigger the `gemini` command via `cmd /c` — do not call `gemini` directly in Claude Code's Bash.

## Platform Notes (Windows)

| Issue | Solution |
|-------|----------|
| PowerShell can't find `gemini` | Use `shell: "cmd"` in Desktop Commander |
| `-p "text"` fails with conflict error | Use stdin pipe: `echo text \| gemini -p "" -y` |
| Chinese characters garbled in terminal | Redirect to file: `... -y > output.md 2>&1` then read file |
| Sandbox blocks file access | Don't use `--sandbox` when Gemini needs files outside CWD |
| Process hangs / too slow | Set timeout 120s+; kill stale node processes before launching |

## Known Limitations

1. **No shared context**: Gemini can't see Claude's conversation — always write a complete context file
2. **Sandbox restriction**: `--sandbox` prevents accessing files outside workspace. Skip it for cross-directory tasks
3. **Write persistence**: Verify files actually changed on disk after runs — occasionally writes don't persist
4. **Windows quoting**: Never pass prompt text directly to `-p` flag on Windows — always pipe via stdin
5. **Token cost**: Gemini is free/cheap — prefer it over Claude for bulk generation

## Task Routing Decision Tree

```
Planning / architecture / security review?  → Keep in Claude
100+ lines of code/text generation?         → Delegate to Gemini
Chinese/CJK content?                        → Delegate to Gemini
Multi-file batch edit or refactor?          → Delegate to Gemini
Otherwise?                                  → Handle in Claude
```

## Examples

See `references/examples.md` for complete delegation examples.
