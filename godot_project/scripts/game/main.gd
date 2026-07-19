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
@onready var fear_bar: ProgressBar = $UI/NovelUI/StatusLeft/InfoBox/FearBar
@onready var kizuna_label: Label = $UI/NovelUI/StatusRight/InfoBox/IntimacyLabel
@onready var kizuna_bar: ProgressBar = $UI/NovelUI/StatusRight/InfoBox/IntimacyBar
# @onready var kegare_label: Label = $UI/NovelUI/ParameterDisplay/KegareLabel

# パラメータバーの塗り色（恐怖度は危険度で色が変わる）
var _fear_fill_style: StyleBoxFlat = null
var _kizuna_fill_style: StyleBoxFlat = null
var _fear_color_normal := Color(0.55, 0.75, 0.45, 1.0)   # 平常（緑）
var _fear_color_warn := Color(0.95, 0.8, 0.25, 1.0)      # 警戒（黄, fear>=70）
var _fear_color_danger := Color(0.9, 0.2, 0.2, 1.0)      # 危険（赤, fear>=90）
var _kizuna_color := Color(0.92, 0.42, 0.68, 1.0)        # 親密度（ピンク）

@onready var screen_effects: CanvasLayer = $ScreenEffects
@onready var command_executor: Node = $CommandExecutor
@onready var qte_controller: Control = $UI/QTEController

# QTE用
var current_qte_data: Dictionary = {}

# テキスト表示設定
var text_speed: float = 0.03  # 1文字あたりの秒数
var current_full_text: String = ""
var is_text_displaying: bool = false
var text_display_tween: Tween
var _advance_guard_until_ms: int = 0  # この時刻までは手動の次送りを抑止
const ADVANCE_GUARD_MS: int = 150
var _click_indicator_tween: Tween = null

# ADV送り制御（オート/スキップ）。周回テンポ改善用。設定はセッション内のみ（セーブ非依存）
var is_auto_mode: bool = false          # オートモード（トグル）
var auto_advance_delay: float = 1.2     # テキスト完了からオート送りまでの待機秒
var _auto_timer: float = 0.0            # オート送りの残り待機時間
var skip_interval: float = 0.04         # スキップ時の送り間隔（秒）
var _skip_accum: float = 0.0            # スキップ送りの間隔計測
var auto_indicator: Label = null        # 「AUTO」表示
var skip_indicator: Label = null        # 「SKIP」表示

# 選択肢ボタンテンプレート
var choice_button_scene: PackedScene

# メニュー/オーバーレイ状態
const TITLE_SCENE := "res://scenes/ui/title.tscn"
var pause_menu: PauseMenu = null
var save_load_menu: SaveLoadMenu = null
var overlay_layer: CanvasLayer = null
var is_game_over: bool = false
var is_ending_shown: bool = false
var end_overlay: Control = null

func _ready() -> void:
	# シグナル接続
	ScenarioManager.scene_changed.connect(_on_scene_changed)
	ScenarioManager.text_display_requested.connect(_on_text_display_requested)
	ScenarioManager.character_display_requested.connect(_on_character_display_requested)
	ScenarioManager.choices_display_requested.connect(_on_choices_display_requested)
	ScenarioManager.qte_requested.connect(_on_qte_requested)
	ScenarioManager.ending_reached.connect(_on_ending_reached)

	GameManager.parameter_changed.connect(_on_parameter_changed)
	GameManager.game_over.connect(_on_game_over)

	# オーバーレイ用レイヤー（ゲームオーバー/エンディング/メニュー表示先）
	overlay_layer = CanvasLayer.new()
	overlay_layer.layer = 100
	add_child(overlay_layer)
	
	# CommandExecutor設定
	if command_executor:
		command_executor.set_screen_effects(screen_effects)
	
	# QTE シグナル接続
	if qte_controller:
		qte_controller.qte_completed.connect(_on_qte_completed)
	
	# 初期化
	_setup_parameter_bars()
	update_parameter_display()
	hide_choices()
	click_indicator.visible = false
	_setup_adv_indicators()
	
	# Load Status Images (PNG versions)
	if ResourceLoader.exists("res://assets/images/mai-hinata.png"):
		status_left_image.texture = load("res://assets/images/mai-hinata.png")
	if ResourceLoader.exists("res://assets/images/yui-shitsuki.png"):
		status_right_image.texture = load("res://assets/images/yui-shitsuki.png")
	
	# シナリオ開始
	GameManager.load_system_data()

	# 最初のシーンを開始（つづきからの場合はセーブ地点から再開）
	call_deferred("_start_first_scene")

	print("[Main] Ready")

