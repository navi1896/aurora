extends Node

class_name InputManager

signal button_pressed(button_name: String)


func _ready() -> void:
	pass


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_ESCAPE:
				emit_signal("button_pressed", "back")
			KEY_ENTER:
				emit_signal("button_pressed", "confirm")
			KEY_UP:
				emit_signal("button_pressed", "up")
			KEY_DOWN:
				emit_signal("button_pressed", "down")
			KEY_LEFT:
				emit_signal("button_pressed", "left")
			KEY_RIGHT:
				emit_signal("button_pressed", "right")
