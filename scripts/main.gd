extends Node2D

const BURST_PIECES: int = 10
const STARTING_LIVES: int = 3
const LEVEL_SCENES: Array[PackedScene] = [
	preload("res://scenes/level_1.tscn"),
	preload("res://scenes/level_2.tscn"),
]
const MAIN_MENU_SCENE: PackedScene = preload("res://scenes/main_menu.tscn")
const TOTAL_COINS_TARGET: int = 8

var score: int = 0
var lives: int = STARTING_LIVES
var game_active: bool = false
var current_level_index: int = 0
var level_coin_total: int = 0
var level_coins_collected: int = 0
var menu_layer: CanvasLayer
var current_level_root: Node2D
var current_goal: Area2D
var shake_strength: float = 0.0

@onready var world: Node2D = $World
@onready var level_container: Node2D = $World/LevelContainer
@onready var player: CharacterBody2D = $World/Player
@onready var camera: Camera2D = $World/Player/Camera2D
@onready var audio_feedback: Node = $AudioFeedback
@onready var score_label: Label = $HUD/ScoreLabel
@onready var lives_label: Label = $HUD/LivesLabel
@onready var level_label: Label = $HUD/LevelLabel
@onready var message_label: Label = $HUD/MessageLabel
@onready var game_over_panel: ColorRect = $HUD/GameOverPanel
@onready var retry_button: Button = $HUD/GameOverPanel/RetryButton
@onready var game_over_quit_button: Button = $HUD/GameOverPanel/QuitButton
@onready var victory_panel: ColorRect = $HUD/VictoryPanel
@onready var victory_summary_label: Label = $HUD/VictoryPanel/SummaryLabel
@onready var victory_retry_button: Button = $HUD/VictoryPanel/PlayAgainButton
@onready var victory_quit_button: Button = $HUD/VictoryPanel/QuitButton


func _ready() -> void:
	if player.has_signal("respawned"):
		player.connect("respawned", Callable(self, "_on_player_respawned"))
	if player.has_signal("jumped"):
		player.connect("jumped", Callable(self, "_on_player_jumped"))

	retry_button.pressed.connect(_on_retry_pressed)
	game_over_quit_button.pressed.connect(_on_quit_pressed)
	victory_retry_button.pressed.connect(_on_retry_pressed)
	victory_quit_button.pressed.connect(_on_quit_pressed)

	_reset_run_state()
	_show_main_menu()


func _reset_run_state() -> void:
	score = 0
	lives = STARTING_LIVES
	current_level_index = 0
	game_over_panel.visible = false
	victory_panel.visible = false
	_update_score_label()
	_update_lives_label()
	message_label.text = "Press Start to begin."
	_set_level_label(current_level_index)


func _show_main_menu() -> void:
	menu_layer = MAIN_MENU_SCENE.instantiate() as CanvasLayer
	add_child(menu_layer)
	menu_layer.start_pressed.connect(_on_menu_start_pressed)
	menu_layer.quit_pressed.connect(_on_quit_pressed)
	_set_gameplay_active(false)


func _on_menu_start_pressed() -> void:
	_load_level(current_level_index)
	message_label.text = "Collect all coins to activate the exit."
	_set_gameplay_active(true)
	menu_layer.queue_free()


func _load_level(next_level_index: int) -> void:
	if current_level_root != null:
		current_level_root.queue_free()
		current_level_root = null

	current_level_root = LEVEL_SCENES[next_level_index].instantiate() as Node2D
	level_container.add_child(current_level_root)
	level_coins_collected = 0
	level_coin_total = 0

	var spawn_point: Marker2D = current_level_root.get_node("SpawnPoint") as Marker2D
	player.global_position = spawn_point.global_position
	player.velocity = Vector2.ZERO
	if player.has_method("set_spawn_position"):
		player.call("set_spawn_position", player.global_position)

	var coins: Array = _get_current_level_group_nodes("coins")
	level_coin_total = coins.size()
	for coin in coins:
		coin.connect("collected", Callable(self, "_on_coin_collected"))

	current_goal = current_level_root.get_node("Goal") as Area2D
	current_goal.connect("reached", Callable(self, "_on_goal_reached"))
	current_goal.call("set_active", false)

	_set_level_label(next_level_index)


func _get_current_level_group_nodes(group_name: String) -> Array:
	var result: Array = []
	for candidate in get_tree().get_nodes_in_group(group_name):
		if current_level_root.is_ancestor_of(candidate):
			result.append(candidate)
	return result


