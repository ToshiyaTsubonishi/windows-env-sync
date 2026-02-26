# windows-env-sync

Windows の開発環境を同期するためのリポジトリです。  
`ai-config` が依存する実行基盤（`winget`, `git`, `node/npx`, `pwsh`, `gh`）を `winget` と User PATH で整備します。

## できること

- `winget` で必須ツールをインストール/更新
- User PATH に必要エントリを追記（重複排除）
- ドットファイルの展開（予定）
- WSL2 環境の構築（予定）
- 必須コマンドの最終検証

## 構成

```
config/
  winget-packages.json        パッケージ一覧と PATH 定義
scripts/
  Setup-WindowsEnv.ps1        統括エントリーポイント
  core/
    Logger.ps1                共通ロギング
    ErrorHandler.ps1          共通エラーハンドリング
  modules/
    Install-WingetPackages.ps1  winget パッケージ導入
    Sync-UserPath.ps1           User PATH 同期
    Deploy-Dotfiles.ps1         ドットファイル展開（スタブ）
    Setup-WSL2.ps1              WSL2 構築（スタブ）
```

## 使い方

```powershell
cd $HOME/windows-env-sync
pwsh ./scripts/Setup-WindowsEnv.ps1 -NonInteractive
```

オプション:

- 追加パッケージも入れる  
  `pwsh ./scripts/Setup-WindowsEnv.ps1 -IncludeOptionalPackages -NonInteractive`
- インストールを飛ばして PATH だけ更新  
  `pwsh ./scripts/Setup-WindowsEnv.ps1 -SkipInstall`
- 個別ステップをスキップ  
  `pwsh ./scripts/Setup-WindowsEnv.ps1 -SkipDotfiles -SkipWSL`
- ドライラン  
  `pwsh ./scripts/Setup-WindowsEnv.ps1 -DryRun`

## ai-config 連携

- `ai-config/scripts/fetch-repos.ps1` で `windows-env-sync` を取得
- `ai-config/scripts/sync-all.ps1` 実行時に、Windows では
  `../windows-env-sync/scripts/Setup-WindowsEnv.ps1` が存在すれば自動実行

## 注意

- PATH 更新直後は新しいターミナルを開き直すと確実です
- `winget` が見つからない場合は Microsoft Store の **App Installer** を導入してください
