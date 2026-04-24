extends CharacterBody2D

signal respawned

const SPEED: float = 300.0
const ACCELERATION: float = 1800.0
const AIR_ACCELERATION: float = 900.0
const FRICTION: float = 2200.0
const JUMP_VELOCITY: float = -510.0
const GRAVITY: float = 1350.0
const FALL_LIMIT_Y: float = 860.0

var spawn_position: Vector2

@onready var sprite: ColorRect = $Sprite


func _ready() -> void:
	add_to_group("player")
	spawn_position = global_position


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += GRAVITY * delta

	if is_on_floor() and _jump_pressed():
		velocity.y = JUMP_VELOCITY

	var direction: float = Input.get_axis("ui_left", "ui_right")
	var target_speed: float = direction * SPEED
	var accel: float = ACCELERATION if is_on_floor() else AIR_ACCELERATION

	if is_zero_approx(direction):
		velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)
	else:
		velocity.x = move_toward(velocity.x, target_speed, accel * delta)

	move_and_slide()

	if not is_zero_approx(direction):
		sprite.scale.x = sign(direction)

	if global_position.y > FALL_LIMIT_Y:
		respawn()

	if Engine.get_frames_drawn() % 90 == 0:
		print("Player pos: %s | on_floor: %s | velocity: %s" % [
			global_position,
			is_on_floor(),
			velocity,
		])


func set_spawn_position(next_spawn_position: Vector2) -> void:
	spawn_position = next_spawn_position


func respawn() -> void:
	global_position = spawn_position
	velocity = Vector2.ZERO
	respawned.emit()


func _jump_pressed() -> bool:
	return (
		Input.is_action_just_pressed("ui_accept")
		or Input.is_action_just_pressed("ui_select")
	)
