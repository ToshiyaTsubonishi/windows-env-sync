[CmdletBinding()]
param(
  [string]$ConfigPath = (Join-Path (Resolve-Path (Join-Path $PSScriptRoot "..")).Path "config/winget-packages.json"),
  [switch]$IncludeOptional,
  [switch]$NonInteractive,
  [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Resolve-WingetExecutable {
  $cmd = Get-Command "winget" -ErrorAction SilentlyContinue
  if ($cmd -and -not [string]::IsNullOrWhiteSpace($cmd.Source)) {
    return $cmd.Source
  }

  $fallback = Join-Path $env:LOCALAPPDATA "Microsoft/WindowsApps/winget.exe"
  if (Test-Path $fallback) {
    return $fallback
  }

  throw "winget.exe not found. Install App Installer from Microsoft Store first."
}

function Test-WingetPackageInstalled {
  param(
    [Parameter(Mandatory = $true)][string]$WingetExe,
    [Parameter(Mandatory = $true)][string]$PackageId
  )

  $args = @("list", "--id", $PackageId, "--exact", "--accept-source-agreements")
  if ($NonInteractive) {
    $args += "--disable-interactivity"
  }

  $output = (& $WingetExe @args 2>&1 | Out-String)
  if ([string]::IsNullOrWhiteSpace($output)) {
    return $false
  }

  return $output -match [regex]::Escape($PackageId)
}

function Test-PackageInstalledFromPath {
  param([Parameter(Mandatory = $true)][object]$Package)

  if (-not $Package.PSObject.Properties.Name.Contains("checkPath")) {
    return $false
  }

  $checkPath = [string]$Package.checkPath
  if ([string]::IsNullOrWhiteSpace($checkPath)) {
    return $false
  }

  $expanded = [Environment]::ExpandEnvironmentVariables($checkPath)
  return Test-Path $expanded
}

function Test-PackageProvisioned {
  param(
    [Parameter(Mandatory = $true)][string]$WingetExe,
    [Parameter(Mandatory = $true)][object]$Package
  )

  $id = [string]$Package.id
  if (-not [string]::IsNullOrWhiteSpace($id)) {
    if (Test-WingetPackageInstalled -WingetExe $WingetExe -PackageId $id) {
      return $true
    }
  }

  if (Test-PackageInstalledFromPath -Package $Package) {
    return $true
  }

  return $false
}

if (-not (Test-Path $ConfigPath)) {
  throw "Config file not found: $ConfigPath"
}

$config = Get-Content -Path $ConfigPath -Raw | ConvertFrom-Json
$wingetExe = Resolve-WingetExecutable

$packages = @()
if ($config.required) {
  $packages += @($config.required)
}
if ($IncludeOptional -and $config.optional) {
  $packages += @($config.optional)
}

if ($packages.Count -eq 0) {
  Write-Host "No packages configured."
  return
}

foreach ($pkg in $packages) {
  $id = [string]$pkg.id
  if ([string]::IsNullOrWhiteSpace($id)) {
    continue
  }

  $alreadyInstalled = $false
  if (-not $DryRun) {
    $alreadyInstalled = Test-PackageProvisioned -WingetExe $wingetExe -Package $pkg
  }

  if ($alreadyInstalled) {
    Write-Host "[skip] $id is already installed."
    continue
  }

  $args = @(
    "install",
    "--id", $id,
    "--exact",
    "--source", "winget",
    "--accept-package-agreements",
    "--accept-source-agreements"
  )

  if ($NonInteractive) {
    $args += "--disable-interactivity"
  }

  if ($DryRun) {
    Write-Host "[dry-run] $wingetExe $($args -join ' ')"
    continue
  }

  Write-Host "[install] $id"
  & $wingetExe @args
  if ($LASTEXITCODE -ne 0) {
    if (Test-PackageProvisioned -WingetExe $wingetExe -Package $pkg) {
      Write-Warning "winget reported failure for $id, but the package appears to be present. Continuing."
      continue
    }
    throw "Failed to install package: $id"
  }
}

Write-Host "Package sync completed."
