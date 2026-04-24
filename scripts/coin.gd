extends Area2D

signal collected(value: int, world_position: Vector2)

@export var value: int = 1

var collected_once: bool = false

@onready var collision_shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if collected_once or not body.is_in_group("player"):
		return

	collected_once = true
	set_deferred("monitoring", false)
	collision_shape.set_deferred("disabled", true)
	visible = false
	collected.emit(value, global_position)
	queue_free()
