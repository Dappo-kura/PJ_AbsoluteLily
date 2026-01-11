# AudioManager - BGM/SE管理
extends Node

var bgm_player: AudioStreamPlayer
var se_players: Array[AudioStreamPlayer] = []
var current_bgm: String = ""

var bgm_volume: float = 0.5
var se_volume: float = 0.7

const MAX_SE_PLAYERS = 8
const FADE_DURATION = 2.0

func _ready() -> void:
	# BGMプレイヤー作成
	bgm_player = AudioStreamPlayer.new()
	bgm_player.bus = "Master"
	add_child(bgm_player)
	
	# SEプレイヤープール作成
	for i in MAX_SE_PLAYERS:
		var player = AudioStreamPlayer.new()
		player.bus = "Master"
		add_child(player)
		se_players.append(player)
	
	print("[AudioManager] Initialized")

func play_bgm(bgm_name: String, fade_in: bool = true) -> void:
	if bgm_name == current_bgm and bgm_player.playing:
		return
	
	var path = "res://assets/audio/%s" % bgm_name
	if not bgm_name.ends_with(".mp3") and not bgm_name.ends_with(".ogg"):
		path += ".mp3"
	
	if not ResourceLoader.exists(path):
		push_warning("[AudioManager] BGM not found: %s" % path)
		return
	
	var stream = load(path)
	if stream:
		if fade_in and bgm_player.playing:
			# クロスフェード
			var tween = create_tween()
			tween.tween_property(bgm_player, "volume_db", -80.0, FADE_DURATION)
			await tween.finished
		
		bgm_player.stream = stream
		bgm_player.volume_db = -80.0 if fade_in else linear_to_db(bgm_volume)
		bgm_player.play()
		current_bgm = bgm_name
		
		if fade_in:
			var tween = create_tween()
			tween.tween_property(bgm_player, "volume_db", linear_to_db(bgm_volume), FADE_DURATION)
		
		print("[AudioManager] Playing BGM: %s" % bgm_name)

func stop_bgm(fade_out: bool = true) -> void:
	if not bgm_player.playing:
		return
	
	if fade_out:
		var tween = create_tween()
		tween.tween_property(bgm_player, "volume_db", -80.0, FADE_DURATION)
		await tween.finished
	
	bgm_player.stop()
	current_bgm = ""

func play_se(se_name: String, volume_scale: float = 1.0, pitch_scale: float = 1.0) -> void:
	var path = "res://assets/audio/%s" % se_name
	if not se_name.ends_with(".mp3") and not se_name.ends_with(".ogg") and not se_name.ends_with(".wav"):
		path += ".wav"
	
	if not ResourceLoader.exists(path):
		push_warning("[AudioManager] SE not found: %s" % path)
		return
	
	var stream = load(path)
	if stream:
		var player = get_available_se_player()
		if player:
			player.stream = stream
			player.volume_db = linear_to_db(se_volume * volume_scale)
			player.pitch_scale = pitch_scale
			player.play()
			print("[AudioManager] Playing SE: %s" % se_name)

func get_available_se_player() -> AudioStreamPlayer:
	for player in se_players:
		if not player.playing:
			return player
	# 全て使用中の場合は最初のプレイヤーを再利用
	return se_players[0]

func set_bgm_volume(volume: float) -> void:
	bgm_volume = clamp(volume, 0.0, 1.0)
	if bgm_player.playing:
		bgm_player.volume_db = linear_to_db(bgm_volume)

func set_se_volume(volume: float) -> void:
	se_volume = clamp(volume, 0.0, 1.0)

func linear_to_db(linear: float) -> float:
	if linear <= 0.0:
		return -80.0
	return 20.0 * log(linear) / log(10.0)
