[CmdletBinding()]
param(
  [string]$ConfigPath = (Join-Path (Resolve-Path (Join-Path $PSScriptRoot "..")).Path "config/winget-packages.json"),
  [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Normalize-PathValue {
  param([Parameter(Mandatory = $true)][string]$Value)

  $trimmed = $Value.Trim().TrimEnd('\')
  if ([string]::IsNullOrWhiteSpace($trimmed)) {
    return ""
  }

  try {
    return ([IO.Path]::GetFullPath($trimmed)).TrimEnd('\').ToLowerInvariant()
  } catch {
    return $trimmed.ToLowerInvariant()
  }
}

if (-not (Test-Path $ConfigPath)) {
  throw "Config file not found: $ConfigPath"
}

$config = Get-Content -Path $ConfigPath -Raw | ConvertFrom-Json
$entries = @()
if ($config.pathEntries) {
  $entries = @($config.pathEntries)
}

if ($entries.Count -eq 0) {
  Write-Host "No path entries configured."
  return
}

$rawUserPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ($null -eq $rawUserPath) {
  $rawUserPath = ""
}

$currentParts = @()
if (-not [string]::IsNullOrWhiteSpace($rawUserPath)) {
  $currentParts = @($rawUserPath.Split(';', [System.StringSplitOptions]::RemoveEmptyEntries))
}

$seen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
foreach ($part in $currentParts) {
  $normalized = Normalize-PathValue -Value $part
  if (-not [string]::IsNullOrWhiteSpace($normalized)) {
    [void]$seen.Add($normalized)
  }
}

$added = @()
foreach ($rawEntry in $entries) {
  $expanded = [Environment]::ExpandEnvironmentVariables([string]$rawEntry)
  if ([string]::IsNullOrWhiteSpace($expanded)) {
    continue
  }

  if (-not (Test-Path $expanded)) {
    Write-Warning "Path does not exist yet, skip: $expanded"
    continue
  }

  $normalized = Normalize-PathValue -Value $expanded
  if ([string]::IsNullOrWhiteSpace($normalized)) {
    continue
  }

  if ($seen.Contains($normalized)) {
    continue
  }

  [void]$seen.Add($normalized)
  $currentParts += $expanded
  $added += $expanded
}

if ($added.Count -eq 0) {
  Write-Host "User PATH is already up to date."
  return
}

$newUserPath = ($currentParts -join ';')
if ($DryRun) {
  Write-Host "[dry-run] User PATH additions:"
  foreach ($item in $added) {
    Write-Host "  + $item"
  }
  return
}

[Environment]::SetEnvironmentVariable("Path", $newUserPath, "User")
$env:Path = $newUserPath + ";" + [Environment]::GetEnvironmentVariable("Path", "Machine")

Write-Host "User PATH updated with:"
foreach ($item in $added) {
  Write-Host "  + $item"
}

