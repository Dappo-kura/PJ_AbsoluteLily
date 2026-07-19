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
var _hovered: bool = false
var _focused: bool = false
var _flash: float = 0.0

# UI References
@onready var button: Button = $Button
@onready var label: Label = $Button/Label

func _ready() -> void:
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	focus_entered.connect(_on_focus_entered)
	focus_exited.connect(_on_focus_exited)

func _process(delta: float) -> void:
	var should_redraw := false
	if is_active and current_time > 0.0:
		current_time -= delta
		current_time = maxf(current_time, 0.0)
		should_redraw = true

	if _flash > 0.0:
		_flash = maxf(_flash - delta * 6.0, 0.0)
		should_redraw = true

	if should_redraw:
		queue_redraw()

func setup(type: ChoiceType, text: String, remaining: float, total: float) -> void:
	current_type = type
	max_time = total
	current_time = remaining
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

func set_interactable(active: bool) -> void:
	is_active = active
	if not active and has_focus():
		release_focus()
	queue_redraw()

func _has_point(point: Vector2) -> bool:
	var center := size / 2.0
	var radius := minf(size.x, size.y) / 2.0 * 0.8
	return point.distance_to(center) <= radius + 10.0

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			_confirm_choice()
			accept_event()
			return

	if event.is_action_pressed("ui_accept"):
		_confirm_choice()
		accept_event()

func _draw() -> void:
	var center := size / 2.0
	var radius := minf(size.x, size.y) / 2.0 * 0.8 # 少し内側に本体を描画
	var display_color := base_color.lightened(0.12) if _hovered and is_active else base_color
	if not is_active:
		display_color = display_color.darkened(0.2)
	if _flash > 0.0:
		display_color = display_color.lerp(Color.WHITE, _flash * 0.45)
	
	# 背景の円を描画
	draw_circle(center, radius, display_color)

	# マウスオーバー中は本体のすぐ外側を細く強調する
	if _hovered and is_active:
		draw_arc(center, radius + 4.0, 0.0, TAU, 64, ring_color.lightened(0.25), 2.0, true)
	
	# 外側の残り時間プログレスバー（サークル）を描画
	if is_active and max_time > 0:
		var ratio := clampf(current_time / max_time, 0.0, 1.0)
		var start_angle := -PI / 2.0 # 12時の位置から開始
		var end_angle := start_angle + (TAU * ratio)
		
		# 円弧を描画（太めの線でプログレスバーを表現）
		if ratio > 0.01: # わずかな残りでも描画が崩れないように
			draw_arc(center, radius + 10.0, start_angle, end_angle, 64, ring_color, 8.0, true)

	# キーボードフォーカスは時間リングより外側へ太く描いて明示する
	if _focused and is_active:
		draw_arc(center, radius + 17.0, 0.0, TAU, 64, Color.WHITE.lerp(ring_color, 0.35), 4.0, true)

	# 確定直後は短いフラッシュリングを表示する
	if _flash > 0.0:
		draw_arc(center, radius + 10.0 + _flash * 8.0, 0.0, TAU, 64, Color(1.0, 1.0, 1.0, _flash), 3.0 + _flash * 3.0, true)

func _confirm_choice() -> void:
	if not is_active:
		return
	_flash = 1.0
	set_interactable(false)
	choice_selected.emit(current_type)

func _on_mouse_entered() -> void:
	_hovered = true
	queue_redraw()

func _on_mouse_exited() -> void:
	_hovered = false
	queue_redraw()

func _on_focus_entered() -> void:
	_focused = true
	queue_redraw()

func _on_focus_exited() -> void:
	_focused = false
	queue_redraw()
