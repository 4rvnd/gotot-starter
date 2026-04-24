extends Area2D

signal reached

@onready var sprite: ColorRect = $Sprite
@onready var collision_shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	set_active(false)


func set_active(next_active: bool) -> void:
	monitoring = next_active
	collision_shape.disabled = not next_active
	sprite.color = Color(0.2, 0.9, 0.35, 1.0) if next_active else Color(0.28, 0.28, 0.32, 1.0)


func _on_body_entered(body: Node) -> void:
	if monitoring and body.is_in_group("player"):
		reached.emit()
