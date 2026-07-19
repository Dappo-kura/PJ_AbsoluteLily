# GameManager - グローバル状態管理
extends Node

signal fear_changed(new_value: int)
signal kizuna_changed(new_value: int)
signal kegare_changed(new_value: int)
signal game_over()
signal parameter_changed(param_name: String, new_value: int)

enum GameState { TITLE, GAME, PAUSE, QTE, MENU, ENDING }

var current_state: GameState = GameState.TITLE

# パラメータ
var fear: int = 0:
	set(value):
		fear = clamp(value, 0, 100)
		fear_changed.emit(fear)
		parameter_changed.emit("fear", fear)
		if fear >= 100:
			game_over.emit()

var kizuna: int = 0:
	set(value):
		kizuna = clamp(value, 0, 100)
		kizuna_changed.emit(kizuna)
		parameter_changed.emit("kizuna", kizuna)

var kegare: int = 0:
	set(value):
		kegare = clamp(value, 0, 100)
		kegare_changed.emit(kegare)
		parameter_changed.emit("kegare", kegare)

# フラグ管理
var flags: Dictionary = {}

# 隠しパラメータ
var hidden_params: Dictionary = {
	"courage": 0,
	"curiosity": 0
}

# QTE成功カウント
var qte_success_count: int = 0

# セーブスロット数
const SAVE_SLOT_COUNT: int = 3

# タイトル画面「つづきから」用: main.tscn 起動後にこのスロットをロードする（-1 = 新規開始）
var pending_load_slot: int = -1

# QTE失敗時の再挑戦用。永続化せず、現在のプレイセッション内だけで保持する。
var _qte_retry_checkpoint: Dictionary = {}

# 既読シーン
var visited_scenes: Array[String] = []

# エンディング回収状況
var collected_endings: Dictionary = {}

func _ready() -> void:
	print("[GameManager] Initialized")

func reset_game() -> void:
	clear_qte_retry_checkpoint()
	fear = 0
	kizuna = 0
	kegare = 0
	flags.clear()
	hidden_params = {"courage": 0, "curiosity": 0}
	qte_success_count = 0
	current_state = GameState.GAME
	print("[GameManager] Game reset")

# QTE直前の進行状態をメモリに退避する。ネストしたフラグも失敗ルートから分離する。
func capture_qte_checkpoint(scene_id: String, event_index: int) -> void:
	_qte_retry_checkpoint = {
		"scene_id": scene_id,
		"event_index": event_index,
		"fear": fear,
		"kizuna": kizuna,
		"kegare": kegare,
		"flags": flags.duplicate(true),
		"hidden_params": hidden_params.duplicate(true),
		"qte_success_count": qte_success_count
	}

func has_qte_retry_checkpoint() -> bool:
	return not _qte_retry_checkpoint.is_empty()

# ゲーム状態を復元し、Mainが再開に使うシナリオ位置を返す。
func restore_qte_checkpoint() -> Dictionary:
	if _qte_retry_checkpoint.is_empty():
		return {}
	current_state = GameState.GAME
	fear = int(_qte_retry_checkpoint.get("fear", 0))
	kizuna = int(_qte_retry_checkpoint.get("kizuna", 0))
	kegare = int(_qte_retry_checkpoint.get("kegare", 0))
	flags = _qte_retry_checkpoint.get("flags", {}).duplicate(true)
	hidden_params = _qte_retry_checkpoint.get(
		"hidden_params", {"courage": 0, "curiosity": 0}
	).duplicate(true)
	qte_success_count = int(_qte_retry_checkpoint.get("qte_success_count", 0))
	return {
		"scene_id": str(_qte_retry_checkpoint.get("scene_id", "")),
		"event_index": int(_qte_retry_checkpoint.get("event_index", 0))
	}

func clear_qte_retry_checkpoint() -> void:
	_qte_retry_checkpoint.clear()

