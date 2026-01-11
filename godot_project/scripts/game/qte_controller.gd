# QTEController - Shrinking Ring QTE システム
extends Control

signal qte_completed(success: bool)

@onready var ring_outer: Control = $RingOuter
@onready var ring_shrinking: Control = $RingShrinking
@onready var target_zone: Control = $TargetZone
@onready var action_text: Label = $ActionText
@onready var result_label: Label = $ResultLabel

# QTEパラメータ
var duration: float = 2.0  # ms -> sec
var ring_size: float = 300.0
var zone_inner_ratio: float = 0.65
var zone_outer_ratio: float = 0.80
var display_text: String = "タップ!"
var attempts: int = 3
var success_threshold: int = 2

# 状態
var is_active: bool = false
var current_attempt: int = 0
var success_count: int = 0
var shrink_tween: Tween
var current_qte_data: Dictionary = {}

func _ready() -> void:
	visible = false
	result_label.visible = false
	print("[QTEController] Initialized")

func start_qte(qte_data: Dictionary) -> void:
	current_qte_data = qte_data
	
	# パラメータ設定
	duration = qte_data.get("duration", 2000) / 1000.0
	ring_size = qte_data.get("size", 300)
	zone_inner_ratio = qte_data.get("zone_inner_ratio", 0.65)
	zone_outer_ratio = qte_data.get("zone_outer_ratio", 0.80)
	display_text = qte_data.get("text", "タップ!")
	attempts = qte_data.get("attempts", 3)
	success_threshold = qte_data.get("success_threshold", 2)
	
	# ラベル配列がある場合
	if qte_data.has("labels") and qte_data["labels"].size() > 0:
		attempts = qte_data["labels"].size()
	
	current_attempt = 0
	success_count = 0
	
	visible = true
	is_active = true
	result_label.visible = false
	
	start_attempt()

func start_attempt() -> void:
	if current_attempt >= attempts:
		finish_qte()
		return
	
	# テキスト設定
	if current_qte_data.has("labels") and current_attempt < current_qte_data["labels"].size():
		action_text.text = current_qte_data["labels"][current_attempt]
	else:
		action_text.text = display_text
	
	# リングサイズ設定
	ring_outer.custom_minimum_size = Vector2(ring_size, ring_size)
	ring_outer.size = Vector2(ring_size, ring_size)
	ring_outer.position = (get_viewport_rect().size - ring_outer.size) / 2
	
	ring_shrinking.custom_minimum_size = Vector2(ring_size, ring_size)
	ring_shrinking.size = Vector2(ring_size, ring_size)
	ring_shrinking.position = ring_outer.position
	ring_shrinking.scale = Vector2(1.5, 1.5)  # 外側から開始
	
	# ターゲットゾーン設定
	var zone_size = ring_size * zone_outer_ratio
	target_zone.custom_minimum_size = Vector2(zone_size, zone_size)
	target_zone.size = Vector2(zone_size, zone_size)
	target_zone.position = ring_outer.position + Vector2((ring_size - zone_size) / 2, (ring_size - zone_size) / 2)
	
	# 収縮アニメーション開始
	if shrink_tween and shrink_tween.is_valid():
		shrink_tween.kill()
	
	shrink_tween = create_tween()
	shrink_tween.tween_property(ring_shrinking, "scale", Vector2(zone_inner_ratio, zone_inner_ratio), duration)
	shrink_tween.tween_callback(_on_time_out)

func _input(event: InputEvent) -> void:
	if not is_active:
		return
	
	if event.is_action_pressed("qte_action"):
		check_input()

func check_input() -> void:
	if shrink_tween and shrink_tween.is_valid():
		shrink_tween.kill()
	
	var current_scale = ring_shrinking.scale.x
	
	# 判定
	var success = current_scale >= zone_inner_ratio and current_scale <= zone_outer_ratio
	
	if success:
		success_count += 1
		show_result("SUCCESS!", Color.GREEN)
		AudioManager.play_se("success", 1.0, 1.0)
	else:
		show_result("MISS!", Color.RED)
		AudioManager.play_se("miss", 1.0, 1.0)
	
	current_attempt += 1
	
	# 次のアテンプトへ
	await get_tree().create_timer(0.5).timeout
	result_label.visible = false
	start_attempt()

func _on_time_out() -> void:
	# タイムアウト = 失敗
	show_result("MISS!", Color.RED)
	AudioManager.play_se("miss", 1.0, 1.0)
	
	current_attempt += 1
	
	await get_tree().create_timer(0.5).timeout
	result_label.visible = false
	start_attempt()

func show_result(text: String, color: Color) -> void:
	result_label.text = text
	result_label.modulate = color
	result_label.visible = true

func finish_qte() -> void:
	is_active = false
	
	var overall_success = success_count >= success_threshold
	
	if overall_success:
		show_result("CLEAR!", Color.GOLD)
	else:
		show_result("FAILED...", Color.DARK_RED)
	
	await get_tree().create_timer(1.0).timeout
	
	visible = false
	qte_completed.emit(overall_success)

# デバッグ用: パラメータを直接設定してテスト
func test_run(test_duration: float, test_size: float, test_text: String) -> void:
	var test_data = {
		"duration": test_duration * 1000,
		"size": test_size,
		"text": test_text,
		"attempts": 1,
		"success_threshold": 1
	}
	start_qte(test_data)

func get_current_params() -> Dictionary:
	return {
		"duration": duration * 1000,
		"size": ring_size,
		"zone_inner_ratio": zone_inner_ratio,
		"zone_outer_ratio": zone_outer_ratio,
		"text": display_text
	}
