extends Label

@export var player_path: NodePath = NodePath("../../World/Player")

@onready var player: CharacterBody2D = get_node_or_null(player_path) as CharacterBody2D


func _process(_delta: float) -> void:
	if player == null:
		player = get_node_or_null(player_path) as CharacterBody2D

	text = "FPS: %d" % Engine.get_frames_per_second()

	if player != null:
		text += (
			"\nPlayer: %.0f, %.0f"
			% [
				player.global_position.x,
				player.global_position.y,
			]
		)
		text += (
			"\nVelocity: %.0f, %.0f"
			% [
				player.velocity.x,
				player.velocity.y,
			]
		)
