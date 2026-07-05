# パッケージマネージャ

- npmではなくpnpmを使うこと

# 設計フェーズのワークフロー(/design-interview)

plan / 設計段階では `/design-interview <機能名>` を使い、設計を確定させる前に
曖昧点と設計決定を網羅的に洗い出して人間の承認を得る。運用ルール:

- **確信も検証対象にする。** Claude の「質問(不確実性)」だけでなく「決定(確信)」も
  人間に確認する。間違った確信は質問として上がってこないため、決定の方が事故リスクが
  大きい。確定と判断した設計決定は `docs/design/<機能名>/assumptions.md` に全件残す。
- **網羅性はファイル、認知負荷は1件ずつ。** 曖昧点・決定・non-goals はすべて
  `docs/design/<機能名>/` のバックログに漏れなく書き出す。人間への提示は常に1件ずつ。
- **non-goals を明示する。** スコープ外と判断したことを暗黙に残さず assumptions.md に列挙する。
- **完了条件を守る。** questions.md の未回答ゼロ、assumptions.md の未承認ゼロを満たし、
  承認済み決定を decisions.md(軽量 ADR)に記録するまで、設計完了とせず実装へ進まない。
- テンプレートは `docs/design/_templates/`(questions / assumptions / decisions)。
