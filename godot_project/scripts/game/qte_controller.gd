# QTEController - 新QTE（複数選択肢・ランダム配置・即死ルート）システム
extends Control

# result: "success" | "fail" | "harem"
signal qte_completed(result: String)

@onready var action_text: Label = $ActionText
@onready var result_label: Label = $ResultLabel
@onready var background: VideoStreamPlayer = $Background
@onready var choices_container: Control = $ChoicesContainer

var qte_choice_scene = preload("res://scenes/game/qte_choice.tscn")

# QTEパラメータ
var duration: float = 2.0
var display_text: String = "タップ!"
var is_active: bool = false
var current_qte_data: Dictionary = {}
var timer: float = 0.0

# 選択肢用の定数とリスト
var death_texts: Array = ["逃げる", "動かない", "諦める", "目を閉じる", "声を上げる", "後ずさる"]

func _ready() -> void:
	visible = false
	result_label.visible = false
	# 背景動画をVideoStreamTheoraで設定
	var stream = VideoStreamTheora.new()
	stream.file = "res://assets/images/Wan22_i2v_00001_1.ogv"
	background.stream = stream
	background.expand = true
	print("[QTEController] Initialized (New Spec)")

func _process(delta: float) -> void:
	if not is_active:
		return
	
	timer -= delta
	if timer <= 0:
		_on_time_out()

func start_qte(qte_data: Dictionary) -> void:
	current_qte_data = qte_data
	
	# パラメータ設定 (最低4秒を保証)
	var req_duration = qte_data.get("duration", 4000) / 1000.0
	duration = max(4.0, req_duration)
	display_text = qte_data.get("text", "生き残れ！")
	
	action_text.text = display_text
	
	visible = true
	is_active = true
	result_label.visible = false
	timer = duration
	
	# 背景動画の再生を開始
	background.play()
	
	# 既存の選択肢をクリア
	for child in choices_container.get_children():
		child.queue_free()
	
	var labels = qte_data.get("labels", ["生きる"])

	# 今回正解となるテキスト
	var correct_text = labels[0] if labels.size() > 0 else "生きる"

	# 生存(SURVIVAL) か エッチ(EROTIC) かの判定
	var correct_type = 0 # SURVIVAL
	if "触れる" in correct_text or "キス" in correct_text or "抱きつく" in correct_text:
		correct_type = 1 # EROTIC

	# ハーレムルート選択肢（シナリオデータで明示指定された場合のみ出現）
	var harem_text: String = qte_data.get("harem_label", "")
	
	# --- グリッドを利用した分散配置 ---
	var viewport_size = get_viewport_rect().size
	var margin = 60
	var safe_rect = Rect2(margin, margin, viewport_size.x - margin * 2, viewport_size.y - margin * 2)
	
	# 4x3 のグリッド (最大12個のセル)
	var cols = 4
	var rows = 3
	var cell_w = safe_rect.size.x / cols
	var cell_h = safe_rect.size.y / rows
	
	# 利用可能なセルのインデックスリスト (0 ~ 11)
	var available_cells = []
	for i in range(cols * rows):
		available_cells.append(i)
	
	# シャッフルしてランダムなセルを選ぶ
	available_cells.shuffle()
	
	# --- 死亡(DEATH)選択肢の生成 (3 ~ 9個追加) ---
	# 利用可能なセル12個のうち、正解1つ＋ハーレム1つ＋死亡Max9つ＝11個であれば必ず収まる
	var death_count = randi_range(3, 9)
	var total_choices = 1 + (1 if harem_text != "" else 0) + death_count

	# スポーンデータを配列にまとめる（後でシャッフルして順番をランダムに）
	var spawn_list = []

	for i in range(total_choices):
		if available_cells.size() == 0:
			break

		var cell_index = available_cells.pop_back()
		var col = cell_index % cols
		var row = cell_index / cols

		# セルの矩形
		var cell_rect = Rect2(
			safe_rect.position.x + col * cell_w,
			safe_rect.position.y + row * cell_h,
			cell_w,
			cell_h
		)

		var choice_size = 160
		# セル内で少しだけランダムにずらす余裕を計算
		var padding_x = max(0.0, cell_rect.size.x - choice_size)
		var padding_y = max(0.0, cell_rect.size.y - choice_size)

		var rx = cell_rect.position.x + randf_range(0, padding_x)
		var ry = cell_rect.position.y + randf_range(0, padding_y)
		var pos = Vector2(rx, ry)

		if i == 0:
			# 正解ルート
			spawn_list.append({"type": correct_type, "text": correct_text, "pos": pos, "result": "success"})
		elif i == 1 and harem_text != "":
			# ハーレムルート
			spawn_list.append({"type": 1, "text": harem_text, "pos": pos, "result": "harem"})
		else:
			# 死亡ルート
			var d_text = death_texts[randi() % death_texts.size()]
			spawn_list.append({"type": 2, "text": d_text, "pos": pos, "result": "fail"})
	
	# 出現順をシャッフル（正解が最初に出るとは限らないように）
	spawn_list.shuffle()
	
	# 選択肢を次々に表示する（非同期）
	_spawn_choices_sequentially(spawn_list)

func _spawn_choices_sequentially(spawn_list: Array) -> void:
	for data in spawn_list:
		if not is_active:
			break
		# 0.2～0.5秒のランダム間隔で次の選択肢を出現させる
		await get_tree().create_timer(randf_range(0.2, 0.5)).timeout
		if not is_active:
			break
		_spawn_choice(data["type"], data["text"], data["pos"], data["result"])

func _spawn_choice(type: int, text: String, pos: Vector2, result: String) -> void:
	var choice = qte_choice_scene.instantiate()
	choices_container.add_child(choice)

	choice.position = pos
	choice.set_meta("result", result)
	choice.setup(type, text, duration)
	choice.choice_selected.connect(_on_choice_selected.bind(choice))

func _on_choice_selected(_type: int, choice: Control) -> void:
	if not is_active:
		return

	# 選択されたら他の全選択肢を無効化
	is_active = false
	for child in choices_container.get_children():
		child.is_active = false

	var result: String = choice.get_meta("result", "fail")
	if result == "fail":
		show_result("DEATH END", Color.DARK_RED)
		AudioManager.play_se("miss", 1.0, 1.0)
		finish_qte(result)
	else:
		show_result("SUCCESS!", Color.GREEN)
		AudioManager.play_se("success", 1.0, 1.0)
		finish_qte(result)

func _on_time_out() -> void:
	if not is_active: return
	is_active = false
	
	for child in choices_container.get_children():
		child.is_active = false
		
	# タイムアウト = 失敗
	show_result("TIME OUT", Color.RED)
	AudioManager.play_se("miss", 1.0, 1.0)
	finish_qte("fail")

func show_result(text: String, color: Color) -> void:
	result_label.text = text
	result_label.modulate = color
	result_label.visible = true

func finish_qte(result: String) -> void:
	await get_tree().create_timer(1.0).timeout
	visible = false
	background.stop()
	qte_completed.emit(result)

# デバッグ用
func test_run(test_duration: float, test_size: float, test_text: String) -> void:
	var test_data = {
		"duration": test_duration * 1000,
		"text": test_text,
		"labels": ["生き延びる"]
	}
	start_qte(test_data)
