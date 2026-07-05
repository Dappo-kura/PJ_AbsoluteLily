# ScenarioManager - シナリオ進行と演出コマンド管理
extends Node

signal scene_changed(scene_data: Dictionary)
signal event_started(event: Dictionary)
signal text_display_requested(speaker: String, text: String)
signal character_display_requested(character_data)
signal choices_display_requested(choices: Array)
signal qte_requested(qte_data: Dictionary)
signal command_executed(command: Dictionary)
signal scenario_reloaded()
signal ending_reached(scene: Dictionary)

var scenario_data: Dictionary = {}
var current_chapter_id: String = ""
var current_scene_id: String = ""
var current_event_index: int = 0
var current_scene_events: Array = []

# ホットリロード用
var scenario_file_path: String = "res://data/scenario.json"
var last_modified_time: int = 0

func _ready() -> void:
	print("[ScenarioManager] Initialized")
	load_scenario()

func _process(_delta: float) -> void:
	# デバッグ時のみホットリロードチェック
	if OS.is_debug_build():
		check_hot_reload()

func load_scenario(path: String = "") -> bool:
	if path != "":
		scenario_file_path = path
	
	if FileAccess.file_exists(scenario_file_path):
		var file = FileAccess.open(scenario_file_path, FileAccess.READ)
		if file:
			var json_text = file.get_as_text()
			file.close()
			var data = JSON.parse_string(json_text)
			if data:
				scenario_data = data
				last_modified_time = FileAccess.get_modified_time(scenario_file_path)
				print("[ScenarioManager] Scenario loaded: %s" % scenario_file_path)
				return true
	
	# res:// パスの場合
	if scenario_file_path.begins_with("res://"):
		var file = FileAccess.open(scenario_file_path, FileAccess.READ)
		if file:
			var json_text = file.get_as_text()
			file.close()
			var data = JSON.parse_string(json_text)
			if data:
				scenario_data = data
				print("[ScenarioManager] Scenario loaded from res://")
				return true
	
	push_warning("[ScenarioManager] Failed to load scenario")
	return false

func check_hot_reload() -> void:
	if scenario_file_path.begins_with("user://") or not scenario_file_path.begins_with("res://"):
		if FileAccess.file_exists(scenario_file_path):
			var current_time = FileAccess.get_modified_time(scenario_file_path)
			if current_time > last_modified_time:
				print("[ScenarioManager] Hot reload triggered")
				load_scenario()
				scenario_reloaded.emit()

func reload_scenario() -> void:
	load_scenario()
	scenario_reloaded.emit()

func start_scene(scene_id: String) -> void:
	var scene = find_scene(scene_id)
	if scene:
		current_scene_id = scene_id
		current_event_index = 0
		current_scene_events = scene.get("events", [])
		_root_content_processed = false  # シーン開始時にリセット
		GameManager.mark_scene_visited(scene_id)
		scene_changed.emit(scene)
		print("[ScenarioManager] Starting scene: %s" % scene_id)
		process_next_event()
	else:
		push_error("[ScenarioManager] Scene not found: %s" % scene_id)

func find_scene(scene_id: String) -> Dictionary:
	# chapters構造の場合
	if scenario_data.has("chapters"):
		for chapter in scenario_data["chapters"]:
			if chapter.has("scenes"):
				for scene in chapter["scenes"]:
					if scene.get("id") == scene_id:
						return scene
	# フラット配列の場合
	elif scenario_data.has("scenes"):
		for scene in scenario_data["scenes"]:
			if scene.get("id") == scene_id:
				return scene
	# 直接配列の場合
	elif typeof(scenario_data) == TYPE_ARRAY:
		for scene in scenario_data:
			if scene.get("id") == scene_id:
				return scene
	return {}

func process_next_event() -> void:
	if current_event_index >= current_scene_events.size():
		# シーン終了、次のシーンへ
		var scene = find_scene(current_scene_id)
		
		# rootレベルのコンテンツをチェック
		if scene.has("qte") or scene.has("choices"):
			_check_root_level_content()
			return

		if scene.has("next"):
			start_scene(scene["next"])
		elif scene.has("isEnding") and scene["isEnding"]:
			handle_ending(scene)
		return
	
	var event = current_scene_events[current_event_index]
	event_started.emit(event)
	
	match event.get("type", "line"):
		"line":
			handle_line_event(event)
		"choices":
			handle_choices_event(event)
		"qte":
			handle_qte_event(event)
		"se":
			handle_se_event(event)
		"bgm":
			handle_bgm_event(event)
		"flag":
			handle_flag_event(event)
		"item_gain":
			handle_item_event(event)
		_:
			# 演出コマンドとして処理
			execute_command(event)
			current_event_index += 1
			process_next_event()
	# 注意: rootレベルQTEチェックはここでは行わない（シーン終了時のみ）

# rootレベルQTE/選択肢処理済みフラグ
var _root_content_processed: bool = false

func _check_root_level_content() -> void:
	if _root_content_processed:
		return
	
	var scene = find_scene(current_scene_id)
	if not scene: return
	
	if scene.has("qte"):
		_root_content_processed = true
		handle_qte_event(scene["qte"])
	elif scene.has("choices"):
		_root_content_processed = true
		handle_choices_event(scene["choices"])