func _start_first_scene() -> void:
	# タイトル画面「つづきから」経由の場合
	if GameManager.pending_load_slot >= 0:
		var slot = GameManager.pending_load_slot
		GameManager.pending_load_slot = -1
		if GameManager.resume_from_save(slot):
			return
		push_warning("[Main] Failed to resume from slot %d, starting new game" % slot)

	GameManager.reset_game()

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
	# 終了画面は専用ボタンで操作する。ここでui_acceptを処理するとボタン入力を横取りしてしまう。
	if is_game_over or is_ending_shown:
		return

	# オートモードのトグル（Aキー）
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_A:
		if _can_auto_advance():
			toggle_auto_mode()
		return

	if event.is_action_pressed("ui_accept"):
		# 手動送りしたらオートは解除（誤操作防止）
		if is_auto_mode:
			set_auto_mode(false)
		handle_click()
	elif event.is_action_pressed("ui_cancel"):
		toggle_pause_menu()
	elif event.is_action_pressed("debug_toggle"):
		toggle_debug_ui()

# 毎フレーム、オート/スキップ送りを処理する（周回テンポ改善）
func _process(delta: float) -> void:
	var can_advance := _can_auto_advance()
	# スキップ（Ctrl押下中）を最優先で判定
	var skip_held := can_advance and Input.is_key_pressed(KEY_CTRL)
	_update_skip_indicator(skip_held)

	if not can_advance:
		_skip_accum = 0.0
		return

	if skip_held:
		if is_auto_mode:
			# スキップ解除直後に古い待機時間でAUTO送りされないよう満タンに戻す
			_auto_timer = auto_advance_delay
		if is_text_displaying:
			# 表示中は即座に全文表示してから次フレームで送る
			complete_text_display()
		else:
			_skip_accum += delta
			if _skip_accum >= skip_interval:
				_skip_accum = 0.0
				ScenarioManager.advance_text()
		return
	_skip_accum = 0.0

	# オートモード：表示完了後、一定待機してから次へ
	if is_auto_mode:
		if is_text_displaying:
			_auto_timer = auto_advance_delay  # 表示中は待機時間をリセット
		else:
			_auto_timer -= delta
			if _auto_timer <= 0.0:
				_auto_timer = auto_advance_delay
				ScenarioManager.advance_text()

# オート/スキップ送りが許可される状況か（メニュー/選択肢/QTE/終了画面では不許可）
func _can_auto_advance() -> bool:
	if is_game_over or is_ending_shown:
		return false
	if _is_menu_open():
		return false
	if GameManager.current_state == GameManager.GameState.QTE:
		return false
	if choices_container.visible:
		return false
	return true

# AUTO/SKIP インジケータをコード構築（tscn非依存）
func _setup_adv_indicators() -> void:
	auto_indicator = _make_adv_indicator("AUTO", Color(1.0, 0.85, 0.3), 16)
	skip_indicator = _make_adv_indicator("SKIP", Color(0.5, 0.8, 1.0), 44)

func _make_adv_indicator(text: String, color: Color, top: float) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("outline_size", 4)
	# 画面右上に固定（トップレベルControlとしてビューポート基準でアンカー）
	label.anchor_left = 1.0
	label.anchor_right = 1.0
	label.anchor_top = 0.0
	label.anchor_bottom = 0.0
	label.offset_left = -130.0
	label.offset_right = -20.0
	label.offset_top = top
	label.offset_bottom = top + 28.0
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.visible = false
	overlay_layer.add_child(label)
	return label

func toggle_auto_mode() -> void:
	set_auto_mode(not is_auto_mode)

func set_auto_mode(enabled: bool) -> void:
	is_auto_mode = enabled
	_auto_timer = auto_advance_delay
	if auto_indicator:
		auto_indicator.visible = enabled

func _update_skip_indicator(active: bool) -> void:
	if skip_indicator and skip_indicator.visible != active:
		skip_indicator.visible = active

