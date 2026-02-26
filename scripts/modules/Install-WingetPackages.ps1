# scripts/modules/Install-WingetPackages.ps1
# winget パッケージの導入・同期
# 前提: core/Logger.ps1, core/ErrorHandler.ps1 がドットソース済み

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
        [Parameter(Mandatory)][string]$WingetExe,
        [Parameter(Mandatory)][string]$PackageId,
        [switch]$NonInteractive
    )

    $wingetArgs = @("list", "--id", $PackageId, "--exact", "--accept-source-agreements")
    if ($NonInteractive) {
        $wingetArgs += "--disable-interactivity"
    }

    $output = (& $WingetExe @wingetArgs 2>&1 | Out-String)
    if ([string]::IsNullOrWhiteSpace($output)) {
        return $false
    }

    return $output -match [regex]::Escape($PackageId)
}

function Test-PackageInstalledFromPath {
    param([Parameter(Mandatory)][object]$Package)

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
        [Parameter(Mandatory)][string]$WingetExe,
        [Parameter(Mandatory)][object]$Package,
        [switch]$NonInteractive
    )

    $id = [string]$Package.id
    if (-not [string]::IsNullOrWhiteSpace($id)) {
        if (Test-WingetPackageInstalled -WingetExe $WingetExe -PackageId $id -NonInteractive:$NonInteractive) {
            return $true
        }
    }

    if (Test-PackageInstalledFromPath -Package $Package) {
        return $true
    }

    return $false
}

function Invoke-WingetPackageSync {
    <#
  .SYNOPSIS
    winget-packages.json に基づきパッケージをインストールする。
  #>
    param(
        [Parameter(Mandatory)][string]$ConfigPath,
        [switch]$IncludeOptional,
        [switch]$NonInteractive,
        [switch]$DryRun
    )

    if (-not (Test-Path $ConfigPath)) {
        throw "Config file not found: $ConfigPath"
    }

    $config = Get-Content -Path $ConfigPath -Raw | ConvertFrom-Json
    $wingetExe = Resolve-WingetExecutable

    Write-StepLog "winget: $wingetExe" -DryRun:$DryRun

    $packages = @()
    if ($config.required) {
        $packages += @($config.required)
    }
    if ($IncludeOptional -and $config.optional) {
        $packages += @($config.optional)
    }

    if ($packages.Count -eq 0) {
        Write-StepWarn "No packages configured." -DryRun:$DryRun
        return
    }

    Write-StepLog "$($packages.Count) 件のパッケージを処理します。" -DryRun:$DryRun

    foreach ($pkg in $packages) {
        $id = [string]$pkg.id
        if ([string]::IsNullOrWhiteSpace($id)) {
            continue
        }

        $alreadyInstalled = $false
        if (-not $DryRun) {
            $alreadyInstalled = Test-PackageProvisioned -WingetExe $wingetExe -Package $pkg -NonInteractive:$NonInteractive
        }

        if ($alreadyInstalled) {
            Write-StepSuccess "[skip] $id is already installed." -DryRun:$DryRun
            continue
        }

        $wingetArgs = @(
            "install",
            "--id", $id,
            "--exact",
            "--source", "winget",
            "--accept-package-agreements",
            "--accept-source-agreements"
        )

        if ($NonInteractive) {
            $wingetArgs += "--disable-interactivity"
        }

        if ($DryRun) {
            Write-StepLog "[dry-run] $wingetExe $($wingetArgs -join ' ')" -DryRun
            continue
        }

        Write-StepLog "[install] $id"
        & $wingetExe @wingetArgs
        if ($LASTEXITCODE -ne 0) {
            if (Test-PackageProvisioned -WingetExe $wingetExe -Package $pkg -NonInteractive:$NonInteractive) {
                Write-StepWarn "winget reported failure for $id, but the package appears to be present. Continuing."
                continue
            }
            throw "Failed to install package: $id"
        }

        Write-StepSuccess "[installed] $id"
    }

    Write-StepLog "Package sync completed." -DryRun:$DryRun
}
