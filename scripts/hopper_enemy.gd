extends Area2D

@export var hop_height: float = 54.0
@export var hop_speed: float = 2.2
@export var drift_frequency: float = 0.45
@export var drift_range: float = 120.0

var base_position: Vector2
var elapsed: float = 0.0

@onready var sprite: ColorRect = $Sprite


func _ready() -> void:
	base_position = global_position
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	elapsed += delta
	var hop_phase: float = sin(elapsed * TAU * hop_speed)
	var drift_phase: float = sin(elapsed * TAU * drift_frequency)
	global_position = (
		base_position + Vector2(drift_phase * drift_range, -abs(hop_phase) * hop_height)
	)
	sprite.scale.x = -1.0 if drift_phase < 0.0 else 1.0


func _on_body_entered(body: Node) -> void:
	_flash_hit_feedback()
	if body.has_method("respawn"):
		body.call("respawn", "enemy")


func _flash_hit_feedback() -> void:
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color(1.0, 0.6, 0.6, 1.0), 0.06)
	tween.tween_property(sprite, "modulate", Color(1, 1, 1, 1), 0.12)
