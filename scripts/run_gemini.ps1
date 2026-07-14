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
        [string]$Summary,
        [string[]]$FilesChanged = @()
    )

    # Assemble JSON by hand. Windows PowerShell 5.1 `ConvertTo-Json` renders an
    # empty `@()` hashtable property as `null`, not `[]`, which would break the
    # array contract for files_changed / risks / tests_run. Each scalar is
    # escaped by running `ConvertTo-Json` on the single value. This mirrors the
    # hand-built JSON in run_gemini.sh, keeping the two wrappers byte-compatible.
    function ConvertTo-JsonScalar($value) {
        if ($null -eq $value) { $value = "" }
        return ([string]$value | ConvertTo-Json -Compress)
    }

    $filesArr =
        if ($FilesChanged -and @($FilesChanged).Count -gt 0) {
            "[" + ((@($FilesChanged) | ForEach-Object { ConvertTo-JsonScalar $_ }) -join ",") + "]"
        } else { "[]" }
    $timestamp = [DateTime]::UtcNow.ToString("o")
    $json = (@(
        "{",
        ('  "status": ' + (ConvertTo-JsonScalar $Status) + ","),
        ('  "delegate": ' + (ConvertTo-JsonScalar $backendName) + ","),
        ('  "model": ' + (ConvertTo-JsonScalar $ModelUsed) + ","),
        ('  "log_file": ' + (ConvertTo-JsonScalar $logPath) + ","),
        ('  "summary": ' + (ConvertTo-JsonScalar $Summary) + ","),
        '  "risks": [],',
        ('  "files_changed": ' + $filesArr + ","),
        '  "tests_run": [],',
        ('  "timestamp_utc": ' + (ConvertTo-JsonScalar $timestamp)),
        "}"
    ) -join "`n")

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

# Snapshot the repo's changed-file set via `git status --porcelain`.
# Returns an empty array when the path is not a git work tree (or git is
# absent), so files_changed degrades to [] instead of failing the run.
function Get-GitStatusSnapshot {
    param([string]$Path)
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) { return @() }
    $out = & git -C $Path -c core.quotePath=false status --porcelain 2>$null
    if ($LASTEXITCODE -ne 0) { return @() }
    # `git status` on a clean repo yields $null; strip it so the result is a
    # true empty array, not @($null) (a 1-element array holding null).
    return @($out | Where-Object { $null -ne $_ })
}
# Diff two porcelain snapshots; return the paths that became changed during
# the run. A file already dirty before the run, with an unchanged porcelain
# status line, is intentionally not re-reported (it was not this run's doing).
function Get-FilesChanged {
    param([string[]]$Before = @(), [string[]]$After = @())
    $beforeSet = New-Object 'System.Collections.Generic.HashSet[string]'
    foreach ($line in $Before) { [void]$beforeSet.Add($line) }
    $paths = New-Object 'System.Collections.Generic.List[string]'
    foreach ($line in $After) {
        if ($beforeSet.Contains($line)) { continue }
        $entry = if ($line.Length -gt 3) { $line.Substring(3) } else { "" }
        if ($entry -match ' -> ') { $entry = ($entry -split ' -> ', 2)[1] }   # renamed
        $entry = $entry.Trim().Trim('"')
        if ($entry) { [void]$paths.Add($entry) }
    }
    return @($paths | Sort-Object -Unique)
}

$promptFile = "$env:TEMP\gemini_prompt_$(Get-Random).txt"
$Prompt | Out-File -FilePath $promptFile -Encoding utf8

$backendName = "unknown"
# Snapshot the repo before the run so files_changed attributes edits to this
# run only. The wrapper's own log / sentinel / result files are written after
# the after-snapshot, so they never leak in.
$changedBefore = Get-GitStatusSnapshot -Path $Repo
$filesChanged = @()

