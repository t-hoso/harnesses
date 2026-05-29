#!/usr/bin/env bash
# UserPromptSubmit hook: inject a standing instruction telling Claude to first
# classify the user's message — "implement now" vs "just answer / discuss" —
# before responding. The classification itself is done by Claude, not here.
set -euo pipefail

read -r -d '' CONTEXT <<'EOF' || true
<intent-classification>
このメッセージに応答する前に、まずユーザーの意図を分類せよ:

(A) 即座にコードの実装・変更・ファイル編集を行うべき指示
(B) 実装ではなく、回答・説明・調査・相談・レビューだけを返すべきもの

分類の指針:
- 「実装して」「直して」「追加して」「作って」「修正して」など、変更そのものを
  明確に要求している → (A)
- 「どう思う?」「可能?」「なぜ?」「教えて」「比較して」「どうすべき?」など、
  情報・判断・意見を求めている → (B)
- 判断に迷う、または要求が曖昧な場合は (B) を選び、実装せずにまず確認・回答する。

(A) と判断したときのみコードの実装・変更に着手すること。着手する場合は原則テストファースト
(先に失敗するテストを書き、それを通す形で実装する)で進める(ただしテストが馴染まない変更
——設定・ドキュメント・UI微調整・調査目的の試行など——にまで無理に適用しない)。(B) のときは
コード実装には踏み込まず、まず回答・確認を優先する(ただしドキュメント編集など、回答のために
必要なファイル操作まで禁じるものではない)。
</intent-classification>
EOF

# Emit as additionalContext so it is injected into Claude's context for this turn.
printf '{"hookSpecificOutput":{"hookEventName":"UserPromptSubmit","additionalContext":%s},"suppressOutput":true}\n' \
  "$(printf '%s' "$CONTEXT" | jq -Rs .)"
