[CmdletBinding()]
param(
  [string]$ConfigPath = (Join-Path (Resolve-Path (Join-Path $PSScriptRoot "..")).Path "config/winget-packages.json"),
  [switch]$IncludeOptionalPackages,
  [switch]$SkipInstall,
  [switch]$SkipPathUpdate,
  [switch]$SkipVerify,
  [switch]$NonInteractive,
  [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not $IsWindows) {
  Write-Host "Skipping: this script is for Windows only."
  return
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$installScript = Join-Path $repoRoot "scripts/install-winget-packages.ps1"
$pathScript = Join-Path $repoRoot "scripts/ensure-path.ps1"

if (-not $SkipInstall) {
  & $installScript `
    -ConfigPath $ConfigPath `
    -IncludeOptional:$IncludeOptionalPackages `
    -NonInteractive:$NonInteractive `
    -DryRun:$DryRun
}

if (-not $SkipPathUpdate) {
  & $pathScript -ConfigPath $ConfigPath -DryRun:$DryRun
}

if ($SkipVerify) {
  Write-Host "Windows environment sync completed (verification skipped)."
  return
}

$requiredCommands = @("winget", "git", "node", "npx", "pwsh")
$missing = @()

foreach ($name in $requiredCommands) {
  $cmd = Get-Command $name -ErrorAction SilentlyContinue
  if ($cmd) {
    Write-Host "[ok] $name -> $($cmd.Source)"
  } else {
    Write-Warning "[missing] $name"
    $missing += $name
  }
}

if ($missing.Count -gt 0 -and -not $DryRun) {
  throw "Missing required commands after sync: $($missing -join ', '). Open a new terminal and rerun if PATH was just updated."
}

Write-Host "Windows environment sync completed."

