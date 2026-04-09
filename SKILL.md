---
name: gemini-delegate
description: "Delegate token-heavy tasks to Gemini CLI (Google's coding agent). Use this skill whenever Claude needs to offload bulk code generation, file refactoring, Chinese/CJK content writing, research synthesis, or any task involving 100+ lines of output. Triggers: 'use gemini', 'delegate to gemini', 'gemini cli', batch file edits, large text generation, CJK reports, or when Claude is orchestrating and needs a worker agent. Also use when the CLAUDE.md delegation rules say to route work to Gemini."
---

# Gemini CLI Delegation

Gemini CLI is a coding agent from Google, installed locally via npm. Use it as a worker agent: Claude plans, writes context, launches Gemini, and reviews output.

---

## ⚠️ SHELL COMPATIBILITY — READ THIS FIRST

**Claude Code's Bash tool = git-bash (Unix shell) on Windows. It is NOT cmd.exe and NOT PowerShell.**

**NEVER use CMD syntax in Bash tool calls:**

| Task | ✅ Bash (Claude Code) | ❌ CMD (NEVER in Bash) |
|------|----------------------|----------------------|
| Change directory | `cd ~/project` | `cd /d C:\project` |
| Read a file | `cat file.md` | `type file.md` |
| List files | `ls` | `dir` |
| Path separator | `/` forward slash | `\` backslash |

**`cd /d` is CMD-only. In bash it fails: `bash: cd: /d: No such file or directory`.**
**`type file.md` is CMD-only. In bash use `cat file.md`.**

### Gemini PATH in git-bash
Gemini CLI is installed via npm. If `gemini` is not found in git-bash, try:
```bash
# Check if gemini is in PATH
which gemini 2>/dev/null || echo "not found"

# If not found, use the full npm path
/c/Users/wenyu/AppData/Roaming/npm/gemini -p "" -y
```

If gemini still can't be reached from git-bash, use Desktop Commander MCP with `shell: "cmd"` as a fallback (see Desktop Commander section below).

> Desktop Commander MCP users: use `shell: "cmd"` + `cd /d` in that specific context.
> Claude Code Bash tool users: always use Unix syntax; use full path if needed.

---

## When to Delegate

- **Chinese/CJK content**: financial reports, Threads posts, translations — Gemini handles 繁體中文 fluently
- **Bulk code generation**: 100+ lines of new code, boilerplate, migrations
- **Multi-file refactors**: renaming across files, pattern replacement, batch edits
- **Research synthesis**: summarizing papers, generating literature reviews
- **README / documentation**: bilingual docs, long-form technical writing
- **JS/React/frontend work**: component generation, UI code

Keep in Claude: architecture decisions, security review, multi-subsystem debugging, final approval.

## Invocation Syntax (Claude Code Bash — PREFERRED)

On Windows, Gemini CLI has a quirk: passing text directly to `-p` causes a
"positional + -p conflict" error. The reliable patterns are:

```bash
# Pattern 1: Pipe prompt via echo (short prompts)
echo "Your prompt here" | gemini -p "" -y

# Pattern 2: Pipe context file via cat (complex tasks — PREFERRED)
cat .ai/task.md | gemini -p "" -y

# Pattern 3: From a specific directory with output capture
cd ~/mispricing-engine && cat .ai/task.md | gemini -p "" -y > .ai/output.md 2>&1

# Pattern 4: Full path (no cd needed)
cat ~/mispricing-engine/.ai/task.md | gemini -p "" -y > ~/mispricing-engine/.ai/output.md 2>&1
```

**Key rules (bash):**
- Always use `-p ""` (empty string) when piping stdin — never `-p "actual text"` on Windows
- Always include `-y` (YOLO mode) for non-interactive auto-approval
- Use `cat` to read files — never `type`
- Use `cd ~/path` or full Unix paths — never `cd /d C:\path`
- Redirect output to a file if capturing CJK content (avoids terminal garbling)

### Desktop Commander MCP (cmd shell — fallback only)
If `gemini` is not accessible from git-bash, use Desktop Commander MCP with cmd shell:
```
shell: "cmd"
cd /d C:\Users\wenyu\project && type task.md | gemini -p "" -y
```

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

Save to `.ai/gemini_task_<name>.md`.

### Step 2: Launch Gemini (from Claude Code Bash)

```bash
cat .ai/gemini_task_<name>.md | gemini -p "" -y
```

With output captured to file:
```bash
cat .ai/gemini_task_<name>.md | gemini -p "" -y > .ai/gemini_result_<name>.md 2>&1
```

### Step 3: Review Output

Always verify Gemini's work before reporting to the user:
1. Check that target files were actually modified on disk (not just logged)
2. Run tests or linters if applicable
3. Fix any remaining issues Claude-side

## Platform Notes

| Issue | Bash solution | Desktop Commander solution |
|-------|--------------|---------------------------|
| `gemini` not found in git-bash | Use full npm path: `/c/Users/wenyu/AppData/Roaming/npm/gemini` | Use `shell: "cmd"` |
| `-p "text"` fails | Use stdin pipe: `echo "text" \| gemini -p "" -y` | Same |
| Chinese chars garbled | Redirect to file: `... -y > output.md 2>&1` then read file | Same |
| Sandbox blocks file access | Don't use `--sandbox` when Gemini needs files outside CWD | Same |
| Process hangs / too slow | Kill stale node processes; set timeout 120s+ | Same |

## Known Limitations

1. **No shared context**: Gemini can't see Claude's conversation — always write a complete context file
2. **Write persistence**: Verify files actually changed on disk after runs — occasionally writes don't persist
3. **Windows quoting**: Never pass prompt text directly to `-p` flag on Windows — always pipe via stdin
4. **Token cost**: Gemini is free/cheap — prefer it over Claude for bulk generation

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
