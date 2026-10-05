# 検証記録

2026-10-06 / macOS arm64

- Swift `swift test`: 6件成功。人数・不正日付・切り替え・JSON往復・原子的ファイル保存・破損時の保護・記録分離・CSV・厳格名簿パーサー。
- JavaScript `npm test`: 5件成功。人数・日付・記録検証・保存・CSV。
- Playwright Chrome / WebKit: 各9件、計18件成功。初期30人、40人、再読み込み、同一課題の再開、記録分離、未提出表示、全員完了、取り消し、CSV実ダウンロード、バックアップ復元、保存失敗時のロールバック、破損時の保護、複数タブ、iPad縦横・携帯のレイアウト、オフライン再起動。
- iPad相当1194×834と820×1180では40人全員のボタンが画面内に入り、タップ領域44px以上。
- オフラインテストは専用HTTPサーバーを停止して検証。Playwright WebKitの`setOffline`には既知の不具合があるため、このエミュレーションAPIを使わない。 https://github.com/microsoft/playwright/issues/42775
- 公開URL: HTTPS 200、GitHub Pages build成功。公開版のWebKitで40人の操作・再読み込み後の復元・JavaScriptエラーなしを確認。
- SwiftUI全ソース: Xcode 27のiPhoneOS SDK、arm64 iOS 17ターゲットで`swiftc -typecheck`成功。
- Xcodeアプリ全体のビルド／シミュレーター実行: 初回コンポーネント（CoreSimulator）の未導入により保留。管理者権限で`sudo /Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild -runFirstLaunch`が必要。
- 実機iPadでのタップ・SafariからファイルアプリへのCSV保存、ネイティブアプリ署名・インストールは未実施。
- Apple Foundation Models・一般名簿解析・写真ツール接続は将来用インターフェイスのみ。動作確認済み機能として扱わない。
