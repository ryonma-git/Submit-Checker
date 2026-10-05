# 提出チェッカー

出席番号をタップして宿題の提出を確認する、iPad向けSwiftUIアプリとWeb版です。名簿登録は不要です。

公開Web版: https://ryonma-git.github.io/Submit-Checker/

## 使い方

1. 学年・組・提出日・課題名・人数を選びます。人数は初期30人、1〜40人。提出日は端末の今日です。
2. 「提出チェックを始める」を押します。同じクラス・日付・課題なら保存した人数で再開します。
3. 提出した人の番号をタップ。もう一度押すと未提出に戻ります。「ひとつ戻す」は直前の操作を取り消します。
4. 「CSVを書き出す」でクラス・提出日・課題名・全員の提出状況を保存します。

課題名は候補から選択、または自由入力できます。人数は記録作成時に固定されます。人数を間違えた場合は別の課題名で新規作成してください。欠番には現在対応していません。

「未提出を確認」は提出済みの番号を薄く表示し、席の位置は変えません。4・5・6・8列を選べます。名簿なしでは左上から出席番号順です。

## 保存とバックアップ

- Web: このブラウザのlocalStorageに操作ごとに保存します。外部へのデータ送信・解析・外部フォントはありません。GitHub Pagesへの通常のページアクセスは発生します。
- Swift: Application SupportのJSONファイルへアトミック保存します。Webとの自動同期はありません。
- 両版: 「バックアップを書き出す／読み込む」で共通JSON形式の記録を移せます。読み込みは現在の記録の**置き換え**です。
- CSV: UTF-8 BOM付き、CRLF、日本語見出し、全番号、提出確認時刻（UTC）を含みます。Excelの数式として解釈される文字列には接頭辞を付けます。CSVからの復元は提供していません。
- Safariの履歴・サイトデータ削除、プライベートブラウズの終了、アプリ削除等で保存内容を失う場合があります。大切な記録はバックアップを保管してください。
- Web版は初回オンライン読み込み後にキャッシュし、オフラインでも利用できます。Safariの「共有 → ホーム画面に追加」から利用できます。Safariとホーム画面版の保存領域の共有は前提にせず、利用場所を統一してください。

## iOS版

- iOS / iPadOS 17以降。SwiftUIによるネイティブUIです。WebViewラッパーではありません。
- `ios/SubmitChecker.xcodeproj` をXcodeで開き、Signing & Capabilitiesで自分のTeamを選び、接続したiPadへ実行してください。
- プロジェクト再生成: `xcodegen generate --spec ios/project.yml`
- ビルド（署名なし）:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project ios/SubmitChecker.xcodeproj -scheme SubmitChecker \
  -destination 'generic/platform=iOS' -derivedDataPath DerivedData \
  CODE_SIGNING_ALLOWED=NO build
```

## 開発・検証

```sh
swift test
npm ci
npm test
npx playwright install webkit
npm run test:e2e
npm run serve
```

E2Eはインストール済みChromeとPlaywright WebKitを使用します。localhost:4173で開けます。

- `Sources/SubmitCore`: Swiftのデータモデル、保存、CSV、厳格CSV名簿パーサー、将来の連携インターフェイス。
- `ios/SubmitChecker`: ネイティブ画面。
- `web`: 同一仕様をJavaScriptに移植した静的Webアプリ。フレームワーク・サーバー不要。
- `web-tests`, `Tests`: 保存、復元、境界、CSV、ブラウザ操作のテスト。
- `docs/EXTENSIONS.md`: 名簿・Apple Foundation Models・顔写真連携の導入点。

Web公開先はGitHub Pagesの`gh-pages`ブランチです。`main`に変更をコミット・pushした後、`bash scripts/deploy-web.sh`で`web/`だけを公開します。実データ・名簿・写真をGitへ追加しないでください。
