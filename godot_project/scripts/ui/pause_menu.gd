# PauseMenu - ゲーム内ポーズメニュー（Escで開く。UIはコードで構築）
class_name PauseMenu
extends Control

signal resume_requested()
signal save_requested()
signal load_requested()
signal title_requested()

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var dim = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var panel = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(400, 0)
	add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	var title = Label.new()
	title.text = "メニュー"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	vbox.add_child(title)

	_add_button(vbox, "つづける", func(): resume_requested.emit())
	_add_button(vbox, "セーブ", func(): save_requested.emit())
	_add_button(vbox, "ロード", func(): load_requested.emit())
	_add_button(vbox, "タイトルへ戻る", func(): title_requested.emit())

func _add_button(parent: Control, text: String, handler: Callable) -> void:
	var button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(360, 56)
	button.pressed.connect(handler)
	parent.add_child(button)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		resume_requested.emit()
