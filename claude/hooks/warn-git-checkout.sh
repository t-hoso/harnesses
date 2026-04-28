#!/bin/bash
cmd=$(echo "$TOOL_INPUT" | jq -r '.command')
if echo "$cmd" | grep -q "git checkout"; then
  echo '{"decision":"warn","reason":"ブランチ操作にはgit checkoutではなくgit switchを使ってください。git switch <branch>で切り替え、git switch -c <branch>で作成できます。"}'
fi
