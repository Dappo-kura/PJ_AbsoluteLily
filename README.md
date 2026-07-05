# 迷界ユリメトリカ（PJ_AbsoluteLily）

都市伝説×百合ホラーのQTE付きビジュアルノベル。Godot 4.5 製。

放課後、古いプリクラ機で異世界に迷い込んだ結と舞が、都市伝説の怪異たちをQTEで切り抜けながら帰還を目指す全7章のストーリー。

## 必要環境

- [Godot 4.5](https://godotengine.org/)（エクスポートも4.5系を使用。CIは4.5）
- Python 3.x（シナリオ変換ツールを使う場合のみ）

## 起動方法

Godot エディタで `godot_project/project.godot` を開いて実行（F5）。
タイトル画面 →「はじめから」でゲーム開始。

### 操作

| 操作 | 機能 |
|------|------|
| クリック / Space / Enter | テキスト送り・QTEの選択肢タップ |
| Esc / 右クリック | ポーズメニュー（セーブ／ロード／タイトルへ） |
| F1 | デバッグUI（シーンジャンプ等） |

セーブデータは `user://save_<slot>.json`（Windows: `%APPDATA%\Godot\app_userdata\都市伝説JK百合ホラー\`）に保存されます。スロットは3つ。

## フォルダ構成

```
00_document/      仕様書・実装計画・画面遷移図
99_html_mock/     初期のHTMLプロトタイプ（参考資料）
scenario/         シナリオ台本（全7章 .txt、これが正本）
tools/            シナリオ変換ツール
godot_project/    Godot プロジェクト本体
  data/scenario.json   ゲームが読むシナリオデータ（自動生成物）
scenario_agent.py Claude APIでシナリオ草稿を作る補助CLI
```

## シナリオ更新の流れ

**`godot_project/data/scenario.json` は自動生成ファイルです。直接編集しないでください。**

1. `scenario/*.txt`（台本）を編集する
2. 変換を実行する:
   ```
   python tools/scenario_converter.py
   ```
3. `tools/conversion_report.md` の警告を確認する
4. 分岐先の修正など台本で表現できない調整は `tools/scenario_overrides.json` に書く（再生成しても消えない）

台本の書式（場面区切り・台詞・QTEマーカー等）は `tools/scenario_converter.py` 冒頭のコメントを参照。

## ゲームの分岐構造

- 各章のQTEは **成功／失敗／ハーレム** の3ルート
- 失敗ルートは章ごとのバッドエンド（第2章のみ合流して継続）
- 最終章でエンディングA（トゥルー）／エンディングB（ハーレム）に分岐
- 恐怖度(fear)が100に達するとゲームオーバー

## CI

GitHub Actions（`.github/workflows/godot-ci.yml`）:
- `main` / `develop` への push でプロジェクト検証
- `v*` タグ push で Windows / Linux / Web 向けエクスポート
