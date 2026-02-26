# scripts/modules/Sync-UserPath.ps1
# User PATH の同期
# 前提: core/Logger.ps1, core/ErrorHandler.ps1 がドットソース済み

function Normalize-PathValue {
    param([Parameter(Mandatory)][string]$Value)

    $trimmed = $Value.Trim().TrimEnd('\')
    if ([string]::IsNullOrWhiteSpace($trimmed)) {
        return ""
    }

    try {
        return ([IO.Path]::GetFullPath($trimmed)).TrimEnd('\').ToLowerInvariant()
    }
    catch {
        return $trimmed.ToLowerInvariant()
    }
}

function Invoke-UserPathSync {
    <#
  .SYNOPSIS
    winget-packages.json の pathEntries に基づき User PATH を同期する。
  #>
    param(
        [Parameter(Mandatory)][string]$ConfigPath,
        [switch]$DryRun
    )

    if (-not (Test-Path $ConfigPath)) {
        throw "Config file not found: $ConfigPath"
    }

    $config = Get-Content -Path $ConfigPath -Raw | ConvertFrom-Json
    $entries = @()
    if ($config.pathEntries) {
        $entries = @($config.pathEntries)
    }

    if ($entries.Count -eq 0) {
        Write-StepWarn "No path entries configured." -DryRun:$DryRun
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
            Write-StepWarn "Path does not exist yet, skip: $expanded" -DryRun:$DryRun
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
        Write-StepSuccess "User PATH is already up to date." -DryRun:$DryRun
        return
    }

    $newUserPath = ($currentParts -join ';')
    if ($DryRun) {
        Write-StepLog "User PATH additions:" -DryRun
        foreach ($item in $added) {
            Write-StepLog "  + $item" -DryRun
        }
        return
    }

    [Environment]::SetEnvironmentVariable("Path", $newUserPath, "User")
    $env:Path = $newUserPath + ";" + [Environment]::GetEnvironmentVariable("Path", "Machine")

    Write-StepSuccess "User PATH updated:"
    foreach ($item in $added) {
        Write-StepLog "  + $item"
    }
}
