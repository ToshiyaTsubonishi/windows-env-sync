# scripts/modules/Setup-WSL2.ps1
# WSL2 環境の構築
# 前提: core/Logger.ps1, core/ErrorHandler.ps1 がドットソース済み

function Invoke-WSL2Setup {
    <#
  .SYNOPSIS
    WSL2 のインストール・初期設定を行う。
  .PARAMETER Distro
    インストールするディストリビューション名。デフォルトは Ubuntu。
  .PARAMETER DryRun
    $true の場合、実際のインストールを行わない。
  #>
    param(
        [string]$Distro = "Ubuntu",
        [switch]$DryRun
    )

    # TODO: 以下の機能を実装する
    # 1. WSL2 がインストール済みか確認 (wsl --status)
    # 2. 未インストールの場合:
    #    a. Windows 機能の有効化 (VirtualMachinePlatform, Microsoft-Windows-Subsystem-Linux)
    #    b. wsl --install --distribution $Distro
    #    c. WSL2 をデフォルトバージョンに設定 (wsl --set-default-version 2)
    # 3. .wslconfig の配置 (config/wslconfig があれば $HOME にコピー)
    # 4. 結果をログ出力
    # 注意: 管理者権限が必要な場合は事前チェックして案内する

    Write-StepWarn "Setup-WSL2 is not yet implemented (stub)." -DryRun:$DryRun
}
