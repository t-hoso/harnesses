import json, sys, os

cmd = json.loads(os.environ["TOOL_INPUT"]).get("command", "")

if "git commit" not in cmd:
    sys.exit(0)

if "Co-Authored-By" in cmd or "Co-authored-by" in cmd:
    print(json.dumps({
        "decision": "block",
        "reason": "コミットメッセージに Co-Authored-By トレーラを含めないでください。"
    }))
    sys.exit(0)

print(json.dumps({
    "decision": "warn",
    "reason": (
        "コミットメッセージは以下に従ってください:\n"
        "- 件名は命令形で簡潔に (~50字)\n"
        "- diffから自明な情報を書かない (ファイルパス・配置先・ディレクトリ構造)\n"
        "- 選定経緯・除外したものを書かない\n"
        "- リポジトリの目的の言い直しを書かない\n"
        "- Co-Authored-By トレーラを付けない"
    )
}))
