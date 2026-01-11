# CommandExecutor - 演出コマンド実行
extends Node

signal command_completed(command_type: String)

@onready var screen_effects: CanvasLayer

var active_tweens: Array[Tween] = []

func _ready() -> void:
	ScenarioManager.command_executed.connect(_on_command_executed)
	print("[CommandExecutor] Initialized")

func set_screen_effects(effects_node: CanvasLayer) -> void:
	screen_effects = effects_node

func _on_command_executed(command: Dictionary) -> void:
	var cmd_type = command.get("type", "")
	match cmd_type:
		"fade_in":
			execute_fade_in(command)
		"fade_out":
			execute_fade_out(command)
		"shake":
			execute_shake(command)
		"flash":
			execute_flash(command)
		"glitch":
			execute_glitch(command)
		"wait":
			execute_wait(command)
		"char_move":
			execute_char_move(command)
		_:
			print("[CommandExecutor] Unknown command: %s" % cmd_type)

func execute_fade_in(command: Dictionary) -> void:
	var duration = command.get("duration", 1.0)
	var color = Color(command.get("color", "black"))
	
	if screen_effects:
		var overlay = screen_effects.get_node_or_null("FadeOverlay")
		if overlay:
			overlay.color = color
			overlay.modulate.a = 1.0
			var tween = create_tween()
			tween.tween_property(overlay, "modulate:a", 0.0, duration)
			tween.tween_callback(func(): command_completed.emit("fade_in"))

func execute_fade_out(command: Dictionary) -> void:
	var duration = command.get("duration", 1.0)
	var color = Color(command.get("color", "black"))
	
	if screen_effects:
		var overlay = screen_effects.get_node_or_null("FadeOverlay")
		if overlay:
			overlay.color = color
			overlay.modulate.a = 0.0
			var tween = create_tween()
			tween.tween_property(overlay, "modulate:a", 1.0, duration)
			tween.tween_callback(func(): command_completed.emit("fade_out"))

func execute_shake(command: Dictionary) -> void:
	var duration = command.get("duration", 0.5)
	var strength = command.get("strength", 10.0)
	
	if screen_effects:
		var original_pos = screen_effects.offset
		var tween = create_tween()
		var shake_count = int(duration * 20)
		
		for i in shake_count:
			var offset = Vector2(
				randf_range(-strength, strength),
				randf_range(-strength, strength)
			)
			tween.tween_property(screen_effects, "offset", offset, 0.05)
		
		tween.tween_property(screen_effects, "offset", original_pos, 0.05)
		tween.tween_callback(func(): command_completed.emit("shake"))

func execute_flash(command: Dictionary) -> void:
	var duration = command.get("duration", 0.3)
	var color_name = command.get("color", "white")
	var color = Color.WHITE if color_name == "white" else Color.RED
	
	if screen_effects:
		var overlay = screen_effects.get_node_or_null("FlashOverlay")
		if overlay:
			overlay.color = color
			overlay.modulate.a = 0.0
			var tween = create_tween()
			tween.tween_property(overlay, "modulate:a", 0.8, duration * 0.3)
			tween.tween_property(overlay, "modulate:a", 0.0, duration * 0.7)
			tween.tween_callback(func(): command_completed.emit("flash"))

func execute_glitch(command: Dictionary) -> void:
	var duration = command.get("duration", 1.0)
	# グリッチシェーダーの適用はscreen_effectsで行う
	if screen_effects:
		var glitch = screen_effects.get_node_or_null("GlitchEffect")
		if glitch:
			glitch.visible = true
			get_tree().create_timer(duration).timeout.connect(func():
				glitch.visible = false
				command_completed.emit("glitch")
			)

func execute_wait(command: Dictionary) -> void:
	var duration = command.get("duration", 1.0)
	get_tree().create_timer(duration).timeout.connect(func():
		command_completed.emit("wait")
	)

func execute_char_move(_command: Dictionary) -> void:
	# キャラクター移動は NovelUI で処理
	command_completed.emit("char_move")

func cancel_all() -> void:
	for tween in active_tweens:
		if tween and tween.is_valid():
			tween.kill()
	active_tweens.clear()