func _set_gameplay_active(next_active: bool) -> void:
	game_active = next_active
	player.set_physics_process(next_active)

	for hazard in _get_current_level_group_nodes("hazards"):
		hazard.set_physics_process(next_active)


func _on_coin_collected(value: int, world_position: Vector2) -> void:
	if not game_active:
		return

	score += value
	level_coins_collected += value
	audio_feedback.call("play_event", "coin")
	_update_score_label()
	_spawn_coin_burst(world_position)

	if level_coins_collected >= level_coin_total:
		current_goal.call("set_active", true)
		audio_feedback.call("play_event", "goal_unlocked")
		message_label.text = "Exit unlocked. Reach the green goal."


func _on_goal_reached() -> void:
	if not game_active:
		return

	if current_level_index < LEVEL_SCENES.size() - 1:
		audio_feedback.call("play_event", "level_transition")
		current_level_index += 1
		_load_level(current_level_index)
		message_label.text = "Level %d. Grab coins and find the exit." % [current_level_index + 1]
	else:
		_show_final_victory()


func _on_player_respawned(cause: String) -> void:
	if not game_active:
		return

	if cause != "enemy":
		message_label.text = "Watch your step."
		return

	lives -= 1
	_update_lives_label()
	audio_feedback.call("play_event", "hit")
	_shake_camera()

	if lives <= 0:
		_show_game_over()
	else:
		message_label.text = "Ouch. Keep going."


func _show_game_over() -> void:
	_set_gameplay_active(false)
	game_over_panel.visible = true
	message_label.text = "Game over."


func _show_final_victory() -> void:
	_set_gameplay_active(false)
	victory_panel.visible = true
	audio_feedback.call("play_event", "victory")
	victory_summary_label.text = (
		"Finished both levels with %d / %d coins." % [score, TOTAL_COINS_TARGET]
	)
	message_label.text = "Final victory!"


func _on_retry_pressed() -> void:
	get_tree().reload_current_scene()


func _on_quit_pressed() -> void:
	get_tree().quit()


func _update_score_label() -> void:
	score_label.text = "Coins: %d / %d" % [score, TOTAL_COINS_TARGET]
	_pulse_score_label()


func _update_lives_label() -> void:
	lives_label.text = "Lives: %d" % lives


func _set_level_label(level_index: int) -> void:
	level_label.text = "Level %d" % [level_index + 1]


func _on_player_jumped() -> void:
	audio_feedback.call("play_event", "jump")


func _pulse_score_label() -> void:
	var tween := create_tween()
	tween.tween_property(score_label, "scale", Vector2(1.12, 1.12), 0.07)
	tween.tween_property(score_label, "scale", Vector2.ONE, 0.12)


func _shake_camera() -> void:
	var tween := create_tween()
	shake_strength = 14.0
	tween.tween_property(self, "shake_strength", 0.0, 0.24)


func _process(_delta: float) -> void:
	if shake_strength <= 0.01:
		camera.offset = Vector2.ZERO
		return

	camera.offset = Vector2(
		randf_range(-shake_strength, shake_strength),
		randf_range(-shake_strength, shake_strength),
	)


func _spawn_coin_burst(world_position: Vector2) -> void:
	for index in range(BURST_PIECES):
		var piece := Polygon2D.new()
		var size: float = 4.0 + float(index % 3)
		piece.polygon = PackedVector2Array(
			[
				Vector2(-size, -size),
				Vector2(size, 0.0),
				Vector2(-size, size),
			]
		)
		piece.color = Color(1.0, 0.86, 0.22, 1.0)
		piece.position = world_position
		piece.z_index = 20
		world.add_child(piece)

		var angle: float = TAU * float(index) / float(BURST_PIECES)
		var distance: float = 28.0 + float(index % 4) * 7.0
		var target_position: Vector2 = world_position + Vector2.RIGHT.rotated(angle) * distance
		var tween := create_tween()
		tween.set_parallel(true)
		(
			tween
			. tween_property(piece, "position", target_position, 0.38)
			. set_trans(Tween.TRANS_QUAD)
			. set_ease(Tween.EASE_OUT)
		)
		tween.tween_property(piece, "modulate:a", 0.0, 0.38)
		tween.chain().tween_callback(Callable(piece, "queue_free"))