try {
    Push-Location $Repo
    try {
        $backend = Resolve-Backend
        $backendBin = $backend.Bin
        $backendName = $backend.Name
        # --- Legacy Gemini CLI deprecation guard (2026-06-18) ---
        # Consumer-tier CLI auth killed by Google (IneligibleTierError /
        # UNSUPPORTED_CLIENT); non-interactive gemini then silently emits
        # pseudo-code. Fail closed on the gemini fallback; agy unaffected.
        if ($backendName -eq "gemini" -and -not $env:GEMINI_DEPRECATED_OVERRIDE) {
            throw "FATAL: legacy Gemini CLI backend is deprecated (2026-06-18) - it silently emits pseudo-code under the killed consumer tier. Use the agy backend (install: https://antigravity.google/cli/install.sh), or the evidence-backed antigravity-delegate skill (https://github.com/WenyuChiou/antigravity-delegate). Override only if the tier is restored: GEMINI_DEPRECATED_OVERRIDE=1"
        }
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
    $changedAfter = Get-GitStatusSnapshot -Path $Repo
    $filesChanged = @(Get-FilesChanged -Before $changedBefore -After $changedAfter)

    if (Test-QuotaError -Output $output -ExitCode $exitCode) {
        Write-Warning "$backendName quota/rate-limit exceeded; creating .fallback_claude sentinel for Claude to handle"
        "[$($backendName.ToUpperInvariant()) QUOTA EXCEEDED at $(Get-Date -Format o)]`n$output" | Out-File $logPath -Encoding utf8
        "ALL_QUOTA_EXCEEDED|$(Get-Date -Format o)" | Out-File $errorPath -Encoding utf8
        "FALLBACK_TO_CLAUDE|$(Get-Date -Format o)" | Out-File $fallbackPath -Encoding utf8
        "FALLBACK|$(Get-Date -Format o)" | Out-File $donePath -Encoding utf8
        Write-ResultJson -Status "fallback" -ModelUsed "$backendName/$Model" -Summary "$backendName quota exceeded; Claude must take over." -FilesChanged $filesChanged
        exit 0
    }

    if ($exitCode -ne 0) {
        $output | Out-File $errorPath -Encoding utf8
        Write-ResultJson -Status "error" -ModelUsed "$backendName/$Model" -Summary "$backendName exited with a hard failure." -FilesChanged $filesChanged
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
            Write-ResultJson -Status "verify_failed" -ModelUsed "$backendName/$Model" -Summary "$backendName exited, but required output files failed verification." -FilesChanged $filesChanged
            exit 1
        }
    }
    "[MODEL_USED: $backendName/$Model]`n$output" | Out-File $logPath -Encoding utf8
    "DONE|$backendName/$Model|$(Get-Date -Format o)" | Out-File $donePath -Encoding utf8
    Write-ResultJson -Status "success" -ModelUsed "$backendName/$Model" -Summary "$backendName completed successfully. Claude must still review facts, terminology, and tone." -FilesChanged $filesChanged
}
catch {
    $errMsg = $_.Exception.Message

    # Best-effort after-snapshot: a PowerShell-level exception may still have
    # left Gemini edits on disk, so re-derive files_changed here too (the bash
    # wrapper's error path populates it for parity).
    $changedAfter = Get-GitStatusSnapshot -Path $Repo
    $filesChanged = @(Get-FilesChanged -Before $changedBefore -After $changedAfter)

    if (Test-QuotaError -Output $errMsg -ExitCode 0) {
        "[$($backendName.ToUpperInvariant()) QUOTA EXCEPTION at $(Get-Date -Format o)]`n$errMsg" | Out-File $logPath -Encoding utf8
        "ALL_QUOTA_EXCEEDED|$(Get-Date -Format o)" | Out-File $errorPath -Encoding utf8
        "FALLBACK_TO_CLAUDE|$(Get-Date -Format o)" | Out-File $fallbackPath -Encoding utf8
        "FALLBACK|$(Get-Date -Format o)" | Out-File $donePath -Encoding utf8
        Write-ResultJson -Status "fallback" -ModelUsed "$backendName/$Model" -Summary "$backendName quota exception triggered fallback to Claude." -FilesChanged $filesChanged
        exit 0
    }

    $errMsg | Out-File $errorPath -Encoding utf8
    Write-ResultJson -Status "error" -ModelUsed "$backendName/$Model" -Summary "$backendName exited with a hard failure." -FilesChanged $filesChanged
    exit 1
}