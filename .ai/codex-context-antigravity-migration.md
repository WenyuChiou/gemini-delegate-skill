# Codex Task: Migrate gemini-delegate-skill to support Antigravity CLI (`agy`)

## Background

Google deprecated Gemini CLI for free/Pro/Ultra individual users on 2026-06-18.
The replacement is **Antigravity CLI** (`agy`), a Go-based rewrite.

- Enterprise/Cloud users still have `gemini` access
- Free/individual users MUST use `agy`
- `gemini` v0.42.0 is still on PATH but returns `IneligibleTierError` for free tier

### Key `agy` vs `gemini` differences

| Feature | `gemini` (legacy) | `agy` (new) |
|---|---|---|
| Binary | `gemini` | `agy` |
| Language | Node.js/TypeScript | Go (single binary) |
| Config file | `GEMINI.md` | `AGENTS.md` |
| Approval mode | `--approval-mode yolo` | `--yolo` flag |
| Model flag | `-m <model>` | `-m <model>` (same) |
| Stdin pipe | `< promptfile` | `cat promptfile \| agy -m model --yolo -` (append `-` to read stdin) |
| `-C` flag | Does NOT exist | Does NOT exist |

## Strategy: Dual-backend support

The wrappers should auto-detect which binary is available. Priority order:
1. If `$AGY_PATH` env var is set → use it
2. If `$GEMINI_PATH` env var is set → use it
3. If `agy` is on PATH → use it
4. If `gemini` is on PATH → use it
5. Neither → error with install instructions for both

This keeps backward compatibility for enterprise users on `gemini` while working for free users who migrated to `agy`.

## Files to modify (14 files total)

### 1. `scripts/run_gemini.sh` (168 lines → ~190 lines)

**Changes:**
- Add `AGY_PATH` env var support alongside `GEMINI_PATH`
- Add auto-detection function `resolve_backend()` that checks: `$AGY_PATH` → `$GEMINI_PATH` → `agy` on PATH → `gemini` on PATH
- Store detected backend name in `$BACKEND_NAME` variable ("agy" or "gemini")
- For `agy`: stdin pattern is `cat "$PROMPT_FILE" | "$BACKEND_BIN" -m "$MODEL" --yolo - 2>&1`
- For `gemini`: keep existing pattern `"$BACKEND_BIN" -m "$MODEL" --approval-mode yolo < "$PROMPT_FILE" 2>&1`
- Update `write_result_json` to use `$BACKEND_NAME` in the `delegate` and `model` fields
- Update all log messages to use `$BACKEND_NAME` instead of hardcoded "Gemini"
- Keep all existing features: quota detection, verify-file, sentinels, result.json

**New function to add (insert after the `json_escape` function):**
```bash
resolve_backend() {
    if [[ -n "${AGY_PATH:-}" ]] && command -v "$AGY_PATH" >/dev/null 2>&1; then
        BACKEND_BIN="$AGY_PATH"
        BACKEND_NAME="agy"
        return 0
    fi
    if [[ -n "${GEMINI_PATH:-}" ]] && command -v "$GEMINI_PATH" >/dev/null 2>&1; then
        BACKEND_BIN="$GEMINI_PATH"
        BACKEND_NAME="gemini"
        return 0
    fi
    if command -v agy >/dev/null 2>&1; then
        BACKEND_BIN="agy"
        BACKEND_NAME="agy"
        return 0
    fi
    if command -v gemini >/dev/null 2>&1; then
        BACKEND_BIN="gemini"
        BACKEND_NAME="gemini"
        return 0
    fi
    echo "Error: neither 'agy' (Antigravity CLI) nor 'gemini' (Gemini CLI) found on PATH." >&2
    echo "Install Antigravity CLI: curl -fsSL https://antigravity.google/cli/install.sh | bash" >&2
    echo "Or set AGY_PATH or GEMINI_PATH environment variable." >&2
    exit 1
}
```

