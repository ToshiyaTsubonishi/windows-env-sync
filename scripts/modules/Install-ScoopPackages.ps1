# scripts/modules/Install-ScoopPackages.ps1
# Scoop によるCLIツール群の導入
# 前提: core/Logger.ps1, core/ErrorHandler.ps1 がドットソース済み

function Test-ScoopInstalled {
    $cmd = Get-Command "scoop" -ErrorAction SilentlyContinue
    return ($null -ne $cmd)
}

function Install-ScoopBootstrap {
    <#
  .SYNOPSIS
    Scoop 本体をインストールする。
  #>
    param([switch]$DryRun)

    if (Test-ScoopInstalled) {
        Write-StepSuccess "Scoop は既にインストール済みです。" -DryRun:$DryRun
        return
    }

    if ($DryRun) {
        Write-StepLog "[dry-run] Invoke-RestMethod get.scoop.sh | Invoke-Expression" -DryRun
        return
    }

    Write-StepLog "Scoop をインストールしています..."
    try {
        Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force -ErrorAction SilentlyContinue
        Invoke-RestMethod -Uri "https://get.scoop.sh" | Invoke-Expression
        Write-StepSuccess "Scoop のインストールが完了しました。"
    }
    catch {
        throw "Scoop のインストールに失敗しました: $($_.Exception.Message)"
    }
}

function Invoke-ScoopPackageSync {
    <#
  .SYNOPSIS
    config/scoop-packages.json に基づき Scoop バケットとパッケージを同期する。
  #>
    param(
        [Parameter(Mandatory)][string]$ConfigPath,
        [switch]$IncludeOptional,
        [switch]$DryRun
    )

    if (-not (Test-Path $ConfigPath)) {
        throw "Config file not found: $ConfigPath"
    }

    # Scoop 本体の確保
    Install-ScoopBootstrap -DryRun:$DryRun

    $config = Get-Content -Path $ConfigPath -Raw | ConvertFrom-Json

    # --- バケットの追加 ---
    $buckets = @()
    if ($config.buckets) {
        $buckets = @($config.buckets)
    }

    if ($buckets.Count -gt 0) {
        # 既存バケット一覧を取得
        $existingBuckets = @()
        if (-not $DryRun -and (Test-ScoopInstalled)) {
            $existingBuckets = @(scoop bucket list 2>&1 |
                Where-Object { $_ -is [string] -or $_.GetType().Name -ne 'ErrorRecord' } |
                ForEach-Object { ($_ -split '\s+')[0] } |
                Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
        }

        foreach ($bucket in $buckets) {
            if ($existingBuckets -contains $bucket) {
                Write-StepSuccess "[skip] bucket '$bucket' は追加済みです。" -DryRun:$DryRun
                continue
            }

            if ($DryRun) {
                Write-StepLog "[dry-run] scoop bucket add $bucket" -DryRun
                continue
            }

            Write-StepLog "[bucket] $bucket を追加しています..."
            scoop bucket add $bucket 2>&1 | Out-Null
            Write-StepSuccess "[bucket] $bucket を追加しました。"
        }
    }

    # --- パッケージのインストール ---
    $packages = @()
    if ($config.required) {
        $packages += @($config.required)
    }
    if ($IncludeOptional -and $config.optional) {
        $packages += @($config.optional)
    }

    if ($packages.Count -eq 0) {
        Write-StepWarn "No scoop packages configured." -DryRun:$DryRun
        return
    }

    Write-StepLog "$($packages.Count) 件の Scoop パッケージを処理します。" -DryRun:$DryRun

    foreach ($pkg in $packages) {
        $id = [string]$pkg.id
        if ([string]::IsNullOrWhiteSpace($id)) {
            continue
        }

        # インストール済みチェック（冪等性）
        $alreadyInstalled = $false
        if (-not $DryRun -and (Test-ScoopInstalled)) {
            $cmd = Get-Command $id -ErrorAction SilentlyContinue
            if ($null -ne $cmd) {
                $alreadyInstalled = $true
            }
            else {
                # scoop list で確認
                $scoopList = scoop list $id 2>&1 | Out-String
                if ($scoopList -match [regex]::Escape($id)) {
                    $alreadyInstalled = $true
                }
            }
        }

        if ($alreadyInstalled) {
            Write-StepSuccess "[skip] $id は既にインストール済みです。" -DryRun:$DryRun
            continue
        }

        if ($DryRun) {
            Write-StepLog "[dry-run] scoop install $id" -DryRun
            continue
        }

        Write-StepLog "[install] $id"
        scoop install $id 2>&1 | ForEach-Object { Write-Host "  $_" }
        if ($LASTEXITCODE -ne 0) {
            Write-StepWarn "scoop install $id が非ゼロで終了しましたが、続行します。"
        }
        else {
            Write-StepSuccess "[installed] $id"
        }
    }

    Write-StepLog "Scoop package sync completed." -DryRun:$DryRun
}
