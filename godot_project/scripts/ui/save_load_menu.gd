# SaveLoadMenu - セーブ/ロード画面（UIはコードで構築）
class_name SaveLoadMenu
extends Control

signal slot_activated(slot: int, mode: String)
signal closed()

var mode: String = "save"  # "save" or "load"

var _title_label: Label
var _slot_buttons: Array[Button] = []

func _init(menu_mode: String = "save") -> void:
	mode = menu_mode

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	# 背景を暗くする
	var dim = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var panel = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(640, 480)
	add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	panel.add_child(vbox)

	_title_label = Label.new()
	_title_label.text = "セーブ" if mode == "save" else "ロード"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 32)
	vbox.add_child(_title_label)

	for slot in range(1, GameManager.SAVE_SLOT_COUNT + 1):
		var button = Button.new()
		button.custom_minimum_size = Vector2(560, 90)
		button.pressed.connect(_on_slot_pressed.bind(slot))
		vbox.add_child(button)
		_slot_buttons.append(button)

	var close_button = Button.new()
	close_button.text = "閉じる"
	close_button.custom_minimum_size = Vector2(200, 50)
	close_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_button.pressed.connect(_on_close_pressed)
	vbox.add_child(close_button)

	refresh_slots()

func refresh_slots() -> void:
	for i in _slot_buttons.size():
		var slot = i + 1
		var button = _slot_buttons[i]
		var data = GameManager.read_save_data(slot)
		if data.is_empty():
			button.text = "スロット %d　--- 空きデータ ---" % slot
			button.disabled = (mode == "load")
		else:
			var timestamp = data.get("timestamp", "????")
			var scene_id = data.get("current_scene", "?")
			button.text = "スロット %d　%s\n進行: %s" % [slot, timestamp, scene_id]
			button.disabled = false

func _on_slot_pressed(slot: int) -> void:
	if mode == "save":
		GameManager.save_game(slot)
		refresh_slots()
	slot_activated.emit(slot, mode)

func _on_close_pressed() -> void:
	closed.emit()
	queue_free()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_close_pressed()
