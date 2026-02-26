# scripts/modules/Setup-WSL2.ps1
# WSL2 環境の構築
# 前提: core/Logger.ps1, core/ErrorHandler.ps1 がドットソース済み

function Test-WindowsFeatureEnabled {
  <#
  .SYNOPSIS
    指定された Windows Optional Feature が有効かどうかを返す。
  #>
  param([Parameter(Mandatory)][string]$FeatureName)

  try {
    $feature = Get-WindowsOptionalFeature -Online -FeatureName $FeatureName -ErrorAction Stop
    return ($feature.State -eq "Enabled")
  }
  catch {
    return $false
  }
}

function Invoke-WSL2Setup {
  <#
  .SYNOPSIS
    WSL2 のインストール・初期設定を行う。
    Windows 機能の有効化が必要な場合は Set-RebootRequired を呼び出し、
    エントリーポイントが再起動を促してスクリプトを安全に停止する。
  .PARAMETER Distro
    インストールするディストリビューション名。デフォルトは Ubuntu。
  .PARAMETER DryRun
    $true の場合、実際の変更を行わない。
  #>
  param(
    [string]$Distro = "Ubuntu",
    [switch]$DryRun
  )

  # --- Step 1: 管理者権限チェック ---
  $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator
  )

  # --- Step 2: 必要な Windows 機能の確認 ---
  $requiredFeatures = @(
    @{ Name = "VirtualMachinePlatform"; Display = "仮想マシン プラットフォーム" },
    @{ Name = "Microsoft-Windows-Subsystem-Linux"; Display = "Windows Subsystem for Linux" }
  )

  $featuresToEnable = @()

  foreach ($feature in $requiredFeatures) {
    if ($DryRun) {
      Write-StepLog "[dry-run] Get-WindowsOptionalFeature -FeatureName $($feature.Name)" -DryRun
      continue
    }

    if (Test-WindowsFeatureEnabled -FeatureName $feature.Name) {
      Write-StepSuccess "$($feature.Display) は有効です。" -DryRun:$DryRun
    }
    else {
      Write-StepWarn "$($feature.Display) が無効です。有効化が必要です。"
      $featuresToEnable += $feature
    }
  }

  # --- Step 3: 機能の有効化（必要な場合） ---
  if ($featuresToEnable.Count -gt 0) {
    if (-not $isAdmin) {
      Write-StepFail "Windows 機能の有効化には管理者権限が必要です。"
      Write-StepWarn "管理者権限のターミナルで再実行してください:"
      Write-StepWarn "  Start-Process pwsh -Verb RunAs -ArgumentList '-File', './scripts/Setup-WindowsEnv.ps1'"
      throw "管理者権限が必要です。"
    }

    foreach ($feature in $featuresToEnable) {
      if ($DryRun) {
        Write-StepLog "[dry-run] Enable-WindowsOptionalFeature -Online -FeatureName $($feature.Name) -NoRestart" -DryRun
        continue
      }

      Write-StepLog "$($feature.Display) を有効化しています..."
      try {
        Enable-WindowsOptionalFeature -Online -FeatureName $feature.Name -NoRestart -ErrorAction Stop | Out-Null
        Write-StepSuccess "$($feature.Display) を有効化しました。"
      }
      catch {
        throw "$($feature.Display) の有効化に失敗しました: $($_.Exception.Message)"
      }
    }

    # 再起動フラグを設定
    if (-not $DryRun) {
      Set-RebootRequired
      Write-StepWarn "=========================================="
      Write-StepWarn "  Windows 機能を有効化しました。"
      Write-StepWarn "  変更を反映するにはPCを再起動してください。"
      Write-StepWarn "  再起動後、このスクリプトを再実行すると"
      Write-StepWarn "  WSL2 のセットアップが続行されます。"
      Write-StepWarn "=========================================="
    }
    else {
      Write-StepLog "[dry-run] Set-RebootRequired (再起動要求フラグ設定)" -DryRun
    }
    return
  }

  # --- Step 4: WSL デフォルトバージョンを 2 に設定 ---
  if ($DryRun) {
    Write-StepLog "[dry-run] wsl --set-default-version 2" -DryRun
  }
  else {
    Write-StepLog "WSL デフォルトバージョンを 2 に設定しています..."
    wsl --set-default-version 2 2>&1 | Out-Null
    Write-StepSuccess "WSL デフォルトバージョンが 2 に設定されました。"
  }

  # --- Step 5: ディストリビューションのインストール ---
  $wslInstalled = $false
  if (-not $DryRun) {
    $wslList = wsl --list --quiet 2>&1 | Out-String
    if ($wslList -match [regex]::Escape($Distro)) {
      $wslInstalled = $true
    }
  }

  if ($wslInstalled) {
    Write-StepSuccess "$Distro は既にインストール済みです。"
  }
  else {
    if ($DryRun) {
      Write-StepLog "[dry-run] wsl --install --distribution $Distro --no-launch" -DryRun
    }
    else {
      Write-StepLog "$Distro をインストールしています..."
      wsl --install --distribution $Distro --no-launch 2>&1 | ForEach-Object { Write-Host "  $_" }
      if ($LASTEXITCODE -ne 0) {
        Write-StepWarn "wsl --install が非ゼロで終了しましたが、既にインストール済みの可能性があります。"
      }
      else {
        Write-StepSuccess "$Distro のインストールが完了しました。"
      }
    }
  }

  Write-StepLog "WSL2 セットアップが完了しました。" -DryRun:$DryRun
}