**Invocation logic change (replace the existing gemini invocation block):**
```bash
resolve_backend

pushd "$REPO" > /dev/null
if [[ "$BACKEND_NAME" == "agy" ]]; then
    OUTPUT=$(cat "$PROMPT_FILE" | "$BACKEND_BIN" -m "$MODEL" --yolo - 2>&1) || EXIT_CODE=$?
else
    OUTPUT=$("$BACKEND_BIN" -m "$MODEL" --approval-mode yolo < "$PROMPT_FILE" 2>&1) || EXIT_CODE=$?
fi
popd > /dev/null
```

**Update all occurrences of:** `"gemini/$MODEL"` → `"$BACKEND_NAME/$MODEL"` in write_result_json calls and log outputs.

**Remove:** the old `GEMINI_BIN="${GEMINI_PATH:-gemini}"` line (replaced by resolve_backend).

### 2. `scripts/run_gemini.ps1` (150 lines → ~170 lines)

**Changes (mirror bash wrapper):**
- Add `$env:AGY_PATH` support
- Add `Resolve-Backend` function with same priority: `$env:AGY_PATH` → `$env:GEMINI_PATH` → `agy` on PATH → `gemini` on PATH
- Branch invocation: `agy` uses `Get-Content $promptFile -Raw -Encoding utf8 | & $backendBin -m $Model --yolo - 2>&1 | Out-String` vs gemini's existing pattern
- Update all `"gemini/$Model"` references to `"$backendName/$Model"`
- Update warning/error messages to use `$backendName`
- Keep all existing features intact

**New function:**
```powershell
function Resolve-Backend {
    if ($env:AGY_PATH -and (Get-Command $env:AGY_PATH -ErrorAction SilentlyContinue)) {
        return @{ Bin = $env:AGY_PATH; Name = "agy" }
    }
    if ($env:GEMINI_PATH -and (Get-Command $env:GEMINI_PATH -ErrorAction SilentlyContinue)) {
        return @{ Bin = $env:GEMINI_PATH; Name = "gemini" }
    }
    if (Get-Command "agy" -ErrorAction SilentlyContinue) {
        return @{ Bin = "agy"; Name = "agy" }
    }
    if (Get-Command "gemini" -ErrorAction SilentlyContinue) {
        return @{ Bin = "gemini"; Name = "gemini" }
    }
    throw "Neither 'agy' (Antigravity CLI) nor 'gemini' (Gemini CLI) found. Install: https://antigravity.google/cli/install.sh"
}
```

### 3. `skills/gemini-delegate/SKILL.md` (152 lines)

**Changes:**
- Update description frontmatter: add "or Google Antigravity CLI (`agy`)" 
- Update "Prerequisite check" section: check for `agy` first, then `gemini`. If neither found, give install instructions for Antigravity CLI (preferred) and legacy Gemini CLI (enterprise only)
- Update "Hard rules" section: rule 2 changes from "`--approval-mode yolo`" to "use `--yolo` (agy) or `--approval-mode yolo` (gemini). The wrapper handles this automatically."
- Update "Compatibility" section at the bottom: add Antigravity CLI info, note the `agy` command and `--yolo` flag
- Update CLAUDE.md snippet: update the canonical command patterns to show both backends
- Update "Workflow" step 2: the wrapper command stays the same (it auto-detects)
- Add a brief "Migration from Gemini CLI" subsection explaining dual-backend
- Keep all anti-pattern documentation (F1, F13, F14) — these still apply to both backends

### 4. `skills/gemini-delegate/references/wrapper.md` (58 lines)

**Changes:**
- Update "What the wrapper enforces" section: rule 2 → "The wrapper uses `--yolo` for agy or `--approval-mode yolo` for gemini automatically."
- Add `AGY_PATH` to environment variables section
- Add note that wrapper auto-detects backend with priority: `AGY_PATH` → `GEMINI_PATH` → `agy` → `gemini`
- Invocation examples stay the same (wrapper is backend-agnostic)

### 5. `skills/gemini-delegate/references/examples.md` (144 lines)

