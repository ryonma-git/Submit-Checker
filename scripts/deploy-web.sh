#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ -n "$(git status --porcelain)" ]]; then
  echo '変更をコミットしてから公開してください。' >&2
  exit 1
fi
npm test
publish_commit=$(git subtree split --prefix web main)
git push origin "$publish_commit:refs/heads/gh-pages"
echo 'GitHub Pagesへ送信しました。公開状況は gh api repos/ryonma-git/Submit-Checker/pages/builds/latest で確認できます。'
