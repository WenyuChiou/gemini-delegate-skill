param(
    [Parameter(Mandatory=$true)][string]$Prompt,
    [string]$Repo = "C:\Users\wenyu\mispricing-engine",
    [string]$Model = "gemini-2.5-pro",
    [string]$LogFile = ""
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
$promptFile = "$env:TEMP\gemini_prompt_$(Get-Random).txt"
$Prompt | Out-File -FilePath $promptFile -Encoding utf8NoBOM
$safePrompt = Get-Content $promptFile -Raw -Encoding utf8
Remove-Item $promptFile -ErrorAction SilentlyContinue

try {
    $output   = & gemini -m $Model -C $Repo $safePrompt 2>&1 | Out-String
    $exitCode = $LASTEXITCODE

    if (Test-QuotaError -output $output -exitCode $exitCode) {
        Write-Warning "Gemini quota/rate-limit exceeded — creating .fallback_claude sentinel for Claude to handle"
        "[GEMINI QUOTA EXCEEDED at $(Get-Date -Format o)]`n$output" | Out-File $logPath -Encoding utf8
        "ALL_QUOTA_EXCEEDED|$(Get-Date -Format o)"  | Out-File $errorPath    -Encoding utf8
        "FALLBACK_TO_CLAUDE|$(Get-Date -Format o)"  | Out-File $fallbackPath -Encoding utf8
        "FALLBACK|$(Get-Date -Format o)"            | Out-File $donePath     -Encoding utf8
        exit 0
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
