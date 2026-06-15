#!/usr/bin/env bash
# PostToolUse(Bash) hook: after a `git add` stages changes, send the staged set
# to an independent reviewer (a separate `claude -p` session) and wait for its
# verdict. If the reviewer flags a violation the staging is rejected and the
# findings are handed back so they can be fixed before committing.
#
# Reviewing at `git add` (not `git commit`) catches issues one step earlier, and
# reviewing the staged diff means brand-new files are covered too. The reviewer
# is a real, fresh-context model — not this session grading its own work — which
# is why the verdict is trustworthy enough to gate on.
#
# Tunables (env): REVIEW_CMD (reviewer invocation, prompt on stdin),
# REVIEW_TIMEOUT (seconds). Any reviewer error or timeout fails OPEN so a flaky
# reviewer never blocks staging.
set -uo pipefail

# Don't review the reviewer: the spawned session inherits this guard.
[ -n "${CLAUDE_REVIEW_IN_PROGRESS:-}" ] && exit 0

RAW="${TOOL_INPUT:-}"; [ -n "$RAW" ] || RAW='{}'
CMD="$(printf '%s' "$RAW" | jq -r '.command // ""')"
case "$CMD" in
  *"git add"*) ;;
  *) exit 0 ;;
esac

DIFF="$(git diff --cached 2>/dev/null || true)"
[ -n "$DIFF" ] || exit 0

# Keep the prompt bounded on large changes.
MAX=200000
if [ "${#DIFF}" -gt "$MAX" ]; then
  DIFF="${DIFF:0:$MAX}
[... diff truncated ...]"
fi

read -r -d '' RUBRIC <<'EOF' || true
あなたはコードレビュアーです。以下の git diff のうち、**新規に追加された行(先頭が +)** だけを
審査対象とし、下記ルーブリックへの違反を検出してください。既存行や削除行は対象外です。

# ルーブリック
## 1. 不要な否定・履歴コメントの禁止
- コメントは「今のコードが何を・なぜするか」を説明するもの。
- 「かつて何があったか / 何をやめたか / 何を使っていないか」を説明するコメントは書かない
  (履歴は git が持つ)。削除・変更の作業ログをコードに残さない。
- 判断テスト: 「その対象が最初から存在しなかったとしても、このコメントを書くか?」
  → 書かないなら違反。
- 例外: その不在が将来の読者を確実に罠にかける場合(あえて X しない理由など)で、
  理由が明記されているものは違反としない。

# 出力形式(厳守)
- 違反が無ければ、最初の行に厳密に `REVIEW: PASS` とだけ出力する。
- 違反があれば、最初の行に `REVIEW: FAIL` と出力し、続けて各違反を
  `- <file>:<該当箇所> 該当コメント / なぜ違反か / どう直すか` の箇条書きで簡潔に書く。
EOF

PROMPT="$RUBRIC

# 対象の diff
\`\`\`diff
$DIFF
\`\`\`"

REVIEW_CMD="${REVIEW_CMD:-claude -p --model claude-haiku-4-5-20251001}"
OUT="$(printf '%s' "$PROMPT" | CLAUDE_REVIEW_IN_PROGRESS=1 timeout "${REVIEW_TIMEOUT:-120}" $REVIEW_CMD 2>/dev/null || true)"

# Only an explicit FAIL blocks; empty/garbled/PASS all let staging through.
if printf '%s' "$OUT" | grep -q 'REVIEW: FAIL'; then
  FINDINGS="$(printf '%s' "$OUT" | grep -v 'REVIEW: FAIL')"
  REASON="ステージ前レビューで指摘がありました。コメントを直してから再度 git add してください。
背景説明として本当に必要なコメントは、上の判断テストに照らして残して構いません。

$FINDINGS"
  jq -n --arg r "$REASON" '{decision: "block", reason: $r}'
fi
exit 0
