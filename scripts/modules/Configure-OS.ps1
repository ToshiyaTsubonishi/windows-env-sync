# scripts/modules/Configure-OS.ps1
# OS設定の自動化（レジストリ一括書き換え）
# 前提: core/Logger.ps1, core/ErrorHandler.ps1 がドットソース済み

function Invoke-OSConfiguration {
    <#
  .SYNOPSIS
    config/os-settings.json に基づきレジストリキーを一括適用し、エクスプローラーを再起動する。
  .PARAMETER ConfigPath
    os-settings.json のパス。
  .PARAMETER DryRun
    $true の場合、レジストリ変更を行わない。
  #>
    param(
        [Parameter(Mandatory)][string]$ConfigPath,
        [switch]$DryRun
    )

    if (-not (Test-Path $ConfigPath)) {
        throw "Config file not found: $ConfigPath"
    }

    $config = Get-Content -Path $ConfigPath -Raw | ConvertFrom-Json
    $settings = @()
    if ($config.registrySettings) {
        $settings = @($config.registrySettings)
    }

    if ($settings.Count -eq 0) {
        Write-StepWarn "No registry settings configured." -DryRun:$DryRun
        return
    }

    Write-StepLog "$($settings.Count) 件のレジストリ設定を処理します。" -DryRun:$DryRun

    $changedCount = 0
    $skippedCount = 0
    $failedCount = 0

    foreach ($entry in $settings) {
        $desc = [string]$entry.description
        $regPath = [string]$entry.path
        $regName = [string]$entry.name
        $regValue = $entry.value
        $regType = [string]$entry.type

        # HKLM は管理者権限が必要
        $isHKLM = $regPath.StartsWith("HKLM:")
        if ($isHKLM) {
            $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
                [Security.Principal.WindowsBuiltInRole]::Administrator
            )
            if (-not $isAdmin) {
                Write-StepWarn "[skip] $desc — 管理者権限が必要です (HKLM)" -DryRun:$DryRun
                $skippedCount++
                continue
            }
        }

        # レジストリキーの存在確認（なければ作成）
        if (-not (Test-Path $regPath)) {
            if ($DryRun) {
                Write-StepLog "[dry-run] mkdir $regPath" -DryRun
            }
            else {
                New-Item -Path $regPath -Force | Out-Null
            }
        }

        # 現在値チェック（冪等性）
        $current = Get-ItemProperty -Path $regPath -Name $regName -ErrorAction SilentlyContinue
        if ($null -ne $current -and $current.$regName -eq $regValue) {
            Write-StepSuccess "[skip] $desc (既に設定済み)" -DryRun:$DryRun
            $skippedCount++
            continue
        }

        # 適用
        if ($DryRun) {
            Write-StepLog "[dry-run] Set $regPath\$regName = $regValue ($regType) — $desc" -DryRun
            $changedCount++
            continue
        }

        try {
            Set-ItemProperty -Path $regPath -Name $regName -Value $regValue -Type $regType -Force
            Write-StepSuccess "[set] $desc" -DryRun:$DryRun
            $changedCount++
        }
        catch {
            Write-StepFail "[fail] $desc — $($_.Exception.Message)"
            $failedCount++
        }
    }

    Write-StepLog "レジストリ: $changedCount 変更, $skippedCount スキップ, $failedCount 失敗" -DryRun:$DryRun

    # エクスプローラー再起動（変更があった場合のみ）
    if ($changedCount -gt 0 -and -not $DryRun) {
        Write-StepLog "エクスプローラーを再起動して設定を即時反映します..."
        Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2
        Write-StepSuccess "エクスプローラーが再起動されました。"
    }
    elseif ($changedCount -gt 0 -and $DryRun) {
        Write-StepLog "[dry-run] Stop-Process -Name explorer -Force" -DryRun
    }
}
