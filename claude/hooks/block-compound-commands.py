import json, sys, os

cmd = json.loads(os.environ["TOOL_INPUT"]).get("command", "")
for op in ["&&", "||", "|", ";", "`", "$("]:
    if op in cmd:
        print(json.dumps({
            "decision": "block",
            "reason": "複合コマンドは禁止です。コマンドを分けて個別に実行してください。パイプの代わりにリダイレクト(> /tmp/out.txt)でファイルに書き出し、Readツールで読んでください。"
        }))
        sys.exit(0)