func handle_click() -> void:
	if _is_menu_open():
		return  # メニュー表示中はクリック無効
	if GameManager.current_state == GameManager.GameState.QTE:
		return
	if choices_container.visible:
		return  # 選択肢表示中はクリック無効

	if is_text_displaying:
		# テキスト表示中→全文表示
		complete_text_display()
	else:
		# テキスト表示完了→次へ
		if Time.get_ticks_msec() < _advance_guard_until_ms:
			return
		ScenarioManager.advance_text()

func _is_menu_open() -> bool:
	return (pause_menu != null and is_instance_valid(pause_menu)) \
		or (save_load_menu != null and is_instance_valid(save_load_menu))

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

func _on_parameter_changed(param_name: String, _new_value: int) -> void:
	update_parameter_display()
	# 変化したパラメータのバーを一瞬強調して気づきやすくする
	if param_name == "fear":
		_pulse_node(fear_bar)
		_pulse_node(fear_label_left)
	elif param_name == "kizuna":
		_pulse_node(kizuna_bar)
		_pulse_node(kizuna_label)

# バー/ラベルを一瞬明るくして戻す（パラメータ変化のフィードバック）
func _pulse_node(node: CanvasItem) -> void:
	if node == null or not is_instance_valid(node):
		return
	var tween := create_tween()
	node.modulate = Color(1.6, 1.6, 1.6, 1.0)
	tween.tween_property(node, "modulate", Color(1, 1, 1, 1), 0.35)

func _on_game_over() -> void:
	if is_game_over or is_ending_shown:
		return
	print("[Main] GAME OVER!")
	is_game_over = true
	_close_menus()
	_show_fullscreen_message("GAME OVER", Color(0.8, 0.1, 0.1), null)

func _on_ending_reached(scene: Dictionary) -> void:
	if is_game_over or is_ending_shown:
		return
	is_ending_shown = true
	_close_menus()
	var ending_id: String = scene.get("endingId", "")
	var label: String = scene.get("ending_label", "")
	if label == "":
		label = "BAD END" if "death" in ending_id else "THE END"
	var image: Texture2D = null
	var image_path: String = scene.get("ending_image", "")
	if image_path != "":
		var full_path = image_path if image_path.begins_with("res://") else "res://assets/images/%s" % image_path
		if ResourceLoader.exists(full_path):
			image = load(full_path)
	_show_fullscreen_message(label, Color.WHITE, image)

# ゲームオーバー/エンディング共通の全画面表示。誤操作防止のため明示ボタンで遷移する。
func _show_fullscreen_message(message: String, color: Color, image: Texture2D) -> void:
	if end_overlay != null and is_instance_valid(end_overlay):
		return
	end_overlay = Control.new()
	end_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	end_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay_layer.add_child(end_overlay)

	var black = ColorRect.new()
	black.color = Color(0, 0, 0, 1)
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	end_overlay.add_child(black)

	if image:
		var tex = TextureRect.new()
		tex.texture = image
		tex.set_anchors_preset(Control.PRESET_FULL_RECT)
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		end_overlay.add_child(tex)

	var label = Label.new()
	label.text = message
	label.add_theme_font_size_override("font_size", 72)
	label.add_theme_color_override("font_color", color)
	label.set_anchors_preset(Control.PRESET_CENTER)
	label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	label.grow_vertical = Control.GROW_DIRECTION_BOTH
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	end_overlay.add_child(label)

	var button_box = VBoxContainer.new()
	button_box.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	button_box.position.x -= 210.0
	button_box.position.y -= 150.0
	button_box.custom_minimum_size = Vector2(420, 0)
	button_box.add_theme_constant_override("separation", 12)
	button_box.visible = false
	end_overlay.add_child(button_box)

	var first_button: Button = null
	if GameManager.has_qte_retry_checkpoint():
		var retry_button = Button.new()
		retry_button.text = "QTE直前からやり直す"
		retry_button.custom_minimum_size = Vector2(420, 58)
		retry_button.disabled = true
		retry_button.pressed.connect(_retry_from_qte_checkpoint)
		button_box.add_child(retry_button)
		first_button = retry_button

	var title_button = Button.new()
	title_button.text = "タイトルへ戻る"
	title_button.custom_minimum_size = Vector2(420, 58)
	title_button.disabled = true
	title_button.pressed.connect(_return_to_title)
	button_box.add_child(title_button)
	if first_button == null:
		first_button = title_button

	# 直前の決定入力を拾わないよう、フェード完了後に操作を解禁する。
	end_overlay.modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(end_overlay, "modulate:a", 1.0, 1.0)
	tween.tween_interval(0.5)
	tween.tween_callback(func():
		if button_box == null or not is_instance_valid(button_box):
			return
		button_box.visible = true
		for child in button_box.get_children():
			var child_button := child as Button
			if child_button != null:
				child_button.disabled = false
		if first_button != null and is_instance_valid(first_button):
			first_button.grab_focus()
	)

