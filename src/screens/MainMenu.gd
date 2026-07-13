extends Control

class_name MainMenu

signal play_pressed
signal editor_pressed
signal settings_pressed


func _ready() -> void:
	pass


func _on_play_pressed() -> void:
	emit_signal("play_pressed")


func _on_editor_pressed() -> void:
	emit_signal("editor_pressed")


func _on_settings_pressed() -> void:
	emit_signal("settings_pressed")


func _on_quit_pressed() -> void:
	get_tree().quit()
