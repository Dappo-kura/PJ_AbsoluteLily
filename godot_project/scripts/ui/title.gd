# Title - タイトル画面
extends Control

const MAIN_SCENE := "res://scenes/game/main.tscn"

var _continue_button: Button

func _ready() -> void:
	GameManager.current_state = GameManager.GameState.TITLE
	GameManager.load_system_data()

	# 背景
	var bg = TextureRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	if ResourceLoader.exists("res://assets/images/title.png"):
		bg.texture = load("res://assets/images/title.png")
	add_child(bg)

	# メニューボタン（画面下部中央）
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	vbox.position.y -= 260
	vbox.add_theme_constant_override("separation", 14)
	add_child(vbox)

	_add_button(vbox, "はじめから", _on_new_game)
	_continue_button = _add_button(vbox, "つづきから", _on_continue)
	_continue_button.disabled = not GameManager.has_any_save()
	_add_button(vbox, "終了", _on_quit)

	AudioManager.play_bgm("title.mp3")

func _add_button(parent: Control, text: String, handler: Callable) -> Button:
	var button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(320, 60)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.pressed.connect(handler)
	parent.add_child(button)
	return button

func _on_new_game() -> void:
	GameManager.pending_load_slot = -1
	get_tree().change_scene_to_file(MAIN_SCENE)

func _on_continue() -> void:
	var menu = SaveLoadMenu.new("load")
	menu.slot_activated.connect(func(slot: int, _mode: String):
		GameManager.pending_load_slot = slot
		get_tree().change_scene_to_file(MAIN_SCENE)
	)
	add_child(menu)

func _on_quit() -> void:
	get_tree().quit()
