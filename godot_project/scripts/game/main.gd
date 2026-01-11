# Main - メインゲームシーンコントローラー
extends Node

@onready var background_image: TextureRect = $Background/BackgroundImage
@onready var background_blurred: TextureRect = $Background/BackgroundBlurred
@onready var character_left: TextureRect = $Characters/CharacterLeft
@onready var character_center: TextureRect = $Characters/CharacterCenter
@onready var character_right: TextureRect = $Characters/CharacterRight

@onready var dialog_box: Panel = $UI/NovelUI/DialogBox
@onready var speaker_name: Label = $UI/NovelUI/DialogBox/SpeakerName
@onready var dialog_text: RichTextLabel = $UI/NovelUI/DialogBox/DialogText
@onready var click_indicator: Label = $UI/NovelUI/DialogBox/ClickIndicator
@onready var choices_container: VBoxContainer = $UI/NovelUI/ChoicesContainer

@onready var status_left_image: TextureRect = $UI/NovelUI/StatusLeft/Image
@onready var status_right_image: TextureRect = $UI/NovelUI/StatusRight/Image
@onready var fear_label_left: Label = $UI/NovelUI/StatusLeft/InfoBox/FearLabel
@onready var fear_label_right: Label = $UI/NovelUI/StatusRight/InfoBox/FearPanel/FearLabel
@onready var kizuna_label: Label = $UI/NovelUI/StatusRight/InfoBox/IntimacyPanel/IntimacyLabel
# @onready var kegare_label: Label = $UI/NovelUI/ParameterDisplay/KegareLabel

@onready var screen_effects: CanvasLayer = $ScreenEffects
@onready var command_executor: Node = $CommandExecutor

# テキスト表示設定
var text_speed: float = 0.03  # 1文字あたりの秒数
var current_full_text: String = ""
var is_text_displaying: bool = false
var text_display_tween: Tween

# 選択肢ボタンテンプレート
var choice_button_scene: PackedScene

func _ready() -> void:
	# シグナル接続
	ScenarioManager.scene_changed.connect(_on_scene_changed)
	ScenarioManager.text_display_requested.connect(_on_text_display_requested)
	ScenarioManager.character_display_requested.connect(_on_character_display_requested)
	ScenarioManager.choices_display_requested.connect(_on_choices_display_requested)
	ScenarioManager.qte_requested.connect(_on_qte_requested)
	
	GameManager.parameter_changed.connect(_on_parameter_changed)
	GameManager.game_over.connect(_on_game_over)
	
	# CommandExecutor設定
	if command_executor:
		command_executor.set_screen_effects(screen_effects)
	
	# 初期化
	update_parameter_display()
	hide_choices()
	click_indicator.visible = false
	
	# Load Status Images (PNG versions)
	if ResourceLoader.exists("res://assets/images/mai-hinata.png"):
		status_left_image.texture = load("res://assets/images/mai-hinata.png")
	if ResourceLoader.exists("res://assets/images/yui-shitsuki.png"):
		status_right_image.texture = load("res://assets/images/yui-shitsuki.png")
	
	# シナリオ開始
	GameManager.load_system_data()
	GameManager.reset_game()
	
	# 最初のシーンを開始
	call_deferred("_start_first_scene")
	
	print("[Main] Ready")

func _start_first_scene() -> void:
	# シナリオの最初のシーンを特定して開始
	var scene_ids = ScenarioManager.get_all_scene_ids()
	if scene_ids.size() > 0:
		ScenarioManager.start_scene(scene_ids[0])
	else:
		# フォールバック: P0 または scene1
		if ScenarioManager.find_scene("P0"):
			ScenarioManager.start_scene("P0")
		elif ScenarioManager.find_scene("scene1"):
			ScenarioManager.start_scene("scene1")
		else:
			push_error("[Main] No starting scene found")

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		handle_click()
	elif event.is_action_pressed("debug_toggle"):
		toggle_debug_ui()

func handle_click() -> void:
	if choices_container.visible:
		return  # 選択肢表示中はクリック無効
	
	if is_text_displaying:
		# テキスト表示中→全文表示
		complete_text_display()
	else:
		# テキスト表示完了→次へ
		ScenarioManager.advance_text()

func _on_scene_changed(scene_data: Dictionary) -> void:
	# 背景変更
	if scene_data.has("bg"):
		load_background(scene_data["bg"])
	elif scene_data.has("background"):
		load_background(scene_data["background"])
	
	# BGM変更
	if scene_data.has("bgm"):
		AudioManager.play_bgm(scene_data["bgm"])
	
	# キャラクター表示
	if scene_data.has("character"):
		show_character(scene_data["character"])

