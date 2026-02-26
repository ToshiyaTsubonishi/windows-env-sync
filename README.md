# windows-env-sync

Windows の開発環境を同期するためのリポジトリです。  
OS の根幹設定から開発ツールの最適配置まで、GUI の手作業を完全排除して一気通貫で完了させます。

## できること

1. **OS設定** — レジストリ一括適用（隠しファイル表示・拡張子表示・タスクバー整頓・開発者モード等）
2. **winget パッケージ導入** — 必須開発ツールのインストール/更新
3. **Scoop パッケージ導入** — CLI ツール群の管理（jq, fzf, bat, eza, fd, delta 等）
4. **User PATH 同期** — 必要エントリの追記（重複排除）
5. **ドットファイル展開** — シンボリックリンクによる設定ファイルの即時反映
6. **WSL2 構築** — Windows 機能有効化・ディストリビューション導入（再起動考慮）
7. **必須コマンド検証** — 全ツールの最終確認

## 構成

```
config/
  winget-packages.json        winget パッケージ一覧と PATH 定義
  scoop-packages.json         Scoop バケット・パッケージ定義
  os-settings.json            レジストリ設定定義
  dotfiles.json               ドットファイルのリンクマッピング
dotfiles/                     (任意) 展開元のドットファイル実体
scripts/
  Setup-WindowsEnv.ps1        統括エントリーポイント
  core/
    Logger.ps1                共通ロギング
    ErrorHandler.ps1          共通エラーハンドリング・再起動フラグ
  modules/
    Configure-OS.ps1            OS設定 (レジストリ適用)
    Install-WingetPackages.ps1  winget パッケージ導入
    Install-ScoopPackages.ps1   Scoop パッケージ導入
    Sync-UserPath.ps1           User PATH 同期
    Deploy-Dotfiles.ps1         ドットファイル展開
    Setup-WSL2.ps1              WSL2 構築
```

## 使い方

```powershell
cd $HOME/windows-env-sync
pwsh ./scripts/Setup-WindowsEnv.ps1 -NonInteractive
```

### オプション

| フラグ | 説明 |
|---|---|
| `-IncludeOptionalPackages` | winget/Scoop の optional パッケージも導入 |
| `-SkipOSConfig` | OS設定 (レジストリ) をスキップ |
| `-SkipInstall` | winget パッケージ導入をスキップ |
| `-SkipScoop` | Scoop パッケージ導入をスキップ |
| `-SkipPath` | User PATH 同期をスキップ |
| `-SkipDotfiles` | ドットファイル展開をスキップ |
| `-SkipWSL` | WSL2 構築をスキップ |
| `-SkipVerify` | 必須コマンド検証をスキップ |
| `-DryRun` | 全ステップをドライランで実行 |
| `-NonInteractive` | 対話なしで実行 |

### 管理者権限が必要な操作

- 開発者モードの有効化 (HKLM レジストリ)
- WSL2 の Windows 機能有効化

管理者として実行:

```powershell
Start-Process pwsh -Verb RunAs -ArgumentList '-File', './scripts/Setup-WindowsEnv.ps1'
```

### WSL2 の再起動フロー

WSL2 の Windows 機能が未有効の場合、スクリプトは機能を有効化した後に **exit code 3010** で安全に停止し、PC の再起動を促します。再起動後にスクリプトを再実行すると、WSL2 のセットアップが続行されます。

## ai-config 連携

- `ai-config/scripts/fetch-repos.ps1` で `windows-env-sync` を取得
- `ai-config/scripts/sync-all.ps1` 実行時に、Windows では
  `../windows-env-sync/scripts/Setup-WindowsEnv.ps1` が存在すれば自動実行

## 注意

- PATH 更新直後は新しいターミナルを開き直すと確実です
- `winget` が見つからない場合は Microsoft Store の **App Installer** を導入してください
- シンボリックリンク作成には開発者モードの有効化が必要です
