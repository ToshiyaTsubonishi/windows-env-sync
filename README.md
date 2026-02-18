# windows-env-sync

Windows の開発環境を同期するためのリポジトリです。  
`ai-config` が依存する実行基盤（`winget`, `git`, `node/npx`, `pwsh`, `gh`）を `winget` と User PATH で整備します。

## できること

- `winget` で必須ツールをインストール/更新
- User PATH に必要エントリを追記（重複排除）
- 必須コマンドの最終検証

## 構成

- `config/winget-packages.json`: パッケージ一覧とPATH定義
- `scripts/install-winget-packages.ps1`: winget導入同期
- `scripts/ensure-path.ps1`: User PATH 同期
- `scripts/sync-windows-env.ps1`: 一括実行

## 使い方

```powershell
cd $HOME/windows-env-sync
pwsh ./scripts/sync-windows-env.ps1 -NonInteractive
```

オプション:

- 追加パッケージも入れる  
  `pwsh ./scripts/sync-windows-env.ps1 -IncludeOptionalPackages -NonInteractive`
- インストールを飛ばしてPATHだけ更新  
  `pwsh ./scripts/sync-windows-env.ps1 -SkipInstall`
- ドライラン  
  `pwsh ./scripts/sync-windows-env.ps1 -DryRun`

## ai-config 連携

- `ai-config/scripts/fetch-repos.ps1` で `windows-env-sync` を取得
- `ai-config/scripts/sync-all.ps1` 実行時に、Windows では
  `../windows-env-sync/scripts/sync-windows-env.ps1` が存在すれば自動実行

## 注意

- PATH更新直後は新しいターミナルを開き直すと確実です
- `winget` が見つからない場合は Microsoft Store の **App Installer** を導入してください

