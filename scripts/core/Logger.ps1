# scripts/core/Logger.ps1
# 共通ロギングユーティリティ
# Usage: . "$PSScriptRoot/../core/Logger.ps1" でドットソースして使用

function Write-StepHeader {
  param([Parameter(Mandatory)][string]$Title)
  $line = "=" * 60
  Write-Host ""
  Write-Host $line -ForegroundColor Cyan
  Write-Host "  $Title" -ForegroundColor Cyan
  Write-Host $line -ForegroundColor Cyan
}

function Write-StepLog {
  param(
    [Parameter(Mandatory)][string]$Message,
    [switch]$DryRun
  )
  $ts = Get-Date -Format "HH:mm:ss"
  $prefix = if ($DryRun) { "[DRY-RUN]" } else { "[INFO]" }
  Write-Host "$ts $prefix $Message"
}

function Write-StepSuccess {
  param(
    [Parameter(Mandatory)][string]$Message,
    [switch]$DryRun
  )
  $ts = Get-Date -Format "HH:mm:ss"
  $prefix = if ($DryRun) { "[DRY-RUN][OK]" } else { "[OK]" }
  Write-Host "$ts $prefix $Message" -ForegroundColor Green
}

function Write-StepWarn {
  param(
    [Parameter(Mandatory)][string]$Message,
    [switch]$DryRun
  )
  $ts = Get-Date -Format "HH:mm:ss"
  $prefix = if ($DryRun) { "[DRY-RUN][WARN]" } else { "[WARN]" }
  Write-Host "$ts $prefix $Message" -ForegroundColor Yellow
}

function Write-StepFail {
  param(
    [Parameter(Mandatory)][string]$Message,
    [switch]$DryRun
  )
  $ts = Get-Date -Format "HH:mm:ss"
  $prefix = if ($DryRun) { "[DRY-RUN][FAIL]" } else { "[FAIL]" }
  Write-Host "$ts $prefix $Message" -ForegroundColor Red
}
