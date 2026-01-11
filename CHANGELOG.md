# Changelog

All notable changes to this project will be documented in this file.

## [0.1.0] - 2026-01-12

### Added
- **Liquid Glass Shader**: DialogBox にガラス風エフェクト (背景ぼかし、液状の歪み、エッジグロー)
- **Status Panels**: 左右にキャラクターステータス表示パネル (恐怖度/親密度)
- **Background Blur Layer**: メイン背景の後ろに暗くぼかした背景レイヤー
- **Top/Bottom UI Bars**: 映画的なVNスタイルの上下バー
- **Shaders**: `liquid_glass.gdshader`, `background_blur.gdshader`

### Changed
- DialogBox のスタイルをダークテーマに変更
- パラメータ表示を左右ステータスパネルに移動 (旧: 右上ParameterDisplay)

### Technical
- ステータス画像をPNG形式に変更 (GodotのGIF非対応のため)
- `.gitignore` を追加 (Godot 4用)
