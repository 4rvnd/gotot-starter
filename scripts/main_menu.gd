extends CanvasLayer

signal start_pressed
signal quit_pressed

@onready var start_button: Button = $Overlay/Panel/StartButton
@onready var quit_button: Button = $Overlay/Panel/QuitButton


func _ready() -> void:
	start_button.pressed.connect(_on_start_button_pressed)
	quit_button.pressed.connect(_on_quit_button_pressed)


func _on_start_button_pressed() -> void:
	start_pressed.emit()


func _on_quit_button_pressed() -> void:
	quit_pressed.emit()
