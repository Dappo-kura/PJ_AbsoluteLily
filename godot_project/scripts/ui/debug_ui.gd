# DebugUI - シナリオディレクター / QTEチューナー
extends CanvasLayer

@onready var debug_panel: Panel = $DebugPanel
@onready var scene_list: ItemList = $DebugPanel/VBox/SceneList
@onready var scene_id_input: LineEdit = $DebugPanel/VBox/SceneIDInput
@onready var jump_button: Button = $DebugPanel/VBox/JumpButton
@onready var reload_button: Button = $DebugPanel/VBox/ReloadButton

@onready var fear_slider: HSlider = $DebugPanel/VBox/FearHBox/FearSlider
@onready var kizuna_slider: HSlider = $DebugPanel/VBox/KizunaHBox/KizunaSlider
@onready var kegare_slider: HSlider = $DebugPanel/VBox/KegareHBox/KegareSlider

@onready var fear_value: Label = $DebugPanel/VBox/FearHBox/FearValue
@onready var kizuna_value: Label = $DebugPanel/VBox/KizunaHBox/KizunaValue
@onready var kegare_value: Label = $DebugPanel/VBox/KegareHBox/KegareValue

# QTE Tuner
@onready var qte_panel: Panel = $QTEPanel
@onready var qte_duration_slider: HSlider = $QTEPanel/VBox/DurationSlider
@onready var qte_size_slider: HSlider = $QTEPanel/VBox/SizeSlider
@onready var qte_text_input: LineEdit = $QTEPanel/VBox/TextInput
@onready var qte_test_button: Button = $QTEPanel/VBox/TestButton
@onready var qte_copy_button: Button = $QTEPanel/VBox/CopyButton

var debug_visible: bool = false

func _ready() -> void:
	layer = 1000
	visible = false
	
	# シグナル接続
	jump_button.pressed.connect(_on_jump_pressed)
	reload_button.pressed.connect(_on_reload_pressed)
	
	fear_slider.value_changed.connect(_on_fear_changed)
	kizuna_slider.value_changed.connect(_on_kizuna_changed)
	kegare_slider.value_changed.connect(_on_kegare_changed)
	
	qte_test_button.pressed.connect(_on_qte_test_pressed)
	qte_copy_button.pressed.connect(_on_qte_copy_pressed)
	
	scene_list.item_selected.connect(_on_scene_selected)
	
	ScenarioManager.scenario_reloaded.connect(_refresh_scene_list)
	
	print("[DebugUI] Initialized")

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_toggle"):
		toggle_visibility()

func toggle_visibility() -> void:
	debug_visible = !debug_visible
	visible = debug_visible
	
	if debug_visible:
		refresh_ui()

func refresh_ui() -> void:
	_refresh_scene_list()
	_refresh_parameter_sliders()

func _refresh_scene_list() -> void:
	scene_list.clear()
	var scene_ids = ScenarioManager.get_all_scene_ids()
	for id in scene_ids:
		var visited = "✓ " if GameManager.is_scene_visited(id) else "  "
		scene_list.add_item(visited + id)

func _refresh_parameter_sliders() -> void:
	fear_slider.value = GameManager.fear
	kizuna_slider.value = GameManager.kizuna
	kegare_slider.value = GameManager.kegare
	
	fear_value.text = str(GameManager.fear)
	kizuna_value.text = str(GameManager.kizuna)
	kegare_value.text = str(GameManager.kegare)

func _on_jump_pressed() -> void:
	var scene_id = scene_id_input.text.strip_edges()
	if scene_id != "":
		ScenarioManager.jump_to_scene(scene_id)
		print("[DebugUI] Jumped to: %s" % scene_id)

func _on_reload_pressed() -> void:
	ScenarioManager.reload_scenario()
	refresh_ui()
	print("[DebugUI] Scenario reloaded")

func _on_scene_selected(index: int) -> void:
	var item_text = scene_list.get_item_text(index)
	var scene_id = item_text.substr(2)  # "✓ " または "  " を除去
	scene_id_input.text = scene_id

func _on_fear_changed(value: float) -> void:
	GameManager.fear = int(value)
	fear_value.text = str(int(value))

func _on_kizuna_changed(value: float) -> void:
	GameManager.kizuna = int(value)
	kizuna_value.text = str(int(value))

func _on_kegare_changed(value: float) -> void:
	GameManager.kegare = int(value)
	kegare_value.text = str(int(value))

func _on_qte_test_pressed() -> void:
	var duration = qte_duration_slider.value
	var size = qte_size_slider.value
	var text = qte_text_input.text if qte_text_input.text != "" else "テスト!"
	
	# QTEControllerを取得してテスト実行
	var qte_controller = get_tree().get_first_node_in_group("qte_controller")
	if qte_controller:
		qte_controller.test_run(duration, size, text)
	else:
		push_warning("[DebugUI] QTE Controller not found")

func _on_qte_copy_pressed() -> void:
	var duration = qte_duration_slider.value * 1000
	var size = qte_size_slider.value
	var text = qte_text_input.text if qte_text_input.text != "" else "テスト!"
	
	var json_str = '{"type": "qte", "duration": %.0f, "size": %.0f, "text": "%s"}' % [duration, size, text]
	DisplayServer.clipboard_set(json_str)
	print("[DebugUI] Copied to clipboard: %s" % json_str)