**Changes:**
- Add a note at the top: "The wrapper auto-detects `agy` (Antigravity CLI) or `gemini` (legacy). Examples show wrapper invocations which work with either backend."
- Update the "Raw invocation" section at the bottom to show BOTH patterns:
  - `agy`: `cat .ai/gemini_task_summary.md | agy -m gemini-2.5-pro --yolo - > .ai/gemini_log.txt 2>&1`
  - `gemini`: `gemini --approval-mode yolo < .ai/gemini_task_summary.md > .ai/gemini_log.txt 2>&1`
- No changes needed to wrapper-based examples (they're backend-agnostic)

### 6. `skills/gemini-delegate/references/output-contract.md` (50 lines)

**Changes:**
- Update `delegate` field documentation: now `"agy"` or `"gemini"` depending on detected backend
- Update `model` field: now `"agy/<model>"` or `"gemini/<model>"`
- Add note: consumers should check `delegate` field to know which backend was used

### 7. `skills/gemini-delegate/references/delegation-targets.md` (30 lines)

**Changes:**
- Update routing table: `Gemini` → `Gemini / Antigravity CLI`

### 8. `skills/gemini-delegate/references/task-template.md` (48 lines)

**No changes needed.** Task briefs are backend-agnostic.

### 9. `skills/gemini-delegate/references/review-checklist.md` (39 lines)

**No changes needed.** Review concerns apply to both backends.

### 10. `skills/gemini-delegate/references/multi-agent.md` (53 lines)

**Changes:**
- One-line update: mention that the leaf uses `agy` or `gemini` (auto-detected by wrapper)

### 11. `tests/test_wrappers.py` (151 lines)

**Add two new test functions:**

**Test: bash wrapper with AGY_PATH**
```python
@pytest.mark.skipif(_BASH is None, reason="bash not available")
def test_run_gemini_sh_agy_backend(tmp_path: Path) -> None:
    """Wrapper uses AGY_PATH when set, delegate field says 'agy'."""
    repo = tmp_path / "repo"
    repo.mkdir()
    fake_agy = tmp_path / "fake_agy.sh"
    fake_agy.write_text("#!/usr/bin/env bash\necho 'agy ok'\n", encoding="utf-8", newline="\n")
    if sys.platform != "win32":
        os.chmod(fake_agy, 0o755)
    log_file = repo / ".ai" / "agy_log.txt"
    env = os.environ.copy()
    env["AGY_PATH"] = to_bash_path(fake_agy)
    env.pop("GEMINI_PATH", None)
    proc = subprocess.run(
        [_BASH, "-lc",
         f"chmod +x '{to_bash_path(fake_agy)}' && "
         f"AGY_PATH='{to_bash_path(fake_agy)}' "
         f"'{to_bash_path(Path(_BASH))}' '{to_bash_path(ROOT / 'scripts' / 'run_gemini.sh')}' "
         f"--prompt 'test agy' --repo '{to_bash_path(repo)}' --log-file '{to_bash_path(log_file)}'"],
        capture_output=True, text=True, env=env, check=False)
    assert proc.returncode == 0, proc.stderr
    result = json.loads(log_file.with_suffix(log_file.suffix + ".result.json").read_text(encoding="utf-8-sig"))
    assert result["status"] == "success"
    assert result["delegate"] == "agy"
    assert result["model"].startswith("agy/")
```

**Test: PowerShell wrapper with AGY_PATH**
```python
@pytest.mark.skipif(shutil.which("powershell") is None, reason="powershell not on PATH")
def test_run_gemini_ps1_agy_backend(tmp_path: Path) -> None:
    """PowerShell wrapper uses AGY_PATH, delegate field says 'agy'."""
    repo = tmp_path / "repo"
    repo.mkdir()
    fake_agy = tmp_path / "agy.cmd"
    fake_agy.write_text("@echo off\r\necho agy ok\r\n", encoding="utf-8")
    log_file = repo / ".ai" / "agy_ps_log.txt"
    env = os.environ.copy()
    env["AGY_PATH"] = str(fake_agy)
    env.pop("GEMINI_PATH", None)
    proc = subprocess.run(
        ["powershell", "-ExecutionPolicy", "Bypass", "-File",
         str(ROOT / "scripts" / "run_gemini.ps1"),
         "-Prompt", "test agy", "-Repo", str(repo), "-LogFile", str(log_file)],
        capture_output=True, text=True, env=env, check=False)
    assert proc.returncode == 0, proc.stderr
    result = json.loads(log_file.with_suffix(log_file.suffix + ".result.json").read_text(encoding="utf-8-sig"))
    assert result["status"] == "success"
    assert result["delegate"] == "agy"
```

**Also update existing tests:** verify `delegate` field is `"gemini"` when using `GEMINI_PATH` (already implicitly tested but make it explicit with an assert).

### 12. `README.md` (108 lines)

**Changes:**
- Add after the title: "> Now supports both **Antigravity CLI** (`agy`) and legacy **Gemini CLI**."
- Update "Installation" step 2: show `agy` install first (preferred), `gemini` as enterprise fallback
- Add a "Migration from Gemini CLI" section (3-4 lines: wrapper auto-detects, set `AGY_PATH` to override)
- Update prerequisite check commands

### 13. `README_zh-TW.md` (108 lines)

**Mirror all README.md changes in Traditional Chinese.** Key translations:
- "Antigravity CLI" → keep as-is (technical name)
- "auto-detects" → 自動偵測
- "dual-backend" → 雙後端
- "deprecated" → 已棄用
- "enterprise" → 企業版

### 14. `.claude-plugin/plugin.json` (18 lines)

**Replace entire file with:**
```json
{
  "name": "gemini-delegate",
  "description": "Hand long-context reading, bilingual rewrites, second-opinion review, and Traditional Chinese / CJK output from Claude to Antigravity CLI (agy) or legacy Gemini CLI.",
  "version": "0.2.0",
  "author": {
    "name": "Wenyu Chiou"
  },
  "homepage": "https://github.com/WenyuChiou/gemini-delegate-skill",
  "repository": "https://github.com/WenyuChiou/gemini-delegate-skill",
  "license": "MIT",
  "keywords": [
    "gemini",
    "antigravity",
    "agy",
    "delegation",
    "multi-ai",
    "long-context",
    "cjk"
  ]
}
```

### 15. `.github/workflows/test.yml` (26 lines)

**No changes needed.** Tests use fake binaries via env vars; CI doesn't need real `agy` or `gemini`.

## Verification steps (MUST run after all changes)

1. `cd C:\Users\wenyu\Desktop\gemini-delegate-skill && python -m pytest tests/ -q` — all tests pass (existing + new)
2. Check `scripts/run_gemini.sh` has no bash syntax errors: `bash -n scripts/run_gemini.sh`
3. Grep check: no hardcoded `"gemini"` remains in result.json delegate/model writes in wrappers — should all use variable
4. Grep check: `AGY_PATH` appears in both `run_gemini.sh` and `run_gemini.ps1`
5. Verify `plugin.json` version is `"0.2.0"`
6. Verify both READMEs mention Antigravity CLI

## Commit message

```
feat: add Antigravity CLI (agy) dual-backend support

Gemini CLI was deprecated for free/Pro/Ultra users on 2026-06-18.
The wrapper now auto-detects agy (Antigravity CLI) or gemini (legacy),
with AGY_PATH taking priority over GEMINI_PATH.

- Dual-backend resolution in both bash and PowerShell wrappers
- result.json delegate field reflects actual backend used
- New tests for agy backend path
- Updated docs, README (EN + zh-TW), and plugin.json (v0.2.0)
- Backward compatible: enterprise users on gemini unaffected
```

## What NOT to change

- Do NOT rename the skill from `gemini-delegate` — the name is established (37★, referenced everywhere)
- Do NOT remove `gemini` support — enterprise users still need it
- Do NOT change wrapper file names (`run_gemini.sh`, `run_gemini.ps1`) — referenced in user configs
- Do NOT change `.ai/gemini_task_*.md` brief naming convention — backward compat
- Do NOT add agy-specific features (subagents, sandbox config) — out of scope
- Do NOT change the `--repo` default behavior or any existing CLI flag semantics
