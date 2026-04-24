extends Area2D

@export var speed: float = 90.0
@export var patrol_distance: float = 130.0

var direction: float = 1.0
var start_x: float = 0.0

@onready var sprite: ColorRect = $Sprite


func _ready() -> void:
	start_x = position.x
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	position.x += direction * speed * delta

	if position.x >= start_x + patrol_distance:
		position.x = start_x + patrol_distance
		direction = -1.0
	elif position.x <= start_x - patrol_distance:
		position.x = start_x - patrol_distance
		direction = 1.0

	sprite.scale.x = direction


func _on_body_entered(body: Node) -> void:
	if body.has_method("respawn"):
		body.call("respawn", "enemy")