func apply_effects(effects: Dictionary) -> void:
	if effects.has("fear"):
		fear += effects["fear"]
	if effects.has("kizuna"):
		kizuna += effects["kizuna"]
	if effects.has("kegare"):
		kegare += effects["kegare"]
	if effects.has("courage"):
		hidden_params["courage"] += effects["courage"]
	if effects.has("curiosity"):
		hidden_params["curiosity"] += effects["curiosity"]
	
	# フラグ処理（ネスト形式 or "flags.name" 形式）
	if effects.has("flags"):
		for key in effects["flags"]:
			_apply_single_flag(key, effects["flags"][key])
	
	for key in effects:
		if key.begins_with("flags."):
			var flag_name = key.replace("flags.", "")
			_apply_single_flag(flag_name, effects[key])

func _apply_single_flag(key: String, value) -> void:
	if typeof(value) == TYPE_STRING and value.begins_with("+"):
		flags[key] = flags.get(key, 0) + int(value.substr(1))
	elif typeof(value) == TYPE_STRING and value.begins_with("-"):
		flags[key] = flags.get(key, 0) - int(value.substr(1))
	else:
		flags[key] = value

func mark_scene_visited(scene_id: String) -> void:
	if not scene_id in visited_scenes:
		visited_scenes.append(scene_id)

func is_scene_visited(scene_id: String) -> bool:
	return scene_id in visited_scenes

func collect_ending(ending_id: String) -> void:
	collected_endings[ending_id] = true
	save_system_data()

func save_system_data() -> void:
	var data = {
		"visited_scenes": visited_scenes,
		"collected_endings": collected_endings
	}
	var file = FileAccess.open("user://system_data.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))
		file.close()

func load_system_data() -> void:
	if FileAccess.file_exists("user://system_data.json"):
		var file = FileAccess.open("user://system_data.json", FileAccess.READ)
		if file:
			var data = JSON.parse_string(file.get_as_text())
			file.close()
			if data:
				visited_scenes.assign(data.get("visited_scenes", []))
				collected_endings = data.get("collected_endings", {})

func save_game(slot: int) -> void:
	var data = {
		"fear": fear,
		"kizuna": kizuna,
		"kegare": kegare,
		"flags": flags,
		"hidden_params": hidden_params,
		"qte_success_count": qte_success_count,
		"current_scene": ScenarioManager.current_scene_id,
		"current_event_index": ScenarioManager.current_event_index,
		"timestamp": Time.get_datetime_string_from_system(false, true)
	}
	var file = FileAccess.open("user://save_%d.json" % slot, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))
		file.close()
		print("[GameManager] Saved to slot %d" % slot)

func load_game(slot: int) -> bool:
	var data = read_save_data(slot)
	if data.is_empty():
		return false
	clear_qte_retry_checkpoint()
	fear = data.get("fear", 0)
	kizuna = data.get("kizuna", 0)
	kegare = data.get("kegare", 0)
	flags = data.get("flags", {})
	hidden_params = data.get("hidden_params", {"courage": 0, "curiosity": 0})
	qte_success_count = data.get("qte_success_count", 0)
	current_state = GameState.GAME
	print("[GameManager] Loaded from slot %d" % slot)
	return true

# セーブデータをファイルから読むだけ（状態には反映しない）。存在しなければ空Dictionary。
func read_save_data(slot: int) -> Dictionary:
	var path = "user://save_%d.json" % slot
	if not FileAccess.file_exists(path):
		return {}
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		return {}
	var data = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(data) != TYPE_DICTIONARY:
		return {}
	return data

func has_any_save() -> bool:
	for slot in range(1, SAVE_SLOT_COUNT + 1):
		if FileAccess.file_exists("user://save_%d.json" % slot):
			return true
	return false

# ロード後にシナリオをセーブ地点から再開する
func resume_from_save(slot: int) -> bool:
	var data = read_save_data(slot)
	if data.is_empty():
		return false
	if not load_game(slot):
		return false
	var scene_id = data.get("current_scene", "")
	var event_index = int(data.get("current_event_index", 0))
	if scene_id == "":
		return false
	ScenarioManager.start_scene_at(scene_id, event_index)
	return true
