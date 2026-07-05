# CLAUDE.md

Godot 4.5 製ビジュアルノベル「迷界ユリメトリカ」。会話・コメント・コミットは日本語基調（コミットの先頭は `feat:`/`fix:` 等の英語プレフィックス）。

## 最重要ルール

- **`godot_project/data/scenario.json` は自動生成物。直接編集禁止。** 台本 `scenario/*.txt` か `tools/scenario_overrides.json` を編集し、`python tools/scenario_converter.py` で再生成する。
- GDScript はタブインデント。既存コードは日本語コメント。
- このリポジトリは OneDrive 配下にある。git 操作が稀にファイルロックで失敗したらリトライする。

## アーキテクチャ

オートロード3つ（`project.godot` 定義）がゲームの背骨:

- `GameManager` (`scripts/autoload/game_manager.gd`) — パラメータ（fear/kizuna/kegare、fear≥100でgame_overシグナル）、フラグ、セーブ/ロード（`user://save_<slot>.json`、スロット3つ、`resume_from_save()` で復帰）、タイトルからの継続用 `pending_load_slot`
- `ScenarioManager` (`scripts/autoload/scenario_manager.gd`) — scenario.json のロード、シーン進行（`start_scene`/`advance_text`/`process_next_event`）、シグナルでUIへ通知。デバッグビルドでは scenario.json をホットリロード
- `AudioManager` (`scripts/autoload/audio_manager.gd`) — BGM/SE。ファイルは `assets/audio/` から名前解決

シーンフロー: `scenes/ui/title.tscn`（メインシーン）→ `scenes/game/main.tscn`。
`main.gd` が ScenarioManager のシグナルを受けてテキスト/立ち絵/選択肢/QTEを表示する。ポーズメニュー・セーブUI・ゲームオーバー/エンディング画面は `scripts/ui/pause_menu.gd`・`save_load_menu.gd`・`main.gd` 内でコード構築（tscnではない）。

## シナリオデータ仕様（scenario.json）

```
chapters[] > scenes[] > { id, title?, bg?, bgm?, events[], next? | isEnding+endingId, qte? }
```

- イベント: `{type:"line", speaker, text, character?}` が基本。`se`/`bgm`/`flag`/`choices`/`item_gain` あり
- シーン root の `qte`: `{text, labels:[成功ラベル], harem_label?, duration, success_to, fail_to, harem_to}`
- QTE結果は3値: `"success"` / `"fail"` / `"harem"`（`qte_controller.gd` の `qte_completed` シグナル → `ScenarioManager.handle_qte_result_typed`）
- エンディングシーン: `isEnding: true` + `endingId` + `ending_label?` + `ending_image?`（→ `ScenarioManager.ending_reached` シグナル → main.gd が全画面表示）
- シーンID規約: `C<章>_S<連番>`（通常）、`C<章>_Q<n>_SUCCESS/FAIL/HAREM`（QTEルート）

## 検証方法

Godot エディタ不在でも headless で確認できる（winget の Godot でも可）:

```
godot --headless --path godot_project --import --quit          # インポートエラー確認
godot --headless --path godot_project --quit-after 180         # タイトル起動確認
godot --headless --path godot_project --quit-after 180 "res://scenes/game/main.tscn"  # 本編起動確認
```

変換後は `tools/conversion_report.md` の警告と、シーンリンク切れ（next/success_to等が存在しないIDを指す）を確認する。

## 既知の未実装・保留

- QTE方式: 仕様書は Shrinking Ring 方式だが実装はグリッド配置クリック方式（`qte_preset` は scenario_legacy.json 参照）。方式決定は保留中
- 音量設定UI・バックログ・ギャラリーは未実装
- kegare（穢れ）パラメータは内部処理のみでUI非表示
- 巨大GIF（status用 20MB×2ほか）の最適化は保留
