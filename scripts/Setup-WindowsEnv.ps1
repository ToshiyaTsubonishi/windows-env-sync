<#
.SYNOPSIS
  Windows 開発環境セットアップの統括エントリーポイント。
.DESCRIPTION
  core/ の共通基盤を読み込み、modules/ の各機能を順序立てて実行する。
  各ステップは個別にスキップ可能。
.EXAMPLE
  pwsh ./scripts/Setup-WindowsEnv.ps1 -NonInteractive
.EXAMPLE
  pwsh ./scripts/Setup-WindowsEnv.ps1 -DryRun
.EXAMPLE
  pwsh ./scripts/Setup-WindowsEnv.ps1 -SkipInstall -SkipDotfiles -SkipWSL
#>
[CmdletBinding()]
param(
    [string]$ConfigPath = (Join-Path (Resolve-Path (Join-Path $PSScriptRoot "..")).Path "config/winget-packages.json"),
    [switch]$IncludeOptionalPackages,
    [switch]$SkipInstall,
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

# --- core ロード ---
. (Join-Path $PSScriptRoot "core/Logger.ps1")
. (Join-Path $PSScriptRoot "core/ErrorHandler.ps1")

# --- modules ロード ---
. (Join-Path $PSScriptRoot "modules/Install-WingetPackages.ps1")
. (Join-Path $PSScriptRoot "modules/Sync-UserPath.ps1")
. (Join-Path $PSScriptRoot "modules/Deploy-Dotfiles.ps1")
. (Join-Path $PSScriptRoot "modules/Setup-WSL2.ps1")

# --- 実行開始 ---
Write-StepHeader "Windows Environment Setup"
Write-StepLog "ConfigPath : $ConfigPath" -DryRun:$DryRun
Write-StepLog "DryRun     : $DryRun" -DryRun:$DryRun

# 1. winget パッケージ導入
if (-not $SkipInstall) {
    Invoke-SafeStep -Name "winget パッケージ導入" -ScriptBlock {
        Invoke-WingetPackageSync `
            -ConfigPath $ConfigPath `
            -IncludeOptional:$IncludeOptionalPackages `
            -NonInteractive:$NonInteractive `
            -DryRun:$DryRun
    }
}
else {
    Write-StepLog "[skip] winget パッケージ導入" -DryRun:$DryRun
}

# 2. User PATH 同期
if (-not $SkipPath) {
    Invoke-SafeStep -Name "User PATH 同期" -ScriptBlock {
        Invoke-UserPathSync -ConfigPath $ConfigPath -DryRun:$DryRun
    }
}
else {
    Write-StepLog "[skip] User PATH 同期" -DryRun:$DryRun
}

# 3. ドットファイル展開
if (-not $SkipDotfiles) {
    Invoke-SafeStep -Name "ドットファイル展開" -ScriptBlock {
        Invoke-DotfileDeploy -DryRun:$DryRun
    }
}
else {
    Write-StepLog "[skip] ドットファイル展開" -DryRun:$DryRun
}

# 4. WSL2 構築
if (-not $SkipWSL) {
    Invoke-SafeStep -Name "WSL2 構築" -ScriptBlock {
        Invoke-WSL2Setup -DryRun:$DryRun
    }
}
else {
    Write-StepLog "[skip] WSL2 構築" -DryRun:$DryRun
}

# 5. 必須コマンド検証
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
