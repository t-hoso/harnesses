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

(A) と判断したときのみ実装に着手し、(B) のときは編集ツールを使わず回答だけを返すこと。
</intent-classification>
EOF

# Emit as additionalContext so it is injected into Claude's context for this turn.
printf '{"hookSpecificOutput":{"hookEventName":"UserPromptSubmit","additionalContext":%s},"suppressOutput":true}\n' \
  "$(printf '%s' "$CONTEXT" | jq -Rs .)"