func _on_text_display_requested(speaker: String, text: String) -> void:
	show_text(speaker, text)

func _on_character_display_requested(character_data) -> void:
	show_character(character_data)

func _on_choices_display_requested(choices: Array) -> void:
	show_choices(choices)

func _on_qte_requested(qte_data: Dictionary) -> void:
	start_qte(qte_data)

func _on_parameter_changed(_param_name: String, _new_value: int) -> void:
	update_parameter_display()

func _on_game_over() -> void:
	print("[Main] GAME OVER!")
	# ゲームオーバー処理
	dialog_text.text = "[center][color=red]GAME OVER[/color][/center]"
	speaker_name.text = ""
	# 数秒後にタイトルへ戻る
	get_tree().create_timer(3.0).timeout.connect(func():
		# タイトル画面へ遷移（実装時に追加）
		pass
	)

func load_background(bg_path: String) -> void:
	var full_path = bg_path
	if not bg_path.begins_with("res://"):
		full_path = "res://assets/images/%s" % bg_path
	
	if ResourceLoader.exists(full_path):
		var tex = load(full_path)
		background_image.texture = tex
		# 暗くぼかす背景にも同じ画像を設定
		if background_blurred:
			background_blurred.texture = tex
	else:
		push_warning("[Main] Background not found: %s" % full_path)

func show_character(char_data) -> void:
	# char_dataが辞書の場合
	if typeof(char_data) == TYPE_DICTIONARY:
		var image_path = char_data.get("image", "")
		var position = char_data.get("position", "center")
		
		var target: TextureRect
		match position:
			"left":
				target = character_left
			"right":
				target = character_right
			_:
				target = character_center
		
		load_character_image(target, image_path)
	# char_dataが文字列の場合（画像パス直接指定）
	elif typeof(char_data) == TYPE_STRING:
		load_character_image(character_center, char_data)

func load_character_image(target: TextureRect, image_path: String) -> void:
	if image_path == "":
		target.texture = null
		return
	
	var full_path = image_path
	if not image_path.begins_with("res://"):
		full_path = "res://assets/images/%s" % image_path
	
	if ResourceLoader.exists(full_path):
		target.texture = load(full_path)
	else:
		push_warning("[Main] Character image not found: %s" % full_path)

func show_text(speaker: String, text: String) -> void:
	speaker_name.text = speaker
	current_full_text = text
	dialog_text.text = ""
	dialog_text.visible_ratio = 0.0
	click_indicator.visible = false
	is_text_displaying = true
	
	# タイプライター効果
	if text_display_tween and text_display_tween.is_valid():
		text_display_tween.kill()
	
	dialog_text.text = text
	text_display_tween = create_tween()
	var duration = text.length() * text_speed
	text_display_tween.tween_property(dialog_text, "visible_ratio", 1.0, duration)
	text_display_tween.tween_callback(func():
		is_text_displaying = false
		click_indicator.visible = true
	)

func complete_text_display() -> void:
	if text_display_tween and text_display_tween.is_valid():
		text_display_tween.kill()
	dialog_text.visible_ratio = 1.0
	is_text_displaying = false
	click_indicator.visible = true

func show_choices(choices: Array) -> void:
	# 既存のボタンをクリア
	for child in choices_container.get_children():
		child.queue_free()
	
	# 選択肢ボタンを生成
	for i in choices.size():
		var option = choices[i]
		var button = Button.new()
		button.text = option.get("text", "選択肢 %d" % (i + 1))
		button.custom_minimum_size = Vector2(400, 50)
		button.pressed.connect(func(): select_choice(i))
		choices_container.add_child(button)
	
	choices_container.visible = true
	dialog_box.visible = false

func hide_choices() -> void:
	choices_container.visible = false
	dialog_box.visible = true

func select_choice(index: int) -> void:
	hide_choices()
	ScenarioManager.select_choice(index)

func start_qte(qte_data: Dictionary) -> void:
	# QTE UIを表示（別途実装）
	print("[Main] QTE Started: %s" % str(qte_data))
	# 仮実装: 自動成功
	ScenarioManager.handle_qte_result(true, qte_data)

func update_parameter_display() -> void:
	if fear_label_left: fear_label_left.text = "恐怖度: %d" % GameManager.fear
	if fear_label_right: fear_label_right.text = "恐怖度: %d" % GameManager.fear
	if kizuna_label: kizuna_label.text = "親密度: %d" % GameManager.kizuna
	# kegare_label.text = "穢れ: %d" % GameManager.kegare

func toggle_debug_ui() -> void:
	# デバッグUI表示切り替え（別途実装）
	print("[Main] Debug UI toggle (not implemented yet)")
