extends Node2D

const BURST_PIECES: int = 10
const STARTING_LIVES: int = 3
const MAIN_MENU_SCENE: PackedScene = preload("res://scenes/main_menu.tscn")

var score: int = 0
var total_coins: int = 0
var lives: int = STARTING_LIVES
var game_active: bool = false
var menu_layer: CanvasLayer

@onready var world: Node2D = $World
@onready var player: CharacterBody2D = $World/Player
@onready var score_label: Label = $HUD/ScoreLabel
@onready var lives_label: Label = $HUD/LivesLabel
@onready var message_label: Label = $HUD/MessageLabel
@onready var game_over_panel: ColorRect = $HUD/GameOverPanel
@onready var retry_button: Button = $HUD/GameOverPanel/RetryButton
@onready var game_over_quit_button: Button = $HUD/GameOverPanel/QuitButton
@onready var victory_panel: ColorRect = $HUD/VictoryPanel
@onready var victory_retry_button: Button = $HUD/VictoryPanel/PlayAgainButton
@onready var victory_quit_button: Button = $HUD/VictoryPanel/QuitButton


func _ready() -> void:
	if player.has_method("set_spawn_position"):
		player.call("set_spawn_position", player.global_position)

	if player.has_signal("respawned"):
		player.connect("respawned", Callable(self, "_on_player_respawned"))

	retry_button.pressed.connect(_on_retry_pressed)
	game_over_quit_button.pressed.connect(_on_quit_pressed)
	victory_retry_button.pressed.connect(_on_retry_pressed)
	victory_quit_button.pressed.connect(_on_quit_pressed)

	_connect_coin_signals()
	_reset_run_state()
	_show_main_menu()


func _connect_coin_signals() -> void:
	var coins: Array = get_tree().get_nodes_in_group("coins")
	total_coins = coins.size()

	for coin in coins:
		if coin.has_signal("collected"):
			coin.connect("collected", Callable(self, "_on_coin_collected"))


func _reset_run_state() -> void:
	score = 0
	lives = STARTING_LIVES
	game_over_panel.visible = false
	victory_panel.visible = false
	_update_score_label()
	_update_lives_label()
	message_label.text = "Press Start to begin."


func _show_main_menu() -> void:
	menu_layer = MAIN_MENU_SCENE.instantiate() as CanvasLayer
	add_child(menu_layer)
	menu_layer.start_pressed.connect(_on_menu_start_pressed)
	menu_layer.quit_pressed.connect(_on_quit_pressed)
	_set_gameplay_active(false)


func _set_gameplay_active(next_active: bool) -> void:
	game_active = next_active
	player.set_physics_process(next_active)

	for hazard in get_tree().get_nodes_in_group("hazards"):
		hazard.set_physics_process(next_active)


func _on_menu_start_pressed() -> void:
	message_label.text = "Collect every coin. Avoid patrols, chasers, and hoppers."
	_set_gameplay_active(true)
	menu_layer.queue_free()


func _on_coin_collected(value: int, world_position: Vector2) -> void:
	if not game_active:
		return

	score += value
	_update_score_label()
	_spawn_coin_burst(world_position)

	if score >= total_coins:
		_show_victory()


func _on_player_respawned(cause: String) -> void:
	if not game_active:
		return

	if cause != "enemy":
		message_label.text = "Watch your step."
		return

	lives -= 1
	_update_lives_label()

	if lives <= 0:
		_show_game_over()
	else:
		message_label.text = "Ouch. Keep going."


func _show_game_over() -> void:
	_set_gameplay_active(false)
	game_over_panel.visible = true
	message_label.text = "Game over."


func _show_victory() -> void:
	_set_gameplay_active(false)
	victory_panel.visible = true
	message_label.text = "Victory! You collected every coin."


func _on_retry_pressed() -> void:
	get_tree().reload_current_scene()


func _on_quit_pressed() -> void:
	get_tree().quit()


func _update_score_label() -> void:
	score_label.text = "Coins: %d / %d" % [score, total_coins]


func _update_lives_label() -> void:
	lives_label.text = "Lives: %d" % lives


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
