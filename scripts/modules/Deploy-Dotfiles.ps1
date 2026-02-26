# scripts/modules/Deploy-Dotfiles.ps1
# ドットファイルの展開（シンボリックリンク生成）
# 前提: core/Logger.ps1, core/ErrorHandler.ps1 がドットソース済み

function Backup-ExistingFile {
  <#
  .SYNOPSIS
    既存のファイルやリンクをタイムスタンプ付き .bak として退避する。
  #>
  param(
    [Parameter(Mandatory)][string]$Path,
    [switch]$DryRun
  )

  if (-not (Test-Path $Path)) {
    return
  }

  $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
  $bakPath = "$Path.bak_$timestamp"

  if ($DryRun) {
    Write-StepLog "[dry-run] Backup: $Path -> $bakPath" -DryRun
    return
  }

  # 既存のシンボリックリンクの場合は削除のみ（リンク先は別に存在する）
  $item = Get-Item $Path -Force
  if ($item.LinkType -eq "SymbolicLink") {
    Write-StepLog "[backup] 既存リンクを削除: $Path -> $($item.Target)"
    Remove-Item $Path -Force
    return
  }

  # 通常ファイルの場合はリネームして退避
  Move-Item -Path $Path -Destination $bakPath -Force
  Write-StepLog "[backup] $Path -> $bakPath"
}

function Invoke-DotfileDeploy {
  <#
  .SYNOPSIS
    config/dotfiles.json に基づき、リポジトリ内のファイルへのシンボリックリンクをシステムに展開する。
  .PARAMETER ConfigPath
    dotfiles.json のパス。
  .PARAMETER RepoRoot
    リポジトリのルートディレクトリ。source のベースパスとなる。
  .PARAMETER DryRun
    $true の場合、実際のファイル操作を行わない。
  #>
  param(
    [Parameter(Mandatory)][string]$ConfigPath,
    [Parameter(Mandatory)][string]$RepoRoot,
    [switch]$DryRun
  )

  if (-not (Test-Path $ConfigPath)) {
    throw "Config file not found: $ConfigPath"
  }

  $config = Get-Content -Path $ConfigPath -Raw | ConvertFrom-Json
  $links = @()
  if ($config.links) {
    $links = @($config.links)
  }

  if ($links.Count -eq 0) {
    Write-StepWarn "No dotfile links configured." -DryRun:$DryRun
    return
  }

  Write-StepLog "$($links.Count) 件のドットファイルを処理します。" -DryRun:$DryRun

  $createdCount = 0
  $skippedCount = 0

  foreach ($link in $links) {
    $desc = [string]$link.description
    $sourcePath = Join-Path $RepoRoot ([string]$link.source)
    $targetPath = [Environment]::ExpandEnvironmentVariables([string]$link.target)

    # ソースファイルの存在確認
    if (-not (Test-Path $sourcePath)) {
      Write-StepWarn "[skip] $desc — ソースが存在しません: $sourcePath" -DryRun:$DryRun
      $skippedCount++
      continue
    }

    # ターゲットが既に正しいリンクか確認（冪等性）
    if (Test-Path $targetPath) {
      $existingItem = Get-Item $targetPath -Force
      if ($existingItem.LinkType -eq "SymbolicLink") {
        $resolvedTarget = $existingItem.Target
        $resolvedSource = (Resolve-Path $sourcePath).Path
        if ($resolvedTarget -eq $resolvedSource) {
          Write-StepSuccess "[skip] $desc (正しいリンク済み)" -DryRun:$DryRun
          $skippedCount++
          continue
        }
      }
    }

    # ターゲットの親ディレクトリを作成
    $targetDir = Split-Path $targetPath -Parent
    if (-not (Test-Path $targetDir)) {
      if ($DryRun) {
        Write-StepLog "[dry-run] mkdir $targetDir" -DryRun
      }
      else {
        New-Item -Path $targetDir -ItemType Directory -Force | Out-Null
      }
    }

    # 既存ファイル/リンクの退避
    Backup-ExistingFile -Path $targetPath -DryRun:$DryRun

    # シンボリックリンクの作成
    if ($DryRun) {
      Write-StepLog "[dry-run] New-Item -ItemType SymbolicLink -Path '$targetPath' -Target '$sourcePath'" -DryRun
      $createdCount++
      continue
    }

    try {
      New-Item -ItemType SymbolicLink -Path $targetPath -Target $sourcePath -Force | Out-Null
      Write-StepSuccess "[link] $desc : $targetPath -> $sourcePath"
      $createdCount++
    }
    catch {
      Write-StepFail "[fail] $desc — $($_.Exception.Message)"
      Write-StepWarn "ヒント: シンボリックリンク作成には開発者モードの有効化が必要です。"
    }
  }

  Write-StepLog "ドットファイル: $createdCount 作成, $skippedCount スキップ" -DryRun:$DryRun
}
