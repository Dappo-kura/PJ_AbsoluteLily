# test_qte.gd - QTEシーン単体テスト用スクリプト
extends Node

var qte_scene = preload("res://scenes/game/qte.tscn")

func _ready() -> void:
	var qte = qte_scene.instantiate()
	add_child(qte)
	
	# 少し待ってから開始するテスト
	await get_tree().create_timer(1.0).timeout
	
	var test_data = {
		"duration": 4000, # 4秒
		"text": "生き延びろ！",
		"labels": ["逃げる！"] # これが生存(非エロ)ルートとして1つ生成される
	}
	
	qte.qte_completed.connect(_on_qte_completed)
	qte.start_qte(test_data)

func _on_qte_completed(success: bool) -> void:
	print("[Test] QTE Completed. Success: ", success)
	# もう一度テスト
	await get_tree().create_timer(2.0).timeout
	
	var qte = get_child(0)
	var test_data2 = {
		"duration": 4000, # 4秒
		"text": "触れろ！",
		"labels": ["キスする"] # EROTICルートとして1つ生成される
	}
	qte.start_qte(test_data2)
