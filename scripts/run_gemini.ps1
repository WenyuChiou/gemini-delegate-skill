param(
    [Parameter(Mandatory = $true)][string]$Prompt,
    [string]$Repo = "",
    [string]$Model = "gemini-2.5-pro",
    [string]$LogFile = "",
    [string[]]$VerifyFile = @(),
    [string]$VerifySentinel = ""
)

# Default -Repo to the caller's working directory.
# Resolved here (not at param default) so it reflects the shell's PWD
# at invocation time, not the script's parse-time location.
if (-not $Repo) { $Repo = (Get-Location).Path }

$ErrorActionPreference = "Continue"

[Console]::InputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
$env:PYTHONIOENCODING = "utf-8"
chcp 65001 | Out-Null

$logPath = if ($LogFile) { $LogFile } else { "$Repo\.ai\gemini_output.txt" }
$donePath = "$logPath.done"
$errorPath = "$logPath.error"
$fallbackPath = "$logPath.fallback_claude"
$resultPath = "$logPath.result.json"

$aiDir = Join-Path $Repo ".ai"
if (!(Test-Path $aiDir)) { New-Item -ItemType Directory -Path $aiDir -Force | Out-Null }

Remove-Item $fallbackPath -ErrorAction SilentlyContinue
Remove-Item $donePath -ErrorAction SilentlyContinue
Remove-Item $errorPath -ErrorAction SilentlyContinue
Remove-Item $resultPath -ErrorAction SilentlyContinue

function Test-QuotaError {
    param([string]$Output, [int]$ExitCode)

    if ($ExitCode -eq 429) { return $true }
    $patterns = @(
        "quota exceeded", "rate limit", "rate_limit", "quota_exceeded",
        "insufficient_quota", "too many requests", "RateLimitError",
        "exceeded your current quota", "RESOURCE_EXHAUSTED", "429"
    )
    foreach ($pattern in $patterns) {
        if ($Output -ilike "*$pattern*") { return $true }
    }
    return $false
}

function Write-ResultJson {
    param(
        [string]$Status,
        [string]$ModelUsed,
        [string]$Summary
    )

    $payload = [ordered]@{
        status        = $Status
        delegate      = $backendName
        model         = $ModelUsed
        log_file      = $logPath
        summary       = $Summary
        risks         = @()
        files_changed = @()
        tests_run     = @()
        timestamp_utc = [DateTime]::UtcNow.ToString("o")
    }

    $json = $payload | ConvertTo-Json -Depth 5
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($resultPath, $json, $utf8NoBom)
}

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

$promptFile = "$env:TEMP\gemini_prompt_$(Get-Random).txt"
$Prompt | Out-File -FilePath $promptFile -Encoding utf8

$backendName = "unknown"

try {
    Push-Location $Repo
    try {
        $backend = Resolve-Backend
        $backendBin = $backend.Bin
        $backendName = $backend.Name
        if ($backendName -eq "agy") {
            $output = Get-Content $promptFile -Raw -Encoding utf8 | & $backendBin -m $Model --yolo - 2>&1 | Out-String
        }
        else {
            $output = Get-Content $promptFile -Raw -Encoding utf8 | & $backendBin -m $Model --approval-mode yolo 2>&1 | Out-String
        }
        $exitCode = $LASTEXITCODE
    }
    finally {
        Pop-Location
        Remove-Item $promptFile -ErrorAction SilentlyContinue
    }

    if (Test-QuotaError -Output $output -ExitCode $exitCode) {
        Write-Warning "$backendName quota/rate-limit exceeded; creating .fallback_claude sentinel for Claude to handle"
        "[$($backendName.ToUpperInvariant()) QUOTA EXCEEDED at $(Get-Date -Format o)]`n$output" | Out-File $logPath -Encoding utf8
        "ALL_QUOTA_EXCEEDED|$(Get-Date -Format o)" | Out-File $errorPath -Encoding utf8
        "FALLBACK_TO_CLAUDE|$(Get-Date -Format o)" | Out-File $fallbackPath -Encoding utf8
        "FALLBACK|$(Get-Date -Format o)" | Out-File $donePath -Encoding utf8
        Write-ResultJson -Status "fallback" -ModelUsed "$backendName/$Model" -Summary "$backendName quota exceeded; Claude must take over."
        exit 0
    }

    if ($exitCode -ne 0) {
        $output | Out-File $errorPath -Encoding utf8
        Write-ResultJson -Status "error" -ModelUsed "$backendName/$Model" -Summary "$backendName exited with a hard failure."
        exit 1
    }

    if ($VerifyFile.Count -gt 0) {
        $verifyFail = $false
        foreach ($file in $VerifyFile) {
            if (!(Test-Path $file) -or (Get-Item $file).Length -eq 0) {
                Write-Warning "VERIFICATION FAILED: $file missing or empty"
                $verifyFail = $true
                continue
            }
            if ($VerifySentinel) {
                $content = Get-Content $file -Raw -Encoding utf8
                if ($content -notlike "*$VerifySentinel*") {
                    Write-Warning "VERIFICATION FAILED: $file missing sentinel '$VerifySentinel'"
                    $verifyFail = $true
                }
            }
        }
        if ($verifyFail) {
            "[VERIFICATION FAILED at $(Get-Date -Format o)]`n[MODEL_USED: $backendName/$Model]`n$output" | Out-File $logPath -Encoding utf8
            "VERIFY_FAILED|$backendName/$Model|$(Get-Date -Format o)" | Out-File $errorPath -Encoding utf8
            Write-ResultJson -Status "verify_failed" -ModelUsed "$backendName/$Model" -Summary "$backendName exited, but required output files failed verification."
            exit 1
        }
    }

    "[MODEL_USED: $backendName/$Model]`n$output" | Out-File $logPath -Encoding utf8
    "DONE|$backendName/$Model|$(Get-Date -Format o)" | Out-File $donePath -Encoding utf8
    Write-ResultJson -Status "success" -ModelUsed "$backendName/$Model" -Summary "$backendName completed successfully. Claude must still review facts, terminology, and tone."
}
catch {
    $errMsg = $_.Exception.Message

    if (Test-QuotaError -Output $errMsg -ExitCode 0) {
        "[$($backendName.ToUpperInvariant()) QUOTA EXCEPTION at $(Get-Date -Format o)]`n$errMsg" | Out-File $logPath -Encoding utf8
        "ALL_QUOTA_EXCEEDED|$(Get-Date -Format o)" | Out-File $errorPath -Encoding utf8
        "FALLBACK_TO_CLAUDE|$(Get-Date -Format o)" | Out-File $fallbackPath -Encoding utf8
        "FALLBACK|$(Get-Date -Format o)" | Out-File $donePath -Encoding utf8
        Write-ResultJson -Status "fallback" -ModelUsed "$backendName/$Model" -Summary "$backendName quota exception triggered fallback to Claude."
        exit 0
    }

    $errMsg | Out-File $errorPath -Encoding utf8
    Write-ResultJson -Status "error" -ModelUsed "$backendName/$Model" -Summary "$backendName exited with a hard failure."
    exit 1
}