func _retry_from_qte_checkpoint() -> void:
	if not GameManager.has_qte_retry_checkpoint():
		return
	# 終了状態を先に解除し、復元時の表示更新シグナルを通常状態として受ける。
	is_game_over = false
	is_ending_shown = false
	if end_overlay != null and is_instance_valid(end_overlay):
		end_overlay.queue_free()
	end_overlay = null
	set_auto_mode(false)
	_update_skip_indicator(false)
	if text_display_tween and text_display_tween.is_valid():
		text_display_tween.kill()
	is_text_displaying = false
	current_qte_data = {}
	hide_choices()

	var resume_position := GameManager.restore_qte_checkpoint()
	var scene_id: String = str(resume_position.get("scene_id", ""))
	if scene_id == "":
		push_error("[Main] QTE retry checkpoint has no scene id")
		_return_to_title()
		return
	ScenarioManager.start_scene_at(scene_id, int(resume_position.get("event_index", 0)))

func _return_to_title() -> void:
	GameManager.clear_qte_retry_checkpoint()
	get_tree().change_scene_to_file(TITLE_SCENE)

# ---- ポーズメニュー / セーブ・ロード ----

func toggle_pause_menu() -> void:
	if save_load_menu != null and is_instance_valid(save_load_menu):
		return  # セーブ/ロード画面表示中（閉じる操作はメニュー側で処理）
	if GameManager.current_state == GameManager.GameState.QTE:
		return  # QTE中はメニュー禁止
	if pause_menu != null and is_instance_valid(pause_menu):
		_close_menus()
		return
	pause_menu = PauseMenu.new()
	pause_menu.resume_requested.connect(_close_menus)
	pause_menu.save_requested.connect(func(): _open_save_load_menu("save"))
	pause_menu.load_requested.connect(func(): _open_save_load_menu("load"))
	pause_menu.title_requested.connect(_return_to_title)
	overlay_layer.add_child(pause_menu)

func _open_save_load_menu(mode: String) -> void:
	if pause_menu != null and is_instance_valid(pause_menu):
		pause_menu.queue_free()
		pause_menu = null
	save_load_menu = SaveLoadMenu.new(mode)
	save_load_menu.slot_activated.connect(_on_save_load_slot_activated)
	save_load_menu.closed.connect(func(): save_load_menu = null)
	overlay_layer.add_child(save_load_menu)

func _on_save_load_slot_activated(slot: int, mode: String) -> void:
	if mode == "load":
		if save_load_menu != null and is_instance_valid(save_load_menu):
			save_load_menu.queue_free()
			save_load_menu = null
		GameManager.resume_from_save(slot)

func _close_menus() -> void:
	if pause_menu != null and is_instance_valid(pause_menu):
		pause_menu.queue_free()
		pause_menu = null
	if save_load_menu != null and is_instance_valid(save_load_menu):
		save_load_menu.queue_free()
		save_load_menu = null

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
	_stop_click_indicator_anim()
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
		_start_click_indicator_anim()
	)

func complete_text_display() -> void:
	if text_display_tween and text_display_tween.is_valid():
		text_display_tween.kill()
	dialog_text.visible_ratio = 1.0
	is_text_displaying = false
	click_indicator.visible = true
	_start_click_indicator_anim()
	_advance_guard_until_ms = Time.get_ticks_msec() + ADVANCE_GUARD_MS

# 次送り可能であることを示すインジケータを緩やかに明滅させる
func _start_click_indicator_anim() -> void:
	if _click_indicator_tween and _click_indicator_tween.is_valid():
		_click_indicator_tween.kill()
	click_indicator.modulate.a = 1.0
	_click_indicator_tween = create_tween()
	_click_indicator_tween.set_loops()
	_click_indicator_tween.tween_property(click_indicator, "modulate:a", 0.35, 0.6)
	_click_indicator_tween.tween_property(click_indicator, "modulate:a", 1.0, 0.6)

