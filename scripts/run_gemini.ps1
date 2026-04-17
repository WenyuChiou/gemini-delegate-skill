param(
    [Parameter(Mandatory=$true)][string]$Prompt,
    [string]$Repo = "C:\Users\wenyu\mispricing-engine",
    [string]$Model = "gemini-2.5-pro",
    [string]$LogFile = "",
    [string[]]$VerifyFile = @(),
    [string]$VerifySentinel = ""
)

$ErrorActionPreference = "Stop"

# UTF-8 encoding setup — required for Chinese/CJK characters in prompts and output
[Console]::InputEncoding  = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding           = [System.Text.Encoding]::UTF8
$env:PYTHONIOENCODING     = "utf-8"
chcp 65001 | Out-Null

$logPath      = if ($LogFile) { $LogFile } else { "$Repo\.ai\gemini_output.txt" }
$donePath     = "$logPath.done"
$errorPath    = "$logPath.error"
$fallbackPath = "$logPath.fallback_claude"

# Ensure .ai directory exists
$aiDir = Join-Path $Repo ".ai"
if (!(Test-Path $aiDir)) { New-Item -ItemType Directory -Path $aiDir -Force | Out-Null }

# Clean up stale sentinel files from previous runs
Remove-Item $fallbackPath -ErrorAction SilentlyContinue
Remove-Item $donePath     -ErrorAction SilentlyContinue
Remove-Item $errorPath    -ErrorAction SilentlyContinue

# ── Quota / rate-limit detection ──────────────────────────────────────────────
function Test-QuotaError {
    param([string]$output, [int]$exitCode)
    if ($exitCode -eq 429) { return $true }
    $patterns = @(
        "quota exceeded", "rate limit", "rate_limit", "quota_exceeded",
        "insufficient_quota", "too many requests", "RateLimitError",
        "exceeded your current quota", "RESOURCE_EXHAUSTED", "429"
    )
    foreach ($p in $patterns) {
        if ($output -ilike "*$p*") { return $true }
    }
    return $false
}

# ── Run Gemini ────────────────────────────────────────────────────────────────
# Three critical rules for non-interactive Gemini CLI runs:
#   1. Gemini CLI has NO `-C <dir>` flag (that is Codex CLI syntax). Must
#      Push-Location into the target workspace so Gemini's sandbox allows
#      writes there.
#   2. Must pass `--approval-mode yolo`. Default mode prompts for approval
#      per tool call; in non-interactive mode those calls are silently
#      skipped and Gemini falls back to emitting write_file() as pseudo-code
#      comments instead of actually writing files.
#   3. Pipe the prompt via stdin, not as a positional arg — positional args
#      hit the ~32 KB Windows command-line length limit for large briefs.

$promptFile = "$env:TEMP\gemini_prompt_$(Get-Random).txt"
$Prompt | Out-File -FilePath $promptFile -Encoding utf8NoBOM

try {
    Push-Location $Repo
    try {
        $output   = Get-Content $promptFile -Raw -Encoding utf8 | & gemini -m $Model --approval-mode yolo 2>&1 | Out-String
        $exitCode = $LASTEXITCODE
    } finally {
        Pop-Location
        Remove-Item $promptFile -ErrorAction SilentlyContinue
    }

    if (Test-QuotaError -output $output -exitCode $exitCode) {
        Write-Warning "Gemini quota/rate-limit exceeded — creating .fallback_claude sentinel for Claude to handle"
        "[GEMINI QUOTA EXCEEDED at $(Get-Date -Format o)]`n$output" | Out-File $logPath -Encoding utf8
        "ALL_QUOTA_EXCEEDED|$(Get-Date -Format o)"  | Out-File $errorPath    -Encoding utf8
        "FALLBACK_TO_CLAUDE|$(Get-Date -Format o)"  | Out-File $fallbackPath -Encoding utf8
        "FALLBACK|$(Get-Date -Format o)"            | Out-File $donePath     -Encoding utf8
        exit 0
    }

    # Success — but FIRST verify expected files exist on disk
    # (Gemini sometimes exits 0 even when write_file calls failed mid-execution
    #  due to internal tool-schema bugs. See SKILL.md "Fourth rule".)
    if ($VerifyFile.Count -gt 0) {
        $verifyFail = $false
        foreach ($f in $VerifyFile) {
            if (!(Test-Path $f) -or (Get-Item $f).Length -eq 0) {
                Write-Warning "VERIFICATION FAILED: $f missing or empty"
                $verifyFail = $true
                continue
            }
            if ($VerifySentinel) {
                $content = Get-Content $f -Raw -Encoding utf8
                if ($content -notlike "*$VerifySentinel*") {
                    Write-Warning "VERIFICATION FAILED: $f missing sentinel '$VerifySentinel'"
                    $verifyFail = $true
                }
            }
        }
        if ($verifyFail) {
            "[VERIFICATION FAILED at $(Get-Date -Format o)]`n[MODEL_USED: gemini/$Model]`n$output" | Out-File $logPath -Encoding utf8
            "VERIFY_FAILED|gemini/$Model|$(Get-Date -Format o)" | Out-File $errorPath -Encoding utf8
            exit 1
        }
        Write-Host "Verified $($VerifyFile.Count) file(s) exist + non-empty$(if ($VerifySentinel) { ' + contain sentinel' })."
    }

    # Success — log model used
    "[MODEL_USED: gemini/$Model]`n$output" | Out-File $logPath -Encoding utf8
    "DONE|gemini/$Model|$(Get-Date -Format o)" | Out-File $donePath -Encoding utf8

} catch {
    $errMsg = $_.Exception.Message

    if (Test-QuotaError -output $errMsg -exitCode 0) {
        Write-Warning "Gemini exception looks like quota error: $errMsg"
        "[GEMINI QUOTA EXCEPTION at $(Get-Date -Format o)]`n$errMsg" | Out-File $logPath -Encoding utf8
        "ALL_QUOTA_EXCEEDED|$(Get-Date -Format o)"  | Out-File $errorPath    -Encoding utf8
        "FALLBACK_TO_CLAUDE|$(Get-Date -Format o)"  | Out-File $fallbackPath -Encoding utf8
        "FALLBACK|$(Get-Date -Format o)"            | Out-File $donePath     -Encoding utf8
        exit 0
    }

    # Hard failure (not quota-related)
    $errMsg | Out-File $errorPath -Encoding utf8
    exit 1
}