func handle_line_event(event: Dictionary) -> void:
	var speaker = event.get("speaker", "")
	var text = event.get("text", "")
	
	# キャラクター画像を表示
	if event.has("character"):
		character_display_requested.emit(event["character"])
	
	text_display_requested.emit(speaker, text)

func handle_choices_event(event: Dictionary) -> void:
	var options = event.get("options", [])
	choices_display_requested.emit(options)

func handle_qte_event(event: Dictionary) -> void:
	qte_requested.emit(event)

func handle_se_event(event: Dictionary) -> void:
	var se_name = event.get("name", "")
	AudioManager.play_se(se_name)
	current_event_index += 1
	process_next_event()

func handle_bgm_event(event: Dictionary) -> void:
	var bgm_name = event.get("name", "")
	AudioManager.play_bgm(bgm_name)
	current_event_index += 1
	process_next_event()

func handle_flag_event(event: Dictionary) -> void:
	if event.has("set"):
		for key in event["set"]:
			GameManager.flags[key] = event["set"][key]
	current_event_index += 1
	process_next_event()

func handle_item_event(event: Dictionary) -> void:
	var item = event.get("item", "")
	var value = event.get("value", true)
	if not GameManager.flags.has("items"):
		GameManager.flags["items"] = {}
	GameManager.flags["items"][item] = value
	current_event_index += 1
	process_next_event()

func handle_ending(scene: Dictionary) -> void:
	var ending_id = scene.get("endingId", "unknown")
	GameManager.collect_ending(ending_id)
	GameManager.current_state = GameManager.GameState.ENDING
	print("[ScenarioManager] Ending reached: %s" % ending_id)
	ending_reached.emit(scene)

func execute_command(command: Dictionary) -> void:
	command_executed.emit(command)
	print("[ScenarioManager] Command executed: %s" % str(command))

func advance_text() -> void:
	current_event_index += 1
	process_next_event()

func select_choice(choice_index: int) -> void:
	var event = current_scene_events[current_event_index]
	var options = event.get("options", [])
	if choice_index < options.size():
		var selected = options[choice_index]
		
		# エフェクト適用
		if selected.has("effects"):
			GameManager.apply_effects(selected["effects"])
		
		# 次のシーンへ
		if selected.has("next"):
			start_scene(selected["next"])
		else:
			current_event_index += 1
			process_next_event()

func handle_qte_result(success: bool, qte_data: Dictionary) -> void:
	handle_qte_result_typed("success" if success else "fail", qte_data)

# QTE結果を3ルート（success / fail / harem）で処理する。
# harem は遷移先未定義なら success にフォールバックする。
func handle_qte_result_typed(result: String, qte_data: Dictionary) -> void:
	if result == "harem" and not qte_data.has("harem_to") and not qte_data.has("effects_harem"):
		result = "success"
	match result:
		"success":
			GameManager.qte_success_count += 1
			if qte_data.has("effects_success"):
				GameManager.apply_effects(qte_data["effects_success"])
			_goto_after_qte(qte_data, "success_to")
		"harem":
			GameManager.qte_success_count += 1
			if qte_data.has("effects_harem"):
				GameManager.apply_effects(qte_data["effects_harem"])
			_goto_after_qte(qte_data, "harem_to")
		_:
			if qte_data.has("effects_fail"):
				GameManager.apply_effects(qte_data["effects_fail"])
			_goto_after_qte(qte_data, "fail_to")

func _goto_after_qte(qte_data: Dictionary, to_key: String) -> void:
	if qte_data.has(to_key):
		start_scene(qte_data[to_key])
	else:
		current_event_index += 1
		process_next_event()

# セーブデータ復帰用: 指定イベント位置からシーンを再開
func start_scene_at(scene_id: String, event_index: int) -> void:
	var scene = find_scene(scene_id)
	if scene.is_empty():
		push_error("[ScenarioManager] Scene not found for resume: %s" % scene_id)
		return
	current_scene_id = scene_id
	current_scene_events = scene.get("events", [])
	current_event_index = clamp(event_index, 0, current_scene_events.size())
	_root_content_processed = false
	scene_changed.emit(scene)
	print("[ScenarioManager] Resuming scene %s at event %d" % [scene_id, current_event_index])
	process_next_event()

# デバッグ用: 任意のシーンにジャンプ
func jump_to_scene(scene_id: String) -> void:
	print("[ScenarioManager] Debug jump to: %s" % scene_id)
	start_scene(scene_id)

# デバッグ用: 現在のシーンの特定イベントにジャンプ
func jump_to_event(event_index: int) -> void:
	if event_index >= 0 and event_index < current_scene_events.size():
		current_event_index = event_index
		process_next_event()

# 全シーンIDを取得
func get_all_scene_ids() -> Array[String]:
	var ids: Array[String] = []
	if scenario_data.has("chapters"):
		for chapter in scenario_data["chapters"]:
			if chapter.has("scenes"):
				for scene in chapter["scenes"]:
					if scene.has("id"):
						ids.append(scene["id"])
	elif scenario_data.has("scenes"):
		for scene in scenario_data["scenes"]:
			if scene.has("id"):
				ids.append(scene["id"])
	return ids