func _stop_click_indicator_anim() -> void:
	if _click_indicator_tween and _click_indicator_tween.is_valid():
		_click_indicator_tween.kill()
	_click_indicator_tween = null
	click_indicator.modulate.a = 1.0

func show_choices(choices: Array) -> void:
	# 既存のボタンをクリア
	for child in choices_container.get_children():
		child.queue_free()
	
	# 選択肢ボタンを生成
	var first_button: Button = null
	for i in choices.size():
		var option = choices[i]
		var button = Button.new()
		button.text = option.get("text", "選択肢 %d" % (i + 1))
		button.custom_minimum_size = Vector2(400, 50)
		button.pressed.connect(func(): select_choice(i))
		choices_container.add_child(button)
		if first_button == null:
			first_button = button
	
	choices_container.visible = true
	if first_button != null:
		first_button.call_deferred("grab_focus")
	dialog_box.visible = false

func hide_choices() -> void:
	choices_container.visible = false
	dialog_box.visible = true

func select_choice(index: int) -> void:
	hide_choices()
	ScenarioManager.select_choice(index)

func start_qte(qte_data: Dictionary) -> void:
	if not qte_controller:
		push_error("[Main] QTEController not found!")
		GameManager.clear_qte_retry_checkpoint()
		ScenarioManager.handle_qte_result(true, qte_data)
		return
	
	print("[Main] QTE Started: %s" % str(qte_data))
	GameManager.capture_qte_checkpoint(
		ScenarioManager.current_scene_id,
		ScenarioManager.current_event_index
	)
	current_qte_data = qte_data
	GameManager.current_state = GameManager.GameState.QTE

	# ダイアログを非表示にしてQTEを開始
	dialog_box.visible = false
	qte_controller.start_qte(qte_data)

func _on_qte_completed(result: String) -> void:
	print("[Main] QTE Completed: %s" % result)
	GameManager.current_state = GameManager.GameState.GAME
	dialog_box.visible = true
	if result == "success" or result == "harem":
		GameManager.clear_qte_retry_checkpoint()
	ScenarioManager.handle_qte_result_typed(result, current_qte_data)
	current_qte_data = {}

# パラメータバーの塗りスタイルを生成し、色を動的に変えられるようにする
func _setup_parameter_bars() -> void:
	if fear_bar:
		_fear_fill_style = StyleBoxFlat.new()
		_fear_fill_style.bg_color = _fear_color_normal
		_fear_fill_style.corner_radius_top_left = 3
		_fear_fill_style.corner_radius_top_right = 3
		_fear_fill_style.corner_radius_bottom_left = 3
		_fear_fill_style.corner_radius_bottom_right = 3
		fear_bar.add_theme_stylebox_override("fill", _fear_fill_style)
	if kizuna_bar:
		_kizuna_fill_style = StyleBoxFlat.new()
		_kizuna_fill_style.bg_color = _kizuna_color
		_kizuna_fill_style.corner_radius_top_left = 3
		_kizuna_fill_style.corner_radius_top_right = 3
		_kizuna_fill_style.corner_radius_bottom_left = 3
		_kizuna_fill_style.corner_radius_bottom_right = 3
		kizuna_bar.add_theme_stylebox_override("fill", _kizuna_fill_style)

func update_parameter_display() -> void:
	if fear_label_left: fear_label_left.text = "恐怖度: %d" % GameManager.fear
	if kizuna_label: kizuna_label.text = "親密度: %d" % GameManager.kizuna
	if fear_bar:
		fear_bar.value = GameManager.fear
	if kizuna_bar:
		kizuna_bar.value = GameManager.kizuna
	# 恐怖度が高いほど危険色へ（100でゲームオーバーの予兆を可視化）
	if _fear_fill_style:
		if GameManager.fear >= 90:
			_fear_fill_style.bg_color = _fear_color_danger
		elif GameManager.fear >= 70:
			_fear_fill_style.bg_color = _fear_color_warn
		else:
			_fear_fill_style.bg_color = _fear_color_normal
	# kegare_label.text = "穢れ: %d" % GameManager.kegare

func toggle_debug_ui() -> void:
	# デバッグUI表示切り替え（別途実装）
	print("[Main] Debug UI toggle (not implemented yet)")
