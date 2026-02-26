# scripts/core/ErrorHandler.ps1
# 共通エラーハンドリングユーティリティ
# Usage: . "$PSScriptRoot/../core/ErrorHandler.ps1" でドットソースして使用
# 前提: Logger.ps1 が先にドットソースされていること

# モジュールスコープでエラーを蓄積するリスト
if (-not (Get-Variable -Name '_StepErrors' -Scope Script -ErrorAction SilentlyContinue)) {
  $script:_StepErrors = [System.Collections.Generic.List[string]]::new()
}

function Invoke-SafeStep {
  <#
  .SYNOPSIS
    ScriptBlock を安全に実行し、失敗時にログ出力 + エラー蓄積する。
  .PARAMETER Name
    ステップの表示名。
  .PARAMETER ScriptBlock
    実行するスクリプトブロック。
  .PARAMETER StopOnError
    $true の場合、失敗時に即座に throw する。デフォルトは $false（蓄積モード）。
  #>
  param(
    [Parameter(Mandatory)][string]$Name,
    [Parameter(Mandatory)][scriptblock]$ScriptBlock,
    [switch]$StopOnError
  )

  Write-StepHeader $Name
  try {
    & $ScriptBlock
    Write-StepSuccess "完了: $Name"
  }
  catch {
    $errMsg = "$Name : $($_.Exception.Message)"
    Write-StepFail $errMsg
    $script:_StepErrors.Add($errMsg)

    if ($StopOnError) {
      throw $_
    }
  }
}

function Get-StepErrors {
  <#
  .SYNOPSIS
    蓄積されたエラーのリストを返す。
  #>
  return $script:_StepErrors
}

function Write-StepSummary {
  <#
  .SYNOPSIS
    実行結果のサマリーを表示する。エラーがあれば一覧表示して throw する。
  #>
  param([switch]$DryRun)

  Write-StepHeader "実行結果サマリー"

  $errors = @(Get-StepErrors)
  if ($errors.Count -eq 0) {
    Write-StepSuccess "全ステップが正常に完了しました。" -DryRun:$DryRun
  }
  else {
    Write-StepFail "$($errors.Count) 件のエラーが発生しました:" -DryRun:$DryRun
    foreach ($e in $errors) {
      Write-Host "  - $e" -ForegroundColor Red
    }
    if (-not $DryRun) {
      throw "環境セットアップは一部失敗しました。上記エラーを確認してください。"
    }
  }
}
