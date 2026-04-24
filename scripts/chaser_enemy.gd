extends Area2D

@export var player_path: NodePath
@export var speed: float = 120.0
@export var aggro_range: float = 210.0
@export var return_speed: float = 90.0

var home_position: Vector2

@onready var sprite: ColorRect = $Sprite
@onready var player: CharacterBody2D = get_node_or_null(player_path)


func _ready() -> void:
	home_position = global_position
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	if player == null:
		return

	var to_player: Vector2 = player.global_position - global_position
	var chase_player: bool = to_player.length() <= aggro_range
	var desired_velocity: Vector2 = Vector2.ZERO

	if chase_player and not to_player.is_zero_approx():
		desired_velocity = to_player.normalized() * speed
	else:
		var to_home: Vector2 = home_position - global_position
		if not to_home.is_zero_approx():
			desired_velocity = to_home.normalized() * return_speed

	global_position += desired_velocity * delta

	if not is_zero_approx(desired_velocity.x):
		sprite.scale.x = sign(desired_velocity.x)


func _on_body_entered(body: Node) -> void:
	_flash_hit_feedback()
	if body.has_method("respawn"):
		body.call("respawn", "enemy")


func _flash_hit_feedback() -> void:
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color(1.0, 0.6, 0.6, 1.0), 0.06)
	tween.tween_property(sprite, "modulate", Color(1, 1, 1, 1), 0.12)
