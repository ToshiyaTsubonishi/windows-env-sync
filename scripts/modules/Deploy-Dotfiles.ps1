# scripts/modules/Deploy-Dotfiles.ps1
# ドットファイルの展開
# 前提: core/Logger.ps1, core/ErrorHandler.ps1 がドットソース済み

function Invoke-DotfileDeploy {
    <#
  .SYNOPSIS
    config/dotfiles/ 配下のファイルを所定の場所にシンボリックリンクまたはコピーで展開する。
  .PARAMETER ConfigPath
    ドットファイル定義 JSON のパス（将来実装）。
  .PARAMETER DryRun
    $true の場合、実際のファイル操作を行わない。
  #>
    param(
        [string]$ConfigPath,
        [switch]$DryRun
    )

    # TODO: 以下の機能を実装する
    # 1. config/dotfiles.json を読み込む（対象ファイルと展開先のマッピング）
    # 2. 各ドットファイルについて:
    #    a. 展開先に既存ファイルがあればバックアップ
    #    b. シンボリックリンク作成（管理者権限不要な場合）またはコピー
    #    c. 結果をログ出力
    # 3. .gitconfig, .bashrc, PowerShell $PROFILE 等を想定

    Write-StepWarn "Deploy-Dotfiles is not yet implemented (stub)." -DryRun:$DryRun
}
