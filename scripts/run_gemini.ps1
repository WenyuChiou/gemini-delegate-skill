<# 
.SYNOPSIS
  Helper to run Gemini CLI from PowerShell (routes through cmd to avoid PATH issues)
.PARAMETER Prompt
  The prompt string to send to Gemini
.PARAMETER ContextFile
  Optional path to a context .md file to pipe as input
.PARAMETER OutputFile
  Optional path to capture output (defaults to stdout)
.PARAMETER Model
  Gemini model to use (default: gemini-2.5-pro)
.PARAMETER TimeoutSec
  Timeout in seconds (default: 120)
.EXAMPLE
  .\run_gemini.ps1 -Prompt "refactor utils.py" 
  .\run_gemini.ps1 -ContextFile task.md -Prompt "do the task" -OutputFile result.md
#>
param(
    [string]$Prompt,
    [string]$ContextFile,
    [string]$OutputFile,
    [string]$Model = "",
    [int]$TimeoutSec = 120
)

$modelFlag = if ($Model) { "-m $Model" } else { "" }

if ($ContextFile -and (Test-Path $ContextFile)) {
    $cmd = "type `"$ContextFile`" | gemini -p `"$Prompt`" -y $modelFlag"
} else {
    $cmd = "gemini -p `"$Prompt`" -y $modelFlag"
}

if ($OutputFile) {
    $cmd += " > `"$OutputFile`" 2>&1"
}

Write-Host "[gemini-delegate] Running: $cmd" -ForegroundColor Cyan
Write-Host "[gemini-delegate] Timeout: ${TimeoutSec}s" -ForegroundColor Gray

$process = Start-Process -FilePath "cmd.exe" -ArgumentList "/c", $cmd `
    -NoNewWindow -PassThru -Wait:$false

$completed = $process.WaitForExit($TimeoutSec * 1000)

if (-not $completed) {
    $process.Kill()
    Write-Host "[gemini-delegate] TIMEOUT after ${TimeoutSec}s - process killed" -ForegroundColor Red
    exit 1
}

Write-Host "[gemini-delegate] Done (exit code: $($process.ExitCode))" -ForegroundColor Green

if ($OutputFile -and (Test-Path $OutputFile)) {
    Write-Host "[gemini-delegate] Output saved to: $OutputFile" -ForegroundColor Green
}
