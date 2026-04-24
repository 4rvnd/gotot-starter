extends Node2D

const BURST_PIECES: int = 10

var score: int = 0
var total_coins: int = 0

@onready var world: Node2D = $World
@onready var player: CharacterBody2D = $World/Player
@onready var score_label: Label = $HUD/ScoreLabel
@onready var message_label: Label = $HUD/MessageLabel


func _ready() -> void:
	if player.has_method("set_spawn_position"):
		player.call("set_spawn_position", player.global_position)

	if player.has_signal("respawned"):
		player.connect("respawned", Callable(self, "_on_player_respawned"))

	var coins: Array = get_tree().get_nodes_in_group("coins")
	total_coins = coins.size()

	for coin in coins:
		if coin.has_signal("collected"):
			coin.connect("collected", Callable(self, "_on_coin_collected"))

	_update_score_label()
	message_label.text = "Collect every coin. Avoid the red patrol."


func _on_coin_collected(value: int, world_position: Vector2) -> void:
	score += value
	_update_score_label()
	_spawn_coin_burst(world_position)

	if score >= total_coins:
		message_label.text = "All coins collected. Nice run."


func _on_player_respawned() -> void:
	message_label.text = "Careful. The red patrol sends you back."


func _update_score_label() -> void:
	score_label.text = "Coins: %d / %d" % [score, total_coins]


func _spawn_coin_burst(world_position: Vector2) -> void:
	for index in range(BURST_PIECES):
		var piece := Polygon2D.new()
		var size: float = 4.0 + float(index % 3)
		piece.polygon = PackedVector2Array([
			Vector2(-size, -size),
			Vector2(size, 0.0),
			Vector2(-size, size),
		])
		piece.color = Color(1.0, 0.86, 0.22, 1.0)
		piece.position = world_position
		piece.z_index = 20
		world.add_child(piece)

		var angle: float = TAU * float(index) / float(BURST_PIECES)
		var distance: float = 28.0 + float(index % 4) * 7.0
		var target_position: Vector2 = world_position + Vector2.RIGHT.rotated(angle) * distance
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(piece, "position", target_position, 0.38).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(piece, "modulate:a", 0.0, 0.38)
		tween.chain().tween_callback(Callable(piece, "queue_free"))
