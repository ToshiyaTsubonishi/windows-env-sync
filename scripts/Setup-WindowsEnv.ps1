<#
.SYNOPSIS
  Windows 開発環境セットアップの統括エントリーポイント。
.DESCRIPTION
  core/ の共通基盤を読み込み、modules/ の各機能を論理的な順序で実行する。
  各ステップは個別にスキップ可能。
.EXAMPLE
  pwsh ./scripts/Setup-WindowsEnv.ps1 -NonInteractive
.EXAMPLE
  pwsh ./scripts/Setup-WindowsEnv.ps1 -DryRun
.EXAMPLE
  pwsh ./scripts/Setup-WindowsEnv.ps1 -SkipOSConfig -SkipScoop -SkipDotfiles -SkipWSL
#>
[CmdletBinding()]
param(
    [string]$ConfigDir = (Join-Path (Resolve-Path (Join-Path $PSScriptRoot "..")).Path "config"),
    [switch]$IncludeOptionalPackages,
    [switch]$SkipOSConfig,
    [switch]$SkipInstall,
    [switch]$SkipScoop,
    [switch]$SkipPath,
    [switch]$SkipDotfiles,
    [switch]$SkipWSL,
    [switch]$SkipVerify,
    [switch]$NonInteractive,
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# --- OS ガード ---
if (-not $IsWindows) {
    Write-Host "Skipping: this script is for Windows only."
    return
}

# --- パス解決 ---
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$configWinget = Join-Path $ConfigDir "winget-packages.json"
$configScoop = Join-Path $ConfigDir "scoop-packages.json"
$configOS = Join-Path $ConfigDir "os-settings.json"
$configDotfiles = Join-Path $ConfigDir "dotfiles.json"

# --- core ロード ---
. (Join-Path $PSScriptRoot "core/Logger.ps1")
. (Join-Path $PSScriptRoot "core/ErrorHandler.ps1")

# --- modules ロード ---
. (Join-Path $PSScriptRoot "modules/Configure-OS.ps1")
. (Join-Path $PSScriptRoot "modules/Install-WingetPackages.ps1")
. (Join-Path $PSScriptRoot "modules/Install-ScoopPackages.ps1")
. (Join-Path $PSScriptRoot "modules/Sync-UserPath.ps1")
. (Join-Path $PSScriptRoot "modules/Deploy-Dotfiles.ps1")
. (Join-Path $PSScriptRoot "modules/Setup-WSL2.ps1")

# --- 実行開始 ---
Write-StepHeader "Windows Environment Setup"
Write-StepLog "ConfigDir : $ConfigDir" -DryRun:$DryRun
Write-StepLog "DryRun    : $DryRun" -DryRun:$DryRun

# 1. OS設定（レジストリ適用）
if (-not $SkipOSConfig) {
    Invoke-SafeStep -Name "OS設定 (レジストリ適用)" -ScriptBlock {
        Invoke-OSConfiguration -ConfigPath $configOS -DryRun:$DryRun
    }
}
else {
    Write-StepLog "[skip] OS設定" -DryRun:$DryRun
}

# 2. winget パッケージ導入
if (-not $SkipInstall) {
    Invoke-SafeStep -Name "winget パッケージ導入" -ScriptBlock {
        Invoke-WingetPackageSync `
            -ConfigPath $configWinget `
            -IncludeOptional:$IncludeOptionalPackages `
            -NonInteractive:$NonInteractive `
            -DryRun:$DryRun
    }
}
else {
    Write-StepLog "[skip] winget パッケージ導入" -DryRun:$DryRun
}

# 3. Scoop パッケージ導入
if (-not $SkipScoop) {
    Invoke-SafeStep -Name "Scoop パッケージ導入" -ScriptBlock {
        Invoke-ScoopPackageSync `
            -ConfigPath $configScoop `
            -IncludeOptional:$IncludeOptionalPackages `
            -DryRun:$DryRun
    }
}
else {
    Write-StepLog "[skip] Scoop パッケージ導入" -DryRun:$DryRun
}

# 4. User PATH 同期
if (-not $SkipPath) {
    Invoke-SafeStep -Name "User PATH 同期" -ScriptBlock {
        Invoke-UserPathSync -ConfigPath $configWinget -DryRun:$DryRun
    }
}
else {
    Write-StepLog "[skip] User PATH 同期" -DryRun:$DryRun
}

# 5. ドットファイル展開
if (-not $SkipDotfiles) {
    Invoke-SafeStep -Name "ドットファイル展開" -ScriptBlock {
        Invoke-DotfileDeploy -ConfigPath $configDotfiles -RepoRoot $repoRoot -DryRun:$DryRun
    }
}
else {
    Write-StepLog "[skip] ドットファイル展開" -DryRun:$DryRun
}

# 6. WSL2 構築
if (-not $SkipWSL) {
    Invoke-SafeStep -Name "WSL2 構築" -ScriptBlock {
        Invoke-WSL2Setup -DryRun:$DryRun
    }

    # 再起動が必要な場合は残りステップをスキップして安全に停止
    if (Test-RebootRequired) {
        Write-StepHeader "再起動が必要です"
        Write-StepWarn "Windows 機能を有効化したため、PCの再起動が必要です。"
        Write-StepWarn "再起動後にこのスクリプトを再実行してください。"
        Write-StepWarn ""
        Write-StepWarn "  Restart-Computer"
        Write-StepWarn ""
        exit 3010
    }
}
else {
    Write-StepLog "[skip] WSL2 構築" -DryRun:$DryRun
}

# 7. 必須コマンド検証
if (-not $SkipVerify) {
    Invoke-SafeStep -Name "必須コマンド検証" -ScriptBlock {
        $requiredCommands = @("winget", "git", "node", "npx", "pwsh")
        $missing = @()

        foreach ($name in $requiredCommands) {
            $cmd = Get-Command $name -ErrorAction SilentlyContinue
            if ($cmd) {
                Write-StepSuccess "$name -> $($cmd.Source)" -DryRun:$DryRun
            }
            else {
                Write-StepWarn "[missing] $name" -DryRun:$DryRun
                $missing += $name
            }
        }

        if ($missing.Count -gt 0 -and -not $DryRun) {
            throw "Missing required commands: $($missing -join ', '). Open a new terminal and rerun if PATH was just updated."
        }
    }
}
else {
    Write-StepLog "[skip] 必須コマンド検証" -DryRun:$DryRun
}

# --- サマリー ---
Write-StepSummary -DryRun:$DryRun
