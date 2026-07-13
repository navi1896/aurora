extends Control

class_name Results

@onready var scene_manager: SceneManager = get_tree().root.get_node("App/SceneManager")


func _ready() -> void:
	var label = Label.new()
	label.text = "Results - En desarrollo"
	label.anchor_left = 0.5
	label.anchor_top = 0.5
	label.offset_left = -100
	label.offset_top = -20
	add_child(label)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			scene_manager.load_scene("song_select")
			get_tree().root.set_input_as_handled()
