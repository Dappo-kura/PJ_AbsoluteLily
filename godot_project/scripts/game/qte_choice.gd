extends Control
class_name QTEChoice

signal choice_selected(type: int)

enum ChoiceType {
	SURVIVAL,
	EROTIC,
	DEATH
}

var current_type: ChoiceType = ChoiceType.SURVIVAL
var max_time: float = 2.0
var current_time: float = 2.0
var is_active: bool = false
var base_color: Color = Color.WHITE
var ring_color: Color = Color.WHITE

# UI References
@onready var button: Button = $Button
@onready var label: Label = $Button/Label

func _ready() -> void:
	button.pressed.connect(_on_button_pressed)

func _process(delta: float) -> void:
	if not is_active:
		return
	
	if current_time > 0:
		current_time -= delta
		queue_redraw()
		if current_time <= 0:
			current_time = 0

func setup(type: ChoiceType, text: String, time: float) -> void:
	current_type = type
	max_time = time
	current_time = time
	label.text = text
	is_active = true
	
	# タイプに応じた見た目の設定
	match current_type:
		ChoiceType.SURVIVAL:
			base_color = Color(0.1, 0.3, 0.8, 0.8) # 青
			ring_color = Color(0.4, 0.7, 1.0, 1.0)
			label.add_theme_color_override("font_color", Color.WHITE)
		ChoiceType.EROTIC:
			base_color = Color(0.8, 0.2, 0.5, 0.8) # ピンク
			ring_color = Color(1.0, 0.5, 0.8, 1.0)
			label.add_theme_color_override("font_color", Color.WHITE)
		ChoiceType.DEATH:
			base_color = Color(0.1, 0.1, 0.1, 0.8) # 黒
			ring_color = Color(0.8, 0.1, 0.1, 1.0)
			label.add_theme_color_override("font_color", Color(0.9, 0.2, 0.2, 1.0))
			
	queue_redraw()

func _draw() -> void:
	var center = size / 2.0
	var radius = size.x / 2.0 * 0.8 # 少し内側に本体を描画
	
	# 背景の円を描画
	draw_circle(center, radius, base_color)
	
	# 外側の残り時間プログレスバー（サークル）を描画
	if is_active and max_time > 0:
		var ratio = current_time / max_time
		var start_angle = -PI / 2.0 # 12時の位置から開始
		var end_angle = start_angle + (PI * 2.0 * ratio)
		
		# 円弧を描画（太めの線でプログレスバーを表現）
		if ratio > 0.01: # わずかな残りでも描画が崩れないように
			draw_arc(center, radius + 10.0, start_angle, end_angle, 64, ring_color, 8.0, true)

func _on_button_pressed() -> void:
	if not is_active:
		return
	is_active = false
	choice_selected.emit(current_type)
